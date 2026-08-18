The image has the database hostname compiled into it, so staging and production
are different builds of the same commit. There are no probes, so a wedged
process keeps receiving traffic. There are no limits, so one leaking container
takes the node with it.

All three are configuration problems, and Kubernetes has an object for each.

**What you will do**

1. **Move configuration out of the image** — one image, any environment
2. **Break a readiness probe on purpose** — and watch the Pod leave the Service
   without being restarted
3. **Set the QoS class you meant to set** — not the one you got by accident
4. **Change a ConfigMap** — and find out why the Pods ignore it

The second and fourth are the ones that catch people in production.

```
kubectl get namespace platform
```{{exec}}
