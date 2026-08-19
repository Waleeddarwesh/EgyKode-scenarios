#!/bin/bash
NS=chaos

READY=$(kubectl -n $NS get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 3 ] || { echo "FAIL: ${READY:-0} of 3 replicas are ready"; exit 1; }

[ -f /root/chaos/experiments.md ] || {
  echo "FAIL: no /root/chaos/experiments.md - an experiment nobody wrote down is an anecdote"; exit 1; }

# A hypothesis has to exist for each experiment, and be falsifiable rather than
# a shrug. Checking for the word alone would pass on "something might happen".
HYP=$(grep -c "Hypothesis:" /root/chaos/experiments.md)
[ "${HYP:-0}" -ge 2 ] || { echo "FAIL: only ${HYP:-0} hypotheses recorded, expected at least 2"; exit 1; }

# The Pod kill must have actually happened. Events outlive the Pod they describe,
# so the ReplicaSet's replacement is on record even though the Pod is gone.
KILLED=$(kubectl -n $NS get events --no-headers 2>/dev/null | grep -c "Killing\|SuccessfulDelete")
CREATED=$(kubectl -n $NS get events --no-headers 2>/dev/null | grep "SuccessfulCreate" | grep -c "replicaset/web-")
[ "${CREATED:-0}" -ge 1 ] || {
  echo "FAIL: nothing records a ReplicaSet creating Pods - run the experiment"; exit 1; }

# The measurement itself: traffic ran across the failure and none of it failed.
[ -f /tmp/probe.log ] || { echo "FAIL: /tmp/probe.log is missing - the probe was not running"; exit 1; }
TOTAL=$(wc -l < /tmp/probe.log)
BAD=$(grep -vc 200 /tmp/probe.log)
[ "$TOTAL" -ge 20 ] || { echo "FAIL: only $TOTAL requests recorded since the baseline reset - let the probe run across the experiment"; exit 1; }
[ "$BAD" -eq 0 ] || {
  echo "FAIL: $BAD of $TOTAL requests failed during the experiment"
  echo "      Codes: $(sort /tmp/probe.log | uniq -c | tr '\n' ' ')"
  exit 1; }

# A result must be filled in, or the log records only what was expected.
grep -q "Hypothesis held\|Result:.*recovered" /root/chaos/experiments.md || {
  echo "FAIL: experiment 1 has no result recorded"; exit 1; }

echo "PASS - 3 ready replicas, $TOTAL requests with no failures, and the experiment is written down"
exit 0
