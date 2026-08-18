#!/bin/bash
EP=http://localhost:4566
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

grep -rq "terraform_data" *.tf 2>/dev/null || {
  echo "FAIL: the slow resource is not declared - there is nothing to race against"; exit 1; }

terraform state list 2>/dev/null | grep -q "terraform_data.slow_step" || {
  echo "FAIL: terraform_data.slow_step is not in state - the first apply has not completed"; exit 1; }

# The lock must be released. Counting rows is not the test: the table always
# holds a permanent "<key>-md5" digest item that is not a lock. Only a real
# lock carries an Info attribute.
LOCK=$(curl -s --max-time 10 -X POST $EP/ \
  -H "X-Amz-Target: DynamoDB_20120810.Scan" \
  -H "Content-Type: application/x-amz-json-1.0" \
  -d '{"TableName":"egykode-tfstate-locks"}' 2>/dev/null)
HELD=$(echo "$LOCK" | grep -o '"Info"' | grep -c .)
[ "${HELD:-0}" -eq 0 ] || {
  echo "FAIL: ${HELD} lock(s) still held - an apply is running, or a lock is stale"
  echo "      Wait for it to finish, or see the next step."
  exit 1; }

# And the run that lost the race must have changed nothing.
terraform plan -detailed-exitcode -input=false >/tmp/p3.out 2>&1
CODE=$?
[ "$CODE" -eq 0 ] || {
  echo "FAIL: terraform plan exits $CODE - state and configuration disagree after the race"
  grep -E "will be" /tmp/p3.out | head -4
  exit 1; }

echo "PASS - the slow resource applied once, the lock is released, and state is consistent"
exit 0
