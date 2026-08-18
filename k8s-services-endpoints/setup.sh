#!/bin/bash
# Waits for the cluster before handing over. A step that runs against an API
# server still starting fails in a way the learner will assume is their fault.
set -e
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not available here. Please report it." >&2; exit 1; }

for i in $(seq 1 60); do
  kubectl get nodes >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null 2>&1 || true

mkdir -p /root/manifests
echo "Ready. The cluster is up; work in /root/manifests."
