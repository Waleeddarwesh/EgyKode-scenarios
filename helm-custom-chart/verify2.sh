#!/bin/bash
for ENV in dev staging; do
  helm status $ENV -n $ENV >/dev/null 2>&1 || {
    echo "FAIL: no release named $ENV in namespace $ENV"; exit 1; }
done

# Same chart both times. Two charts that happen to be installed twice would
# satisfy everything else here while missing the entire point.
CD=$(helm list -n dev -o json 2>/dev/null | tr ',' '\n' | grep '"chart"' | head -1)
CS=$(helm list -n staging -o json 2>/dev/null | tr ',' '\n' | grep '"chart"' | head -1)
[ "$CD" = "$CS" ] || { echo "FAIL: the two releases are not the same chart: $CD vs $CS"; exit 1; }

DEV=$(kubectl get deployment dev-myapp -n dev -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
STG=$(kubectl get deployment staging-myapp -n staging -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${DEV:-0}" -eq 1 ] || { echo "FAIL: dev has ${DEV:-0} ready replicas, expected 1"; exit 1; }
[ "${STG:-0}" -eq 3 ] || { echo "FAIL: staging has ${STG:-0} ready replicas, expected 3"; exit 1; }

# Read the values from inside the running containers. The values files prove
# only what was asked for.
DL=$(kubectl exec -n dev deploy/dev-myapp -- printenv LOG_LEVEL 2>/dev/null)
SL=$(kubectl exec -n staging deploy/staging-myapp -- printenv LOG_LEVEL 2>/dev/null)
[ "$DL" = "debug" ] || { echo "FAIL: LOG_LEVEL in dev is '$DL', expected debug"; exit 1; }
[ "$SL" = "warn" ]  || { echo "FAIL: LOG_LEVEL in staging is '$SL', expected warn"; exit 1; }

echo "PASS - one chart, two environments, values differing inside the containers"
exit 0
