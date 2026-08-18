# Done

- **A container filesystem is disposable** — same Pod name, new filesystem
- **Data lives with the claim**, not the Pod. Delete the Pod as often as you
  like; the PVC is a separate object with a separate lifecycle
- **`ReadWriteOnce` is a node restriction** — it reads like "one writer" and
  means "one node", which is why it only bites on a multi-node cluster

That last one is the trap. It works on your single-node test cluster and leaves
Pods `Pending` in production, and the event message talks about volume
attachment rather than saying "your access mode is wrong".

When several replicas each need their own storage, the answer is a StatefulSet
with a `volumeClaimTemplate` — one claim per Pod, not one claim shared.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's PostgreSQL runs on a claim exactly like this one. Knowing that
the data survives the Pod, and that the access mode restricts the node rather
than the replica count, is what stops a database being scheduled somewhere it
cannot attach its disk.
