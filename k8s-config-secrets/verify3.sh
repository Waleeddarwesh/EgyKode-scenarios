#!/bin/bash
NS=platform

kubectl get deployment api -n $NS >/dev/null 2>&1 || {
  echo "FAIL: no Deployment named api in namespace $NS"; exit 1; }

# Check the spec first so a wrong answer fails immediately. Waiting below is
# only for a rollout that is genuinely on its way to being right.
for KIND in containers initContainers; do
  REQ=$(kubectl get deployment api -n $NS -o jsonpath="{.spec.template.spec.$KIND[*].resources.requests}" 2>/dev/null)
  LIM=$(kubectl get deployment api -n $NS -o jsonpath="{.spec.template.spec.$KIND[*].resources.limits}" 2>/dev/null)
  [ -n "$REQ" ] || { echo "FAIL: no resource requests on the $KIND"; exit 1; }
  [ -n "$LIM" ] || { echo "FAIL: no resource limits on the $KIND"; exit 1; }
  [ "$REQ" = "$LIM" ] || {
    echo "FAIL: on the $KIND, requests and limits differ - that is Burstable, not Guaranteed"
    echo "      requests: $REQ"
    echo "      limits:   $LIM"
    exit 1; }
done

# The spec is right; let the replacement Pods arrive. This can still only pass
# on Guaranteed Pods, so waiting is not generosity.
for i in $(seq 1 15); do
  QOS=$(kubectl get pod -n $NS -l app=api --field-selector=status.phase=Running -o jsonpath='{.items[*].status.qosClass}' 2>/dev/null)
  GOOD=$(echo "$QOS" | grep -o Guaranteed | wc -l)
  BAD=$(echo "$QOS" | grep -o -E 'Burstable|BestEffort' | wc -l)
  if [ "$BAD" -eq 0 ] && [ "$GOOD" -ge 2 ]; then
    echo "PASS - $GOOD Pods are Guaranteed, so requests equal limits on every container"
    exit 0
  fi
  sleep 2
done

echo "FAIL: the spec looks right but the running Pods report '$QOS'"
exit 1
