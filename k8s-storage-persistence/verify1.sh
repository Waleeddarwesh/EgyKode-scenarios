#!/bin/bash
# Proves the claim against the running Pod, not against a note. The file must
# be absent in a Pod that exists — which is only true if it was recreated.
fail() { echo "$1"; exit 1; }

kubectl get pod scratch >/dev/null 2>&1 \
  || fail "No 'scratch' Pod. Create it, write a file, delete the Pod, then create it again."

phase=$(kubectl get pod scratch -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$phase" = "Running" ] || fail "The scratch Pod is '$phase', not Running."

# The file must not be there. If it is, the Pod was never actually replaced.
if kubectl exec scratch -- test -f /data.txt >/dev/null 2>&1; then
  fail "/data.txt still exists in the scratch Pod, so it was not deleted and recreated. Delete the Pod, then create it again."
fi

# And the Pod must have no volume mounted, or the demonstration is meaningless.
vols=$(kubectl get pod scratch -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null)
[ -z "$vols" ] || fail "The scratch Pod mounts a claim ('$vols'). This step is about a Pod with no persistent storage at all."

echo "PASS"
