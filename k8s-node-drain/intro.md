The cluster needs a Kubernetes upgrade. That means taking each node out of
service in turn, and the first node you try teaches you which of your workloads
were only ever running by luck.

**What you will do**

1. **Deploy something built to be moved** — and measure it with real traffic
   while the cluster changes underneath it
2. **Drain a node** — and meet a Pod that cannot come back
3. **Write a PodDisruptionBudget that refuses a drain** — then find the mistake
   that makes one refuse *every* drain, forever
4. **Return the node to service** — and discover that nothing moves back on its
   own

This cluster has two nodes, and the control plane has been made schedulable so
there is somewhere to reschedule to:

```
kubectl get nodes
```{{exec}}

There is also a Pod here that somebody created by hand, a long time ago:

```
kubectl get pod legacy-cache -o wide
```{{exec}}
