# Kubernetes Workloads

Three objects, and the relationship between them:

```
Deployment  →  ReplicaSet  →  Pod
```

You will create a Deployment, find the ReplicaSet it created, delete a Pod and
watch something put it back, then update the image and undo that.

A single-node cluster is running. Check it:

```
kubectl get nodes
```
