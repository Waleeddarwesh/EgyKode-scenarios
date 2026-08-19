#!/bin/bash
# Criterion 3: an alarm exists on a metric that reflects user impact, and you
# can justify the threshold.
#
# The justification is prose. What is checkable is whether the alarm was
# configured like one somebody thought about: pointed at a symptom rather than
# at a resource, summed rather than averaged, and given more than one
# evaluation period so a single noisy minute does not page anyone.
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
    | grep -qE '"cloudwatch": *"(available|running)"' && break
  sleep 3
done

ALARM=$($AWS cloudwatch describe-alarms --alarm-names egykode-lab-errors 2>/dev/null)
echo "$ALARM" | grep -q 'egykode-lab-errors' || {
  echo "FAIL: no alarm named egykode-lab-errors"
  echo "      Create it with cloudwatch put-metric-alarm."
  exit 1; }

FLAT=$(echo "$ALARM" | tr -d ' "')

METRIC=$(echo "$FLAT" | grep -o 'MetricName:[^,}]*' | head -1 | cut -d: -f2)
[ -n "$METRIC" ] || { echo "FAIL: the alarm names no metric"; exit 1; }

# A resource metric is the wrong thing to page on and is the single most common
# mistake this step exists to correct, so it is rejected by name rather than
# passed over in silence.
case "$METRIC" in
  CPUUtilization|NetworkIn|NetworkOut|DiskReadOps|DiskWriteOps)
    echo "FAIL: the alarm is on $METRIC, which is a resource rather than a symptom"
    echo "      A box at 90% CPU serving every request correctly is fine; one at"
    echo "      4% CPU returning 503 is an outage. Alarm on what the user"
    echo "      experiences and keep CPU for the graph you read afterwards."
    exit 1 ;;
esac

THRESHOLD=$(echo "$FLAT" | grep -o 'Threshold:[^,}]*' | head -1 | cut -d: -f2)
[ -n "$THRESHOLD" ] || { echo "FAIL: the alarm has no threshold"; exit 1; }

PERIODS=$(echo "$FLAT" | grep -o 'EvaluationPeriods:[^,}]*' | head -1 | cut -d: -f2)
case "$PERIODS" in ''|*[!0-9]*) PERIODS=0 ;; esac
if [ "$PERIODS" -lt 2 ]; then
  echo "FAIL: the alarm evaluates $PERIODS period(s)"
  echo "      One bad minute is noise - a deploy, a restart, a retried"
  echo "      connection. Two consecutive breaches is a pattern, and this is"
  echo "      the biggest single lever on whether people trust the alarm."
  exit 1
fi

# Averaging a count hides exactly the spike being alarmed on.
STAT=$(echo "$FLAT" | grep -o 'Statistic:[^,}]*' | head -1 | cut -d: -f2)
if [ "$STAT" = "Average" ]; then
  echo "FAIL: the alarm averages a count"
  echo "      Ten errors in one minute averaged over five looks like two."
  echo "      Use Sum for an occurrence count."
  exit 1
fi

echo "PASS - alarm on $METRIC, threshold $THRESHOLD, $PERIODS evaluation periods, statistic $STAT"
exit 0
