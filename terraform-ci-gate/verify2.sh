#!/bin/bash
DIR=/root/infra
cd "$DIR" 2>/dev/null || { echo "FAIL: no $DIR"; exit 1; }

tflint >/tmp/tflint.out 2>&1
TL=$?
[ "$TL" -eq 0 ] || {
  echo "FAIL: tflint exits $TL:"
  head -6 /tmp/tflint.out
  exit 1; }

[ -d examples ] || { echo "FAIL: no examples/ directory to scan"; exit 1; }

# There has to be something worth scanning. An empty directory scans clean, and
# deleting the file is not the same as fixing it.
RES=$(cat examples/*.tf 2>/dev/null | grep -c '^resource "aws_')
[ "${RES:-0}" -ge 2 ] || {
  echo "FAIL: examples/ declares ${RES:-0} AWS resources - the scan needs something to look at"
  exit 1; }
grep -rq "aws_security_group" examples/ || { echo "FAIL: the security group is gone from examples/"; exit 1; }
grep -rq "aws_s3_bucket" examples/ || { echo "FAIL: the bucket is gone from examples/"; exit 1; }

# And the open ingress must actually be closed, not merely absent from the
# scanner's findings.
grep -rq '0\.0\.0\.0/0' examples/ && {
  echo "FAIL: something in examples/ is still open to 0.0.0.0/0"
  grep -rn '0\.0\.0\.0/0' examples/
  exit 1; }

trivy config --severity HIGH,CRITICAL --exit-code 1 examples/ >/tmp/trivy.out 2>&1
TV=$?
[ "$TV" -eq 0 ] || {
  echo "FAIL: the security scan still reports HIGH or CRITICAL findings:"
  grep -E "^(AWS|AVD)-" /tmp/trivy.out | head -5
  exit 1; }

echo "PASS - tflint clean, and $RES AWS resources scan without a HIGH or CRITICAL finding"
exit 0
