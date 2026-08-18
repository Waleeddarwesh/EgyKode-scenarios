# Break one on purpose

Ship a revision that cannot possibly start, and let `--atomic` do its job. This
takes about ninety seconds — the timeout has to expire before Helm gives up:

```
helm upgrade demo ./demo-chart -n demo \
  --set image.tag=this-tag-does-not-exist --set replicaCount=3 \
  --atomic --timeout 90s
```{{exec}}

While it waits, that is a real deployment stuck on a real problem: the new Pod
cannot pull its image, never becomes ready, and the rollout stalls rather than
replacing the healthy Pods. Kubernetes is protecting you here; Helm is about to
finish the job.

Then:

```
Error: UPGRADE FAILED: release demo failed, and has been rolled back
due to atomic being set: context deadline exceeded
```

Read that message: it failed, **and it has already been undone**. The command
that broke the release is the command that repaired it.

Now look at what the cluster is actually running:

```
helm history demo -n demo
kubectl get pods -n demo
kubectl get deployment -n demo -l app.kubernetes.io/instance=demo \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'; echo
```{{exec}}

```
REVISION  STATUS      DESCRIPTION
1         superseded  Install complete
2         superseded  Upgrade complete
3         failed      Upgrade "demo" failed: context deadline exceeded
4         deployed    Rollback to 2
```

**Four revisions, and the release is healthy.** Revision 3 failed; Helm rolled
forward to revision 4, which is a copy of revision 2, and the three Pods
serving traffic are the ones that were serving it before you started. The
running image is `nginx:1.27-alpine` — the broken tag never reached a running
container.

## Why the failure stays in the history

Revision 3 is still listed, permanently, with the reason. A rollback that
quietly erased the attempt would leave the next person asking why the release
jumped from 2 to 4 — and would make the postmortem an exercise in memory.

## What `--atomic` did that `--wait` alone would not

With `--wait`, everything above happens identically **up to the error message**.
The command still fails, still takes ninety seconds, and still tells you the
release broke — and then leaves it broken, sitting at revision 3, with a
Deployment trying forever to pull a tag that does not exist. Someone has to
notice and run `helm rollback` by hand.

`--atomic` is that rollback, executed automatically, in the same command, by
the process that already knows which revision was good.

There is exactly one reason to leave it off: when you want to inspect the
broken state deliberately. That is a debugging session, not a deployment.

**Done when:** the history records a failed revision, and the release is
deployed and serving the working image.
