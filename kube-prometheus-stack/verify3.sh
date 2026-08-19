#!/bin/bash
# Criterion 3: Grafana shows CPU and memory for the workload.
#
# A Grafana panel is a PromQL query against a datasource, so the two things
# that make the graph real are checked directly: the datasource resolves, and
# the queries behind a CPU/memory panel return values for this workload.
# Screenshotting a dashboard would prove neither.
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

kubectl get deploy kps-grafana -n "$NS" >/dev/null 2>&1 || {
  echo "FAIL: Grafana is not installed"; exit 1; }

READY=$(kubectl get deploy kps-grafana -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$READY" = "1" ] || { echo "FAIL: Grafana has no ready replica"; exit 1; }

# The datasource must actually resolve to Prometheus. A dashboard against a
# broken datasource draws empty panels and looks like missing metrics.
DS=$(kubectl exec -n "$NS" deploy/kps-grafana -c grafana -- \
  curl -s --max-time 15 -u admin:egykode http://localhost:3000/api/datasources 2>/dev/null)
echo "$DS" | grep -q '"type":"prometheus"' || {
  echo "FAIL: Grafana has no Prometheus datasource"
  echo "      Every panel would be empty regardless of what Prometheus holds."
  exit 1; }

# CPU, as a rate. The raw counter would return a value even if scraping had
# stopped an hour ago, because it is cumulative; a rate over a recent window
# is only non-zero if fresh samples exist.
CPU=$(q 'query?query=sum(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22shop%22,container!=%22%22%7D%5B2m%5D))' \
  | grep -o '"value":\[[^]]*\]')
[ -n "$CPU" ] || {
  echo "FAIL: no CPU rate for the shop workload"
  echo "      container_cpu_usage_seconds_total comes from cAdvisor in the"
  echo "      kubelet, so check the kubelet target is up."
  exit 1; }

MEM=$(q 'query?query=sum(container_memory_working_set_bytes%7Bnamespace%3D%22shop%22,container!=%22%22%7D)' \
  | grep -o '"value":\[[^]]*\]')
[ -n "$MEM" ] || { echo "FAIL: no memory metric for the shop workload"; exit 1; }

# Non-zero, not merely present. An empty vector and a zero both render as a
# flat line, and only one of them means the workload is being measured.
BYTES=$(int "$MEM")
if [ "$BYTES" -lt 1000 ]; then
  echo "FAIL: memory for the shop workload reads $BYTES bytes"
  echo "      That is not a running container. Check container!=\"\" is in the"
  echo "      query and that the Pods are up."
  exit 1
fi

echo "PASS - Grafana's datasource resolves and CPU and memory both report for the workload ($BYTES bytes)"
exit 0
