#!/bin/bash
SA=system:serviceaccount:team-a:legacy-ci

# The identity must survive. Deleting the account also stops the access, but it
# is not what revoking a grant means, and on a real cluster it breaks whatever
# was using it while leaving the binding behind for the next account.
kubectl get serviceaccount legacy-ci -n team-a >/dev/null 2>&1 || {
  echo "FAIL: the legacy-ci ServiceAccount is gone"
  echo "      The exercise was to remove the grant, not the identity. Recreate it:"
  echo "      kubectl create serviceaccount legacy-ci -n team-a"
  exit 1; }

STAR=$(kubectl auth can-i "*" "*" --all-namespaces --as $SA 2>/dev/null)
NODES=$(kubectl auth can-i delete nodes --as $SA 2>/dev/null)
SECRETS=$(kubectl auth can-i get secrets -n kube-system --as $SA 2>/dev/null)

[ "$STAR" = "no" ] || { echo "FAIL: legacy-ci can still do anything, anywhere - the cluster-admin binding is still in place"; exit 1; }
[ "$NODES" = "no" ] || { echo "FAIL: legacy-ci can still delete nodes"; exit 1; }
[ "$SECRETS" = "no" ] || { echo "FAIL: legacy-ci can still read Secrets in kube-system"; exit 1; }

# Nothing else should have been bound to cluster-admin on the way past. This
# catches "fixed" by binding a different account instead.
EXTRA=$(kubectl get clusterrolebindings -o jsonpath='{range .items[?(@.roleRef.name=="cluster-admin")]}{.subjects[*].namespace}{" "}{end}' 2>/dev/null | grep -o team-a | wc -l)
[ "$EXTRA" -eq 0 ] || { echo "FAIL: something in team-a is still bound to cluster-admin"; exit 1; }

echo "PASS - the grant is gone and the identity remains"
exit 0
