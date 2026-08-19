#!/bin/bash
echo "Installing the ingress-nginx controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml >/dev/null 2>&1

echo "Installing the Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml >/dev/null 2>&1

echo "Installing NGINX Gateway Fabric..."
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.4.0/deploy/crds.yaml >/dev/null 2>&1
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.4.0/deploy/default/deploy.yaml >/dev/null 2>&1

kubectl create namespace routing >/dev/null 2>&1
kubectl config set-context --current --namespace=routing >/dev/null 2>&1

# Two versions of one application, each announcing which it is.
for V in v1 v2; do
  kubectl -n routing create deployment $V --image=nginx:1.27-alpine >/dev/null 2>&1
  kubectl -n routing expose deployment $V --port=80 >/dev/null 2>&1
done

kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s >/dev/null 2>&1
kubectl -n nginx-gateway rollout status deployment/nginx-gateway --timeout=300s >/dev/null 2>&1
kubectl -n routing rollout status deployment/v1 --timeout=300s >/dev/null 2>&1
kubectl -n routing rollout status deployment/v2 --timeout=300s >/dev/null 2>&1
kubectl -n routing exec deploy/v1 -- sh -c 'echo v1 > /usr/share/nginx/html/index.html' >/dev/null 2>&1
kubectl -n routing exec deploy/v2 -- sh -c 'echo v2 > /usr/share/nginx/html/index.html' >/dev/null 2>&1

echo done
