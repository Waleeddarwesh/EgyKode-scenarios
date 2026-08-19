#!/bin/bash
# Criterion 3: no credential appears in the build log.
#
# An absence check on its own passes by default - a build that never logged in
# has no password in its log either, and so does a build that never ran. So
# this requires the presence of a successful authenticated push FIRST, and only
# then asserts the absence.
J=http://localhost:8080
SECRET='ci-lab-password'

for i in $(seq 1 24); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass $J/api/json)" = "200" ] && break
  sleep 5
done

LOG=$(curl -s --max-time 15 -u admin:adminpass "$J/job/platform-image/lastSuccessfulBuild/consoleText" 2>/dev/null)
if [ -z "$LOG" ]; then
  echo "FAIL: there is no successful build to inspect"
  echo "      Finish step 1 first - this step is about what that build did not print."
  exit 1
fi

# Presence: the build must actually have authenticated. Without this the
# absence check below is satisfied by any build that never reached the push.
if ! echo "$LOG" | grep -q 'Login Succeeded'; then
  echo "FAIL: the build log has no 'Login Succeeded'"
  echo "      Nothing authenticated to the registry, so 'no credential in the"
  echo "      log' is true by default rather than because anything protected it."
  exit 1
fi

# Presence: and it must have pushed, which is what needed the credential.
if ! echo "$LOG" | grep -qE 'digest: sha256:|latest: digest'; then
  echo "FAIL: the build log shows no push to the registry"
  exit 1
fi

# Absence, now that it means something.
COUNT=$(echo "$LOG" | grep -c "$SECRET")
if [ "$COUNT" -ne 0 ]; then
  echo "FAIL: the registry password appears in the build log $COUNT time(s)"
  echo "      Something printed it outside withCredentials, or a shell trace"
  echo "      (set -x) ran in a stage that touches the secret."
  exit 1
fi

# The Jenkinsfile is in git and gets copied around; a secret written into it
# defeats the whole arrangement even when the log happens to be clean.
if [ -f /root/app/Jenkinsfile ] && grep -q "$SECRET" /root/app/Jenkinsfile; then
  echo "FAIL: the password is hardcoded in the Jenkinsfile"
  echo "      Use the credentialsId binding - a pipeline file is reviewed,"
  echo "      forked and copied far more often than a controller's config."
  exit 1
fi

if ! grep -q 'withCredentials' /root/app/Jenkinsfile 2>/dev/null; then
  echo "FAIL: the Jenkinsfile does not use withCredentials"
  exit 1
fi

echo "PASS - the build authenticated and pushed, and printed no credential doing it"
exit 0
