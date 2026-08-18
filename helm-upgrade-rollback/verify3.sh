#!/bin/bash
NS=demo

# The attempt has to be on record. A history with no failed revision means the
# broken upgrade was never run, or was run without --atomic and then tidied up
# by hand - neither of which is what this step teaches.
helm history demo -n $NS 2>/dev/null | grep -q failed || {
  echo "FAIL: no failed revision in the history - run the deliberately broken upgrade"; exit 1; }

# And the release has to be healthy despite it. This is the half that matters:
# a failed upgrade that left the release failed proves the opposite point.
helm status demo -n $NS 2>/dev/null | grep -qi 'STATUS: deployed' || {
  echo "FAIL: the release is not deployed - it was left in the broken state"
  echo "      Was --atomic on the upgrade command?"
  exit 1; }

IMG=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null)
echo "$IMG" | grep -q "this-tag-does-not-exist" && {
  echo "FAIL: the Deployment still carries the broken image ($IMG)"; exit 1; }
echo "$IMG" | grep -q "1.27-alpine" || {
  echo "FAIL: the running image is '$IMG', expected the working nginx:1.27-alpine"; exit 1; }

# Serving, not merely configured. The rollback must have left ready Pods behind.
READY=$(kubectl get deployment -n $NS -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 3 ] || {
  echo "FAIL: ${READY:-0} replicas are ready, expected 3 still serving"; exit 1; }

# No Pod may be left stuck pulling the bad tag.
BAD=$(kubectl get pods -n $NS -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null | grep -o "this-tag-does-not-exist" | wc -l)
[ "$BAD" -eq 0 ] || {
  echo "FAIL: $BAD Pod(s) are still trying to run the broken image"; exit 1; }

echo "PASS - the failure is on record and the release rolled itself back"
exit 0
