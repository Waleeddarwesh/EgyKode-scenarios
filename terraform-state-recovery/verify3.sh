#!/bin/bash
D=/root/recovery
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }
AWS="aws --endpoint-url=http://localhost:4566"

# The object must be present, not merely recoverable.
$AWS s3api head-object --bucket egykode-state-recovery --key recovery/terraform.tfstate >/dev/null 2>&1 || {
  echo "FAIL: recovery/terraform.tfstate is not in the bucket"
  echo "      Remove the delete marker to uncover the previous version."
  exit 1; }

# No delete marker may still be the latest version, or the next read fails again.
MARKER=$($AWS s3api list-object-versions --bucket egykode-state-recovery \
  --prefix recovery/terraform.tfstate \
  --query 'DeleteMarkers[?IsLatest==`true`].VersionId' --output text 2>/dev/null)
# The CLI prints the literal string "None" when the queried key is absent, so
# testing for an empty string alone reports a delete marker that is not there.
case "$MARKER" in
  ""|None) ;;
  *) echo "FAIL: a delete marker is still the latest version ($MARKER)"; exit 1 ;;
esac

COUNT=$(terraform state list 2>/dev/null | grep -c .)
[ "${COUNT:-0}" -ge 3 ] || {
  echo "FAIL: state lists ${COUNT:-0} resources, expected at least 3"; exit 1; }

# Restored state must match reality. A state file restored from too old a
# version would list resources and still disagree with the account.
terraform plan -detailed-exitcode -input=false >/tmp/v3.out 2>&1
CODE=$?
[ "$CODE" -ne 2 ] || {
  echo "FAIL: the restored state does not match reality - the plan wants changes"
  grep -E "will be|^  [~+-]" /tmp/v3.out | head -5
  exit 1; }
[ "$CODE" -eq 0 ] || { echo "FAIL: terraform plan errored (exit $CODE)"; tail -4 /tmp/v3.out; exit 1; }

# Nothing may have been rebuilt during the recovery. One VPC, not two.
VPCS=$($AWS ec2 describe-vpcs --filters Name=tag:Name,Values=recovery \
  --query 'Vpcs[].VpcId' --output text 2>/dev/null | wc -w)
[ "$VPCS" -eq 1 ] || {
  echo "FAIL: $VPCS VPCs tagged 'recovery' exist - applying with empty state built a duplicate"
  exit 1; }

echo "PASS - state restored from versioning, $COUNT resources, plan quiet, nothing rebuilt"
exit 0
