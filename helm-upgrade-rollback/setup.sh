#!/bin/bash
# Helm is usually present on this backend; install it if not, so the scenario
# does not open with a command-not-found.
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3 2>/dev/null
  bash /tmp/get-helm-3 >/dev/null 2>&1
fi

kubectl create namespace demo >/dev/null 2>&1
kubectl config set-context --current --namespace=demo >/dev/null 2>&1

# The one image every revision uses, so no step waits on a registry.
ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1

echo done
