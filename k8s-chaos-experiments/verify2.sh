#!/bin/bash
NS=chaos

READY=$(kubectl -n $NS get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 3 ] || { echo "FAIL: ${READY:-0} of 3 replicas are ready - restore the Deployment"; exit 1; }

# The Deployment must genuinely have been deleted and recreated, not merely
# scaled. A scale to zero and back leaves the original object's age intact.
AGE=$(kubectl -n $NS get deployment web -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
[ -n "$AGE" ] || { echo "FAIL: cannot read the Deployment"; exit 1; }
NOW=$(date -u +%s)
CREATED=$(date -u -d "$(echo "$AGE" | sed 's/Z$//' | tr 'T' ' ')" +%s 2>/dev/null)
[ -n "$CREATED" ] || { echo "FAIL: could not parse the Deployment creation time"; exit 1; }
AGE_S=$((NOW - CREATED))
[ "$AGE_S" -lt 900 ] || {
  echo "FAIL: the Deployment is ${AGE_S}s old - it was never deleted and recreated"
  echo "      Experiment 2 is deleting the Deployment, not scaling it."
  exit 1; }

# The outage has to be on record. This is the experiment that disproves
# "it is highly available", so a log without it has skipped the finding.
[ -f /root/chaos/experiments.md ] || { echo "FAIL: no experiments.md"; exit 1; }
RESULTS=$(grep -c "^\*\*Result:\*\* [A-Z]" /root/chaos/experiments.md)
[ "${RESULTS:-0}" -ge 2 ] || {
  echo "FAIL: ${RESULTS:-0} experiments have a recorded result, expected 2"
  echo "      An experiment with a hypothesis and no result is a plan."
  exit 1; }
grep -qi "no automatic recovery\|nothing watches\|manual" /root/chaos/experiments.md || {
  echo "FAIL: experiment 2's result does not record that nothing recovered it"; exit 1; }

echo "PASS - the Deployment was deleted and restored, and both experiments have results"
exit 0
