#!/bin/bash
# Everything this step produces is transient: the drift lasts under a second
# and the cluster ends up exactly where it started. So the check is entirely
# about the trace left behind, and the trace is events.
#
# Events last an hour by default, which outlives a session here. If this fails
# on a cluster where you know you did the work, that is the reason.

SELFHEAL=$(kubectl -n argocd get application web-app -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
[ "$SELFHEAL" = "true" ] || {
  echo "FAIL: syncPolicy.automated.selfHeal is not true, so nothing would be reverted."
  exit 1; }

# The drift itself. Any scale away from three counts — the point is that you
# changed the cluster by hand, not which number you chose.
DRIFT=$(kubectl -n web get events --no-headers 2>/dev/null \
  | grep -c 'Scaled down replica set web-')
[ "${DRIFT:-0}" -ge 1 ] || {
  echo "FAIL: nothing in this namespace records the web Deployment being scaled down."
  echo "      Run the scale in step 3 first — an unbroken cluster and a healed"
  echo "      one look identical, which is exactly why this checks the events."
  exit 1; }

# The heal. Argo CD writes 'Partial sync operation' when it reapplies a single
# drifted resource against the commit already deployed, and plain 'Sync
# operation' when it deploys a new commit. Only the first can come from a
# self-heal, so a step-2 sync cannot satisfy this.
for i in $(seq 1 12); do
  HEAL=$(kubectl -n argocd get events --no-headers 2>/dev/null \
    | grep -c 'Partial sync operation to .* succeeded')
  [ "${HEAL:-0}" -ge 1 ] && break
  sleep 5
done
[ "${HEAL:-0}" -ge 1 ] || {
  echo "FAIL: Argo CD has not recorded a partial sync, so it did not heal anything."
  echo "      A scale you reverted yourself leaves the same replica count and no"
  echo "      such event. Scale it down and leave it alone."
  echo "      kubectl -n argocd get events --sort-by=.lastTimestamp | grep Operation"
  exit 1; }

# And it has to have landed back where Git says.
REPLICAS=$(kubectl -n web get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "${REPLICAS:-0}" -eq 3 ] || {
  echo "FAIL: the web Deployment wants ${REPLICAS:-0} replicas, and Git asks for 3."
  exit 1; }

SYNC=$(kubectl -n argocd get application web-app -o jsonpath='{.status.sync.status}' 2>/dev/null)
[ "$SYNC" = "Synced" ] || {
  echo "FAIL: the Application is $SYNC, so the cluster and Git still disagree."
  exit 1; }

echo "PASS — you drifted it, Argo CD recorded a partial sync, and it is back at 3"
exit 0
