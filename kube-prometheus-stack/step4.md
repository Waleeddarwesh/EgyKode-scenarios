# Metrics that outlive the Pod

Prometheus keeps its data on disk. Which disk decides whether a restart is an
inconvenience or a hole in your history.

```
kubectl get pvc -n monitoring
kubectl get statefulset prometheus-kps-kube-prometheus-stack-prometheus -n monitoring \
  -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}{"\n"}'
```{{exec}}

A **PersistentVolumeClaim**, bound, from the `volumeClaimTemplate` on the
StatefulSet. That is not the default: with no `storageSpec` in the chart values,
kube-prometheus-stack gives Prometheus an `emptyDir`, which lives and dies with
the Pod. Every graph would reset to the moment of the last restart, and nobody
notices until the first incident review asks what the traffic looked like an
hour ago.

## Record what history exists, then delete Prometheus

```
Q() {
  kubectl run q$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
    curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=$1" 2>/dev/null \
    | grep -o '"value":\[[^]]*\]'
}
echo "samples of up{namespace=shop} in the last 10 minutes, BEFORE:"
Q 'count_over_time(up%7Bnamespace%3D%22shop%22%7D%5B10m%5D)'
```{{exec}}

Now take the Pod away. Not a restart of the process — delete it, so a new Pod
with a new name and a new IP has to attach to the same volume:

```
kubectl delete pod prometheus-kps-kube-prometheus-stack-prometheus-0 -n monitoring
kubectl rollout status statefulset/prometheus-kps-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=600s
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o wide
```{{exec}}

## Ask for the same window again

```
Q() {
  kubectl run q$RANDOM --rm -i --restart=Never --image=curlimages/curl:8.10.1 -n monitoring -- \
    curl -s "http://kps-kube-prometheus-stack-prometheus:9090/api/v1/query?query=$1" 2>/dev/null \
    | grep -o '"value":\[[^]]*\]'
}
sleep 20
echo "samples of up{namespace=shop} in the last 10 minutes, AFTER:"
Q 'count_over_time(up%7Bnamespace%3D%22shop%22%7D%5B10m%5D)'
```{{exec}}

**The count went up, not back to one.** The new Pod read the old blocks off the
volume and carried on appending. Had this been an `emptyDir`, the same query
would report a handful of samples — everything before the delete gone, with no
error anywhere to tell you so.

## Why a StatefulSet, and not a Deployment

```
kubectl get statefulset -n monitoring -o jsonpath='{.items[0].spec.serviceName}{"\n"}'
```{{exec}}

A Deployment's Pods are interchangeable and its volume claim would be shared or
duplicated; a StatefulSet gives each Pod a stable name and *its own* claim that
follows it across restarts. `prometheus-…-0` will always reattach to the volume
`prometheus-…-0` was using. That is the entire reason the operator builds a
StatefulSet.

**A caution worth carrying:** this makes Prometheus durable, not backed up. The
volume is one disk in one place. Long retention and real durability are what
remote-write to something like Thanos or Mimir is for — a lab of its own, and
the next question after this one.

**Done when:** the sample count for the same window is no lower after the
delete than before it.
