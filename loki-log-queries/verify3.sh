#!/bin/bash
L=http://localhost:31000

kubectl -n production get deployment crasher >/dev/null 2>&1 || {
  echo "FAIL: no Deployment named crasher in the production namespace."
  exit 1; }

RESTARTS=$(kubectl -n production get pods -l app=crasher \
  -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "${RESTARTS:-0}" -ge 1 ] || {
  echo "FAIL: the crasher Pod has not restarted yet (${RESTARTS:-0} restarts)."
  echo "      Give it a minute — the whole point is the containers it leaves behind."
  exit 1; }

# The claim of this step is that Loki holds what the cluster has thrown away.
# So it is not enough for the message to be in Loki once: there have to be more
# copies of it than Kubernetes still has containers to show you, which is two
# at most — the current one and --previous.
#
# Measured: restart 1 at t+11s, the third copy in Loki at t+61s. CrashLoopBackOff
# backs off exponentially, so waiting is bounded but not instant — and failing a
# learner who ran Check a few seconds early would teach them nothing.
for i in $(seq 1 18); do
  RESP=$(curl -sG --max-time 20 "$L/loki/api/v1/query_range" \
    --data-urlencode 'query={namespace="production", app="crasher"}' \
    --data-urlencode 'since=45m' --data-urlencode 'limit=500' 2>/dev/null)
  FATALS=$(echo "$RESP" | jq -r '[.data.result[].values[][1]] | .[]' 2>/dev/null \
    | grep -ci 'FATAL')
  [ "${FATALS:-0}" -ge 3 ] && break
  sleep 10
done

echo "$RESP" | jq -e '.status == "success"' >/dev/null 2>&1 || {
  echo "FAIL: Loki did not answer the crasher query."
  echo "      $(echo "$RESP" | head -c 200)"
  exit 1; }
[ "${FATALS:-0}" -ge 1 ] || {
  echo "FAIL: Loki holds no FATAL line for app=\"crasher\"."
  echo "      The container writes to stderr and exits immediately, so if this"
  echo "      is empty the agent is not tailing it: check step 1 again."
  exit 1; }

[ "${FATALS:-0}" -ge 3 ] || {
  echo "FAIL: only ${FATALS} copies of the message are in Loki."
  echo "      kubectl logs --previous can already show you two. Wait for a few"
  echo "      more restarts — the argument for shipping logs is the crash from"
  echo "      an hour ago, not the one from a moment ago."
  exit 1; }

# And the learner has to have read it. Everything above is true of a cluster
# where nobody looked.
C=/root/cause.txt
[ -s "$C" ] || { echo "FAIL: $C is empty or missing. Write down what the logs told you."; exit 1; }
grep -qi 'PUT THE MESSAGE' "$C" && { echo "FAIL: $C still contains the placeholder."; exit 1; }

grep -qi 'DATABASE_URL' "$C" || {
  echo "FAIL: $C does not name what was missing."
  echo "      The message says which configuration key it could not find."
  echo "      'it crashed' is the symptom you already had before you queried."
  exit 1; }

echo "PASS — $FATALS crashes recorded in Loki, and you read the cause out of them"
exit 0
