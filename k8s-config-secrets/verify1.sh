#!/bin/bash
NS=platform

kubectl get deployment api -n $NS >/dev/null 2>&1 || {
  echo "FAIL: no Deployment named api in namespace $NS"; exit 1; }

# The point of the step is where the values come from, so check the wiring
# rather than merely that a Deployment exists.
CM=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}' 2>/dev/null)
SEC=$(kubectl get deployment api -n $NS -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].secretRef.name}' 2>/dev/null)
echo "$CM" | grep -q app-config || {
  echo "FAIL: the api container does not read the app-config ConfigMap"; exit 1; }
echo "$SEC" | grep -q app-secrets || {
  echo "FAIL: the api container does not read the app-secrets Secret"; exit 1; }

READY=$(kubectl get deployment api -n $NS -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -ge 2 ] || {
  echo "FAIL: ${READY:-0} of 2 replicas are ready"; exit 1; }

# Read it out of a live container. A spec can name a ConfigMap that does not
# exist and the Pod never starts, so this is the check that means something.
VAL=$(kubectl exec -n $NS deploy/api -- printenv LOG_LEVEL 2>/dev/null)
[ "$VAL" = "info" ] || {
  echo "FAIL: LOG_LEVEL inside the container is '$VAL', expected 'info'"; exit 1; }

echo "PASS - configuration reaches the container from outside the image"
exit 0
