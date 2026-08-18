#!/bin/bash
D=/root/recovery
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

terraform state list 2>/dev/null | grep -q "aws_vpc.main" || { echo "FAIL: aws_vpc.main is not in state"; exit 1; }
terraform state list 2>/dev/null | grep -q "aws_subnet.app" || { echo "FAIL: aws_subnet.app is not in state"; exit 1; }

# Drift resolved means the plan is quiet - in whichever direction the learner
# chose. Both are correct; leaving them disagreeing is not.
terraform plan -detailed-exitcode -input=false >/tmp/v1.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: the plan still reports pending changes - the drift is unresolved"
  grep -E "will be|^  [~+-]" /tmp/v1.out | head -5
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/v1.out; exit 1; }

# And the VPC still has to be the same one. A drift "fix" that recreated it
# would also produce a quiet plan.
VPC=$(terraform state show aws_vpc.main 2>/dev/null | grep -E "^ *id " | head -1 | cut -d'"' -f2)
[ -n "$VPC" ] || { echo "FAIL: no VPC id in state"; exit 1; }
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs --vpc-ids "$VPC" >/dev/null 2>&1 || {
  echo "FAIL: the VPC in state ($VPC) does not exist in the account"; exit 1; }

echo "PASS - drift resolved, plan quiet, and $VPC is the original VPC"
exit 0
