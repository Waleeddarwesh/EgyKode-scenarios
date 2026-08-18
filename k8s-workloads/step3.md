# Roll forward, roll back

Recreate the Deployment and change its image:

```
kubectl create deployment web --image=nginx:1.25 --replicas=3
kubectl rollout status deployment/web
kubectl set image deployment/web nginx=nginx:1.27
kubectl rollout status deployment/web
```{{exec}}

Look at the ReplicaSets now:

```
kubectl get replicaset -l app=web
```{{exec}}

There are two. The old one is kept at zero replicas — that is what makes the
next command possible:

```
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```{{exec}}

**Done when:** the Deployment is back on `nginx:1.25` with 3 replicas
available, and more than one ReplicaSet exists.
