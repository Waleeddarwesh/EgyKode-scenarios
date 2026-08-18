Every workload in this cluster runs as the `default` ServiceAccount, and its
API token is mounted into every Pod. Anything that reaches a container reaches
the Kubernetes API with it.

NetworkPolicies control what a Pod can **talk to**. RBAC controls what it can
**do**. You need both, and this is the second one.

**What you will do**

1. **Grant read-only access to one namespace** — and prove the refusal in the
   other, by asking the API server rather than by reading your own YAML
2. **Give a workload its own identity** — and take away the token it never uses
3. **Find a cluster-admin grant that should not exist** — and discover that you
   cannot deny it, only stop granting it

There are already two namespaces, `team-a` and `team-b`:

```
kubectl get namespace team-a team-b
```{{exec}}
