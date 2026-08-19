#!/bin/bash
# Runs as intro.background while the intro is read. kube-prometheus-stack is a
# lot of images; measured at roughly 20s for the helm install and another four
# minutes before Prometheus itself is ready. Step 1 waits properly rather than
# assuming.
#
# The lab this comes from says "on AWS EKS", but not one of its four criteria
# mentions AWS: they are about Prometheus targets, a ServiceMonitor, a Grafana
# graph and metrics surviving a restart. All four are properties of Kubernetes,
# so a real kubeadm node demonstrates them exactly as EKS would. What you learn
# here transfers to EKS unchanged - the managed control plane changes who
# patches the API server, not how a ServiceMonitor is selected.

set -u

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3 2>/dev/null
  bash /tmp/get-helm-3 >/dev/null 2>&1
fi
command -v jq >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq jq >/dev/null 2>&1
}

# Criterion 4 is "metrics survive a Prometheus Pod restart", which needs a
# PersistentVolumeClaim, which needs a StorageClass. A default one is not
# guaranteed on every kubeadm environment, and without it the PVC stays Pending
# and Prometheus never starts at all - a failure that looks like a broken chart
# and is really a missing provisioner. So make sure of one.
if ! kubectl get storageclass -o jsonpath='{.items[*].metadata.annotations}' 2>/dev/null \
     | grep -q 'is-default-class":"true'; then
  echo "No default StorageClass; installing local-path-provisioner..."
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml >/dev/null 2>&1
  kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=180s >/dev/null 2>&1
  kubectl patch storageclass local-path \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1
helm repo update >/dev/null 2>&1

# Tuned for one node. Alertmanager is off because none of this lab's criteria
# involve routing an alert - that is lab 18's subject - and it is one less
# workload competing for memory. Retention is short for the same reason: the
# restart in step 4 needs minutes of history, not days.
cat > /root/kps-values.yaml <<'YAML'
alertmanager:
  enabled: false
prometheus:
  prometheusSpec:
    retention: 2h
    scrapeInterval: 15s
    resources:
      requests:
        cpu: 100m
        memory: 400Mi
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
grafana:
  adminPassword: egykode
  persistence:
    enabled: false
YAML

echo "Installing kube-prometheus-stack..."
helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f /root/kps-values.yaml --timeout 15m >/dev/null 2>&1
echo "  helm install: exit $?"

# The application Prometheus will be asked to find. Deployed with the Service
# created by `kubectl expose` on purpose: that produces a port with no name,
# which is one of the two reasons a ServiceMonitor silently scrapes nothing.
# Step 2 is where the learner meets it.
kubectl create namespace shop >/dev/null 2>&1
kubectl create deployment web -n shop \
  --image=quay.io/brancz/prometheus-example-app:v0.5.0 --replicas=2 >/dev/null 2>&1
kubectl expose deployment web -n shop --port=8080 --name=web >/dev/null 2>&1

echo "Waiting for the application..."
kubectl wait --for=condition=available deploy/web -n shop --timeout=300s >/dev/null 2>&1
echo "done - step 1 waits for Prometheus itself"
