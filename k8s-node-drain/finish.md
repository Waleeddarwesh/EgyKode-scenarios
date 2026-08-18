# Done

- **Cordon is free, drain is not.** Cordon stops arrivals and evicts nothing —
  run it long before the window. Drain moves what is already there
- **`drain` requests eviction; it does not delete.** Every matching PDB is
  consulted, which is what makes a budget enforceable rather than advisory
- **A Pod with no controller cannot be moved**, only deleted. `--force` is you
  saying so out loud
- **`preStop` plus a readiness probe** is what turns a drain into a non-event.
  Endpoint removal and `SIGTERM` race each other, and the pause decides which
  one wins
- **`minAvailable` must be below the replica count**, or the budget blocks every
  drain forever instead of protecting one
- **Nothing rebalances on its own.** An uncordoned node stays empty until
  something forces a reschedule

A real version upgrade wraps this loop:

```
cordon -> drain -> upgrade kubeadm and kubelet -> uncordon -> verify -> next node
```

Control plane first, one node at a time, and never skip a minor version — 1.28
to 1.30 is two upgrades, not one.

---

## Where this fits

**Phase: Production** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the difference between a platform you can patch and one you cannot. The
capstone workloads carry the settings you added here — spread replicas, a
readiness probe, a `preStop` pause, and a PDB with a floor below the replica
count — because a cluster that cannot be drained is a cluster that cannot be
upgraded, and a cluster that cannot be upgraded eventually becomes a cluster
with a published CVE in it.
