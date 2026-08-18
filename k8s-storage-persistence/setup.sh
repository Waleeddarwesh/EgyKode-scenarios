#!/bin/bash
set -e
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not available here. Please report it." >&2; exit 1; }
for i in $(seq 1 60); do kubectl get nodes >/dev/null 2>&1 && break; sleep 2; done
kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null 2>&1 || true

# A default StorageClass is what makes a PVC bind without anyone writing a
# PersistentVolume by hand. Without one every claim sits Pending forever, and
# the learner would be debugging the cluster rather than the lesson.
if ! kubectl get storageclass 2>/dev/null | grep -q '(default)'; then
  echo "Note: no default StorageClass. Claims may stay Pending." >&2
fi
mkdir -p /root/manifests
echo "Ready. The cluster is up; work in /root/manifests."
