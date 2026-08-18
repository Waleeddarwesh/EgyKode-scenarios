# A Role, a RoleBinding, and asking the cluster

Four objects, two questions between them:

| Object | Answers | Scope |
| --- | --- | --- |
| `Role` | What may be done? | One namespace |
| `ClusterRole` | The same, cluster-wide | Whole cluster |
| `RoleBinding` | Who gets it? | One namespace |
| `ClusterRoleBinding` | Who gets it everywhere? | Whole cluster |

Permissions and subjects are deliberately separate. That separation is what
lets one `ClusterRole` be bound differently in twenty namespaces.

Create the identity, the permission, and the link between them:

```
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: viewer
  namespace: team-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: team-a
  name: pod-reader
rules:
  - apiGroups: [""]                 # "" is the core API group
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: team-a
  name: team-a-read
subjects:
  - kind: ServiceAccount
    name: viewer
    namespace: team-a
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
YAML
```{{exec}}

Now stop reading YAML and ask the API server what it will actually do:

```
SA=system:serviceaccount:team-a:viewer
kubectl auth can-i list pods   -n team-a --as $SA
kubectl auth can-i list pods   -n team-b --as $SA
kubectl auth can-i delete pods -n team-a --as $SA
```{{exec}}

`yes`, `no`, `no`.

**`--as` evaluates the real policy.** Reading the YAML tells you what you meant;
this tells you what the cluster will do, and the two differ more often than
anyone expects.

## A check that lies

Ask whether `viewer` can read Pod logs. Ask it three ways:

```
SA=system:serviceaccount:team-a:viewer
kubectl auth can-i get pods/log -n team-a --as $SA
kubectl auth can-i get pods --subresource=log -n team-a --as $SA
kubectl logs web -n team-a --as $SA --tail=1
```{{exec}}

`yes`. Then `no`. Then **Forbidden**.

The first form does not ask what it looks like it asks. `pods/log` on the
command line resolves to the `pods` resource, so the answer describes `pods` —
which `viewer` can indeed get. The API server disagrees at request time because
the real check is against `pods/log`, and nothing granted that.

**`--subresource` is the form that asks the question you meant.** The other one
will tell you an account is fine right up until it fails in production.

**`pods/log` is a separate resource**, so add it:

```
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: team-a
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
YAML
kubectl logs web -n team-a --as $SA --tail=1
kubectl auth can-i get pods --subresource=log -n team-a --as $SA
```{{exec}}

The log line appears. No Pod was restarted and no binding changed — editing the
Role changed the answer immediately, because authorisation is evaluated per
request.

The full picture for that subject:

```
kubectl auth can-i --list -n team-a --as system:serviceaccount:team-a:viewer
```{{exec}}

**Done when:** `viewer` can list Pods **and read their logs** in `team-a`, and
is refused in `team-b`.
