# A Deployment, and who owns the Pods

Create a Deployment with three replicas:

```
kubectl create deployment web --image=nginx:1.25 --replicas=3
kubectl rollout status deployment/web
```{{exec}}

Now look at what that actually made:

```
kubectl get deployment,replicaset,pod -l app=web
```{{exec}}

You asked for one object and got three layers. The Deployment created a
ReplicaSet; the ReplicaSet created the Pods. Confirm the ownership rather than
assuming it:

```
kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}{"\n"}'
```{{exec}}

**Done when:** a Deployment named `web` has 3 available replicas.
