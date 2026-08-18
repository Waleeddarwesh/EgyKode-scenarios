#!/bin/bash
# Reads the cluster and the learner's record. It deliberately does not require
# Pending Pods: on a single-node cluster ReadWriteOnce does not block anything,
# and a check demanding a failure that cannot happen here would be a check that
# lies about the environment.
fail() { echo "$1"; exit 1; }

kubectl get deploy shared >/dev/null 2>&1 \
  || fail "No 'shared' Deployment. Apply the three-replica manifest from the step."

replicas=$(kubectl get deploy shared -o jsonpath='{.spec.replicas}' 2>/dev/null)
[ "$replicas" = "3" ] || fail "The 'shared' Deployment asks for $replicas replica(s), not 3."

claim=$(kubectl get deploy shared -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null)
echo "$claim" | grep -qw data \
  || fail "The Deployment does not mount the 'data' claim, so it cannot demonstrate the access-mode limit."

mode=$(kubectl get pvc data -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
[ "$mode" = "ReadWriteOnce" ] \
  || fail "The 'data' claim is '$mode'. This step is about ReadWriteOnce."

[ -s /root/manifests/accessmode.txt ] \
  || fail "No /root/manifests/accessmode.txt. Record what ReadWriteOnce restricts."
grep -qi 'node' /root/manifests/accessmode.txt \
  || fail "The record does not say what ReadWriteOnce binds to. It is one NODE, not one Pod."

echo "PASS"
