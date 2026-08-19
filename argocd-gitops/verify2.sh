#!/bin/bash
# Read the repository, not the cluster, first. The question this step asks is
# "did a commit deploy this", and only Git can answer it.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone -q git://localhost:30418/app.git "$WORK/repo" 2>/dev/null || {
  echo "FAIL: cannot clone git://localhost:30418/app.git"
  echo "      kubectl -n gitops get pods"
  exit 1; }

COMMITS=$(git -C "$WORK/repo" rev-list --count HEAD 2>/dev/null)
[ "${COMMITS:-0}" -ge 2 ] || {
  echo "FAIL: the repository still has its single seed commit."
  echo "      This step is a commit and a push. Changing the Deployment with"
  echo "      kubectl reaches the same image and proves nothing — Argo CD would"
  echo "      revert it, which is step 3."
  exit 1; }

IMAGE=$(grep -oE 'image:[[:space:]]*[^[:space:]]+' "$WORK/repo/manifests/web.yaml" 2>/dev/null | awk '{print $2}')
[ -n "$IMAGE" ] || { echo "FAIL: no image found in manifests/web.yaml"; exit 1; }
[ "$IMAGE" != "nginx:1.27-alpine" ] || {
  echo "FAIL: manifests/web.yaml still commits nginx:1.27-alpine."
  echo "      You committed something, but not a change to the image tag."
  exit 1; }

HEAD=$(git -C "$WORK/repo" rev-parse HEAD)

# A Pod that is Running on that image. Not the Deployment spec — a bad tag
# updates the spec, syncs cleanly and never starts, and this step is about
# checking the thing that runs rather than the thing you wrote.
for i in $(seq 1 30); do
  RUNNING=$(kubectl -n web get pods -l app=web \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null \
    | grep -c "^${IMAGE}$")
  [ "${RUNNING:-0}" -ge 1 ] && break
  sleep 10
done

[ "${RUNNING:-0}" -ge 1 ] || {
  echo "FAIL: no Running Pod is using $IMAGE."
  RS=$(kubectl -n web get pods -l app=web -o jsonpath='{range .items[*]}{.status.phase}{" "}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null | sort -u | head -4)
  echo "      Pods right now:"
  echo "$RS" | sed 's/^/        /'
  echo "      ImagePullBackOff means the tag does not exist. Argo CD applied"
  echo "      exactly what you committed; the commit was wrong."
  echo "      Otherwise give it another poll interval — up to about two minutes."
  exit 1; }

# The sync history must name your commit. This is what separates "Argo CD
# deployed it" from "it happens to be running that image".
LAST=$(kubectl -n argocd get application web-app -o jsonpath='{.status.history[-1:].revision}' 2>/dev/null | tr -d '[]" ')
[ "$LAST" = "$HEAD" ] || {
  echo "FAIL: the last sync in history is ${LAST:-none}, and HEAD is $HEAD."
  echo "      Argo CD has not deployed your commit yet, or something else moved"
  echo "      the Deployment to that image."
  exit 1; }

COUNT=$(kubectl -n argocd get application web-app -o jsonpath='{.status.history[*].id}' 2>/dev/null | wc -w)
[ "${COUNT:-0}" -ge 2 ] || {
  echo "FAIL: the sync history has ${COUNT:-0} entry. A deployment by commit adds one."
  exit 1; }

# Argo CD logs a full sync for a commit and a *partial* one for a self-heal.
# Requiring the full-sync wording keeps step 3's evidence from satisfying this
# step, and vice versa.
kubectl -n argocd get events --no-headers 2>/dev/null \
  | grep -v 'Partial sync' | grep -q "Sync operation to ${HEAD} succeeded" || {
  echo "FAIL: no completed sync recorded against ${HEAD}."
  echo "      kubectl -n argocd get events --sort-by=.lastTimestamp | grep Operation"
  exit 1; }

echo "PASS — commit ${HEAD:0:7} is what put $IMAGE on a running Pod"
exit 0
