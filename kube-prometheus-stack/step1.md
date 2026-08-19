# What the stack is already watching

Wait for Prometheus. The chart installs quickly; the Pods take a few minutes:

```
for i in $(seq 1 90); do
  kubectl get statefulset -n monitoring 2>/dev/null | grep -q prometheus && break
  printf "."
  sleep 5
done
echo
kubectl rollout status statefulset/prometheus-kps-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=900s
kubectl get pods -n monitoring
```{{exec}}

Five workloads, and it is worth knowing what each is for before you use any of
them:

| Pod | Does |
| --- | --- |
| `prometheus-…-prometheus-0` | Stores the data and runs the queries |
| `…-operator` | Turns ServiceMonitor objects into scrape configuration |
| `…-kube-state-metrics` | Exports the state of Kubernetes objects — replicas desired vs ready |
| `…-node-exporter` | Exports the machine — CPU, memory, disk, one per node |
| `kps-grafana` | Draws it |

`kube-state-metrics` and `node-exporter` answer different questions and get
confused constantly. *"Is the node out of memory"* is node-exporter. *"Is the
Deployment missing replicas"* is kube-state-metrics. Neither knows anything
about the inside of your application.

## Ask Prometheus what it is scraping

There is no browser here, so query the API directly. This runs a throwaway
`curl` Pod inside the cluster, because the Prometheus Service is a ClusterIP:

```
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/targets?state=active" \
  | tr ',' '\n' | grep -o '"job":"[^"]*"' | sort -u
```{{exec}}

The control plane is already there without you configuring anything:
`apiserver`, `kube-scheduler`, `kube-controller-manager`, `kube-etcd`,
`coredns`, `kubelet`, plus `node-exporter` and `kube-state-metrics`.

**Every one of those arrived as a ServiceMonitor the chart shipped.** That is
the pattern the whole stack rests on: Prometheus has no static target list, it
has a selector, and objects that match get scraped.

## Your application is not in that list

```
kubectl get pods,svc -n shop
kubectl run q --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
  curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=up%7Bnamespace%3D%22shop%22%7D" \
  | grep -o '"result":\[[^]]*\]'
```{{exec}}

Running, exposed, serving `/metrics` — and Prometheus has never heard of it.
`"result":[]`. Nothing is broken; nothing has asked for it to be scraped. That
is step 2.

**Done when:** the Prometheus Pod is running and its target list includes the
cluster's own components.
