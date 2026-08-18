#!/bin/bash
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WORKER" ] || { echo "FAIL: cannot identify the worker node"; exit 1; }

# Drained means no application Pods left, not merely cordoned. DaemonSet Pods
# stay by design and are excluded here, exactly as --ignore-daemonsets does.
# custom-columns prints <none> for a Pod with no owner, so a bare Pod is
# counted; a jsonpath range emits nothing for it and it passes unnoticed.
LEFT=$(kubectl get pods -A --field-selector=spec.nodeName=$WORKER -o custom-columns=OWNER:.metadata.ownerReferences[0].kind --no-headers 2>/dev/null | grep -v DaemonSet | grep -c .)
[ "$LEFT" -eq 0 ] || {
  echo "FAIL: $WORKER still runs $LEFT non-DaemonSet Pod(s) - it is cordoned but not drained"; exit 1; }

kubectl get pod legacy-cache >/dev/null 2>&1 && {
  echo "FAIL: legacy-cache is still running - the drain has not evicted it yet"; exit 1; }

READY=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 4 ] || {
  echo "FAIL: ${READY:-0} of 4 replicas are ready - the workload did not survive the move"; exit 1; }

# The point of the step. A drain that emptied the node and dropped requests is
# a failed drain, and only the probe log knows.
[ -f /tmp/probe.log ] || { echo "FAIL: /tmp/probe.log is missing - the probe was not running"; exit 1; }
TOTAL=$(wc -l < /tmp/probe.log)
BAD=$(grep -vc 200 /tmp/probe.log)
[ "$TOTAL" -ge 50 ] || {
  echo "FAIL: only $TOTAL requests recorded across the drain - the probe stopped early"; exit 1; }
[ "$BAD" -eq 0 ] || {
  echo "FAIL: $BAD of $TOTAL requests failed during the drain"
  echo "      Codes seen: $(sort /tmp/probe.log | uniq -c | tr '\n' ' ')"
  exit 1; }

echo "PASS - node emptied, $TOTAL requests served, none failed"
exit 0
