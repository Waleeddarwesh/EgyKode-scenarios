#!/bin/bash
# Criterion 2: a pull request cannot merge while its status check is failing.
#
# Proven by attempting the merge on a PR that is deliberately failing, and
# requiring the server to refuse for that reason. Reading the setting would
# accept a required context nothing ever posts, which blocks everything and
# demonstrates nothing.
U='ci:CiPassw0rd!'
API="http://localhost:3000/api/v1/repos/ci/platform"
api() { curl -s --max-time 15 -u "$U" -H "Content-Type: application/json" "$@"; }
# Gitea computes a pull request's mergeability asynchronously. Ask to merge too
# soon and it answers {"message":"Please try again later"} - which is neither
# "allowed" nor "refused", and reading it as either makes this check flake.
# Retry until it commits to an answer.
try_merge() { # $1 = PR number
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    M=$(api -X POST "$API/pulls/$1/merge" -d '{"Do":"merge"}' -w '\n%{http_code}')
    echo "$M" | grep -qi 'try again later' || { echo "$M"; return 0; }
    sleep 3
  done
  echo "$M"
}

curl -s -o /dev/null --max-time 5 http://localhost:3000/ 2>/dev/null || {
  echo "FAIL: the forge is not answering on :3000"; exit 1; }

PROT=$(api "$API/branch_protections/main")
echo "$PROT" | grep -q '"enable_status_check":true' || {
  echo "FAIL: main does not require a status check"
  echo "      Set enable_status_check and name a context in"
  echo "      status_check_contexts."
  exit 1; }
echo "$PROT" | grep -q '"status_check_contexts":\[[^]]' || {
  echo "FAIL: status checks are required but no context is named"
  echo "      An empty context list requires nothing."
  exit 1; }

# A dedicated PR, so this proves the rule rather than inspecting whatever the
# learner left open - and so the check is repeatable.
BR="verify/status-$(date +%s)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
git clone -q "http://$U@localhost:3000/ci/platform.git" "$TMP/p" 2>/dev/null || {
  echo "FAIL: cannot clone the repository"; exit 1; }
cd "$TMP/p" || exit 1
git config user.email verify@egykode.local; git config user.name verify
git checkout -q -b "$BR" origin/main
echo "status probe" >> .egykode-status-probe
git add -A && git commit -qm "verifier status probe" >/dev/null 2>&1
git push -q origin "$BR" 2>/dev/null || { echo "FAIL: cannot push a probe branch"; exit 1; }

PR=$(api -X POST "$API/pulls" -d "{\"head\":\"$BR\",\"base\":\"main\",\"title\":\"verifier status probe\"}")
NUM=$(echo "$PR" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$NUM" ] || { echo "FAIL: could not open a probe pull request"; exit 1; }

CTX=$(echo "$PROT" | grep -o '"status_check_contexts":\["[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
SHA=$(git rev-parse HEAD)
api -X POST "$API/statuses/$SHA" \
  -d "{\"context\":\"$CTX\",\"state\":\"failure\",\"description\":\"verifier probe\"}" >/dev/null
sleep 2

MERGE=$(try_merge "$NUM")
CODE=$(echo "$MERGE" | tail -1)

# Close the probe whatever happens, so the repository is not left littered.
api -X PATCH "$API/pulls/$NUM" -d '{"state":"closed"}' >/dev/null 2>&1

if [ "$CODE" = "200" ]; then
  echo "FAIL: the pull request merged with $CTX failing"
  echo "      The context required by the rule is not the one being reported,"
  echo "      or the rule is not applied to this branch. A required context"
  echo "      that never matches blocks nothing."
  exit 1
fi

echo "$MERGE" | grep -qi 'status check' || {
  echo "FAIL: the merge was refused (HTTP $CODE) but not for a status check:"
  echo "$MERGE" | head -2
  exit 1; }

echo "PASS - a merge was refused while $CTX was failing (HTTP $CODE)"
exit 0
