# The access mode that blocks a rollout

`ReadWriteOnce` means the volume can be mounted read-write by **one node**. Ask
for three replicas sharing one such claim and see what happens:

```
cat > /root/manifests/three.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared
spec:
  replicas: 3
  selector:
    matchLabels: { app: shared }
  template:
    metadata:
      labels: { app: shared }
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
kubectl apply -f /root/manifests/three.yaml
sleep 20
kubectl get pods -l app=shared
```{{exec}}

On a single-node cluster all three may schedule, because ReadWriteOnce is a
*node* restriction and there is only one node. On a real multi-node cluster the
Pods that land elsewhere stay `Pending` forever.

Look at why, in the Pod's own words:

```
kubectl describe pod -l app=shared | grep -A5 -i events | head -12
```{{exec}}

Record what the access mode actually restricts:

```
kubectl get pvc data -o jsonpath='{.spec.accessModes[0]}' > /root/manifests/accessmode.txt
echo " - ReadWriteOnce binds to one NODE, not one Pod" >> /root/manifests/accessmode.txt
cat /root/manifests/accessmode.txt
```{{exec}}

**The lesson:** a database gets its own claim, not a shared one. When several
replicas each need storage, that is a StatefulSet with a
`volumeClaimTemplate` — one claim per Pod.
