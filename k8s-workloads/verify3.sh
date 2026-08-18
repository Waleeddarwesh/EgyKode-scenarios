#!/bin/bash
# The image on the running spec is the evidence that undo worked; the second
# ReplicaSet is the evidence that a rollout actually happened rather than the
# learner recreating the Deployment at the old image.
kubectl get deployment web >/dev/null 2>&1 || {
  echo "FAIL: no Deployment named web"; exit 1; }

IMAGE=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
case "$IMAGE" in
  *nginx:1.25*) ;;
  *) echo "FAIL: image is '$IMAGE', expected nginx:1.25 after rollout undo"; exit 1 ;;
esac

HAVE=$(kubectl get deployment web -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ "${HAVE:-0}" = "3" ] || { echo "FAIL: only ${HAVE:-0} of 3 replicas available"; exit 1; }

RS=$(kubectl get replicaset -l app=web --no-headers 2>/dev/null | wc -l)
[ "$RS" -ge 2 ] || {
  echo "FAIL: only $RS ReplicaSet — no rollout history, so undo was never exercised"; exit 1; }

echo "PASS — back on nginx:1.25 with $RS ReplicaSets in history"
exit 0
