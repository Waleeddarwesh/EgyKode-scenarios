#!/bin/bash
NS=team-a

SA=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
[ -n "$SA" ] || { echo "FAIL: no Deployment named api in $NS, or it names no ServiceAccount"; exit 1; }
[ "$SA" != "default" ] || {
  echo "FAIL: the Deployment still runs as the default ServiceAccount"; exit 1; }
kubectl get serviceaccount "$SA" -n $NS >/dev/null 2>&1 || {
  echo "FAIL: the Deployment names ServiceAccount '$SA', which does not exist - the Pods cannot start"; exit 1; }

kubectl rollout status deployment/api -n $NS --timeout=90s >/dev/null 2>&1

# Take the newest running Pod, not items[0]. During a rollout the list holds
# Pods from both ReplicaSets, and reading the old one reports on the spec the
# learner just replaced - which passed this check while the token was mounted.
POD=$(kubectl get pod -n $NS -l app=api --field-selector=status.phase=Running \
        --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null)
[ -n "$POD" ] || { echo "FAIL: no running Pod for the api Deployment"; exit 1; }

# Two independent proofs on that one Pod: no projected token volume, and
# nothing at the path. Either alone can be satisfied by accident.
VOLS=$(kubectl get pod "$POD" -n $NS -o jsonpath='{.spec.volumes[*].name}' 2>/dev/null)
if echo "$VOLS" | grep -q kube-api-access; then
  echo "FAIL: $POD still has a kube-api-access volume - the API token is projected into it"
  echo "      set automountServiceAccountToken: false on the Pod template"
  exit 1
fi

if kubectl exec -n $NS "$POD" -- ls /var/run/secrets/kubernetes.io/serviceaccount >/dev/null 2>&1; then
  echo "FAIL: the API token is readable inside $POD"
  echo "      set automountServiceAccountToken: false on the Pod template"
  exit 1
fi

echo "PASS - the workload has its own identity and carries no API token"
exit 0
