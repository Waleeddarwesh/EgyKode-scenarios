#!/bin/bash
J=http://localhost:8080
cd /root/ci 2>/dev/null || { echo "FAIL: no /root/ci"; exit 1; }

for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done

A=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)
V=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u viewer:viewerpass $J/api/json)
[ "$A" = "200" ] || { echo "FAIL: admin cannot authenticate (got $A)"; exit 1; }
[ "$V" = "200" ] || {
  echo "FAIL: the viewer user cannot authenticate (got $V) - it does not exist or has no Overall/Read"; exit 1; }

# Anonymous must not be able to read. A matrix that grants anonymous Overall/Read
# makes the whole exercise decorative.
ANON=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $J/api/json)
[ "$ANON" != "200" ] || { echo "FAIL: anonymous can read the API - the instance is open"; exit 1; }

# Signup must be off, or anyone reaching the page can make themselves a user.
grep -q "allowsSignup: *false" casc.yaml 2>/dev/null || {
  echo "FAIL: allowsSignup is not false - anyone who can load the page can create an account"; exit 1; }

# The viewer must see the job, or the refusal below proves only that they cannot
# see it rather than that they cannot build it.
VJ=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u viewer:viewerpass $J/job/platform-build/api/json)
[ "$VJ" = "200" ] || { echo "FAIL: the viewer cannot see platform-build (got $VJ) - grant Job/Read"; exit 1; }

# The criterion, demonstrated against the running server.
rm -f /tmp/v2ck
VC=$(curl -s -c /tmp/v2ck --max-time 5 -u viewer:viewerpass $J/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb' 2>/dev/null)
VB=$(curl -s -o /dev/null -w '%{http_code}' -X POST -b /tmp/v2ck --max-time 8 -u viewer:viewerpass -H "$VC" $J/job/platform-build/build)
[ "$VB" = "403" ] || {
  echo "FAIL: the viewer got $VB when starting a build, expected 403"
  echo "      Job/Build is a separate permission from Job/Read."
  exit 1; }

# And the admin must still be able to, or the matrix is simply broken.
rm -f /tmp/a2ck
AC=$(curl -s -c /tmp/a2ck --max-time 5 -u admin:adminpass $J/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb' 2>/dev/null)
AB=$(curl -s -o /dev/null -w '%{http_code}' -X POST -b /tmp/a2ck --max-time 8 -u admin:adminpass -H "$AC" $J/job/platform-build/build)
case "$AB" in
  201|200|302) ;;
  *) echo "FAIL: the admin got $AB when starting a build"; exit 1 ;;
esac

echo "PASS - viewer reads the job and is refused a build (403); admin builds it ($AB)"
exit 0
