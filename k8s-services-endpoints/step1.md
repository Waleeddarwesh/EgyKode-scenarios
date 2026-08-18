# A Service in front of three Pods

```
kubectl create deployment web --image=nginx:1.27-alpine --replicas=3
kubectl wait --for=condition=Available deploy/web --timeout=120s
kubectl get pods -o wide
```{{exec}}

Note the Pod IPs. Now delete one and look again — the replacement has a
different address. That is why nothing addresses a Pod directly.

Put a Service in front:

```
kubectl expose deployment web --port=80 --target-port=80 --name=web
kubectl get svc web
kubectl get endpoints web
```{{exec}}

**You should see** three addresses in the endpoint list. The Service matches
Pods by **label**, not by name — `kubectl expose` copied the Deployment's
`app=web` label into the selector for you.
