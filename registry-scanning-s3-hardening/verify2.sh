#!/bin/bash
# Criterion 2: a lifecycle policy expires untagged images, and you can state
# how many it will keep.
#
# Checked by what happened to the registry, not by what the config says. A
# retention policy that is configured and never runs looks identical in the
# file and does nothing to the disk.
REG=http://localhost:5000
CFG=/root/registry/etc/config.json

[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $REG/v2/ 2>/dev/null)" = "200" ] || {
  echo "FAIL: the registry is not answering on :5000"; exit 1; }

[ -f "$CFG" ] || { echo "FAIL: no registry config at $CFG"; exit 1; }
grep -q 'deleteUntagged' "$CFG" || {
  echo "FAIL: the retention policy does not handle untagged manifests"; exit 1; }

KEEP=$(grep -o '"mostRecentlyPushedCount"[: ]*[0-9]*' "$CFG" | grep -o '[0-9]*$' | head -1)
case "$KEEP" in ''|*[!0-9]*) KEEP=0 ;; esac
[ "$KEEP" -ge 1 ] || {
  echo "FAIL: the policy names no number of tags to keep"
  echo "      'How many will it keep' is half the criterion, and a policy that"
  echo "      cannot answer it is one nobody can rely on during a rollback."
  exit 1; }

# The learner must have pushed more than the policy keeps, or nothing was ever
# asked of it.
LOGGED=$(docker logs zot 2>&1 | grep -c '"module":"retention"')
case "$LOGGED" in ''|*[!0-9]*) LOGGED=0 ;; esac
if [ "$LOGGED" -lt 1 ]; then
  echo "FAIL: the retention policy has never run"
  echo "      It runs on a schedule rather than on push - give it a cycle."
  exit 1
fi

TAGS=$(curl -s --max-time 10 "$REG/v2/platform/api/tags/list" 2>/dev/null)
N=$(echo "$TAGS" | grep -o '"v[0-9]*"' | wc -l)
case "$N" in ''|*[!0-9]*) N=0 ;; esac
if [ "$N" -lt 1 ]; then
  echo "FAIL: no v-prefixed tags in the registry"
  echo "      Push v1..v5 as step 2 does, so the policy has something to expire."
  exit 1
fi
if [ "$N" -gt "$KEEP" ]; then
  echo "FAIL: $N tags remain and the policy keeps $KEEP"
  echo "      Found: $(echo "$TAGS" | grep -o '"v[0-9]*"' | tr '\n' ' ')"
  echo "      The policy has not expired them yet. It runs on a schedule;"
  echo "      wait for a cycle and re-check."
  exit 1
fi

# And the expiry must have actually happened rather than the learner pushing
# three tags and stopping - otherwise nothing was demonstrated.
PUSHED=$(docker logs zot 2>&1 | grep -c 'PUT.*manifests/v[0-9]')
case "$PUSHED" in ''|*[!0-9]*) PUSHED=0 ;; esac
if [ "$PUSHED" -le "$KEEP" ]; then
  echo "FAIL: only $PUSHED tagged pushes were made and the policy keeps $KEEP"
  echo "      Nothing has been expired, so the policy has not been shown to"
  echo "      do anything. Push more versions than it keeps."
  exit 1
fi

echo "PASS - $PUSHED versions pushed, policy keeps $KEEP, $N remain: expiry demonstrated"
exit 0
