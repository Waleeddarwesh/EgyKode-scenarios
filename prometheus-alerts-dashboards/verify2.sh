#!/bin/bash
D=/root/obs
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

RULES=$(curl -s --max-time 5 http://localhost:9090/api/v1/rules 2>/dev/null)
FOR=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .duration' 2>/dev/null)
[ "${FOR:-0}" != "0" ] && [ "${FOR:-0}" != "null" ] || {
  echo "FAIL: the rule has no for: duration - put it back after the experiment"
  echo "      With for: 0 the alert fires on a single evaluation, which is the noise you just saw."
  exit 1; }

# The alert must have genuinely reached firing at some point, not merely be
# loaded. ALERTS is a real series, so this survives the alert having resolved
# once the load stopped.
FIRED=$(curl -s -G --max-time 8 http://localhost:9090/api/v1/query \
  --data-urlencode 'query=max_over_time(ALERTS{alertname="HighErrorRate",alertstate="firing"}[20m])' 2>/dev/null \
  | jq -r '.data.result | length' 2>/dev/null)
[ "${FIRED:-0}" -ge 1 ] || {
  echo "FAIL: HighErrorRate has not reached the firing state in the last 20 minutes"
  echo "      Generate errors long enough to outlast the for: duration, then check again."
  exit 1; }

# And it must have passed through pending on the way. An alert that goes
# straight to firing had no for: when it fired.
PENDING=$(curl -s -G --max-time 8 http://localhost:9090/api/v1/query \
  --data-urlencode 'query=max_over_time(ALERTS{alertname="HighErrorRate",alertstate="pending"}[20m])' 2>/dev/null \
  | jq -r '.data.result | length' 2>/dev/null)
[ "${PENDING:-0}" -ge 1 ] || {
  echo "FAIL: the alert never passed through pending - it fired on the first true evaluation"; exit 1; }

echo "PASS - the alert went pending then firing under load, and for=${FOR}s is back in the rule"
exit 0
