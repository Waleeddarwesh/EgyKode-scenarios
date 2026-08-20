#!/bin/bash
# Criterion 1: an image pushed to the registry is scanned automatically and you
# can read the findings.
#
# Both halves are required and the second is the one that matters. A registry
# holding an image proves nothing about scanning, and a scanner that returned
# no findings is indistinguishable from one that never ran - which is the
# failure this whole lab is about.
REG=http://localhost:5000

[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $REG/v2/ 2>/dev/null)" = "200" ] || {
  echo "FAIL: the registry is not answering on :5000 - setup may still be running"; exit 1; }

curl -s --max-time 10 "$REG/v2/_catalog" 2>/dev/null | grep -q 'platform/api' || {
  echo "FAIL: no platform/api repository in the registry"
  echo "      Build and push it as step 1 does."
  exit 1; }

TAGS=$(curl -s --max-time 10 "$REG/v2/platform/api/tags/list" 2>/dev/null)
echo "$TAGS" | grep -q '"tags":\[' || { echo "FAIL: the repository has no tags"; exit 1; }

# Ask the registry what it found. The CVE database is ~108 MiB on first run, so
# this waits rather than judging a scan that has not had a chance to happen -
# a check that fails on a slow download teaches nothing about the image.
TAG=$(echo "$TAGS" | sed 's/.*"tags":\["\([^"]*\)".*/\1/')
for i in $(seq 1 20); do
  R=$(curl -s --max-time 20 -X POST "$REG/v2/_zot/ext/search" \
    -H 'Content-Type: application/json' \
    -d "{\"query\":\"{ CVEListForImage(image:\\\"platform/api:$TAG\\\") { CVEList { Id Severity } } }\"}" 2>/dev/null)
  echo "$R" | grep -q '"Id"' && break
  sleep 15
done

echo "$R" | grep -q '"Id"' || {
  echo "FAIL: the registry reports no findings for platform/api:$TAG"
  echo ""
  echo "      Either the scan has not run or its database never downloaded."
  echo "      An empty result and a clean image look identical, which is why"
  echo "      this check requires findings rather than accepting silence."
  echo "      Check: docker logs zot | grep -i cve"
  exit 1; }

COUNT=$(echo "$R" | grep -o '"Id":"' | wc -l)
case "$COUNT" in ''|*[!0-9]*) COUNT=0 ;; esac
if [ "$COUNT" -lt 1 ]; then
  echo "FAIL: the scan returned an empty finding list"; exit 1
fi

# A frozen point release should carry actionable findings. Zero at HIGH or
# above usually means an end-of-life base was used instead, where almost
# everything is unfixable and a severity filter reports nothing.
SERIOUS=$(echo "$R" | grep -o '"Severity":"\(HIGH\|CRITICAL\)"' | wc -l)
case "$SERIOUS" in ''|*[!0-9]*) SERIOUS=0 ;; esac
if [ "$SERIOUS" -lt 1 ]; then
  echo "FAIL: $COUNT findings, none of them HIGH or CRITICAL"
  echo "      Build from debian:12.5-slim - a frozen point release of a"
  echo "      maintained distribution. An end-of-life base ships no fixes, so"
  echo "      its findings are unactionable and filter away to nothing."
  exit 1
fi

echo "PASS - platform/api:$TAG was scanned on arrival: $COUNT findings, $SERIOUS at HIGH or CRITICAL"
exit 0
