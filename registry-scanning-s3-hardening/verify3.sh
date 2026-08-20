#!/bin/bash
# Criterion 3: every bucket blocks public access and rejects requests that are
# not over TLS.
#
# The first half is real state and is checked as such. The second half cannot
# be checked by behaviour here: this emulator stores bucket policies and does
# not evaluate them, so the deny refuses nothing - step 3 makes the learner
# observe that rather than hiding it. What is checked is that the policy is
# correct, because it is the artifact that would work on a real account.
A="aws --endpoint-url=http://localhost:4566"
command -v aws >/dev/null 2>&1 || { echo "FAIL: the AWS CLI is not installed"; exit 1; }
for i in $(seq 1 20); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -q '"s3"' && break
  sleep 3
done

BUCKETS=$($A s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
[ -n "$BUCKETS" ] || { echo "FAIL: no buckets exist"; exit 1; }

# All four settings, on every bucket. Two of the four is how a bucket ends up
# public despite someone having turned public access block on.
for B in $BUCKETS; do
  CFG=$($A s3api get-public-access-block --bucket "$B" \
        --query PublicAccessBlockConfiguration 2>/dev/null)
  for K in BlockPublicAcls IgnorePublicAcls BlockPublicPolicy RestrictPublicBuckets; do
    echo "$CFG" | grep -q "\"$K\": true" || {
      echo "FAIL: bucket $B does not set $K"
      echo "      All four are needed and they stop different things: refusing"
      echo "      a new public ACL, neutralising existing ones, refusing a"
      echo "      public policy, and cutting off access through a policy that"
      echo "      is already attached."
      exit 1; }
  done
done

POL=$($A s3api get-bucket-policy --bucket platform-tfstate --query Policy --output text 2>/dev/null)
[ -n "$POL" ] || {
  echo "FAIL: the state bucket has no bucket policy"; exit 1; }

echo "$POL" | grep -q '"Effect": *"Deny"' || { echo "FAIL: the policy has no Deny statement"; exit 1; }
echo "$POL" | grep -q 'aws:SecureTransport' || {
  echo "FAIL: the policy does not test aws:SecureTransport"
  echo "      That condition is what makes it a TLS-only policy."
  exit 1; }

# Both ARNs. A policy carrying only one half-works: bucket-level actions are
# authorised against the bucket ARN and object actions against /*, so the deny
# applies to some calls and not others.
echo "$POL" | grep -q 'arn:aws:s3:::platform-tfstate"' || {
  echo "FAIL: the policy does not name the bucket ARN"
  echo "      ListBucket is authorised against the bucket, not against /*."
  exit 1; }
echo "$POL" | grep -q 'arn:aws:s3:::platform-tfstate/\*' || {
  echo "FAIL: the policy does not name the object ARN (/*)"
  echo "      GetObject and PutObject are authorised against the objects."
  exit 1; }

echo "PASS - every bucket blocks public access all four ways, and the state bucket's TLS-only policy names both ARNs"
echo "       (this emulator stores bucket policies without evaluating them - the deny is correct, not enforced)"
exit 0
