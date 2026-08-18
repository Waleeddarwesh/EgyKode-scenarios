# Back into service

First make the budget usable. A floor of three out of four permits exactly one
eviction at a time, which is what a rolling node upgrade needs:

```
kubectl patch pdb web --type merge -p '{"spec":{"minAvailable":3}}'
kubectl get pdb web
```{{exec}}

`ALLOWED DISRUPTIONS: 1`. The same object now protects the application instead
of blocking maintenance.

Return both nodes to service:

```
kubectl uncordon $(kubectl get nodes -o name)
kubectl get nodes
```{{exec}}

Both `Ready`, neither `SchedulingDisabled`. Now look at where the Pods actually
are:

```
kubectl get pods -o wide -l app=web
```{{exec}}

Still all on the control plane. **Kubernetes does not rebalance running Pods.**
Uncordoning makes a node eligible for *new* Pods; it does not move existing
ones. After a drain the remaining nodes stay loaded until something forces a
reschedule — which is why the node you just brought back sits idle while the
other one carries everything.

Force it:

```
kubectl rollout restart deployment/web
kubectl rollout status deployment/web --timeout=180s
kubectl get pods -o wide -l app=web
```{{exec}}

The replicas are spread again. Confirm the rebalance cost nothing either:

```
echo "total requests: $(wc -l < /tmp/probe.log)"
echo "failed requests: $(grep -vc 200 /tmp/probe.log)"
```{{exec}}

Zero failures, across a drain and a full redeploy.

Stop the probe:

```
pkill -f 30080 ; echo stopped
```{{exec}}

**Done when:** both nodes are schedulable and the worker is running `web` Pods
again.
