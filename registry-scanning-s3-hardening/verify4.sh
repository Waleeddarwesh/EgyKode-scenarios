#!/bin/bash
# Criterion 4: the state bucket has versioning enabled, and you demonstrated
# recovering a deleted object.
#
# Versioning being on is configuration. The recovery is the criterion, and it
# leaves a specific trace: an object that is readable now, with an older
# version behind it and no delete marker on top. This checks that trace, and
# then performs its own delete-and-recover so the check cannot pass for someone
# who only turned the setting on.
A="aws --endpoint-url=http://localhost:4566"
B=platform-tfstate
KEY=terraform.tfstate

command -v aws >/dev/null 2>&1 || { echo "FAIL: the AWS CLI is not installed"; exit 1; }
for i in $(seq 1 20); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -q '"s3"' && break
  sleep 3
done

STATUS=$($A s3api get-bucket-versioning --bucket "$B" --query Status --output text 2>/dev/null)
[ "$STATUS" = "Enabled" ] || {
  echo "FAIL: versioning on $B is '${STATUS:-not set}', not Enabled"
  echo "      Without it a deleted state file is a manual re-import of every"
  echo "      resource Terraform manages."
  exit 1; }

# The object must be readable now - a recovery that was not completed leaves it
# hidden behind a delete marker.
CONTENT=$($A s3 cp "s3://$B/$KEY" - 2>/dev/null)
[ -n "$CONTENT" ] || {
  echo "FAIL: $KEY is not readable in $B"
  echo "      Either it was never uploaded, or it is still hidden behind a"
  echo "      delete marker. Remove the marker with:"
  echo "        aws s3api delete-object --bucket $B --key $KEY --version-id <marker>"
  exit 1; }

# Evidence of a real delete-and-recover: more than one version exists. A single
# version means the object was uploaded and never deleted.
VERSIONS=$($A s3api list-object-versions --bucket "$B" --prefix "$KEY" \
  --query 'length(Versions)' --output text 2>/dev/null)
case "$VERSIONS" in ''|None|*[!0-9]*) VERSIONS=0 ;; esac

# And do the round trip independently, so the criterion is proven rather than
# inferred from state that could have arisen another way.
$A s3 rm "s3://$B/$KEY" >/dev/null 2>&1
STILL=$($A s3 cp "s3://$B/$KEY" - 2>/dev/null)
if [ -n "$STILL" ]; then
  echo "FAIL: the object is still readable after being deleted"
  echo "      A versioned delete should write a marker that hides it."
  exit 1
fi
MARKER=$($A s3api list-object-versions --bucket "$B" --prefix "$KEY" \
  --query 'DeleteMarkers[?IsLatest].VersionId' --output text 2>/dev/null)
[ -n "$MARKER" ] && [ "$MARKER" != "None" ] || {
  echo "FAIL: deleting the object wrote no delete marker"
  echo "      Versioning is reported as Enabled but is not behaving that way."
  exit 1; }
$A s3api delete-object --bucket "$B" --key "$KEY" --version-id "$MARKER" >/dev/null 2>&1
BACK=$($A s3 cp "s3://$B/$KEY" - 2>/dev/null)
[ -n "$BACK" ] || {
  echo "FAIL: removing the delete marker did not bring the object back"; exit 1; }
[ "$BACK" = "$CONTENT" ] || {
  echo "FAIL: the recovered object does not match what was there before"; exit 1; }

echo "PASS - versioning is on, and a delete-and-recover round trip returned the object byte for byte ($VERSIONS version(s) retained)"
exit 0
