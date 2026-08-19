#!/bin/bash
# Criterion 2: a HIGH or CRITICAL vulnerability fails the build, proven with a
# deliberately old base image.
#
# The evidence is a build in history that FAILED at the scan without pushing.
# Checking only the current state would accept a learner who never broke
# anything, and checking only "a build failed" would accept a build that failed
# for any other reason - a typo in the Jenkinsfile fails too.
J=http://localhost:8080

for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done
[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] || {
  echo "FAIL: Jenkins is not answering"; exit 1; }

# The brackets must be percent-encoded. Sent raw, Jenkins answers 200 with an
# empty body rather than an error, so an unencoded tree query looks exactly
# like a job with no builds - and this verifier would report "no build was
# stopped by the scan" no matter what the learner did.
BUILDS=$(curl -s --max-time 15 -u admin:adminpass "$J/job/platform-image/api/json?tree=builds%5Bnumber,result%5D" 2>/dev/null)
echo "$BUILDS" | jq -e '.builds' >/dev/null 2>&1 || {
  echo "FAIL: the platform-image job has no build history"; exit 1; }

# Find a failed build whose log shows Trivy stopping it, and no push after.
GATED=""
for N in $(echo "$BUILDS" | jq -r '.builds[] | select(.result=="FAILURE") | .number' 2>/dev/null); do
  L=$(curl -s --max-time 15 -u admin:adminpass "$J/job/platform-image/$N/consoleText" 2>/dev/null)
  # Trivy ran and reported at the gated severities...
  echo "$L" | grep -qE 'Total: [1-9][0-9]* \(|HIGH: [1-9]|CRITICAL: [1-9]' || continue
  # ...and the push never happened in that build.
  echo "$L" | grep -q 'Login Succeeded' && continue
  GATED="$N"
  break
done

if [ -z "$GATED" ]; then
  echo "FAIL: no build was stopped by the scan"
  echo ""
  echo "      Expected a FAILURE whose log shows Trivy findings and no"
  echo "      'Login Succeeded' after them. If a build failed for another"
  echo "      reason, that is not the gate being demonstrated."
  echo ""
  echo "      If the scan reported 0 findings on debian:12.5-slim, the Trivy"
  echo "      database did not download, or that snapshot has been rebuilt."
  echo "      A scanner that cannot update is not a gate: check"
  echo "      /root/ci/setup.log for the count recorded during setup."
  exit 1
fi

# The vulnerable commit must not have reached the registry. This is the
# difference between a gate and a report, and it is the half people skip.
BROKEN_SHA=$(cd /root/app && git log --oneline --all --format='%h %s' 2>/dev/null \
  | grep -i 'snapshot' | head -1 | awk '{print $1}')
if [ -n "$BROKEN_SHA" ]; then
  TAGS=$(curl -s --max-time 10 -u ci:ci-lab-password http://localhost:5000/v2/platform/api/tags/list 2>/dev/null)
  if echo "$TAGS" | jq -e --arg t "$BROKEN_SHA" '.tags | index($t)' >/dev/null 2>&1; then
    echo "FAIL: the vulnerable commit $BROKEN_SHA is in the registry"
    echo "      The scan ran but did not stop the push. A scan placed after"
    echo "      the push publishes the image before it says anything about it."
    exit 1
  fi
fi

# And the repair must be demonstrated, or the lab ends on a red build with the
# learner never seeing the gate open again.
LAST=$(curl -s --max-time 10 -u admin:adminpass "$J/job/platform-image/lastBuild/api/json" 2>/dev/null | jq -r '.result // empty')
if [ "$LAST" != "SUCCESS" ]; then
  echo "FAIL: build #$GATED was correctly stopped by the scan, but the latest"
  echo "      build is $LAST rather than SUCCESS."
  echo "      Move the Dockerfile back to debian:12-slim, commit, and rebuild -"
  echo "      a gate that cannot be satisfied teaches people to disable it."
  exit 1
fi

echo "PASS - build #$GATED was stopped by the scan with nothing pushed, and the rebuild passed"
exit 0
