#!/bin/bash
L=http://localhost:31000

kubectl -n monitoring get daemonset promtail >/dev/null 2>&1 || {
  echo "FAIL: no promtail DaemonSet in the monitoring namespace."
  echo "      Loki stores logs; it does not go and get them. Install the agent."
  exit 1; }

READY=$(kubectl -n monitoring get daemonset promtail -o jsonpath='{.status.numberReady}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || {
  echo "FAIL: the promtail DaemonSet has no ready Pod."
  echo "      kubectl -n monitoring describe daemonset promtail | tail -20"
  exit 1; }

# The agent existing proves nothing about it shipping. Promtail installed
# before Loki answers drops its batches and then never picks up new Pods, and
# that state looks exactly like this one until you ask Loki what it holds.
for i in $(seq 1 24); do
  NS=$(curl -s --max-time 10 "$L/loki/api/v1/label/namespace/values" 2>/dev/null)
  echo "$NS" | grep -q '"production"' && break
  sleep 5
done

echo "$NS" | grep -q '"data"' || {
  echo "FAIL: Loki knows no namespace labels at all, so nothing has reached it."
  echo "      If promtail is Running, it started before Loki was answering:"
  echo "      kubectl -n monitoring rollout restart daemonset/promtail"
  exit 1; }

for N in production kube-system; do
  echo "$NS" | grep -q "\"$N\"" || {
    echo "FAIL: Loki has no logs labelled namespace=\"$N\"."
    echo "      It reported: $NS"
    echo "      Collecting one namespace is a sidecar. Collecting every namespace"
    echo "      without being told about them is the point of the DaemonSet."
    exit 1; }
done

# And the lines have to be readable, not merely counted. A label that exists
# with no chunks behind it would satisfy everything above.
LINES=$(curl -sG --max-time 15 "$L/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="production"}' \
  --data-urlencode 'since=10m' --data-urlencode 'limit=5' 2>/dev/null \
  | grep -c 'values')
[ "${LINES:-0}" -ge 1 ] || {
  echo "FAIL: the namespace label exists but no log lines came back for it."
  exit 1; }

echo "PASS — promtail is shipping, and Loki holds logs from every namespace on the node"
exit 0
