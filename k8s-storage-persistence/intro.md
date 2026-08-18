A container's filesystem dies with the container. That is a feature, and it is
also why a database in Kubernetes needs one more object than an application
does.

**What you will do**

1. **Prove the filesystem is disposable** — rather than take it on trust
2. **Mount a claim** — and watch the same data survive a Pod deletion
3. **Hit the access-mode wall** — three replicas, one ReadWriteOnce claim

The third is the one that catches people. It looks like a scheduling problem
and it is a storage problem.

```
kubectl get storageclass
```{{exec}}
