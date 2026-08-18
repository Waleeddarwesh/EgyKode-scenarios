# Done

You saw the three layers, and which one is actually responsible for keeping
Pods alive. Deleting a Pod proved the ReplicaSet reconciles; deleting the
Deployment proved ownership cascades.

The old ReplicaSet kept at zero replicas is not clutter — it is the rollback.

Return to EgyKode to record what you proved, and to answer the remaining
criterion there: how to produce a Deployment that creates zero Pods, and why.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The Deployment you create here is the shape the platform's application runs in. ReplicaSets, rolling updates and `rollout undo` are what Argo CD is driving when it reconciles the cluster later.
