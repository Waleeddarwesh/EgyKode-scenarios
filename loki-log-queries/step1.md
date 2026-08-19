Wait for Loki and the application:

```
kubectl -n monitoring rollout status statefulset/loki --timeout=600s
kubectl -n production rollout status deployment/api --timeout=300s
```{{exec}}

Loki is running and holds nothing. Nothing is sending it anything yet.

```
curl -s localhost:31000/loki/api/v1/label/namespace/values; echo
```{{exec}}

An empty answer, not an error. **A logging stack with no agent looks healthy.**

## Three parts, and only two of them exist so far

| Part | Job | Where it runs |
|---|---|---|
| **Promtail** | tails `/var/log/pods`, attaches Kubernetes labels | DaemonSet, one per node |
| **Loki** | stores lines, indexes **only the labels** | one Pod here |
| Grafana | draws the results | not installed — you will use the API it calls |

## Install the agent

```
helm upgrade --install promtail grafana/promtail --version 6.17.1 \
  -n monitoring \
  --set "config.clients[0].url=http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
kubectl -n monitoring rollout status daemonset/promtail --timeout=300s
```{{exec}}

**The order matters, and this is why it is a step rather than part of the
setup.** Install the agent first and it starts pushing to a Loki that is not
answering yet, exhausts its retry budget, and drops those batches. That much is
recoverable. What is not: it then stops picking up Pods created afterwards, so
the stack sits there healthy and empty. That is how this scenario was first
built, and the symptom — green Pods, no logs — reads as a broken query.

If you ever see it: `kubectl -n monitoring rollout restart daemonset/promtail`.

## Now look

Give it around half a minute, then ask which namespaces it has seen:

```
sleep 30
curl -s localhost:31000/loki/api/v1/label/namespace/values; echo
```{{exec}}

`kube-system`, `monitoring` and `production` — every namespace on the node,
without configuring any of them. Promtail discovered them from the Kubernetes
API and labelled each line with where it came from.

That is the whole point of centralised logging in one output: you did not have
to know what was running to collect its logs.
