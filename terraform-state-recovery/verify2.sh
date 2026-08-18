#!/bin/bash
D=/root/recovery
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

terraform state list 2>/dev/null | grep -q "aws_security_group" || {
  echo "FAIL: no security group in state - it has not been imported"; exit 1; }

# The imported resource must be the one that already existed, not a second one
# Terraform created because the import was skipped.
COUNT=$($AWS ec2 describe-security-groups --filters Name=group-name,Values=emergency-access \
  --query 'SecurityGroups[].GroupId' --output text 2>/dev/null | wc -w)
[ "$COUNT" -eq 1 ] || {
  echo "FAIL: there are $COUNT security groups named emergency-access, expected 1"
  echo "      Applying instead of importing creates a duplicate rather than adopting the original."
  exit 1; }

REAL=$($AWS ec2 describe-security-groups --filters Name=group-name,Values=emergency-access \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
IN_STATE=$(terraform state show aws_security_group.emergency 2>/dev/null | grep -E "^ *id " | head -1 | cut -d'"' -f2)
[ "$REAL" = "$IN_STATE" ] || {
  echo "FAIL: state holds '$IN_STATE' but the account has '$REAL'"; exit 1; }

# An import is finished when the plan is quiet. Exit 2 means the configuration
# and the adopted resource disagree, and the next apply would edit something
# somebody is relying on.
terraform plan -detailed-exitcode -input=false >/tmp/v2.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: the plan wants to change the imported resource - the configuration does not match reality"
  grep -E "^  [~+-]|will be" /tmp/v2.out | head -5
  echo "      Change the configuration to match the resource, not the other way round."
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/v2.out; exit 1; }

echo "PASS - $REAL adopted into state and the plan is quiet"
exit 0
