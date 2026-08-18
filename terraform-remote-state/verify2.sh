#!/bin/bash
EP=http://localhost:4566
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

grep -rq 'backend "s3"' *.tf 2>/dev/null || { echo "FAIL: no s3 backend is declared"; exit 1; }

# The state object has to be in the bucket. A declared backend that was never
# initialised leaves the configuration looking right and the state on disk.
curl -s --max-time 10 $EP/egykode-tfstate/ 2>/dev/null | grep -q "<Key>platform/terraform.tfstate</Key>" || {
  echo "FAIL: no platform/terraform.tfstate object in the bucket"
  echo "      terraform init -migrate-state -force-copy"
  exit 1; }

# ...and not on disk. This is the half of the criterion people skip.
[ ! -f terraform.tfstate ] || {
  echo "FAIL: terraform.tfstate is still in the working directory - delete the leftover from the migration"
  exit 1; }

# Nothing may have been destroyed and recreated. A migration that lost track of
# the resources produces a plan wanting to create them all over again.
terraform plan -detailed-exitcode -input=false >/tmp/p.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: the plan wants to make changes - the migration did not carry the resources across"
  grep -E "will be (created|destroyed)" /tmp/p.out | head -5
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/p.out; exit 1; }

COUNT=$(terraform state list 2>/dev/null | grep -c .)
[ "$COUNT" -ge 5 ] || { echo "FAIL: only $COUNT resources in state, expected at least 5"; exit 1; }

echo "PASS - state is in S3, nothing local, $COUNT resources intact and no pending changes"
exit 0
