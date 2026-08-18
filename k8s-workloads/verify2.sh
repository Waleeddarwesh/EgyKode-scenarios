#!/bin/bash
# All three layers must be gone. Checking only the Deployment would pass while
# orphaned ReplicaSets were still running Pods.
if kubectl get deployment web >/dev/null 2>&1; then
  echo "FAIL: Deployment web still exists"; exit 1
fi

RS=$(kubectl get replicaset -l app=web --no-headers 2>/dev/null | wc -l)
PODS=$(kubectl get pod -l app=web --no-headers 2>/dev/null | wc -l)

[ "$RS" -eq 0 ] || { echo "FAIL: $RS ReplicaSet(s) labelled app=web still exist"; exit 1; }
[ "$PODS" -eq 0 ] || { echo "FAIL: $PODS Pod(s) labelled app=web still exist"; exit 1; }

echo "PASS — the cascade removed all three layers"
exit 0
