Three objects, and the relationship between them:

```text
Deployment  →  ReplicaSet  →  Pod
```

**What you will do**

1. **Run a Deployment** — and find the ReplicaSet it created
2. **Delete a Pod** — and watch something put it back
3. **Roll an update** — forward, then undo it

A single-node cluster is already running. Confirm it before you start:

```
kubectl get nodes
```{{exec}}
