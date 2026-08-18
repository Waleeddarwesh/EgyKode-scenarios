#!/bin/bash
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"
M=modules/compute

[ -f "$M/main.tf" ] || { echo "FAIL: no $M/main.tf"; exit 1; }

# The criterion, and the reasoning behind it: the compute module is handed a
# subnet and never goes looking for the network it belongs to.
grep -q "aws_vpc" "$M"/*.tf 2>/dev/null && {
  echo "FAIL: modules/compute references aws_vpc - it should take subnet_id as an input instead"
  exit 1; }
grep -q "var.subnet_id" "$M/main.tf" || {
  echo "FAIL: the instance does not take its subnet from var.subnet_id"; exit 1; }

# No hardcoded ids in the root module either. A wired-up id defeats the point
# as thoroughly as a lookup does.
grep -qE '"(subnet|vpc)-[a-z0-9]+"' *.tf 2>/dev/null && {
  echo "FAIL: there is a hardcoded subnet or vpc id in the root module:"
  grep -nE '"(subnet|vpc)-[a-z0-9]+"' *.tf
  exit 1; }
grep -q "module.network" main.tf 2>/dev/null || {
  echo "FAIL: the root module does not pass a value from module.network to the compute module"; exit 1; }

# And it must genuinely be in the module's network, not merely running.
INSTANCE=$(terraform output -raw app_instance 2>/dev/null)
[ -n "$INSTANCE" ] || { echo "FAIL: no app_instance output"; exit 1; }

SUBNET=$($AWS ec2 describe-instances --instance-ids "$INSTANCE" \
  --query 'Reservations[].Instances[].SubnetId' --output text 2>/dev/null)
[ -n "$SUBNET" ] || { echo "FAIL: $INSTANCE does not resolve in the account"; exit 1; }

VPC=$($AWS ec2 describe-vpcs --filters Name=cidr,Values=10.20.0.0/16 \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
IN_VPC=$($AWS ec2 describe-subnets --subnet-ids "$SUBNET" \
  --query 'Subnets[].VpcId' --output text 2>/dev/null)
[ "$IN_VPC" = "$VPC" ] || {
  echo "FAIL: the instance is in $SUBNET, which belongs to $IN_VPC, not the module's VPC $VPC"
  exit 1; }

echo "PASS - $INSTANCE runs in $SUBNET inside $VPC, wired entirely by reference"
exit 0
