Everything so far is the happy path. The interesting behaviour is what happens
when the cluster and Git disagree.

## Scale it by hand

Git says three replicas. Tell Kubernetes one:

```
kubectl -n web scale deployment web --replicas=1
for i in $(seq 1 12); do printf '%s ' "$(kubectl -n web get deploy web -o jsonpath='{.spec.replicas}')"; done; echo
```{{exec}}

You will see `1` followed by `3 3 3 3...`. Blink and the `1` is gone.

Your change was not rejected — the API server accepted it happily, and for a
fraction of a second the Deployment really did want one replica. It was
**reverted**, because a controller is continuously making the cluster match
Git, and your edit was simply the next difference it found.

```text
Git                          Cluster
replicas: 3                  replicas: 3
     |                            |
     |                     kubectl scale --replicas=1
     |                            v
replicas: 3        <-- drift -->  replicas: 1
     |
     |  Argo CD compares, finds a difference,
     |  and applies Git's version
     v
replicas: 3                  replicas: 3
```

## Why this was instant and step 2 was not

Argo CD **watches** the cluster and **polls** Git. Drift arrives as a watch
event and is corrected in under a second. A commit is not seen until the next
poll.

Look at what it recorded:

```
kubectl -n argocd get events --sort-by=.lastTimestamp | grep OperationCompleted
```{{exec}}

Two different words:

- `Sync operation to <sha> succeeded` — a commit you pushed, in step 2
- `Partial sync operation to <sha> succeeded` — a self-heal, just now

"Partial" because Argo CD reapplied only the one resource that had drifted,
against the commit that was already deployed. Nothing in Git changed.

## What you gave up

Self-heal has a cost, and pretending otherwise is how people are surprised at
3am. Prove the first one to yourself:

```
kubectl -n web set image deployment/web web=nginx:1.25-alpine
sleep 5
kubectl -n web get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```{{exec}}

Your emergency hotfix lasted about a second — measured at one, and the five
above is only so the reverted value is certain by the time you read it.

- **You cannot fix anything by hand.** The fix is a commit, and your recovery
  time is now bounded by how fast you can merge.
- **A bad commit deploys itself.** The protection is review on the pull
  request, not the cluster.
- **`prune: true` deletes.** Remove a manifest from Git and the object goes.
  That is the point, and it is also how a bad rebase deletes a database.

Rolling back is `git revert`, and it takes the same path as everything else.
