# Default deny, and proving it is real

Three workloads: an application, a database, and something unrelated that has no
business talking to either.

```
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-conf
  namespace: platform
data:
  default.conf: |
    server {
        listen 5432;
        location / { return 200 "db\n"; }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: platform
spec:
  replicas: 1
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
        - name: db
          image: nginx:1.27-alpine
          ports: [{ containerPort: 5432 }]
          volumeMounts:
            - { name: conf, mountPath: /etc/nginx/conf.d }
      volumes:
        - name: conf
          configMap: { name: db-conf }
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: platform
spec:
  selector: { app: postgres }
  ports: [{ port: 5432, targetPort: 5432 }]
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
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: platform
spec:
  selector: { app: api }
  ports: [{ port: 80, targetPort: 80 }]
---
apiVersion: v1
kind: Pod
metadata:
  name: stranger
  namespace: platform
  labels: { app: stranger }
spec:
  containers:
    - name: shell
      image: nginx:1.27-alpine
      command: ["sleep", "3600"]
YAML
kubectl rollout status deployment/api -n platform --timeout=180s
kubectl rollout status deployment/db -n platform --timeout=180s
kubectl wait --for=condition=Ready pod/stranger -n platform --timeout=120s
```{{exec}}

Everything can reach everything, which is the Kubernetes default:

```
echo "stranger -> api:"
kubectl exec -n platform stranger -- wget -q -O- --timeout=4 http://api | head -1
echo "api -> db:"
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=4 http://db:5432 | head -1
```{{exec}}

A pod with no business talking to the application is talking to the application.

## Deny everything

```
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: platform
spec:
  podSelector: {}                    # every Pod in the namespace
  policyTypes: ["Ingress", "Egress"]
YAML
sleep 5
kubectl get networkpolicy -n platform
```{{exec}}

An empty `podSelector` selects every Pod. No `ingress` or `egress` rules means
nothing is permitted in either direction.

## Now prove it

```
echo "stranger -> api (expect failure):"
kubectl exec -n platform stranger -- wget -q -O- --timeout=4 http://api 2>&1 | tail -1
echo "exit code: $?"
echo
echo "api -> db (expect failure):"
kubectl exec -n platform deploy/api -- wget -q -O- --timeout=4 http://db:5432 2>&1 | tail -1
```{{exec}}

Both fail. **That is the only evidence that matters.**

If they had succeeded, the object would still be listed by `kubectl get
networkpolicy` and would still be doing nothing whatsoever — because
**enforcing NetworkPolicy is the network plugin's job, not Kubernetes'.** The
API server accepts and stores the object regardless. Calico and Cilium enforce
it; recent kindnet does; plain Flannel does not, and on a Flannel cluster every
policy you write is a YAML file with no effect at all.

That is the answer to "why does a NetworkPolicy sometimes do nothing?", and it
is why this step demonstrates a block before anything else depends on one.

The other two reasons, worth knowing now:

- **A Pod selected by no policy is unrestricted.** Policies are a whitelist for
  Pods they select and irrelevant to Pods they do not. Add one policy to one
  Pod and everything else stays wide open — which is exactly why the
  default-deny goes on first
- **There is no deny rule.** A Pod's allowed traffic is the union of every
  policy selecting it. You restrict by not allowing, and you cannot subtract

**Done when:** the default-deny exists and the stranger genuinely cannot reach
the application.
