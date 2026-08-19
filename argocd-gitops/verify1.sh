#!/bin/bash
# The Application must exist, and in argocd's own namespace. Anywhere else it
# is ignored silently, which is the failure this checks for by name.
kubectl -n argocd get application web-app >/dev/null 2>&1 || {
  echo "FAIL: no Application named web-app in the argocd namespace."
  echo "      An Application created in any other namespace is ignored — no"
  echo "      error, no event — so check metadata.namespace as well."
  exit 1; }

REPO=$(kubectl -n argocd get application web-app -o jsonpath='{.spec.source.repoURL}' 2>/dev/null)
echo "$REPO" | grep -q 'git\.gitops\.svc' || {
  echo "FAIL: repoURL is '$REPO'."
  echo "      Argo CD runs inside the cluster and cannot reach localhost:30418 —"
  echo "      that NodePort is for you. It needs git://git.gitops.svc:9418/app.git"
  exit 1; }

SRCPATH=$(kubectl -n argocd get application web-app -o jsonpath='{.spec.source.path}' 2>/dev/null)
[ "$SRCPATH" = "manifests" ] || {
  echo "FAIL: spec.source.path is '$SRCPATH', and the manifests are in manifests/"
  exit 1; }

# selfHeal is required here rather than in step 3, because step 3 cannot
# demonstrate anything without it and finding that out three steps later is a
# poor way to learn it.
SELFHEAL=$(kubectl -n argocd get application web-app -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null)
[ "$SELFHEAL" = "true" ] || {
  echo "FAIL: syncPolicy.automated.selfHeal is not true."
  echo "      Without it Argo CD deploys but never corrects drift, and step 3"
  echo "      has nothing to show."
  exit 1; }

# Wave 1 pulls postgres, so the first sync is bounded by an image pull rather
# than by Argo CD. Six minutes, checked every ten seconds.
for i in $(seq 1 36); do
  SYNC=$(kubectl -n argocd get application web-app -o jsonpath='{.status.sync.status}' 2>/dev/null)
  HEALTH=$(kubectl -n argocd get application web-app -o jsonpath='{.status.health.status}' 2>/dev/null)
  [ "$SYNC" = "Synced" ] && [ "$HEALTH" = "Healthy" ] && break
  sleep 10
done

[ "$SYNC" = "Synced" ] || {
  echo "FAIL: sync status is '$SYNC', not Synced."
  echo "      kubectl -n argocd describe application web-app | tail -20"
  exit 1; }
[ "$HEALTH" = "Healthy" ] || {
  echo "FAIL: health status is '$HEALTH', not Healthy."
  echo "      Synced and Healthy answer different questions: the first says the"
  echo "      cluster matches Git, the second says the workloads work."
  echo "      kubectl -n web get pods"
  exit 1; }

# Both waves must actually be running. Checking the Application alone would
# pass on an Application pointing at an empty directory with allowEmpty set.
for D in db web; do
  READY=$(kubectl -n web get deployment "$D" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "${READY:-0}" -ge 1 ] || {
    echo "FAIL: Deployment $D in namespace web has no ready replicas."
    exit 1; }
done

WEB=$(kubectl -n web get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${WEB:-0}" -eq 3 ] || {
  echo "FAIL: the web Deployment has ${WEB:-0} ready replicas, and Git asks for 3."
  exit 1; }

# Argo CD must have created these, not you. It stamps everything it manages
# with its own tracking label, so a hand-applied Deployment reaching the same
# state does not pass — which is the whole distinction this lab is about.
OWNER=$(kubectl -n web get deployment web -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null)
[ "$OWNER" = "web-app" ] || {
  echo "FAIL: the web Deployment is not tracked by Argo CD (instance label: '${OWNER:-none}')."
  echo "      Applying the manifests yourself reaches the same state and teaches"
  echo "      the opposite lesson. Delete namespace web and let the Application"
  echo "      build it."
  exit 1; }

HIST=$(kubectl -n argocd get application web-app -o jsonpath='{.status.history[0].revision}' 2>/dev/null)
[ -n "$HIST" ] || { echo "FAIL: the Application has no sync history"; exit 1; }

echo "PASS — Argo CD built both waves from Git and reports Synced and Healthy"
exit 0
