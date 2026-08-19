Ingress has one resource and a hundred annotations. Every non-trivial thing —
a rewrite, a canary, a timeout, mTLS — is a vendor-specific string in
`metadata.annotations`, which means it is unvalidated, undocumented by the API,
and different on the next controller.

Gateway API replaces that with typed resources, and splits them by who owns
what.

**What you will do**

1. **Reach one application through an Ingress and an HTTPRoute** at the same
   time, and compare what each says
2. **Split traffic 80/20** and count the result — with no annotations at all
3. **See the ownership boundary**: a Gateway the platform team runs, and routes
   that application teams attach to it from their own namespaces

Two controllers are installed: ingress-nginx and NGINX Gateway Fabric.

```
kubectl get gatewayclass
kubectl -n routing get deploy,svc --no-headers
```{{exec}}
