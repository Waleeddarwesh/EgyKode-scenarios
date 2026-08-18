# Done

- **`Role` and `RoleBinding` are separate objects** because permissions and
  subjects have different lifetimes. One `ClusterRole`, bound per namespace, is
  the pattern you will use most
- **`kubectl auth can-i --as` asks the authoriser**, which is the only opinion
  that counts. Your YAML is a hypothesis
- **A subresource is a separate grant.** `get pods` is not `get pods/log`
- **`automountServiceAccountToken: false`** for anything that does not call the
  API — most workloads do not
- **RBAC has no deny rule.** Access is the union of every binding, so you
  restrict by not granting, and you fix an over-grant by finding the binding

That last point is the one that changes how you debug. "Why can this account
still do that?" is never answered by looking for a denial. It is answered by
listing every binding that names the subject.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's CI account needs to deploy and nothing more, and its Deployment
runs under a ServiceAccount of its own. The same reasoning carries into IRSA on
EKS later in the path, where a Kubernetes ServiceAccount is bound to an AWS IAM
role — with the same additive model, and the same absence of a deny rule, on
both sides of the boundary.
