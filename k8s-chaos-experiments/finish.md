# Done

- **Each layer is protected by the one above it, and the top layer is not.** A
  container is restarted by the kubelet, a Pod by its ReplicaSet, a ReplicaSet by
  its Deployment — and nothing watches the Deployment
- **A container restart is not a Pod replacement.** Same name, same IP, `RESTARTS`
  incremented, nothing rescheduled
- **Recovery time for the top layer is human response time.** That is the
  argument for continuous reconciliation, not for typing faster
- **A hypothesis written afterwards is a description.** You cannot be surprised
  by a result you have already seen, and the surprises are the whole return
- **Measure the baseline before you inject.** The probe's opening `000`s were the
  measurement starting before kube-proxy was ready — counting them would have
  disproved a correct hypothesis and sent somebody hunting a fault that does not
  exist

| Experiment | Recovery | Who recovers it |
| --- | --- | --- |
| Kill a container | seconds, in place | kubelet |
| Kill a Pod | seconds, rescheduled | ReplicaSet |
| Delete the Deployment | as long as a human takes | nobody |

Voluntary disruption — a drain evicting more replicas than you can afford, and
the PodDisruptionBudget that refuses it — is run in full in the **node drain and
upgrade** scenario rather than repeated here.

---

## Where this fits

**Phase: Production** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The third row of that table is why the platform ends with GitOps. Argo CD
watching the Deployment turns "as long as a human takes" into "as long as a sync
interval", and that is a measured difference rather than a preference.
