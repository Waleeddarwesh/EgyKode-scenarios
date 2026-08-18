# Roll back to a named revision

Automatic rollback handles the failure you caused a moment ago. The other case
is the one where the upgrade *succeeded* and was still wrong — it started, it
passed its probes, and it is serving something nobody wanted.

Helm cannot detect that. You have to name the revision to return to:

```
helm rollback demo 1 -n demo --wait
helm history demo -n demo
```{{exec}}

```
REVISION  STATUS      DESCRIPTION
4         superseded  Rollback to 2
5         deployed    Rollback to 1
```

**A rollback is itself a new revision.** Nothing is rewritten and nothing is
deleted, so the history stays append-only and you can always move forward
again — rolling back to 1 does not destroy revision 4.

Now confirm it, from the cluster rather than from the history:

```
kubectl get deployment -n demo -l app.kubernetes.io/instance=demo \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'; echo
kubectl get pods -n demo
helm get values demo -n demo
```{{exec}}

One replica, not three. Revision 1 was installed before the scale-up, so
returning to it returned **every** value from that revision — not only the ones
you were thinking about.

That is worth sitting with. `helm rollback` restores a complete snapshot of a
release. It is not a targeted undo of the last change, and on a release with
several unrelated settings that is occasionally a surprise: rolling back a bad
image also reverts the replica count, the resource limits, and the feature flag
somebody set last Tuesday.

If that is not what you want, the fix is not a cleverer rollback — it is to
`helm upgrade` forward with the values you actually want, from a values file
that is in Git.

**Done when:** the release is at a revision described as `Rollback to 1`, with
one ready replica running the working image.
