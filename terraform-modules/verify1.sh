#!/bin/bash
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"
M=modules/network

for F in main.tf variables.tf outputs.tf; do
  [ -f "$M/$F" ] || { echo "FAIL: no $M/$F"; exit 1; }
done

# Everything environment-specific must arrive through a variable. A module with
# its CIDR written into it is a directory, not a module.
grep -q "var.cidr_block" "$M/main.tf" || {
  echo "FAIL: the VPC does not take its CIDR from var.cidr_block"; exit 1; }
grep -qE '"10\.[0-9]+\.[0-9]+\.[0-9]+/' "$M/main.tf" && {
  echo "FAIL: there is a hardcoded CIDR inside the module"; exit 1; }

grep -q "subnet_ids" "$M/outputs.tf" || {
  echo "FAIL: the module does not output subnet_ids"; exit 1; }
grep -q "vpc_id" "$M/outputs.tf" || {
  echo "FAIL: the module does not output vpc_id"; exit 1; }

# for_each rather than count, so removing one AZ does not renumber and recreate
# every subnet after it.
grep -q "for_each" "$M/main.tf" || {
  echo "FAIL: the subnets use count rather than for_each - removing an AZ would recreate the rest"; exit 1; }

# And it has to have actually built something. Ask the account.
VPC=$($AWS ec2 describe-vpcs --filters Name=cidr,Values=10.20.0.0/16 \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
[ -n "$VPC" ] || { echo "FAIL: no VPC with CIDR 10.20.0.0/16 in the account"; exit 1; }

SUBNETS=$($AWS ec2 describe-subnets --filters Name=vpc-id,Values=$VPC \
  --query 'Subnets[].CidrBlock' --output text 2>/dev/null)
COUNT=$(echo "$SUBNETS" | wc -w)
[ "$COUNT" -eq 2 ] || { echo "FAIL: $VPC has $COUNT subnet(s), expected 2. Found: $SUBNETS"; exit 1; }

# The subnets must be computed from the VPC CIDR, which is what makes the
# module work for any caller.
echo "$SUBNETS" | grep -q "10.20.0.0/24" || {
  echo "FAIL: expected a 10.20.0.0/24 subnet, found: $SUBNETS"; exit 1; }

echo "PASS - the module built $VPC with two computed subnets: $SUBNETS"
exit 0
