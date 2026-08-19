#!/bin/bash
D=/root/ci
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }
J=http://localhost:8080

for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)
[ "$CODE" = "200" ] || { echo "FAIL: Jenkins is not answering as admin (got $CODE)"; exit 1; }

# JENKINS_HOME must be on a named volume, not the container layer. Everything
# Jenkins knows is in that directory and there is no database behind it.
grep -q "jenkins_home:/var/jenkins_home" compose.yaml 2>/dev/null || {
  echo "FAIL: JENKINS_HOME is not mounted from a named volume"
  echo "      Without it, docker compose down deletes every job and credential."
  exit 1; }
docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q jenkins_home || {
  echo "FAIL: no jenkins_home volume exists"; exit 1; }

curl -s --max-time 5 -u admin:adminpass $J/api/json 2>/dev/null | jq -e '.jobs[] | select(.name=="platform-build")' >/dev/null 2>&1 || {
  echo "FAIL: no job named platform-build"; exit 1; }

# The job existing proves nothing about persistence on its own - it may have
# been created a moment ago. Recreate the container and require it to survive.
docker compose down >/dev/null 2>&1
docker compose up -d >/dev/null 2>&1
for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done
curl -s --max-time 5 -u admin:adminpass $J/api/json 2>/dev/null | jq -e '.jobs[] | select(.name=="platform-build")' >/dev/null 2>&1 || {
  echo "FAIL: platform-build did not survive the container being recreated"
  echo "      JENKINS_HOME is not actually persisting."
  exit 1; }

echo "PASS - Jenkins answers as admin and platform-build survived a full down and up"
exit 0
