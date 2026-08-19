#!/bin/bash
NS=chaos
LOG=/root/chaos/experiments.md
[ -f "$LOG" ] || { echo "FAIL: no $LOG"; exit 1; }

HYP=$(grep -c "^\*\*Hypothesis:\*\*" "$LOG")
RES=$(grep -c "^\*\*Result:\*\* [A-Z]" "$LOG")
[ "${HYP:-0}" -ge 3 ] || { echo "FAIL: ${HYP:-0} hypotheses recorded, expected 3"; exit 1; }
[ "${RES:-0}" -ge 3 ] || {
  echo "FAIL: ${RES:-0} results recorded against ${HYP:-0} hypotheses"
  echo "      An experiment with a hypothesis and no result is a plan."
  exit 1; }
grep -q "(filled in after)" "$LOG" && { echo "FAIL: an experiment still has an unfilled result"; exit 1; }

# The container restart must actually have happened - and be a restart in place
# rather than a replacement, which is the whole distinction.
RESTARTS=$(kubectl -n $NS get pods -l app=web -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' 2>/dev/null | tr ' ' '\n' | sort -rn | head -1)
[ "${RESTARTS:-0}" -ge 1 ] || {
  echo "FAIL: no Pod shows a container restart - run the third experiment"; exit 1; }

READY=$(kubectl -n $NS get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${READY:-0}" -eq 3 ] || { echo "FAIL: ${READY:-0} of 3 replicas are ready"; exit 1; }

# The Pod that restarted must still be there. A replacement would have reset the
# count to zero on a new Pod, which is the opposite of what was hypothesised.
POD_WITH=$(kubectl -n $NS get pods -l app=web -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"|"}{end}' 2>/dev/null | tr '|' '\n' | awk '$2 >= 1 {print $1}' | head -1)
[ -n "$POD_WITH" ] || { echo "FAIL: no surviving Pod carries a restart count"; exit 1; }

echo "PASS - 3 hypotheses, 3 results, and $POD_WITH restarted in place ($RESTARTS)"
exit 0
