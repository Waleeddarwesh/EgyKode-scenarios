# A claim that outlives the Pod

Three objects, and only one of them is yours to write:

| Object | Says | Written by |
| --- | --- | --- |
| `StorageClass` | *how* to provision — which disk type | the platform team, once |
| `PersistentVolume` | a specific piece of storage that exists | usually automatically |
| `PersistentVolumeClaim` | *I need 1Gi* | you |

```
cat > /root/manifests/pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: data
EOF
kubectl apply -f /root/manifests/pvc.yaml
kubectl wait --for=condition=Ready pod/writer --timeout=180s
kubectl get pvc data
```{{exec}}

Write into the mounted path, destroy the Pod, and bring it back:

```
kubectl exec writer -- sh -c 'echo "survives" > /data/keep.txt; cat /data/keep.txt'
kubectl delete pod writer --wait=true
kubectl apply -f /root/manifests/pvc.yaml
kubectl wait --for=condition=Ready pod/writer --timeout=180s
kubectl exec writer -- cat /data/keep.txt
```{{exec}}

**You should see** `survives`. The Pod was destroyed and recreated; the claim
was not, and the data lives with the claim.
