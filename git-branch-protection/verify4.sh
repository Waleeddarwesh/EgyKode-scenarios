#!/bin/bash
# Criterion 4: you can explain why "require branches to be up to date" matters.
#
# The explanation is prose and cannot be checked. What is checked is that the
# learner has the rule on and has seen it do its job: a branch that was fine
# until main moved is refused, and merges once it catches up. Having watched
# that happen is the difference between explaining it and reciting it.
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

api "$API/branch_protections/main" | grep -q '"block_on_outdated_branch":true' || {
  echo "FAIL: main does not require branches to be up to date"
  echo "      Set block_on_outdated_branch on the protection rule."
  exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
git clone -q "http://$U@localhost:3000/ci/platform.git" "$TMP/p" 2>/dev/null || {
  echo "FAIL: cannot clone the repository"; exit 1; }
cd "$TMP/p" || exit 1
git config user.email verify@egykode.local; git config user.name verify

# Branch from main as it is now, then move main on underneath it - the exact
# situation the rule exists for, reproduced rather than assumed.
BASE=$(git rev-parse origin/main)
BR="verify/outdated-$(date +%s)"
git checkout -q -B "$BR" "$BASE"
echo "outdated probe" >> .egykode-outdated-probe
git add -A && git commit -qm "verifier outdated probe" >/dev/null 2>&1
git push -q origin "$BR" 2>/dev/null || { echo "FAIL: cannot push a probe branch"; exit 1; }

PR=$(api -X POST "$API/pulls" -d "{\"head\":\"$BR\",\"base\":\"main\",\"title\":\"verifier outdated probe\"}")
NUM=$(echo "$PR" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
[ -n "$NUM" ] || { echo "FAIL: could not open a probe pull request"; exit 1; }

# Advance main by one commit through the API, briefly lifting the push rule the
# way the step does, then putting it back exactly as it was.
api -X PATCH "$API/branch_protections/main" -d '{"enable_push":true}' >/dev/null
SHA=$(api "$API/contents/README.md?ref=main" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)
C=$(printf 'verifier moved main %s\n' "$(date +%s)" | base64 | tr -d '\n')
api -X PUT "$API/contents/README.md" \
  -d "{\"content\":\"$C\",\"message\":\"verifier advances main\",\"branch\":\"main\",\"sha\":\"$SHA\"}" >/dev/null
api -X PATCH "$API/branch_protections/main" -d '{"enable_push":false}' >/dev/null
sleep 3

OUT=$(try_merge "$NUM")
CODE=$(echo "$OUT" | tail -1)
api -X PATCH "$API/pulls/$NUM" -d '{"state":"closed"}' >/dev/null 2>&1

if [ "$CODE" = "200" ]; then
  echo "FAIL: a pull request branched before main moved merged anyway"
  echo "      block_on_outdated_branch is set but is not being applied, so a"
  echo "      change tested against a main that no longer exists can still"
  echo "      land - which is the whole failure the setting prevents."
  exit 1
fi

# And the learner must have actually merged something through this workflow,
# rather than only configuring it. An untouched repository would satisfy every
# assertion above.
MERGED=$(api "$API/pulls?state=closed&limit=50" | grep -c '"merged_at":"2')
case "$MERGED" in ''|*[!0-9]*) MERGED=0 ;; esac
if [ "$MERGED" -lt 1 ]; then
  echo "FAIL: the rule is set and refuses an outdated branch, but no pull"
  echo "      request has ever been merged in this repository."
  echo "      Work step 4 through: catch the branch up and merge it, so you"
  echo "      have seen both halves rather than only the refusal."
  exit 1
fi

echo "PASS - an outdated branch was refused (HTTP $CODE), and $MERGED pull request(s) merged after catching up"
exit 0
