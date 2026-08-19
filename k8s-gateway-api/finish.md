# Done

- **Two resources instead of one, split by owner.** A `Gateway` carries the
  listener, port and certificate; an `HTTPRoute` carries hostnames and paths.
  In Ingress they share an object, so anyone who may edit a path may edit the
  certificate
- **`weight` is a field, not a string.** Typed, validated on apply, documented by
  `kubectl explain`, and identical on every conformant controller. The Ingress
  equivalent is three vendor annotations that fail silently when misspelled
- **A weighted split is not a quota.** You counted roughly 80/20 over a hundred
  requests and got neither exactly. Weighted round-robin converges over volume,
  so a canary check demanding exact ratios fails on a working system
- **Weights are relative, and not sticky.** `80/20` behaves like `4/1`, and one
  user can see both versions in consecutive requests
- **A more specific match wins**, defined by the API rather than by the order you
  wrote the rules in — which is how a team pins itself to a canary with a header
  while everyone else stays on the split
- **`allowedRoutes` is a real boundary.** The route from an unlabelled namespace
  was refused with `NotAllowedByListeners`, in status, even though it asked for
  a hostname another team was already using

The two things Ingress cannot express are both consequences of one decision:
**fewer, larger resources are easier to write and impossible to delegate.**

One controller-specific note worth carrying: NGINX Gateway Fabric manages a
single Gateway per deployment, which is why the first one had to be deleted
before the shared one could take over. That is an implementation limit, not an
API one.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's entry point is the one resource every team needs and no team
should own outright. This is the shape that makes that workable: one Gateway run
by whoever runs the cluster, and routes each team ships alongside its own
application, with the boundary enforced by the API rather than by review.
