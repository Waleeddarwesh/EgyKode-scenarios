# The filesystem is disposable

Write something into a Pod, delete the Pod, and look for it:

```
kubectl run scratch --image=busybox:1.36 --restart=Never -- sh -c "sleep 3600"
kubectl wait --for=condition=Ready pod/scratch --timeout=120s
kubectl exec scratch -- sh -c 'echo "important" > /data.txt; cat /data.txt'
kubectl delete pod scratch --wait=true
```{{exec}}

Now recreate it with the same name and look for the file:

```
kubectl run scratch --image=busybox:1.36 --restart=Never -- sh -c "sleep 3600"
kubectl wait --for=condition=Ready pod/scratch --timeout=120s
kubectl exec scratch -- sh -c 'cat /data.txt 2>&1 || echo "GONE: no such file"'
```{{exec}}

**You should see** `GONE`. Same name, same image, new filesystem. Nothing about
a Pod's identity carries its data.

Record what you found:

```
kubectl exec scratch -- sh -c 'cat /data.txt 2>/dev/null || echo gone' > /root/manifests/ephemeral.txt
cat /root/manifests/ephemeral.txt
```{{exec}}
