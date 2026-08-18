# Configuration that is not in the image

Two objects hold the values, and the Deployment reads both:

```
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: platform
data:
  LOG_LEVEL: "info"
  DB_HOST: "postgres.platform.svc.cluster.local"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: platform
type: Opaque
stringData:
  DB_PASSWORD: "change-me"
---
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
      containers:
        - name: api
          image: nginx:1.27-alpine
          ports: [{ containerPort: 80 }]
          envFrom:
            - configMapRef: { name: app-config }
            - secretRef: { name: app-secrets }
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: platform
spec:
  selector: { app: api }
  ports:
    - port: 80
      targetPort: 80
YAML
kubectl rollout status deployment/api -n platform --timeout=120s
```{{exec}}

`stringData` takes plain text and lets Kubernetes do the encoding. Writing
`data` by hand means base64 by hand, which is a step people get wrong.

Now read the values back **from inside a running container** — the spec says
what you asked for, this says what the process actually got:

```
kubectl exec -n platform deploy/api -- env | grep -E 'LOG_LEVEL|DB_HOST|DB_PASSWORD'
```{{exec}}

The image is stock `nginx`. Nothing in it knows about your database.

One thing worth seeing for yourself:

```
kubectl get secret app-secrets -n platform -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo
```{{exec}}

**base64 is encoding, not encryption.** What a Secret buys you over a ConfigMap
is that RBAC can withhold it separately, `describe` does not print it, and the
kubelet keeps it on `tmpfs` rather than on disk.

**Done when:** both replicas are ready and `LOG_LEVEL` is `info` inside the
container.
