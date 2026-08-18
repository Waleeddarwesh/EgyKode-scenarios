# Delete a Pod, then delete the Deployment

Kill one Pod and watch what happens:

```
kubectl get pod -l app=web
kubectl delete pod -l app=web --field-selector=status.phase=Running --wait=false | head -1
kubectl get pod -l app=web -w
```

Press `Ctrl+C` once you have seen a replacement appear. You did not create it —
the ReplicaSet did, because its job is to make the observed count match the
desired count.

Now delete the layer above:

```
kubectl delete deployment web
kubectl get replicaset,pod -l app=web
```{{exec}}

The ReplicaSet and Pods went with it. Deleting the owner deletes what it owns;
deleting what it owns changes nothing for long.

**Done when:** no Deployment, ReplicaSet or Pod labelled `app=web` remains.
