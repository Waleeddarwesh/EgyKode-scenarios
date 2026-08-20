#!/bin/bash
# Criterion 3: a CODEOWNERS entry requests the right reviewer automatically.
#
# Both directions are tested. A file that matches everything requests the owner
# on every pull request, which looks identical to a working rule until the day
# it matters - so an owned path must pull the reviewer in AND an unowned path
# must not.
U='ci:CiPassw0rd!'
API="http://localhost:3000/api/v1/repos/ci/platform"
api() { curl -s --max-time 15 -u "$U" -H "Content-Type: application/json" "$@"; }
reviewers() { api "$API/pulls/$1" | grep -o '"requested_reviewers":\[[^]]*\]' | grep -o '"login":"[^"]*"' | cut -d'"' -f4; }

curl -s -o /dev/null --max-time 5 http://localhost:3000/ 2>/dev/null || {
  echo "FAIL: the forge is not answering on :3000"; exit 1; }

FILE=$(api "$API/raw/.gitea/CODEOWNERS?ref=main")
echo "$FILE" | grep -q '@' || {
  echo "FAIL: no CODEOWNERS on main with an owner in it"
  echo "      Looked at .gitea/CODEOWNERS on the base branch - it has to be"
  echo "      there, not on your feature branch."
  exit 1; }

api "$API/collaborators" | grep -q '"login":"platform-lead"' || {
  echo "FAIL: platform-lead is not a collaborator"
  echo "      CODEOWNERS silently ignores an owner who cannot review the"
  echo "      repository, so the entry would never request anyone."
  exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
git clone -q "http://$U@localhost:3000/ci/platform.git" "$TMP/p" 2>/dev/null || {
  echo "FAIL: cannot clone the repository"; exit 1; }
cd "$TMP/p" || exit 1
git config user.email verify@egykode.local; git config user.name verify

probe() { # $1 = path to touch, $2 = branch suffix
  B="verify/own-$2-$(date +%s)"
  git checkout -q -B "$B" origin/main
  mkdir -p "$(dirname "$1")" 2>/dev/null
  echo "probe" >> "$1"
  git add -A && git commit -qm "verifier owner probe $2" >/dev/null 2>&1
  git push -q origin "$B" 2>/dev/null || return 1
  P=$(api -X POST "$API/pulls" -d "{\"head\":\"$B\",\"base\":\"main\",\"title\":\"verifier owner probe $2\"}")
  echo "$P" | tr ',' '\n' | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2
}

OWNED=$(probe "infra/verify-probe.tf" owned)
UNOWNED=$(probe "VERIFY-PROBE.md" unowned)
[ -n "$OWNED" ] && [ -n "$UNOWNED" ] || { echo "FAIL: could not open the probe pull requests"; exit 1; }
sleep 5

R_OWNED=$(reviewers "$OWNED")
R_UNOWNED=$(reviewers "$UNOWNED")

api -X PATCH "$API/pulls/$OWNED" -d '{"state":"closed"}' >/dev/null 2>&1
api -X PATCH "$API/pulls/$UNOWNED" -d '{"state":"closed"}' >/dev/null 2>&1

echo "$R_OWNED" | grep -q 'platform-lead' || {
  echo "FAIL: a pull request touching infra/ did not request platform-lead"
  echo "      Requested: ${R_OWNED:-nobody}"
  echo ""
  echo "      This forge matches CODEOWNERS paths as regular expressions, not"
  echo "      as gitignore globs. 'infra/*' is a valid glob and a regex that"
  echo "      matches nothing useful; 'infra/.*' is what works here. Nothing"
  echo "      warns you - the file parses and no reviewer is ever added."
  exit 1; }

if echo "$R_UNOWNED" | grep -q 'platform-lead'; then
  echo "FAIL: a pull request touching no owned path also requested platform-lead"
  echo "      The pattern matches everything, so it is not routing review - it"
  echo "      is just adding the same person to every change."
  exit 1
fi

echo "PASS - infra/ requests platform-lead and an unowned path does not"
exit 0
