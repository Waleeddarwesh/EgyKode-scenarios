#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

COUNT=$(terraform state list 2>/dev/null | grep -c .)
[ "${COUNT:-0}" -eq 0 ] || {
  echo "FAIL: $COUNT resource(s) still in state:"
  terraform state list | head -5
  exit 1; }

# Empty state is not proof that anything was removed - `terraform state rm`
# empties it too, and leaves everything running and billing. Ask the account.
RUNNING=$($AWS ec2 describe-instances \
  --filters Name=instance-state-name,Values=running,pending \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
[ -z "$RUNNING" ] || {
  echo "FAIL: instance(s) still running in the account: $RUNNING"
  echo "      An empty state file does not mean the resources are gone."
  exit 1; }

BUCKETS=$($AWS s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
echo "$BUCKETS" | grep -q "egykode-assets" && {
  echo "FAIL: the bucket is still there: $BUCKETS"; exit 1; }

# The specific instance the learner built must report terminated, which is a
# stronger statement than "nothing is running".
if [ -f /tmp/was_instance ]; then
  WAS=$(cat /tmp/was_instance)
  ST=$($AWS ec2 describe-instances --instance-ids "$WAS" \
    --query 'Reservations[].Instances[].State.Name' --output text 2>/dev/null)
  case "$ST" in
    terminated|shutting-down|"") ;;
    *) echo "FAIL: instance $WAS reports state '$ST'"; exit 1 ;;
  esac
fi

echo "PASS - state is empty and the account confirms the resources are gone"
exit 0
