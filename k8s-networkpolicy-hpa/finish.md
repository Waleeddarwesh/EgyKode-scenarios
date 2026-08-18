# Done

Both halves of this scenario fail the same way: an object that exists, appears
in `kubectl get`, and does nothing.

- **Kubernetes stores NetworkPolicies; the network plugin enforces them.** The
  API server accepts your policy on a cluster that ignores every one. Calico,
  Cilium and recent kindnet enforce; plain Flannel does not. **Demonstrate a
  block before you depend on one**
- **A Pod selected by no policy is unrestricted.** Policies are a whitelist for
  the Pods they select and irrelevant to the rest, which is why default-deny
  goes on first and everything else is an exception to it
- **There is no deny rule.** Allowed traffic is the union of every policy
  selecting the Pod. You restrict by not allowing
- **Forgetting DNS egress is the classic self-inflicted outage.** By IP it
  works, by name it hangs, and the symptom points at the database. Allow UDP
  **and** TCP on 53
- **`namespaceSelector` and `podSelector` in one list item** means "these Pods
  in those namespaces". In two items it means "any Pod there, or any Pod with
  that label anywhere" — one `-` of difference, and far wider
- **Both ends need a rule.** Egress from the client and ingress to the server
  are separate decisions under a default-deny
- **An HPA with no CPU request does nothing**, because a utilization target is a
  percentage of the request. `<unknown>/50%` and `ScalingActive: False` are what
  that looks like
- **Scale-up is fast, scale-down is slow on purpose.** Five minutes of
  stabilization by default, because flapping costs more than an extra Pod

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's database should be reachable by the application and by nothing
else, and that is a NetworkPolicy rather than a promise. The same reasoning
carries into security groups on the AWS side of the path: allow the specific
source, never the CIDR that happens to work. And the HPA is what makes the
capacity planning in the resources lab load-bearing — requests stop being a
scheduling hint and become the number your autoscaling is computed from.
