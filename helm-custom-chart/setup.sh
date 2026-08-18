#!/bin/bash
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3 2>/dev/null
  bash /tmp/get-helm-3 >/dev/null 2>&1
fi
kubectl create namespace dev >/dev/null 2>&1
kubectl create namespace staging >/dev/null 2>&1
ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1
echo done
