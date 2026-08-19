#!/bin/bash
L=http://localhost:31000
F=/root/query.logql

[ -s "$F" ] || { echo "FAIL: $F is empty or missing. Write your query into it."; exit 1; }

# One query, ignoring blank lines and anything commented out.
Q=$(grep -v '^\s*#' "$F" | grep -v '^\s*$' | head -1)
[ -n "$Q" ] || { echo "FAIL: $F has no query in it."; exit 1; }
echo "$Q" | grep -qi 'PUT YOUR QUERY' && {
  echo "FAIL: $F still contains the placeholder."; exit 1; }

# The selector is the {...} the query opens with. Everything before the first
# pipe decides how much data exists; everything after it scans that data.
SEL=$(echo "$Q" | sed 's/|.*//' | grep -o '{[^}]*}')
[ -n "$SEL" ] || {
  echo "FAIL: the query does not start with a {label} selector."
  echo "      LogQL always begins with one: it is what decides which streams"
  echo "      are read at all."
  exit 1; }

echo "$SEL" | grep -qE '\{\s*\}' && {
  echo "FAIL: the selector is empty."
  echo "      {} asks Loki to scan every stream on the cluster. It is the query"
  echo "      that times out in production, and Loki refuses it outright."
  exit 1; }

# It has to narrow to one workload, and it has to do it in the selector. A
# namespace-wide selector that happens to return one Deployment's lines only
# because nothing else logged the word is not the same skill.
echo "$SEL" | grep -qE '(app|job|pod|container|service_name)\s*=' || {
  echo "FAIL: the selector names no single workload."
  echo "      It has: $SEL"
  echo "      Narrow it with one of app, job, pod, container or service_name."
  echo "      Filtering a whole namespace down with |= reads every line in it"
  echo "      first, which is the cost this step is about."
  exit 1; }

RESP=$(curl -sG --max-time 20 "$L/loki/api/v1/query_range" \
  --data-urlencode "query=$Q" \
  --data-urlencode 'since=15m' --data-urlencode 'limit=50' 2>/dev/null)

echo "$RESP" | jq -e '.status == "success"' >/dev/null 2>&1 || {
  echo "FAIL: Loki rejected the query."
  echo "      $(echo "$RESP" | head -c 300)"
  exit 1; }

COUNT=$(echo "$RESP" | jq '[.data.result[].values[]] | length' 2>/dev/null)
[ "${COUNT:-0}" -ge 1 ] || {
  echo "FAIL: the query is valid and returned no lines in the last 15 minutes."
  echo "      Query: $Q"
  echo "      Check the label values first — a typo in a label name is silent:"
  echo "      curl -s $L/loki/api/v1/label/app/values"
  exit 1; }

# Every line it returned has to be an error. A selector that is right and a
# filter that is missing returns healthcheck traffic and passes everything else.
NONERR=$(echo "$RESP" | jq -r '[.data.result[].values[][1]] | .[]' 2>/dev/null \
  | grep -vciE 'error|fatal|fail|panic')
[ "${NONERR:-1}" -eq 0 ] || {
  echo "FAIL: $NONERR of the $COUNT lines returned are not errors."
  echo "      The selector chooses the stream; a line filter such as |= \"ERROR\""
  echo "      is what reduces it to the lines you actually want."
  exit 1; }

APPS=$(echo "$RESP" | jq -r '[.data.result[].stream.app] | unique | length' 2>/dev/null)
[ "${APPS:-0}" -eq 1 ] || {
  echo "FAIL: the lines came from $APPS different Deployments, not one."
  echo "      $(echo "$RESP" | jq -r '[.data.result[].stream.app] | unique | join(", ")' 2>/dev/null)"
  exit 1; }

NAME=$(echo "$RESP" | jq -r '.data.result[0].stream.app' 2>/dev/null)
echo "PASS — $COUNT error lines, all from $NAME, selected by label before scanning"
exit 0
