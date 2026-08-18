#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

# The instance size must come from the variable, not be repeated in the
# resource. Both produce a t3.micro; only one is the criterion.
grep -A6 'resource "aws_instance"' *.tf 2>/dev/null | grep -q "var.instance_type" || {
  echo "FAIL: the instance does not take its type from var.instance_type"; exit 1; }
grep -rq 'output "instance_public_ip"' *.tf 2>/dev/null || {
  echo "FAIL: no instance_public_ip output"; exit 1; }

# Ask AWS, not the state file. A resource can be in state and absent from the
# account, and that difference is the whole reason the API is the authority.
INST=$($AWS ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output text 2>/dev/null)
[ -n "$INST" ] || { echo "FAIL: no running instance in the account"; exit 1; }
echo "$INST" | grep -q "t3.micro" || {
  echo "FAIL: no running t3.micro instance. Found: $INST"; exit 1; }

BUCKETS=$($AWS s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
echo "$BUCKETS" | grep -q "egykode-assets" || {
  echo "FAIL: no bucket named egykode-assets-* . Found: $BUCKETS"; exit 1; }

# Outputs must actually carry values, which is the difference between declaring
# an interface and having one.
IP=$(terraform output -raw instance_public_ip 2>/dev/null)
echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo "FAIL: instance_public_ip output is '$IP', not an address"; exit 1; }
ID=$(terraform output -raw instance_id 2>/dev/null)
echo "$ID" | grep -q "^i-" || { echo "FAIL: instance_id output is '$ID'"; exit 1; }

# And the id in the output must be an instance that really exists.
$AWS ec2 describe-instances --instance-ids "$ID" >/dev/null 2>&1 || {
  echo "FAIL: the instance_id output ($ID) does not resolve to a real instance"; exit 1; }

echo "PASS - a t3.micro and a bucket exist in the account, and the outputs resolve"
exit 0
