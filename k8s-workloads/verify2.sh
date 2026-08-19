#!/bin/bash
# Everything below is an absence, and absences are also true of a cluster where
# the Deployment was never created at all. So first require evidence that it
# existed: events outlive the objects they describe, so the ReplicaSet's record
# of creating Pods survives the cascade that deleted it.
EVIDENCE=$(kubectl get events --no-headers 2>/dev/null \
  | grep "SuccessfulCreate" | grep -c "replicaset/web-")
[ "${EVIDENCE:-0}" -ge 1 ] || {
  echo "FAIL: nothing here records a ReplicaSet named web- ever creating Pods."
  echo "      Run step 1 first: the Deployment has to exist before deleting it means anything."
  exit 1; }

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
