#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

[ -d .terraform ] || { echo "FAIL: terraform init has not been run in $DIR"; exit 1; }

# A pinned provider is the difference between reproducible and "worked on my
# machine last month".
grep -rq 'version *= *"~> *5' *.tf 2>/dev/null || {
  echo "FAIL: the aws provider is not pinned to a major version"; exit 1; }

for V in instance_type region bucket_name; do
  grep -rq "variable \"$V\"" *.tf 2>/dev/null || { echo "FAIL: no variable \"$V\""; exit 1; }
done

# Typed and described, or the variable is a comment with a default.
grep -A4 'variable "instance_type"' *.tf 2>/dev/null | grep -q "type *= *string" || {
  echo "FAIL: the instance_type variable has no type"; exit 1; }

grep -rq "validation" *.tf 2>/dev/null || {
  echo "FAIL: no validation block - a typo in environment would reach AWS"; exit 1; }

# The validation must actually reject a bad value, not merely be present.
OUT=$(terraform plan -var environment=production -input=false 2>&1)
echo "$OUT" | grep -qi "invalid value\|must be dev" || {
  echo "FAIL: environment=production was not rejected by the validation block"; exit 1; }

echo "PASS - provider pinned, variables typed, and a bad environment is rejected"
exit 0
