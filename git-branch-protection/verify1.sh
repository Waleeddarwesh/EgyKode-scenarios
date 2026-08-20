#!/bin/bash
# Criterion 1: a direct push to the protected branch is rejected.
#
# The setting existing is not the criterion - the criterion is that a push is
# refused. A protection rule with the wrong branch name, or one the pushing
# user is whitelisted out of, reads as configured and stops nothing. So this
# attempts a real push and requires the server to decline it.
A="http://ci:CiPassw0rd!@localhost:3000"
API="http://localhost:3000/api/v1/repos/ci/platform"

curl -s -o /dev/null --max-time 5 http://localhost:3000/ 2>/dev/null || {
  echo "FAIL: the forge is not answering on :3000 - setup may still be running"; exit 1; }

PROT=$(curl -s --max-time 10 -u 'ci:CiPassw0rd!' "$API/branch_protections" 2>/dev/null)
echo "$PROT" | grep -q '"branch_name":"main"' || {
  echo "FAIL: no branch protection rule on main"
  echo "      Create one with the branch_protections API."
  exit 1; }

# The behavioural test. A scratch clone, so whatever the learner has in
# /root/platform is untouched by this check.
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

git clone -q "$A/ci/platform.git" "$TMP/probe" 2>/dev/null || {
  echo "FAIL: cannot clone the repository"; exit 1; }
cd "$TMP/probe" || exit 1
git config user.email verify@egykode.local
git config user.name verify

echo "verify probe $(date +%s)" >> .egykode-probe
git add -A >/dev/null 2>&1
git commit -qm "verifier probe - must be rejected" >/dev/null 2>&1

OUT=$(git push origin main 2>&1)
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "FAIL: a direct push to main succeeded"
  echo ""
  echo "      main is not actually protected against this user. Check that"
  echo "      enable_push is false and that no push whitelist exempts them -"
  echo "      a rule that exists and permits the push protects nothing."
  # Undo the damage the probe just did, so the learner's repository is not
  # left with a stray commit from a failed check.
  git reset -q --hard HEAD~1 2>/dev/null
  git push -q --force origin main 2>/dev/null
  exit 1
fi

# Refused by the server, not by the client failing to reach it. A DNS or auth
# failure is also a non-zero exit and proves nothing about protection.
echo "$OUT" | grep -qE 'remote rejected|pre-receive hook declined|protected branch' || {
  echo "FAIL: the push failed, but not because the branch is protected:"
  echo "$OUT" | tail -3
  exit 1; }

echo "PASS - main is protected and a direct push was rejected by the server"
exit 0
