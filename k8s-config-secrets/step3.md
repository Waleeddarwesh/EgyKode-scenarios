# Requests, limits and the QoS class you meant

- **`requests`** is what the scheduler reserves. Too high and Pods sit `Pending`.
- **`limits`** is the ceiling. Exceeding memory is an **immediate OOM kill**;
  exceeding CPU is **throttling**, not a kill — which is why it presents as
  latency rather than as an error.

The relationship between the two decides the QoS class, and the QoS class
decides who gets evicted when a node runs out:

| Set | Class | Evicted |
| --- | --- | --- |
| requests **equal** limits, every container | `Guaranteed` | last |
| requests only, or requests below limits | `Burstable` | in the middle |
| nothing | `BestEffort` | **first** |

Look at what you have now:

```
kubectl get pod -n platform -l app=api -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```{{exec}}

`BestEffort` — the first thing the kubelet kills under pressure. Set both, on
both containers, equal:

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
          resources:
            requests: { cpu: "50m", memory: "32Mi" }
            limits:   { cpu: "50m", memory: "32Mi" }
          volumeMounts:
            - { name: web, mountPath: /work }
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          envFrom:
            - configMapRef: { name: app-config }
            - secretRef: { name: app-secrets }
          resources:
            requests: { cpu: "100m", memory: "128Mi" }
            limits:   { cpu: "100m", memory: "128Mi" }
          readinessProbe:
            httpGet: { path: /healthz, port: 80 }
            periodSeconds: 3
          volumeMounts:
            - { name: web, mountPath: /usr/share/nginx/html }
      volumes:
        - name: web
          emptyDir: {}
YAML
kubectl rollout status deployment/api -n platform --timeout=180s
kubectl get pod -n platform -l app=api -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```{{exec}}

The rollout replaced both Pods, which is also why the one you broke in step 2
is healthy again — you did not repair it, you replaced it.

**The init container counts.** Leave its resources off and the Pod is
`Burstable` no matter how carefully you set the application container. That is
the usual reason a Pod that looks `Guaranteed` in review is not.

**Done when:** every Pod reports `Guaranteed`.
