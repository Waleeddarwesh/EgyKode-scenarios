#!/bin/bash
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WORKER" ] || { echo "FAIL: cannot identify the worker node"; exit 1; }

SCHED=$(kubectl get node "$WORKER" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
[ "$SCHED" != "true" ] || { echo "FAIL: $WORKER is still cordoned"; exit 1; }

CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
CPSCHED=$(kubectl get node "$CP" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)
[ "$CPSCHED" != "true" ] || {
  echo "FAIL: $CP is still cordoned - the attempted drain in step 3 cordoned it before it was refused"; exit 1; }

# Schedulable is not the same as receiving Pods. Uncordon on its own leaves the
# node empty indefinitely, so this is the check that separates the two.
ON_WORKER=$(kubectl get pods -l app=web --field-selector=spec.nodeName=$WORKER --no-headers 2>/dev/null | wc -l)
[ "$ON_WORKER" -ge 1 ] || {
  echo "FAIL: $WORKER is schedulable but runs no web Pods"
  echo "      Nothing rebalances on its own: kubectl rollout restart deployment/web"
  exit 1; }

READY=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 4 ] || { echo "FAIL: ${READY:-0} of 4 replicas are ready"; exit 1; }

ALLOWED=$(kubectl get pdb web -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)
[ "${ALLOWED:-0}" -ge 1 ] || {
  echo "FAIL: the PDB still allows no disruptions - lower minAvailable below the replica count"; exit 1; }

echo "PASS - both nodes schedulable, $ON_WORKER replica(s) back on $WORKER, budget workable"
exit 0
