# Done

- **One image, any environment.** The values arrive from a ConfigMap and a
  Secret, so staging and production are the same build
- **Readiness removes, liveness kills.** You saw a Pod leave the Service with
  `RESTARTS 0` — reach for liveness where readiness belongs and a slow
  dependency becomes a restart storm
- **QoS comes from the arithmetic**, not from intent. Equal requests and limits
  on *every* container, init containers included, or it is not `Guaranteed`
- **`envFrom` values are read once.** A ConfigMap change reaches the Pods when
  the Pods are replaced, and not before

`base64` is encoding. A Secret is worth more than a ConfigMap because RBAC can
withhold it separately and it is kept on `tmpfs` — not because the value is
hidden.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Every workload you deploy from here on carries this shape: config outside the
image, probes that answer the right question, resources that produce a QoS
class you chose. The Helm chart later in the path templates exactly these
fields, and Argo CD reconciles them — so a mistake made here is a mistake that
gets deployed automatically, on every commit, for the rest of the platform.
