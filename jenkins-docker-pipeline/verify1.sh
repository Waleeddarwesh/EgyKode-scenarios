#!/bin/bash
# Criterion 1: a push produces an image tagged with the short commit SHA.
#
# The tag is compared against `git rev-parse` rather than against a pattern.
# A seven-character hex string is not evidence of anything - the claim is that
# the tag identifies *the commit that was built*, and only the repository can
# settle that.
J=http://localhost:8080
REG_AUTH="ci:ci-lab-password"

[ -d /root/app/.git ] || { echo "FAIL: no git repository at /root/app"; exit 1; }

for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)
[ "$CODE" = "200" ] || { echo "FAIL: Jenkins is not answering as admin (got $CODE)"; exit 1; }

[ -f /root/app/Jenkinsfile ] || { echo "FAIL: no Jenkinsfile in /root/app"; exit 1; }

BUILD=$(curl -s --max-time 10 -u admin:adminpass "$J/job/platform-image/lastBuild/api/json" 2>/dev/null)
RESULT=$(echo "$BUILD" | jq -r '.result // empty' 2>/dev/null)
if [ -z "$RESULT" ]; then
  echo "FAIL: the platform-image job has no completed build"
  echo "      Create the job and start a build, then wait for it to finish."
  exit 1
fi
if [ "$RESULT" != "SUCCESS" ]; then
  echo "FAIL: the last build ended $RESULT, not SUCCESS"
  echo "      Read it with: curl -s -u admin:adminpass $J/job/platform-image/lastBuild/consoleText | tail -40"
  exit 1
fi

SHA=$(cd /root/app && git rev-parse --short=7 HEAD 2>/dev/null)
[ -n "$SHA" ] || { echo "FAIL: cannot read HEAD in /root/app"; exit 1; }

# Retried: the registry was observed answering NAME_UNKNOWN for a moment after
# a push that had already reported its digest. A verifier that flakes teaches
# people to click it twice and stop reading it, which is worse than one that is
# merely strict.
for i in 1 2 3 4 5; do
  TAGS=$(curl -s --max-time 10 -u "$REG_AUTH" http://localhost:5000/v2/platform/api/tags/list 2>/dev/null)
  echo "$TAGS" | jq -e '.tags' >/dev/null 2>&1 && break
  sleep 2
done
echo "$TAGS" | jq -e '.tags' >/dev/null 2>&1 || {
  echo "FAIL: the registry holds no repository called platform/api"
  echo "      The push stage did not run, or it pushed somewhere else."
  exit 1; }

echo "$TAGS" | jq -e --arg t "$SHA" '.tags | index($t)' >/dev/null 2>&1 || {
  echo "FAIL: no tag matching HEAD ($SHA) in the registry"
  echo "      Found: $(echo "$TAGS" | jq -rc '.tags')"
  echo "      The image must be tagged with the commit that built it, so a"
  echo "      running container can be traced back to one commit."
  exit 1; }

# The lab's fourth criterion is that `latest` is not what gets deployed. A
# pipeline that pushes both tags satisfies the letter of criterion 1 and
# defeats its purpose, so that case is rejected by name.
if echo "$TAGS" | jq -e '.tags | index("latest")' >/dev/null 2>&1; then
  echo "FAIL: the registry also holds a 'latest' tag"
  echo "      latest is not a version - it means whatever was pushed most"
  echo "      recently, so a rollback has nothing to roll back to. Push the"
  echo "      commit tag only."
  exit 1
fi

echo "PASS - build succeeded and platform/api:$SHA is in the registry, with no latest tag"
exit 0
