#!/bin/bash
# Criterion 2: application logs appear in a log group and you can query them.
#
# "You can query them" leaves no trace by itself - a query changes nothing, so
# there is nothing to inspect afterwards. Three things are checked instead:
# events are in the group, the one query mechanism this environment really
# implements (the time window) behaves, and the metric filter was configured.
#
# Not the filter pattern. LocalStack accepts --filter-pattern and ignores it -
# a nonsense pattern returns every event in the group, measured - so a check
# built on it would be reading the emulator's indifference, not the work.
AWS="aws --endpoint-url=http://localhost:4566"
# A missing CLI must not be reported as missing work. Without this the checks
# below see empty output and confidently name the wrong cause - which is how a
# verifier ends up lying about a setup failure.
command -v aws >/dev/null 2>&1 || {
  echo "FAIL: the AWS CLI is not installed"
  echo "      Setup could not install it. Ubuntu 24.04 dropped the awscli"
  echo "      package; check /root for the fallback install, or re-run setup."
  exit 1; }
GROUP=/egykode/lab/app

for i in $(seq 1 20); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null \
    | grep -qE '"logs": *"(available|running)"' && break
  sleep 3
done

$AWS logs describe-log-groups --log-group-name-prefix "$GROUP" 2>/dev/null | grep -q "$GROUP" || {
  echo "FAIL: no log group named $GROUP - finish step 1 first"; exit 1; }

# Presence: events must actually be in the group. Without this, an empty group
# satisfies every assertion below by having nothing to disagree with - the
# failure shape that has bitten this repository before.
#
# Deliberately NOT asserted with --filter-pattern. LocalStack accepts that
# argument and ignores it: a nonsense pattern returns every event in the group,
# measured. A check written against it would pass for a learner who shipped
# nothing matching, and would be testing the emulator's indifference rather
# than the learner's work.
HITS=$($AWS logs filter-log-events --log-group-name "$GROUP" \
  --query 'length(events)' --output text 2>/dev/null)
case "$HITS" in ''|*[!0-9]*) HITS=0 ;; esac
if [ "$HITS" -lt 1 ]; then
  echo "FAIL: $GROUP holds no events"
  echo "      Either nothing was shipped, or the timestamps are wrong."
  echo "      put-log-events takes milliseconds; a value in seconds lands in"
  echo "      1970 and sits outside every window you query."
  exit 1
fi

# The time window IS honoured here, so it is what the query criterion is
# checked against: a window starting in the future must return nothing. If this
# ever returns events, log retrieval has stopped being time-aware and the
# "query" in criterion 2 would mean nothing at all.
NOW=$(( $(date +%s) * 1000 ))
FUTURE=$($AWS logs filter-log-events --log-group-name "$GROUP" \
  --start-time $(( NOW + 600000 )) --query 'length(events)' --output text 2>/dev/null)
case "$FUTURE" in ''|*[!0-9]*) FUTURE=-1 ;; esac
if [ "$FUTURE" -ne 0 ]; then
  echo "FAIL: a query for events starting ten minutes from now returned $FUTURE"
  echo "      Time windows are the one part of querying this environment"
  echo "      actually implements. If they stop working there is nothing left"
  echo "      behind the word 'query' here."
  exit 1
fi

FILTERS=$($AWS logs describe-metric-filters --log-group-name "$GROUP" 2>/dev/null)
echo "$FILTERS" | grep -q 'ApplicationErrors' || {
  echo "FAIL: no metric filter publishing ApplicationErrors on $GROUP"
  echo "      Querying is what you do after someone notices. A metric filter"
  echo "      evaluates the pattern on every event as it arrives, so the logs"
  echo "      can drive an alarm instead of waiting to be read."
  exit 1; }

# A filter whose pattern matches nothing is the silent version of this bug: it
# exists, it is wired to a metric, and it will never fire.
PATTERN=$(echo "$FILTERS" | tr -d ' "' | grep -o 'filterPattern:[^,}]*' | head -1 | cut -d: -f2)
if [ -z "$PATTERN" ]; then
  echo "FAIL: the metric filter has an empty pattern"
  echo "      It would match nothing and the alarm built on it could never fire."
  exit 1
fi

echo "PASS - $GROUP holds $HITS events, time windows are honoured, and a metric filter is configured for ApplicationErrors"
exit 0
