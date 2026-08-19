# Grafana, and the numbers behind the graph

Grafana is running with the Prometheus datasource already provisioned by the
chart. Confirm that, rather than assuming it:

```
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl exec -n monitoring deploy/kps-grafana -c grafana -- \
  curl -s -u admin:egykode http://localhost:3000/api/datasources \
  | tr ',' '\n' | grep -E '"name"|"type"|"url"'
```{{exec}}

One datasource, type `prometheus`, pointing at the in-cluster Service. A
dashboard is a saved query against that; if the datasource is wrong every panel
is empty and the dashboard looks broken.

## The queries a CPU-and-memory dashboard is made of

A graph is not a thing Grafana knows — it is a PromQL query it runs for you. So
run them yourself, and the dashboard stops being magic:

```
Q() {
  kubectl run q$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
    curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=$1" 2>/dev/null \
    | grep -o '"value":\[[^]]*\]'
}
echo "CPU cores in use by the shop workload:"
Q 'sum(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22shop%22,container!=%22%22%7D%5B2m%5D))'
echo "Memory bytes held by the shop workload:"
Q 'sum(container_memory_working_set_bytes%7Bnamespace%3D%22shop%22,container!=%22%22%7D)'
```{{exec}}

A small number of cores and a few tens of megabytes. Three things in those
queries are worth keeping:

**`rate(...[2m])` on CPU, not the raw counter.** `container_cpu_usage_seconds_total`
only ever increases — it is seconds of CPU consumed since the container started.
Graphing it gives a line that climbs forever. `rate` turns it into cores-per-second,
which is the thing a human means by "CPU usage".

**`container_memory_working_set_bytes`, not `container_memory_usage_bytes`.**
Usage includes cache the kernel will drop under pressure, so it reads high and
alarms on nothing. Working set is what the OOM killer actually considers, which
makes it the one to alarm on.

**`container!=""`.** Without it each Pod is counted twice — once per container
and once for the Pod's `POD` pause container, whose totals are the sum. Every
memory dashboard that reads exactly double has this bug.

## Where these come from

```
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bjob%3D%22kubelet%22%7D" \
  | grep -o '"result":\[' && echo "kubelet target is up"
```{{exec}}

Not from your application, and not from the ServiceMonitor you wrote in step 2.
Container CPU and memory come from **cAdvisor inside the kubelet**, which is why
you get them for every Pod in the cluster for free — including ones whose
authors never thought about monitoring.

Your ServiceMonitor gets you what the *application* knows: request counts,
latency, queue depth. The two together are the picture; either alone is half of
one.

**Done when:** the datasource resolves and both CPU and memory queries return a
value for the `shop` workload.
