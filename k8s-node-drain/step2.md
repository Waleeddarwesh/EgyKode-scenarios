# Drain, and the Pod that cannot come back

Cordon stopped new arrivals. Draining moves what is already there:

```
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data
```{{exec}}

It refuses, and names the reason:

```
error: unable to drain node "node01" due to error: cannot delete Pods
that declare no controller (use --force to override): default/legacy-cache
```

**That Pod has nothing behind it.** A Deployment's Pods can be evicted because
the ReplicaSet immediately makes new ones somewhere else. `legacy-cache` was
created by hand, so eviction is not a move — it is a deletion. `drain` will not
make that decision for you.

Two flags in that command deserve a sentence each before you add a third:

- **`--ignore-daemonsets`** — DaemonSet Pods are recreated on the same node by
  design, so a drain can never evict them. Without this flag it refuses to
  start at all.
- **`--delete-emptydir-data`** — any `emptyDir` on this node is destroyed. You
  are asked to say so deliberately, because that data has no copy.

Now say the third one deliberately too:

```
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data --force
kubectl get pods -o wide
```{{exec}}

Read the output carefully. Four `web` replicas are running on the control plane
— they were moved. `legacy-cache` is simply **gone**, and nothing anywhere is
going to bring it back. That is what `--force` meant.

Now the question the whole exercise exists to answer:

```
sort /tmp/probe.log | uniq -c
echo "failed requests: $(grep -vc 200 /tmp/probe.log)"
```{{exec}}

**Zero.** The node was emptied while the application kept answering every single
request, because the replicas were spread, the readiness probe kept traffic off
Pods that were not ready, and the `preStop` pause let endpoint removal land
before shutdown.

A workload that cannot survive this has a name: it is a workload you cannot
upgrade a cluster around.

**Done when:** the worker runs no application Pods, `legacy-cache` is gone, all
four replicas are ready elsewhere, and the probe log contains no failures.
