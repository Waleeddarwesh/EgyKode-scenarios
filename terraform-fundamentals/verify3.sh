#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

# The criterion is that a second apply reports no changes. -detailed-exitcode
# is the same comparison with a number instead of prose.
terraform plan -detailed-exitcode -input=false >/tmp/p.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: the plan still wants to make changes, so a second apply would not be a no-op"
  grep -E "will be|must be" /tmp/p.out | head -4
  echo "      Apply once more so reality matches the configuration."
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/p.out; exit 1; }

[ -f terraform.tfstate ] || { echo "FAIL: no terraform.tfstate"; exit 1; }

# State must map the resource to a real id. Reading the id out of state and
# resolving it against the API is the criterion, and it is also the check that
# would catch state describing an instance somebody deleted by hand.
ID=$(terraform state show aws_instance.app 2>/dev/null | grep -E "^ *id " | head -1 | cut -d'"' -f2)
[ -n "$ID" ] || { echo "FAIL: no id for aws_instance.app in state"; exit 1; }
echo "$ID" | grep -q "^i-" || { echo "FAIL: the id in state is '$ID', which is not an instance id"; exit 1; }

STATE_NAME=$($AWS ec2 describe-instances --instance-ids "$ID" \
  --query 'Reservations[].Instances[].State.Name' --output text 2>/dev/null)
[ "$STATE_NAME" = "running" ] || {
  echo "FAIL: state records $ID but the account reports its state as '${STATE_NAME:-absent}'"
  exit 1; }

# The state file must also be the local one, since the destroy step reads it.
grep -q "\"$ID\"" terraform.tfstate || {
  echo "FAIL: $ID does not appear in terraform.tfstate"; exit 1; }

echo "PASS - no pending changes, and state maps aws_instance.app to $ID"
exit 0
