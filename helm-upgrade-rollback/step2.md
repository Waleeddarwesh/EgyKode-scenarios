# Upgrade, and read the history

Scale to three replicas — and notice which flags this command carries:

```
helm upgrade demo ./demo-chart -n demo \
  --set image.tag=1.27-alpine --set replicaCount=3 \
  --atomic --timeout 180s
kubectl get pods -n demo
```{{exec}}

Three flags, three different jobs:

| Flag | Does |
| --- | --- |
| `--wait` | Waits for the resources to become ready, then reports failure |
| `--atomic` | `--wait`, **and rolls the release back automatically if it fails** |
| `--timeout` | How long to wait before calling it failed |

**`--wait` tells you the release broke. `--atomic` un-breaks it.** That is the
difference between a failed deploy being an incident and being a message in a
channel. You will see it happen in the next step.

Now the object this whole scenario turns on:

```
helm history demo -n demo
```{{exec}}

```
REVISION  STATUS      CHART             DESCRIPTION
1         superseded  demo-chart-0.1.0  Install complete
2         deployed    demo-chart-0.1.0  Upgrade complete
```

Revision 1 is not gone. It is **superseded** — its manifests and values are
still sitting in a Secret, complete, ready to be re-applied without fetching or
rendering anything.

## Two habits worth forming now

```
helm get values demo -n demo
```{{exec}}

That is what the release is *actually* running, which is frequently not what
the values file in Git says. When a cluster and a repository disagree, this
command is the tiebreaker.

The other habit is a flag to avoid: **`--reuse-values` is a trap.** It carries
forward every value from the previous revision, including the one you removed
on purpose, so the release keeps a setting nobody can find in source control.
`--reset-values` with an explicit `-f values-prod.yaml` does the same job
predictably.

**Done when:** the release is at revision 2 with three ready replicas.
