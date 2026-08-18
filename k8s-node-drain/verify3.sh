#!/bin/bash
kubectl get pdb web >/dev/null 2>&1 || { echo "FAIL: no PodDisruptionBudget named web"; exit 1; }

# The selector has to match the workload, or the budget guards nothing while
# looking exactly like a budget that guards something.
HEALTHY=$(kubectl get pdb web -o jsonpath='{.status.currentHealthy}' 2>/dev/null)
[ "${HEALTHY:-0}" -ge 4 ] || {
  echo "FAIL: the PDB sees ${HEALTHY:-0} healthy Pods - check that its selector matches app=web"; exit 1; }

# disruptionsAllowed is computed by the controller and is precisely what the
# eviction API consults. Zero here is the state that refuses a drain.
ALLOWED=$(kubectl get pdb web -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)
[ "${ALLOWED:-1}" -eq 0 ] || {
  echo "FAIL: the PDB allows ${ALLOWED} disruption(s), so it would not block the drain"
  echo "      Raise minAvailable to the replica count to see the refusal."
  exit 1; }

# Nothing may have been evicted on the way past.
READY=$(kubectl get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 4 ] || {
  echo "FAIL: ${READY:-0} of 4 replicas are ready - the budget did not hold"; exit 1; }

echo "PASS - the budget allows no disruptions and all four replicas survived"
exit 0
