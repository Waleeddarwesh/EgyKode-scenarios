#!/bin/bash
# Pull the one image every step uses, so no step waits on a registry.
kubectl create namespace platform >/dev/null 2>&1
kubectl config set-context --current --namespace=platform >/dev/null 2>&1
ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1 \
  || docker pull nginx:1.27-alpine >/dev/null 2>&1
echo done
