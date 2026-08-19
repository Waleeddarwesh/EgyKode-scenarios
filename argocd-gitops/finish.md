The cluster is now downstream of a repository.

**What you proved**

- An Application is one object naming a repository, a path and a destination.
  Everything else — the namespace, the waves, the ordering, the pruning —
  follows from it
- A commit deployed an image, with no cluster credentials anywhere in the path
- `status.history` is the deployment record, and it cannot lie, because it is
  what caused the deployment
- Drift is reverted in under a second; a commit takes a poll interval. Argo CD
  watches the cluster and polls Git

**The two words worth remembering**

`Sync operation` is a commit of yours. `Partial sync operation` is Argo CD
undoing something somebody did by hand. If you see the second one in a real
cluster and did not expect it, somebody is editing production.

**What was real here, and what was not**

The reconciliation, the sync waves, the drift detection and the self-heal are
exactly what Argo CD does in production. The Git server is not: real setups use
GitHub or GitLab with authentication and a webhook, and would never enable
anonymous push. The `git://` protocol has no authentication at all — it is here
so that you have something to push to.
