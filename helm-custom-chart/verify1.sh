#!/bin/bash
CHART=$(find /root ~ -maxdepth 3 -name Chart.yaml -path "*myapp*" 2>/dev/null | head -1)
[ -n "$CHART" ] || { echo "FAIL: no myapp/Chart.yaml found"; exit 1; }
DIR=$(dirname "$CHART")

helm lint "$DIR" >/dev/null 2>&1 || {
  echo "FAIL: helm lint does not pass:"; helm lint "$DIR" 2>&1 | tail -3; exit 1; }

# Render locally. This is the check the step is about, and it needs no cluster.
OUT=$(helm template testrel "$DIR" 2>&1) || {
  echo "FAIL: helm template failed:"; echo "$OUT" | tail -3; exit 1; }

echo "$OUT" | grep -q "kind: Deployment" || { echo "FAIL: the chart renders no Deployment"; exit 1; }
echo "$OUT" | grep -q "kind: ConfigMap" || { echo "FAIL: the chart renders no ConfigMap"; exit 1; }

# The helper has to be doing the naming, or step 2's two releases collide.
echo "$OUT" | grep -q "testrel-myapp" || {
  echo "FAIL: resource names do not include the release name - check the fullname helper"; exit 1; }

# The container must read the ConfigMap, or step 3 has nothing to demonstrate.
echo "$OUT" | grep -q "configMapRef" || {
  echo "FAIL: the container does not read the ConfigMap via envFrom"; exit 1; }

# A selector that carries the app version breaks the next upgrade, because a
# Deployment's selector is immutable once created.
SEL=$(echo "$OUT" | sed -n '/matchLabels/,/template:/p')
echo "$SEL" | grep -q "app.kubernetes.io/version" && {
  echo "FAIL: the selector includes app.kubernetes.io/version - selectors are immutable, so the next appVersion bump cannot be upgraded"
  exit 1; }

echo "PASS - the chart lints, renders a Deployment and ConfigMap, and its selector is stable"
exit 0
