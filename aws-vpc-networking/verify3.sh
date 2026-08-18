#!/bin/bash
DIR=/root/network
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

VPC=$($AWS ec2 describe-vpcs --filters Name=tag:Name,Values=egykode \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
[ -n "$VPC" ] || { echo "FAIL: no VPC tagged Name=egykode"; exit 1; }

PUB_RT=$($AWS ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC Name=tag:Name,Values=egykode-public \
  --query 'RouteTables[].RouteTableId' --output text 2>/dev/null)
PRI_RT=$($AWS ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC Name=tag:Name,Values=egykode-private \
  --query 'RouteTables[].RouteTableId' --output text 2>/dev/null)
[ -n "$PUB_RT" ] && [ -n "$PRI_RT" ] || {
  echo "FAIL: need route tables tagged egykode-public and egykode-private"; exit 1; }

# The criterion: the difference is the target of the default route, not a name.
PUB_TARGET=$($AWS ec2 describe-route-tables --route-table-ids $PUB_RT \
  --query 'RouteTables[].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0]' --output text 2>/dev/null)
echo "$PUB_TARGET" | grep -q "^igw-" || {
  echo "FAIL: the public route table sends 0.0.0.0/0 to '$PUB_TARGET', not an internet gateway"; exit 1; }

PRI_NAT=$($AWS ec2 describe-route-tables --route-table-ids $PRI_RT \
  --query 'RouteTables[].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]' --output text 2>/dev/null)
echo "$PRI_NAT" | grep -q "^nat-" || {
  echo "FAIL: the private route table sends 0.0.0.0/0 to '$PRI_NAT', not a NAT gateway"; exit 1; }

# A private table with an internet gateway route is a public subnet with a
# misleading tag, which is precisely the confusion this step exists to remove.
PRI_IGW=$($AWS ec2 describe-route-tables --route-table-ids $PRI_RT \
  --query 'RouteTables[].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0]' --output text 2>/dev/null)
echo "$PRI_IGW" | grep -q "^igw-" && {
  echo "FAIL: the private route table routes to an internet gateway - those subnets are public"; exit 1; }

# Every subnet explicitly associated. An unassociated subnet silently uses the
# main table and reaches nothing, with no error anywhere.
for TIER in public private; do
  RT=$PUB_RT; [ "$TIER" = "private" ] && RT=$PRI_RT
  N=$($AWS ec2 describe-route-tables --route-table-ids $RT \
    --query 'RouteTables[].Associations[?SubnetId!=`null`].SubnetId' --output text 2>/dev/null | wc -w)
  [ "$N" -eq 2 ] || {
    echo "FAIL: $N subnet(s) associated with the $TIER route table, expected 2"
    echo "      A subnet with no association silently falls back to the main table."
    exit 1; }
done

terraform plan -detailed-exitcode -input=false >/tmp/p.out 2>&1
CODE=$?
[ "$CODE" -eq 0 ] || {
  echo "FAIL: terraform plan exits $CODE - apply again until it reports no changes"
  grep -E "will be" /tmp/p.out | head -4
  exit 1; }

echo "PASS - public routes via $PUB_TARGET, private via $PRI_NAT, all four subnets associated, plan quiet"
exit 0
