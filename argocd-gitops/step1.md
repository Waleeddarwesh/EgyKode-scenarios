Argo CD needs a few minutes. Wait for it, and for the Git server:

```
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kubectl -n gitops rollout status deploy/git --timeout=300s
```{{exec}}

## What is in the repository

The Git server is a Pod. Look at what it is serving:

```
git ls-remote git://localhost:30418/app.git
```{{exec}}

Two ways in to the same repository, because two different clients need it:

| Client | URL | Why |
|---|---|---|
| You, in this terminal | `git://localhost:30418/app.git` | you are outside the cluster; that is a NodePort |
| Argo CD, in the cluster | `git://git.gitops.svc:9418/app.git` | Service DNS, reachable only from inside |

Clone it and read what is there:

```
git clone git://localhost:30418/app.git ~/app
cat ~/app/manifests/db.yaml ~/app/manifests/web.yaml
```{{exec}}

Note the `argocd.argoproj.io/sync-wave` annotation on each: `1` on the
database, `2` on the web tier. Argo CD applies wave 1 and **waits for it to be
healthy** before starting wave 2. Without it both apply at once and anything
that needs the database crash-loops until the database happens to be ready.

## The Application

This is the whole configuration. Everything else is consequence:

```
cat > ~/app-of-mine.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git://git.gitops.svc:9418/app.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
EOF
kubectl apply -f ~/app-of-mine.yaml
```{{exec}}

Two details that fail silently rather than loudly:

- **`metadata.namespace` must be `argocd`.** An Application created anywhere
  else is ignored — no error, no event, it simply never syncs.
- **The finalizer** makes deletion cascade. Without it, `kubectl delete
  application` removes the record and leaves everything it created running.

## Watch the waves

```
kubectl -n web get pods -w
```{{exec}}

The database appears first and reaches Running before the three web Pods are
created. Press `Ctrl+C` once you have seen it, then read the two statuses:

```
kubectl -n argocd get application web-app
```{{exec}}

`SYNC STATUS` and `HEALTH STATUS` answer different questions — *does the
cluster match Git*, and *do the workloads actually work*. You will see them
disagree in a moment.
