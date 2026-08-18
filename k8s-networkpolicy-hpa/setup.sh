#!/bin/bash
kubectl create namespace platform >/dev/null 2>&1
kubectl config set-context --current --namespace=platform >/dev/null 2>&1

ctr -n k8s.io images pull docker.io/library/nginx:1.27-alpine >/dev/null 2>&1 \
  || crictl pull nginx:1.27-alpine >/dev/null 2>&1

# The HPA half needs metrics. Installing only if the API is absent keeps a
# cluster that already has it fast.
if ! kubectl top nodes >/dev/null 2>&1; then
  echo "Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null 2>&1
  kubectl -n kube-system patch deployment metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s >/dev/null 2>&1
fi

echo done
