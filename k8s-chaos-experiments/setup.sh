#!/bin/bash
kubectl create namespace chaos >/dev/null 2>&1
kubectl config set-context --current --namespace=chaos >/dev/null 2>&1
ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1
mkdir -p /root/chaos
echo done
