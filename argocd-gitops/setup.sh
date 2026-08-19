#!/bin/bash
# Argo CD takes about four minutes before it can sync anything, so this runs in
# the background while the intro is read. Step 1 waits for it properly.

set -u

echo "Installing Argo CD..."
kubectl create namespace argocd >/dev/null 2>&1
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.1/manifests/install.yaml >/dev/null 2>&1

# Argo CD polls Git every 180 seconds by default. That is the honest number and
# step 2 says so — but three minutes of waiting per commit inside a session
# with a clock on it teaches patience rather than GitOps. Thirty seconds keeps
# the behaviour (it still polls; nothing pushes to it) and removes the wait.
# Production solves this with a webhook, which step 2 explains.
kubectl -n argocd patch cm argocd-cm --type merge \
  -p '{"data":{"timeout.reconciliation":"30s"}}' >/dev/null 2>&1

mkdir -p /root/gitops

# ── The Git server ──────────────────────────────────────────────────────────
# The whole lab turns on the learner pushing a commit and nobody touching the
# cluster. A public example repository cannot show that — you cannot push to
# it — and a fork would need a GitHub account and a token pasted into a shared
# terminal, which is not something this platform will ever ask for.
#
# So Git lives in the cluster: `git daemon` over the git:// protocol, with
# anonymous push switched on. That is a terrible idea on a real network and a
# perfectly good one on a throwaway single-node cluster with no route in.
cat > /root/gitops/git-server.yaml <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: gitops
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: git-seed
  namespace: gitops
data:
  boot.sh: |
    #!/bin/sh
    set -e
    # `git daemon` is a separate Alpine package. Without it the container
    # starts, seeds the repository, then exits with
    # "git: 'daemon' is not a git command" — which reads as a typo.
    apk add --no-cache git-daemon >/dev/null
    git config --global user.email "git@gitops.svc"
    git config --global user.name "Git Server"
    git config --global init.defaultBranch main

    mkdir -p /srv/git
    git init --bare --initial-branch=main /srv/git/app.git
    touch /srv/git/app.git/git-daemon-export-ok

    rm -rf /tmp/seed && mkdir -p /tmp/seed/manifests && cd /tmp/seed
    cp /seed/db.yaml /seed/web.yaml /tmp/seed/manifests/
    git init -q -b main .
    git add -A
    git commit -q -m "Initial manifests: database and web"
    git push -q /srv/git/app.git main

    # --enable=receive-pack is what makes anonymous push work. Without it a
    # clone succeeds, an edit succeeds, and the push is refused with
    # "service not enabled" after the learner has done all the work.
    exec git daemon --verbose --export-all --base-path=/srv/git \
      --enable=receive-pack --reuseaddr --informative-errors
  db.yaml: |
    # sync-wave 1: this is applied, and waited for, before anything in wave 2.
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: db
      labels:
        app: db
      annotations:
        argocd.argoproj.io/sync-wave: "1"
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: db
      template:
        metadata:
          labels:
            app: db
        spec:
          containers:
            - name: db
              image: postgres:16-alpine
              env:
                - name: POSTGRES_PASSWORD
                  value: notasecret
                - name: PGDATA
                  value: /tmp/pgdata
              ports:
                - containerPort: 5432
  web.yaml: |
    # sync-wave 2: without the wave annotation this applies at the same moment
    # as the database and crash-loops until the database happens to be ready.
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web
      labels:
        app: web
      annotations:
        argocd.argoproj.io/sync-wave: "2"
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: web
      template:
        metadata:
          labels:
            app: web
        spec:
          containers:
            - name: web
              image: nginx:1.27-alpine
              ports:
                - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: git
  namespace: gitops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: git
  template:
    metadata:
      labels:
        app: git
    spec:
      containers:
        - name: git
          image: alpine/git:2.45.2
          command: ["/bin/sh", "/seed/boot.sh"]
          ports:
            - containerPort: 9418
          volumeMounts:
            - name: seed
              mountPath: /seed
      volumes:
        - name: seed
          configMap:
            name: git-seed
---
apiVersion: v1
kind: Service
metadata:
  name: git
  namespace: gitops
spec:
  # NodePort as well as ClusterIP, because two different clients need it:
  # Argo CD reaches git.gitops.svc:9418 from inside the cluster, and you reach
  # localhost:30418 from this terminal, which is outside it.
  type: NodePort
  selector:
    app: git
  ports:
    - port: 9418
      targetPort: 9418
      nodePort: 30418
YAML

kubectl apply -f /root/gitops/git-server.yaml >/dev/null 2>&1

# Step 1 clones and step 2 pushes, so a node without git turns into a failure
# three commands into the lab rather than here. Checked rather than assumed:
# the image has carried git every time, and "every time so far" is not a
# dependency declaration.
command -v git >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq git >/dev/null 2>&1
}

# Git refuses to commit without an identity, and the error arrives in the
# middle of step 2 rather than here.
git config --global user.email "learner@egykode.dev" >/dev/null 2>&1
git config --global user.name "Learner" >/dev/null 2>&1
git config --global init.defaultBranch main >/dev/null 2>&1

kubectl -n gitops rollout status deploy/git --timeout=300s >/dev/null 2>&1
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s >/dev/null 2>&1
kubectl -n argocd rollout status deploy/argocd-server --timeout=600s >/dev/null 2>&1
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s >/dev/null 2>&1

# The controller reads timeout.reconciliation once, at startup. Patching the
# ConfigMap above without this leaves it on the 180s default: measured 230s from
# push to running Pod, against 110s once the controller has actually read it.
kubectl -n argocd rollout restart statefulset/argocd-application-controller >/dev/null 2>&1
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s >/dev/null 2>&1

echo done
