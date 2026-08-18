#!/bin/bash
EP=http://localhost:4566
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

# No lock may be held. The -md5 digest item is permanent and is not a lock, so
# only items carrying Info count.
LOCK=$(curl -s --max-time 10 -X POST $EP/ \
  -H "X-Amz-Target: DynamoDB_20120810.Scan" \
  -H "Content-Type: application/x-amz-json-1.0" \
  -d '{"TableName":"egykode-tfstate-locks"}' 2>/dev/null)
HELD=$(echo "$LOCK" | grep -o '"Info"' | grep -c .)
[ "${HELD:-0}" -eq 0 ] || {
  echo "FAIL: a lock is still held - release it with terraform force-unlock <ID>"
  exit 1; }

# The digest item must still be there. Deleting the whole table, or clearing
# every row, also makes the check above pass - and throws away the consistency
# record along with the lock.
echo "$LOCK" | grep -q '\-md5' || {
  echo "FAIL: the state digest item is gone - the table was cleared rather than the lock released"
  exit 1; }

# Terraform must actually run again, which is the point of releasing a lock.
terraform plan -detailed-exitcode -input=false >/tmp/p4.out 2>&1
CODE=$?
[ "$CODE" -ne 1 ] || {
  echo "FAIL: terraform plan still errors:"
  grep -iE "error|lock" /tmp/p4.out | head -4
  exit 1; }

# State must still be intact - force-unlock releases a lock, it does not
# discard state, and a scenario that lost the resources here would be teaching
# the wrong recovery.
COUNT=$(terraform state list 2>/dev/null | grep -c .)
[ "$COUNT" -ge 6 ] || { echo "FAIL: only $COUNT resources in state, expected at least 6"; exit 1; }

echo "PASS - no lock held, digest intact, Terraform runs and $COUNT resources are still tracked"
exit 0
