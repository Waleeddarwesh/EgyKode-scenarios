#!/bin/bash
NS=demo
command -v helm >/dev/null 2>&1 || { echo "FAIL: helm is not installed"; exit 1; }

helm status demo -n $NS >/dev/null 2>&1 || {
  echo "FAIL: there is no Helm release named demo in namespace $NS"; exit 1; }

STATUS=$(helm status demo -n $NS -o json 2>/dev/null | tr ',' '\n' | grep '"status"' | head -1)
echo "$STATUS" | grep -q deployed || {
  echo "FAIL: the release is not in a deployed state: $STATUS"; exit 1; }

# A release can report deployed while its Pods are still starting, unless the
# install waited. This is the check that separates the two.
READY=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 1 ] || {
  echo "FAIL: the release is installed but no replica is ready"; exit 1; }

# The history Secret is what makes rollback possible; if it is missing, later
# steps have nothing to roll back to.
kubectl get secret -n $NS -l owner=helm --no-headers 2>/dev/null | grep -q . || {
  echo "FAIL: no Helm release Secret in $NS - the revision history is missing"; exit 1; }

echo "PASS - demo is deployed and its first revision is recorded"
exit 0
