#!/bin/bash
# The control plane must accept Pods or a drained workload has nowhere to go
# and simply goes Pending. You would not remove this taint on a production
# cluster; here it is the difference between demonstrating rescheduling and
# demonstrating nothing.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- >/dev/null 2>&1

WORKER=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$WORKER" ] || WORKER=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# A Pod with nothing behind it, pinned to the node the learner will drain.
# Nothing recreates this once it is evicted, which is the whole of step 2.
kubectl apply -f - >/dev/null 2>&1 <<POD
apiVersion: v1
kind: Pod
metadata:
  name: legacy-cache
  labels: { app: legacy-cache }
spec:
  nodeName: $WORKER
  containers:
    - name: cache
      image: nginx:1.27-alpine
POD

kubectl wait --for=condition=Ready pod/legacy-cache --timeout=120s >/dev/null 2>&1
echo done
