#!/bin/bash
NS=platform

CM=$(kubectl get configmap app-config -n $NS -o jsonpath='{.data.LOG_LEVEL}' 2>/dev/null)
[ "$CM" = "debug" ] || {
  echo "FAIL: the ConfigMap has LOG_LEVEL='$CM', expected 'debug'"; exit 1; }

kubectl rollout status deployment/api -n $NS --timeout=120s >/dev/null 2>&1

# The ConfigMap alone proves nothing - it held the new value while the Pods
# ignored it, which is the entire point of the step. This has to come from a
# running process.
VAL=$(kubectl exec -n $NS deploy/api -- printenv LOG_LEVEL 2>/dev/null)
[ "$VAL" = "debug" ] || {
  echo "FAIL: the ConfigMap says debug but the container says '$VAL' - the Pods still hold the old value"
  echo "      kubectl rollout restart deployment/api -n platform"
  exit 1; }

echo "PASS - the new value is in the running process, not only in the ConfigMap"
exit 0
