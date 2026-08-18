#!/bin/bash
# Available replicas, not desired. A Deployment can ask for 3 and have 0
# running, and "kubectl get deployment" alone would look fine.
kubectl get deployment web >/dev/null 2>&1 || {
  echo "FAIL: no Deployment named web"; exit 1; }

WANT=$(kubectl get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null)
HAVE=$(kubectl get deployment web -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
HAVE=${HAVE:-0}

[ "$WANT" = "3" ] || { echo "FAIL: web wants $WANT replicas, expected 3"; exit 1; }
[ "$HAVE" = "3" ] || { echo "FAIL: only $HAVE of 3 replicas are available"; exit 1; }

kubectl get replicaset -l app=web --no-headers 2>/dev/null | grep -q . || {
  echo "FAIL: no ReplicaSet owned by web"; exit 1; }

echo "PASS — 3/3 available"
exit 0
