# A workload built to survive being moved

Four replicas, and two settings that decide whether a drain is invisible or an
outage:

```
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 4
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          readinessProbe:
            httpGet: { path: /, port: 80 }
            periodSeconds: 3
          lifecycle:
            preStop:
              exec: { command: ["sh", "-c", "sleep 5"] }
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector: { app: web }
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
YAML
kubectl rollout status deployment/web --timeout=180s
kubectl get pods -o wide -l app=web
```{{exec}}

Note which node each replica landed on. That spread is what makes the next step
survivable.

**The `preStop` sleep is not superstition.** When a Pod is told to stop, two
things happen *at the same time*:

- the Pod is removed from the Service's endpoints, and that removal has to
  propagate to kube-proxy on every node
- `SIGTERM` is sent to the container

Nothing orders those two. Without the pause, the process can be gone before the
last kube-proxy has heard about it, and traffic is still being routed to it —
which is the classic "we drained a node and lost requests" incident. The five
seconds give the removal time to land before shutdown begins.

Now start measuring. This runs in the background and appends one HTTP status
code per request to a file:

```
nohup sh -c 'while true; do curl -s -o /dev/null -w "%{http_code}\n" --max-time 2 http://localhost:30080/ >> /tmp/probe.log; sleep 0.2; done' >/dev/null 2>&1 &
sleep 5
echo "requests so far: $(wc -l < /tmp/probe.log)"
sort /tmp/probe.log | uniq -c
```{{exec}}

All `200`. Leave it running — it is the only honest way to tell whether the
drain cost anything.

Finally, stop new Pods arriving on the worker:

```
WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
echo "worker is $WORKER"
kubectl cordon $WORKER
kubectl get nodes
```{{exec}}

`SchedulingDisabled`. **Cordon stops new Pods arriving; it evicts nothing.**
Existing Pods keep running and keep serving, which is why cordoning well before
a maintenance window is free.

**Done when:** four replicas are ready, the probe is recording, and the worker
is cordoned.
