#!/bin/bash
DIR=/root/network
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

VPC=$($AWS ec2 describe-vpcs --filters Name=tag:Name,Values=egykode \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
[ -n "$VPC" ] || { echo "FAIL: no VPC tagged Name=egykode"; exit 1; }

IGW=$($AWS ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC \
  --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null)
[ -n "$IGW" ] || { echo "FAIL: no internet gateway attached to $VPC"; exit 1; }

NAT=$($AWS ec2 describe-nat-gateways \
  --filter Name=vpc-id,Values=$VPC \
  --query 'NatGateways[?State==`available`].NatGatewayId' --output text 2>/dev/null)
[ -n "$NAT" ] || { echo "FAIL: no available NAT gateway in $VPC"; exit 1; }

# A NAT gateway in a private subnet has no route out, so it never works - and
# nothing errors, which is why this is worth checking rather than assuming.
NAT_SUBNET=$($AWS ec2 describe-nat-gateways --nat-gateway-ids $NAT \
  --query 'NatGateways[].SubnetId' --output text 2>/dev/null)
TIER=$($AWS ec2 describe-subnets --subnet-ids "$NAT_SUBNET" \
  --query 'Subnets[].Tags[?Key==`Tier`].Value|[0][0]' --output text 2>/dev/null)
[ "$TIER" = "public" ] || {
  echo "FAIL: the NAT gateway is in $NAT_SUBNET, tier '$TIER' - it must sit in a public subnet"
  exit 1; }

# The Elastic IP is what step 4 checks gets released, so it has to be allocated
# and attached now.
EIP=$($AWS ec2 describe-addresses --query 'Addresses[].AllocationId' --output text 2>/dev/null)
[ -n "$EIP" ] || { echo "FAIL: no Elastic IP allocated for the NAT gateway"; exit 1; }

echo "PASS - $IGW on the VPC, $NAT in a public subnet with an Elastic IP"
exit 0
