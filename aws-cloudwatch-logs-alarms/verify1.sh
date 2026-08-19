#!/bin/bash
# Criterion 4: you can explain why the default EC2 metrics exclude memory and
# disk. The explanation is prose and cannot be checked, so what is checked is
# the thing that only makes sense if you understood it: a guest metric
# published into a namespace of your own, which is what an agent does and what
# the hypervisor cannot do for you.
AWS="aws --endpoint-url=http://localhost:4566"
# A missing CLI must not be reported as missing work. Without this the checks
# below see empty output and confidently name the wrong cause - which is how a
# verifier ends up lying about a setup failure.
command -v aws >/dev/null 2>&1 || {
  echo "FAIL: the AWS CLI is not installed"
  echo "      Setup could not install it. Ubuntu 24.04 dropped the awscli"
  echo "      package; check /root for the fallback install, or re-run setup."
  exit 1; }

for i in $(seq 1 20); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null \
    | grep -qE '"logs": *"(available|running)"' && break
  sleep 3
done
curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null \
  | grep -qE '"logs": *"(available|running)"' || {
  echo "FAIL: LocalStack is not answering yet - give setup another moment"; exit 1; }

METRICS=$($AWS cloudwatch list-metrics --namespace EgyKode/Ops 2>/dev/null)
echo "$METRICS" | grep -q 'MemoryUtilization' || {
  echo "FAIL: no MemoryUtilization metric in the EgyKode/Ops namespace"
  echo "      Publish it with cloudwatch put-metric-data. Memory is a fact"
  echo "      about the guest OS, so nothing outside the instance can report"
  echo "      it for you - an agent inside has to push it."
  exit 1; }

# AWS/EC2 is reserved. A learner who put the metric there has missed the point
# and, on real AWS, would have been refused - so it is named rather than
# quietly accepted.
if $AWS cloudwatch list-metrics --namespace AWS/EC2 2>/dev/null | grep -q 'MemoryUtilization'; then
  echo "FAIL: MemoryUtilization was published into the AWS/EC2 namespace"
  echo "      That namespace is reserved for metrics AWS collects. Use your"
  echo "      own, as the CloudWatch agent does."
  exit 1
fi

$AWS logs describe-log-groups --log-group-name-prefix /egykode/lab/app 2>/dev/null \
  | grep -q '/egykode/lab/app' || {
  echo "FAIL: no log group named /egykode/lab/app"; exit 1; }

# The group existing proves nothing about whether anything was shipped into it.
EVENTS=$($AWS logs filter-log-events --log-group-name /egykode/lab/app \
  --query 'events[].message' --output text 2>/dev/null)
COUNT=$(printf '%s' "$EVENTS" | grep -c . 2>/dev/null)
if [ -z "$EVENTS" ] || [ "$COUNT" -eq 0 ]; then
  echo "FAIL: the log group is empty"
  echo "      An empty group and a group nobody shipped to look identical."
  echo "      If put-log-events succeeded but nothing is here, check the"
  echo "      timestamps: they are milliseconds, and a value in seconds lands"
  echo "      in 1970 and falls outside every window you will ever query."
  exit 1
fi

echo "PASS - a guest metric is in your own namespace and the log group holds events"
exit 0
