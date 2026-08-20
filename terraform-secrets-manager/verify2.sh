#!/bin/bash
# Criterion 3: an application retrieves the credentials from Secrets Manager at
# run time.
#
# Proven by rotating the secret behind the application's back and requiring it
# to notice. An application that connects successfully proves only that it has
# a working password somewhere; one that follows a change it was never told
# about can only be reading it live.
A="aws --endpoint-url=http://localhost:4566"
APP=/root/app/run.sh

command -v aws >/dev/null 2>&1 || { echo "FAIL: the AWS CLI is not installed"; exit 1; }
[ -x "$APP" ] || { echo "FAIL: no executable application at $APP"; exit 1; }

docker ps --format '{{.Names}}' | grep -qE '^shopdb' || {
  echo "FAIL: no database container is running"
  echo "      Start it with the password from the secret, as step 2 does."
  exit 1; }

SECRET=$($A secretsmanager get-secret-value --secret-id platform/db/credentials \
  --query SecretString --output text 2>/dev/null)
PW=$(echo "$SECRET" | jq -r .password 2>/dev/null)
[ -n "$PW" ] && [ "$PW" != "null" ] || { echo "FAIL: cannot read the secret"; exit 1; }

# The application must hold no credential of its own. A password moved from the
# code into the script is not the criterion.
if grep -q -F -- "$PW" "$APP" 2>/dev/null; then
  echo "FAIL: the password is written inside $APP"
  echo "      Fetching it at run time is the criterion; a copy in the script"
  echo "      is the thing being replaced."
  exit 1
fi
grep -q 'secretsmanager' "$APP" || {
  echo "FAIL: $APP never calls Secrets Manager"
  echo "      It is getting its credentials from somewhere else."
  exit 1; }

# It works as it stands.
OUT=$("$APP" 2>&1)
echo "$OUT" | grep -qi 'connected as' || {
  echo "FAIL: the application does not connect"
  echo "$OUT" | tail -3
  exit 1; }

# Now the real test: change the secret and require the application to follow
# without being edited, restarted with new configuration, or told anything.
BACKUP="$SECRET"
restore() { $A secretsmanager put-secret-value --secret-id platform/db/credentials \
  --secret-string "$BACKUP" >/dev/null 2>&1; }
trap restore EXIT INT TERM

BAD=$(echo "$SECRET" | jq -c '.password = "verifier-wrong-password"')
$A secretsmanager put-secret-value --secret-id platform/db/credentials \
  --secret-string "$BAD" >/dev/null 2>&1
sleep 1

BROKEN=$("$APP" 2>&1)
if echo "$BROKEN" | grep -qi 'connected as'; then
  echo "FAIL: the application still connected after the secret was changed"
  echo "      It is not reading the credential at run time - it has one cached,"
  echo "      baked in, or supplied from the environment. Rotating the secret"
  echo "      would not rotate anything."
  exit 1
fi

restore; trap - EXIT INT TERM
sleep 1
AGAIN=$("$APP" 2>&1)
echo "$AGAIN" | grep -qi 'connected as' || {
  echo "FAIL: the application did not recover after the secret was restored"
  echo "$AGAIN" | tail -3
  exit 1; }

echo "PASS - the application follows the secret: it failed when rotated and recovered when restored"
exit 0
