#!/bin/bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
EP=http://localhost:4566
B=egykode-tfstate

# LocalStack reports a service as "available" before first use and "running"
# after, so both count as up.
curl -s --max-time 10 $EP/_localstack/health 2>/dev/null | grep -qE '"s3": *"(available|running)"' || {
  echo "FAIL: LocalStack is not answering on $EP"; exit 1; }

# Ask the S3 API, not the Terraform state. A resource can be in state and
# absent from the API, which is exactly the situation the next steps depend on
# not being in.
curl -s --max-time 10 -o /dev/null -w '%{http_code}' $EP/$B 2>/dev/null | grep -q 200 || {
  echo "FAIL: the bucket $B does not exist"; exit 1; }

curl -s --max-time 10 "$EP/$B?versioning" 2>/dev/null | grep -q "Enabled" || {
  echo "FAIL: versioning is not enabled on $B - a truncated state write would be unrecoverable"; exit 1; }

curl -s --max-time 10 "$EP/$B?encryption" 2>/dev/null | grep -qE "AES256|aws:kms" || {
  echo "FAIL: default encryption is not configured on $B - state holds every secret in plain text"; exit 1; }

PAB=$(curl -s --max-time 10 "$EP/$B?publicAccessBlock" 2>/dev/null)
echo "$PAB" | grep -q "<BlockPublicAcls>true</BlockPublicAcls>" || {
  echo "FAIL: public access is not blocked on $B"; exit 1; }
echo "$PAB" | grep -q "<RestrictPublicBuckets>true</RestrictPublicBuckets>" || {
  echo "FAIL: restrict_public_buckets is not set on $B"; exit 1; }

# The hash key must be LockID exactly, or the backend writes a lock nothing
# reads and every apply believes it holds the lock.
TBL=$(curl -s --max-time 10 -X POST $EP/ \
  -H "X-Amz-Target: DynamoDB_20120810.DescribeTable" \
  -H "Content-Type: application/x-amz-json-1.0" \
  -d '{"TableName":"egykode-tfstate-locks"}' 2>/dev/null)
echo "$TBL" | grep -q "egykode-tfstate-locks" || {
  echo "FAIL: the DynamoDB table egykode-tfstate-locks does not exist"; exit 1; }
echo "$TBL" | grep -q '"AttributeName": *"LockID"' || echo "$TBL" | grep -q '"AttributeName":"LockID"' || {
  echo "FAIL: the lock table's hash key is not LockID - locking would silently do nothing"; exit 1; }

echo "PASS - versioned, encrypted, private state bucket and a LockID lock table"
exit 0
