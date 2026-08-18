Pod IP addresses change on every rollout, eviction and node failure. A Service
is the stable name in front of whichever Pods currently match its selector.

**What you will do**

1. **Put a Service in front of three Pods** — and read its endpoint list
2. **Reach it by name** — from another Pod, with no IP anywhere
3. **Empty the endpoint list twice** — two causes that look identical and are not

The third is the one worth your time. "Service exists, endpoints empty" is one
of the most common Kubernetes failures, and it has two completely different
causes.

```
kubectl get nodes
```{{exec}}
