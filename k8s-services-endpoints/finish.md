# Done

- **A Service is a label selector** — it has no idea which Pods exist, only
  which labels it is looking for
- **Endpoints are the truth** — `get svc` looks identical whether three Pods
  are behind it or none
- **Two causes, one symptom** — a selector matching nothing, and Pods that are
  running but not ready

The second cause is the subtle one. A Pod can be `Running` and completely
absent from the endpoint list, because readiness — not liveness, not phase —
is what decides whether traffic arrives.

So when something is unreachable, `kubectl get endpoints` before anything else.
It tells you in one line whether the problem is in front of the Service or
behind it.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's application, database and cache all reach each other by Service
name, exactly as here. When the Ingress later returns 502, the endpoint list is
the first thing to look at — an empty one means the Ingress is fine and the
Pods behind it are not.
