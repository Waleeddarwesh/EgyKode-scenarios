#!/bin/bash
# Criterion 1, first half: Prometheus is scraping the cluster.
#
# Checked by asking Prometheus which targets are actually up, not by checking
# that the chart installed. A stack whose Pods are Running while every target
# is down is the exact state this lab exists to teach people to notice.
NS=monitoring
PROM="http://kps-kube-prometheus-stack-prometheus:9090"

q() {
  kubectl run vq$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n "$NS" \
    --command -- curl -s --max-time 20 "$PROM/api/v1/$1" 2>/dev/null \
    | sed 's/}{"status"/}\n{"status"/g' | head -1
  # The sed is not cosmetic. `kubectl run -i` emits the Pod's stdout twice,
  # concatenated on one line as ...}}{"status":..., so a plain head -1 keeps
  # both. Every numeric extraction then saw "14\n14", failed the digits-only
  # guard, and silently read as 0 - a verifier reporting "0 targets are up"
  # about a cluster scraping fourteen of them.
}

# The numeric value of the first result, or empty. Kept in one place because
# every ad-hoc variant of this got the quoting or the anchoring subtly wrong.
val() {
  echo "$1" | grep -o '"value":\[[^]]*\]' | head -1 | sed 's/.*,"//; s/"\]*$//'
}
int() { v=$(val "$1"); v=${v%%.*}; case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac; }

kubectl get ns "$NS" >/dev/null 2>&1 || {
  echo "FAIL: no $NS namespace - setup has not finished"; exit 1; }

for i in $(seq 1 40); do
  READY=$(kubectl get statefulset prometheus-kps-kube-prometheus-stack-prometheus -n "$NS" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  [ "$READY" = "1" ] && break
  sleep 10
done
[ "$READY" = "1" ] || {
  echo "FAIL: the Prometheus StatefulSet has no ready replica"
  echo "      kubectl get pods -n $NS   and check for a Pending PVC:"
  echo "      a missing default StorageClass leaves the volume unbound and"
  echo "      Prometheus never starts."
  exit 1; }

TARGETS=$(q "targets?state=active")
[ -n "$TARGETS" ] || { echo "FAIL: Prometheus is not answering its API"; exit 1; }

# The cluster's own components, which arrive as ServiceMonitors the chart
# ships. Requiring several rather than one: a single lucky job could be up
# while scraping is broadly broken.
MISSING=""
for J in apiserver kubelet kube-state-metrics node-exporter; do
  echo "$TARGETS" | grep -q "\"job\":\"$J\"" || MISSING="$MISSING $J"
done
if [ -n "$MISSING" ]; then
  echo "FAIL: these cluster targets are not being scraped:$MISSING"
  echo "      Prometheus is running but is not watching the cluster."
  exit 1
fi

# Up, not merely present. A target list full of down targets satisfies any
# check that only greps for job names.
UP=$(int "$(q 'query?query=count(up%3D%3D1)')")
if [ "$UP" -lt 4 ]; then
  echo "FAIL: only $UP targets are up"
  echo "      The jobs exist but are not returning metrics."
  exit 1
fi

echo "PASS - Prometheus is ready and scraping the cluster ($UP targets up)"
exit 0
