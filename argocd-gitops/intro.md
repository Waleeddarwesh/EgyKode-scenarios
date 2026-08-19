Every lab up to here ended with you running a command against a cluster. This
one takes that away. From now on the cluster is not something you change — it
is something that **follows** a change you make in Git.

**What you will do**

1. **Point Argo CD at a repository** and watch it build the application from
   nothing, in the order the sync waves declare
2. **Deploy by pushing a commit** — no `kubectl apply`, no cluster credentials
3. **Break the cluster by hand** and watch reconciliation put it back

There is a Git server running inside this cluster, on the `git://` protocol
with anonymous push enabled. That is a bad idea on a real network and the right
one here: the lesson needs a repository you can actually push to, and the
alternative is a GitHub token pasted into a shared terminal.

Argo CD is installing in the background as you read — it takes around four
minutes. Step 1 waits for it properly.

```
kubectl -n argocd get pods
```{{exec}}
