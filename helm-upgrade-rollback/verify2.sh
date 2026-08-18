#!/bin/bash
NS=demo

REV=$(helm list -n $NS -o json 2>/dev/null | tr ',' '\n' | grep '"revision"' | head -1 | tr -dc '0-9')
[ "${REV:-0}" -ge 2 ] || {
  echo "FAIL: the release is at revision ${REV:-0} - the upgrade has not been run"; exit 1; }

helm status demo -n $NS 2>/dev/null | grep -qi 'STATUS: deployed' || {
  echo "FAIL: the release is not in a deployed state"; exit 1; }

# Three ready replicas, from the cluster rather than from the values. An
# upgrade that was accepted but never became ready still reports a revision.
READY=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 3 ] || {
  echo "FAIL: ${READY:-0} replicas are ready, expected 3"; exit 1; }

# Revision 1 must still be retrievable, or there is nothing to roll back to
# later and step 4 cannot mean anything.
helm history demo -n $NS 2>/dev/null | grep -q superseded || {
  echo "FAIL: no superseded revision in the history - the earlier revision was not kept"; exit 1; }

echo "PASS - revision $REV deployed, three replicas ready, revision 1 retained"
exit 0
