#!/bin/bash
DIR=/root/network
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

VPC=$($AWS ec2 describe-vpcs --filters Name=tag:Name,Values=egykode \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
[ -n "$VPC" ] || { echo "FAIL: no VPC tagged Name=egykode"; exit 1; }

# Two AZs is the criterion, and it is fixed at creation - a VPC built in one
# zone has to be rebuilt to become highly available.
AZS=$($AWS ec2 describe-subnets --filters Name=vpc-id,Values=$VPC \
  --query 'Subnets[].AvailabilityZone' --output text 2>/dev/null | tr '\t' '\n' | sort -u | grep -c .)
[ "$AZS" -ge 2 ] || { echo "FAIL: the subnets span $AZS availability zone(s), expected 2"; exit 1; }

for TIER in public private; do
  N=$($AWS ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC Name=tag:Tier,Values=$TIER \
    --query 'Subnets[].SubnetId' --output text 2>/dev/null | wc -w)
  [ "$N" -eq 2 ] || { echo "FAIL: $N subnet(s) tagged Tier=$TIER, expected 2"; exit 1; }

  ZONES=$($AWS ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC Name=tag:Tier,Values=$TIER \
    --query 'Subnets[].AvailabilityZone' --output text 2>/dev/null | tr '\t' '\n' | sort -u | grep -c .)
  [ "$ZONES" -eq 2 ] || {
    echo "FAIL: both Tier=$TIER subnets are in the same availability zone"; exit 1; }
done

# Public subnets auto-assign addresses; private ones must not, because that
# setting is a subnet property and nothing warns you at launch time.
BAD=$($AWS ec2 describe-subnets \
  --filters Name=vpc-id,Values=$VPC Name=tag:Tier,Values=private \
  --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' --output text 2>/dev/null)
[ -z "$BAD" ] || {
  echo "FAIL: private subnet(s) $BAD have map_public_ip_on_launch enabled"; exit 1; }

echo "PASS - $VPC spans $AZS zones with a public and a private subnet in each"
exit 0
