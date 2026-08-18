Two hardening jobs that fail in the same way: they look applied and do nothing.

A NetworkPolicy is accepted by the API server whether or not anything enforces
it. An HPA is created whether or not it can read a single metric. Both sit there
in `kubectl get` output, looking exactly like a control that works.

**What you will do**

1. **Apply a default-deny and prove traffic actually stops** — because a policy
   you cannot demonstrate is indistinguishable from one being ignored
2. **Allow back precisely what the application needs**, including the DNS rule
   everyone forgets and then spends an afternoon debugging
3. **Watch an HPA report `<unknown>`** and fix the reason

```
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name --no-headers | grep -iE "calico|cilium|weave|flannel|kindnet" | head -3
kubectl top nodes
```{{exec}}

The first command names the network plugin. Hold on to it — whether it enforces
NetworkPolicy is the entire subject of step 1.
