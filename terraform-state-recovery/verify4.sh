#!/bin/bash
D=/root/recovery
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

terraform state list 2>/dev/null | grep -q "aws_subnet.application" || {
  echo "FAIL: aws_subnet.application is not in state - the rename has not been applied"; exit 1; }
terraform state list 2>/dev/null | grep -q "aws_subnet.app$" && {
  echo "FAIL: aws_subnet.app is still in state alongside the new address"; exit 1; }

grep -q "moved {" main.tf 2>/dev/null || {
  echo "FAIL: no moved block in main.tf"
  echo "      terraform state mv would rename it here and leave every colleague with the destroy."
  exit 1; }

# The renamed resource must be the original subnet. A destroy-and-recreate also
# ends with one subnet named application, and it is the wrong one.
COUNT=$($AWS ec2 describe-subnets --filters Name=tag:Name,Values=recovery-app \
  --query 'Subnets[].SubnetId' --output text 2>/dev/null | wc -w)
[ "$COUNT" -eq 1 ] || { echo "FAIL: $COUNT subnets tagged recovery-app exist, expected 1"; exit 1; }

REAL=$($AWS ec2 describe-subnets --filters Name=tag:Name,Values=recovery-app \
  --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
IN_STATE=$(terraform state show aws_subnet.application 2>/dev/null | grep -E "^ *id " | head -1 | cut -d'"' -f2)
[ "$REAL" = "$IN_STATE" ] || { echo "FAIL: state holds '$IN_STATE', the account has '$REAL'"; exit 1; }

terraform plan -detailed-exitcode -input=false >/tmp/v4.out 2>&1
CODE=$?
[ "$CODE" -eq 0 ] || {
  echo "FAIL: terraform plan exits $CODE after the move"
  grep -E "will be|^  [~+-]" /tmp/v4.out | head -4
  exit 1; }

# All four resources still present, which is the "nothing was destroyed"
# criterion for the scenario as a whole.
TOTAL=$(terraform state list 2>/dev/null | grep -c .)
[ "$TOTAL" -ge 3 ] || { echo "FAIL: state lists $TOTAL resources, expected at least 3"; exit 1; }

echo "PASS - renamed in state only; $REAL is the original subnet and the plan is quiet"
exit 0
