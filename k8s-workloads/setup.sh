#!/bin/bash
# Only waits for the node to be ready. Nothing is pre-created: the learner
# builds every object in this lab, and a cluster that is not ready yet is the
# most common reason a first kubectl command appears to fail.
set -e
echo "Waiting for the node to become Ready..."
kubectl wait --for=condition=Ready node --all --timeout=180s || {
  echo "Node did not become Ready in time. Try: kubectl get nodes"
  exit 1
}
kubectl get nodes
