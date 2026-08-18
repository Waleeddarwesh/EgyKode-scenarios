# Readiness removes a Pod without restarting it

Three probes answer three different questions, and conflating them causes
outages:

| Probe | Asks | On failure |
| --- | --- | --- |
| `startupProbe` | Has it finished booting? | Holds the other two off |
| `readinessProbe` | Can it serve **now**? | Removed from the Service. Not restarted. |
| `livenessProbe` | Is it wedged? | **Container killed** |

Add a readiness probe. An init container writes the file the probe asks for, so
you have something you can take away later:

```
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: platform
spec:
  replicas: 2
  selector:
    matchLabels: { app: api }
  template:
    metadata:
      labels: { app: api }
    spec:
      initContainers:
        - name: seed
          image: nginx:1.27-alpine
          command: ["sh", "-c", "echo ok > /work/healthz"]
          volumeMounts:
            - { name: web, mountPath: /work }
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          envFrom:
            - configMapRef: { name: app-config }
            - secretRef: { name: app-secrets }
          readinessProbe:
            httpGet: { path: /healthz, port: 80 }
            periodSeconds: 3
          volumeMounts:
            - { name: web, mountPath: /usr/share/nginx/html }
      volumes:
        - name: web
          emptyDir: {}
YAML
kubectl rollout status deployment/api -n platform --timeout=120s
```{{exec}}

Both Pods are in the Service. This is what a Service actually resolves to:

```
kubectl get endpointslice -n platform -l kubernetes.io/service-name=api -o custom-columns=ADDRESS:.endpoints[*].addresses[0],READY:.endpoints[*].conditions.ready
```{{exec}}

Two addresses, both `true`.

Note that the readiness column is the one that matters. An unready endpoint is
not deleted from the slice — it stays listed with `ready=false`, and kube-proxy
skips it. `-o wide` shows you the addresses without that column, which is why
it looks unchanged even when traffic has stopped flowing.

Now break readiness on **one** Pod by deleting the file the probe fetches:

```
POD=$(kubectl get pod -n platform -l app=api -o jsonpath='{.items[0].metadata.name}')
echo "breaking readiness on $POD"
kubectl exec -n platform $POD -- rm /usr/share/nginx/html/healthz
sleep 12
kubectl get pod -n platform -l app=api
kubectl get endpointslice -n platform -l kubernetes.io/service-name=api -o custom-columns=ADDRESS:.endpoints[*].addresses[0],READY:.endpoints[*].conditions.ready
```{{exec}}

Read those two outputs together. One Pod shows `0/1` — and `RESTARTS 0`. One
endpoint now reads `false`. It was taken out of the Service and **left
running**. Nothing killed it, because readiness is not liveness.

Had that been a liveness probe, the container would have been killed instead.
A liveness probe pointed at an endpoint that touches the database is how a
database blip becomes every Pod restarting at once.

**Done when:** exactly one Pod is `0/1` with zero restarts, and the Service has
one ready endpoint left.
