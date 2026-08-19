#!/bin/bash
D=/root/obs
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

RULES=$(curl -s --max-time 5 http://localhost:9090/api/v1/rules 2>/dev/null)
ANN=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .annotations' 2>/dev/null)
[ -n "$ANN" ] || { echo "FAIL: the HighErrorRate rule is not loaded"; exit 1; }

echo "$ANN" | jq -e '.runbook_url' >/dev/null 2>&1 || {
  echo "FAIL: the alert carries no runbook_url"
  echo "      An alert with no runbook asks somebody to invent a procedure while tired."
  exit 1; }
echo "$ANN" | jq -e '.summary' >/dev/null 2>&1 || { echo "FAIL: the alert has no summary annotation"; exit 1; }

# A summary that never names a number is the same text on every fire, which
# tells the responder nothing about severity.
SUMMARY=$(echo "$ANN" | jq -r '.summary')
echo "$SUMMARY" | grep -q '$value' || {
  echo "FAIL: the summary does not include {{ \$value }} - every notification would read identically"
  echo "      summary: \"$SUMMARY\""
  exit 1; }

# severity belongs in labels, where it is part of the alert's identity and can
# route, not in annotations where it is decoration.
SEV=$(echo "$RULES" | jq -r '.data.groups[].rules[] | select(.name=="HighErrorRate") | .labels.severity' 2>/dev/null)
[ -n "$SEV" ] && [ "$SEV" != "null" ] || { echo "FAIL: the alert has no severity label"; exit 1; }

# The dashboard has to exist in Grafana, not merely on disk.
DASH=$(curl -s --max-time 8 http://localhost:3000/api/dashboards/uid/api-red 2>/dev/null)
echo "$DASH" | jq -e '.dashboard.title' >/dev/null 2>&1 || {
  echo "FAIL: no dashboard with uid api-red is loaded in Grafana"
  echo "      Check the provisioning path and that the dashboards directory is mounted."
  exit 1; }

PANELS=$(echo "$DASH" | jq -r '.dashboard.panels | length' 2>/dev/null)
[ "${PANELS:-0}" -ge 3 ] || { echo "FAIL: the dashboard has ${PANELS:-0} panels, expected at least 3"; exit 1; }

# Each of the three must actually return data. A panel whose query is wrong
# renders an empty graph and looks like a quiet service.
for Q in 'sum(rate(prometheus_http_requests_total[2m]))' \
         'sum(rate(prometheus_http_requests_total{code=~"4..|5.."}[2m]))' \
         'histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))'; do
  V=$(curl -s -G --max-time 8 http://localhost:9090/api/v1/query --data-urlencode "query=$Q" 2>/dev/null | jq -r '.data.result[0].value[1] // "none"')
  [ "$V" != "none" ] || { echo "FAIL: this dashboard query returns no data: $Q"; exit 1; }
done

echo "PASS - the alert is actionable and the RED dashboard is loaded with $PANELS panels returning data"
exit 0
