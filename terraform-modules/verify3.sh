#!/bin/bash
DIR=/root/platform
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

A=$(terraform output -raw network_vpc 2>/dev/null)
B=$(terraform output -raw staging_vpc 2>/dev/null)
[ -n "$A" ] && [ -n "$B" ] || {
  echo "FAIL: both network_vpc and staging_vpc outputs are needed"; exit 1; }
[ "$A" != "$B" ] || {
  echo "FAIL: both outputs are $A - the module was called once, not twice"; exit 1; }

# One module block, two instances of it. Two copies of the module directory
# would satisfy everything else here and miss the point entirely.
COUNT=$(grep -c 'source *= *"./modules/network"' main.tf 2>/dev/null)
[ "$COUNT" -eq 2 ] || {
  echo "FAIL: ./modules/network is used $COUNT time(s) in main.tf, expected 2"; exit 1; }
[ -d modules/network ] || { echo "FAIL: modules/network is missing"; exit 1; }
[ ! -d modules/network2 ] || {
  echo "FAIL: there is a second copy of the network module - call the one module twice instead"; exit 1; }

# Independent means different CIDRs and their own subnets, checked in the
# account rather than inferred from the configuration.
for V in "$A" "$B"; do
  CIDR=$($AWS ec2 describe-vpcs --vpc-ids "$V" --query 'Vpcs[].CidrBlock' --output text 2>/dev/null)
  [ -n "$CIDR" ] || { echo "FAIL: $V does not exist in the account"; exit 1; }
  SUBS=$($AWS ec2 describe-subnets --filters Name=vpc-id,Values=$V \
    --query 'Subnets[].CidrBlock' --output text 2>/dev/null)
  N=$(echo "$SUBS" | wc -w)
  [ "$N" -eq 2 ] || { echo "FAIL: $V ($CIDR) has $N subnet(s), expected 2"; exit 1; }
  PREFIX=$(echo "$CIDR" | cut -d. -f1-2)
  echo "$SUBS" | grep -q "$PREFIX\." || {
    echo "FAIL: subnets of $V are $SUBS, which are not carved from $CIDR"; exit 1; }
done

CA=$($AWS ec2 describe-vpcs --vpc-ids "$A" --query 'Vpcs[].CidrBlock' --output text 2>/dev/null)
CB=$($AWS ec2 describe-vpcs --vpc-ids "$B" --query 'Vpcs[].CidrBlock' --output text 2>/dev/null)
[ "$CA" != "$CB" ] || { echo "FAIL: both VPCs have CIDR $CA - they are not independent networks"; exit 1; }

# Each instance in its own network, which is what proves the wiring scaled with
# the second call rather than both pointing at the first network.
IA=$(terraform output -raw app_instance 2>/dev/null)
IB=$(terraform output -raw staging_instance 2>/dev/null)
[ -n "$IB" ] || { echo "FAIL: no staging_instance output"; exit 1; }
for PAIR in "$IA:$A" "$IB:$B"; do
  I=${PAIR%%:*}; WANT=${PAIR##*:}
  SN=$($AWS ec2 describe-instances --instance-ids "$I" \
    --query 'Reservations[].Instances[].SubnetId' --output text 2>/dev/null)
  GOT=$($AWS ec2 describe-subnets --subnet-ids "$SN" --query 'Subnets[].VpcId' --output text 2>/dev/null)
  [ "$GOT" = "$WANT" ] || { echo "FAIL: instance $I is in $GOT, expected $WANT"; exit 1; }
done

echo "PASS - $A ($CA) and $B ($CB), two subnets and one instance each, from one module"
exit 0
