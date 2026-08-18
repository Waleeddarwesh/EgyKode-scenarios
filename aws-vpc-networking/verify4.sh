#!/bin/bash
DIR=/root/network
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

COUNT=$(terraform state list 2>/dev/null | grep -c .)
[ "${COUNT:-0}" -eq 0 ] || {
  echo "FAIL: $COUNT resource(s) still in state:"; terraform state list | head -5; exit 1; }

# Everything below is also true of an account where nothing was ever built, so
# first require evidence that a NAT gateway existed here and was destroyed.
# terraform destroy writes the pre-destroy state to terraform.tfstate.backup.
[ -f terraform.tfstate.backup ] || {
  echo "FAIL: no terraform.tfstate.backup - nothing has been destroyed from this directory"
  exit 1; }
grep -q "aws_nat_gateway" terraform.tfstate.backup || {
  echo "FAIL: the previous state holds no NAT gateway, so none was destroyed"
  echo "      Build the network first, then destroy it."
  exit 1; }
grep -q "aws_eip" terraform.tfstate.backup || {
  echo "FAIL: the previous state holds no Elastic IP"; exit 1; }

# Empty state proves nothing on its own - `terraform state rm` empties it while
# a NAT gateway keeps billing by the hour.
NAT=$($AWS ec2 describe-nat-gateways \
  --query 'NatGateways[?State==`available` || State==`pending`].NatGatewayId' --output text 2>/dev/null)
[ -z "$NAT" ] || {
  echo "FAIL: NAT gateway(s) still present: $NAT"
  echo "      An empty state file does not stop a gateway billing."
  exit 1; }

# The orphan this step exists for. An Elastic IP attached to nothing bills by
# the hour, and deleting a NAT gateway does not release it.
EIP=$($AWS ec2 describe-addresses --query 'Addresses[].[PublicIp,AllocationId]' --output text 2>/dev/null)
[ -z "$EIP" ] || {
  echo "FAIL: Elastic IP still allocated: $EIP"
  echo "      Release it, or it bills by the hour attached to nothing."
  exit 1; }

VPC=$($AWS ec2 describe-vpcs --filters Name=tag:Name,Values=egykode \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null)
[ -z "$VPC" ] || { echo "FAIL: the VPC $VPC still exists"; exit 1; }

echo "PASS - state empty, and the account confirms the NAT gateway and its Elastic IP are gone"
exit 0
