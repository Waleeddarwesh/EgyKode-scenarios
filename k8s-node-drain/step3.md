# A budget that refuses the drain

The worker is empty. In a real upgrade the next node is the one now carrying
everything — and this time you want a guarantee that the drain cannot take the
application below a floor you choose.

That guarantee is a PodDisruptionBudget:

```
kubectl apply -f - <<'YAML'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web
spec:
  minAvailable: 4
  selector:
    matchLabels: { app: web }
YAML
kubectl get pdb web
```{{exec}}

Look at `ALLOWED DISRUPTIONS`. It is `0` — the controller has worked out that
with four replicas and a floor of four, **no Pod may be evicted at all**.

Try the drain and watch it refuse:

```
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data --timeout=20s
```{{exec}}

```
error when evicting pods/"web-..." -n "default" (will retry after 5s):
Cannot evict pod as it would violate the pod's disruption budget.
```

It retries every five seconds until the timeout, because a drain is normally
waiting for a *temporary* condition to clear. This one will never clear.

**The eviction API refused.** That is the mechanism: `drain` does not delete
Pods, it *requests eviction*, and the API server checks every matching PDB
before allowing one through. A PDB is what turns "please do not take this below
three replicas" from a line in a runbook into something the cluster enforces.

## The mistake in that YAML

`minAvailable: 4` on a Deployment with four replicas can never allow a single
eviction, so this node can never be drained — not now, not during the next
upgrade, not at three in the morning when somebody is trying to work out why
the maintenance window is stuck.

**`minAvailable` must be strictly below the replica count**, or the budget
blocks every drain forever rather than protecting availability during one.

The other thing worth knowing: **a PDB governs voluntary disruption only.**
Drains, node upgrades, autoscaler scale-downs. It does nothing whatsoever about
a crash, a kernel panic, or a node falling off the network — and that is the
point of it. It exists to stop you causing an outage, not to prevent one.

**Done when:** the PDB exists and reports zero allowed disruptions, and all four
replicas are still running.
