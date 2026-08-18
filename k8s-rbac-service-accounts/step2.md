# A workload with its own identity

Kubernetes mounts an API token into every Pod by default. An application that
never calls the API has no use for one — but an attacker who reaches the
container does.

Look at what a default Pod carries:

```
kubectl exec -n team-a web -- ls /var/run/secrets/kubernetes.io/serviceaccount
```{{exec}}

`token`, `ca.crt`, `namespace`. That is a working set of API credentials, sitting
in a web server that has never made an API call in its life.

Give the workload its own ServiceAccount and take the token away:

```
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api
  namespace: team-a
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: team-a
spec:
  replicas: 1
  selector:
    matchLabels: { app: api }
  template:
    metadata:
      labels: { app: api }
    spec:
      serviceAccountName: api
      automountServiceAccountToken: false
      containers:
        - name: api
          image: nginx:1.27-alpine
YAML
kubectl rollout status deployment/api -n team-a --timeout=120s
```{{exec}}

Check the same path in the new Pod:

```
POD=$(kubectl get pod -n team-a -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n team-a $POD -- ls /var/run/secrets/kubernetes.io/serviceaccount
```{{exec}}

`No such file or directory` — correct, and worth seeing rather than assuming.

Two separate things happened here:

- **`serviceAccountName: api`** gives the workload an identity of its own, so a
  grant can be aimed at *this* application instead of at everything in the
  namespace
- **`automountServiceAccountToken: false`** stops the credential being written
  into the container at all

The first is what makes least privilege expressible. The second is what makes
it moot for a workload that never calls the API.

**Done when:** the Deployment runs as `api`, not `default`, and the token
directory is absent from the container.
