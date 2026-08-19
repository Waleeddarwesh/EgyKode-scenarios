#!/bin/bash
D=/root/obs
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

curl -s --max-time 5 http://localhost:9090/-/ready >/dev/null 2>&1 || {
  echo "FAIL: Prometheus is not answering on :9090"; exit 1; }

RULES=$(curl -s --max-time 5 http://localhost:9090/api/v1/rules 2>/dev/null)
echo "$RULES" | grep -q "HighErrorRate" || {
  echo "FAIL: no alerting rule named HighErrorRate is loaded"
  echo "      Write prometheus/rules/api.yml and reload: curl -X POST http://localhost:9090/-/reload"
  exit 1; }

# A rule file on disk that Prometheus never loaded is the common failure here,
# so this reads the running configuration rather than the file.
STATE=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .state' 2>/dev/null)
[ -n "$STATE" ] || { echo "FAIL: the rule is present but has no state - it has not been evaluated yet"; exit 1; }

# for: is what separates an alert from a tripwire, and step 2 measures it.
FOR=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .duration' 2>/dev/null)
[ "${FOR:-0}" != "0" ] && [ "${FOR:-0}" != "null" ] || {
  echo "FAIL: the rule has no for: duration - it would fire on a single scrape"; exit 1; }

# The expression must actually be runnable. A rule whose query errors sits in
# the config looking correct and never evaluates to anything.
Q=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .query' 2>/dev/null)
RESULT=$(curl -s -G --max-time 5 http://localhost:9090/api/v1/query --data-urlencode "query=$Q" 2>/dev/null | jq -r '.status' 2>/dev/null)
[ "$RESULT" = "success" ] || { echo "FAIL: the rule's expression does not run: $Q"; exit 1; }

echo "PASS - HighErrorRate is loaded with for=${FOR}s and currently $STATE"
exit 0
