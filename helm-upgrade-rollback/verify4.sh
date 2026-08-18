#!/bin/bash
NS=demo

# Named-revision rollback, not the automatic one from step 3. "Rollback to 1"
# is the description Helm writes for it, so it distinguishes the deliberate
# rollback from the atomic one that already happened.
helm history demo -n $NS 2>/dev/null | grep -q "Rollback to 1" || {
  echo "FAIL: no revision described as 'Rollback to 1' in the history"
  echo "      helm rollback demo 1 -n demo --wait"
  exit 1; }

helm status demo -n $NS 2>/dev/null | grep -qi 'STATUS: deployed' || {
  echo "FAIL: the release is not in a deployed state after the rollback"; exit 1; }

# Revision 1 predates the scale-up, so a complete restore means one replica.
# Three would mean the manifest was not really restored.
DESIRED=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null)
[ "${DESIRED:-0}" -eq 1 ] || {
  echo "FAIL: the Deployment wants ${DESIRED:-0} replicas, expected 1"
  echo "      A rollback restores the whole revision, replica count included."
  exit 1; }

READY=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 1 ] || { echo "FAIL: ${READY:-0} replicas are ready, expected 1"; exit 1; }

# Verified from the cluster, which is the criterion: the running image, not the
# one the history says should be running.
IMG=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null)
echo "$IMG" | grep -q "1.27-alpine" || {
  echo "FAIL: the running image is '$IMG', expected nginx:1.27-alpine"; exit 1; }

# Three revisions at minimum, with both a failure and a deployed state visible,
# which is what makes the history worth reading at all.
COUNT=$(helm history demo -n $NS 2>/dev/null | grep -cE '^[0-9]+')
[ "${COUNT:-0}" -ge 3 ] || { echo "FAIL: only ${COUNT:-0} revisions in the history, expected at least 3"; exit 1; }

echo "PASS - rolled back to revision 1, one replica, working image, $COUNT revisions on record"
exit 0
