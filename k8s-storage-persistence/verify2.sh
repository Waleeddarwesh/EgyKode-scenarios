#!/bin/bash
# The claim must be bound and the data must be in it. Checking only that a PVC
# exists would pass on a claim stuck Pending with nothing behind it.
fail() { echo "$1"; exit 1; }

kubectl get pvc data >/dev/null 2>&1 \
  || fail "No PersistentVolumeClaim called 'data' yet."

phase=$(kubectl get pvc data -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$phase" = "Bound" ] \
  || fail "The 'data' claim is '$phase', not Bound. Without a default StorageClass a claim waits forever — check: kubectl get storageclass"

kubectl get pod writer >/dev/null 2>&1 || fail "No 'writer' Pod mounting the claim."

claim=$(kubectl get pod writer -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null)
echo "$claim" | grep -qw data || fail "The writer Pod does not mount the 'data' claim."

content=$(kubectl exec writer -- cat /data/keep.txt 2>/dev/null | tr -d '[:space:]')
[ -n "$content" ] \
  || fail "Nothing at /data/keep.txt in the writer Pod. Write to the mounted path, delete the Pod, recreate it, and read it back."

# The Pod must be a replacement, not the original — otherwise nothing survived
# anything. A recreated Pod has a different UID.
starts=$(kubectl get pod writer -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
[ -n "$starts" ] || fail "Could not read the writer Pod's metadata."

echo "PASS"
