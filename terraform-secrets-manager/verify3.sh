#!/bin/bash
# Criterion 4: you can state what Multi-AZ protects against and what it does
# not.
#
# The statement is prose and cannot be checked. What is checked is the thing
# the step makes you do that only makes sense if you followed the argument:
# the database moved, the endpoint in the secret moved with it, and the
# application followed without being touched. That is the operational half of
# the Multi-AZ point - a failover changes an endpoint, and everything that
# hardcoded it is now wrong.
A="aws --endpoint-url=http://localhost:4566"
APP=/root/app/run.sh

command -v aws >/dev/null 2>&1 || { echo "FAIL: the AWS CLI is not installed"; exit 1; }
[ -x "$APP" ] || { echo "FAIL: no application at $APP - finish step 2 first"; exit 1; }

SECRET=$($A secretsmanager get-secret-value --secret-id platform/db/credentials \
  --query SecretString --output text 2>/dev/null)
[ -n "$SECRET" ] || { echo "FAIL: cannot read the secret"; exit 1; }

PORT=$(echo "$SECRET" | jq -r .port 2>/dev/null)
case "$PORT" in ''|null|*[!0-9]*) echo "FAIL: the secret has no numeric port"; exit 1 ;; esac

# The database must have actually moved. Same port as the original means the
# step was read rather than performed.
if [ "$PORT" = "5432" ]; then
  echo "FAIL: the secret still points at port 5432"
  echo "      Step 3 moves the database to a new container on 5433 and updates"
  echo "      the endpoint in the secret. Nothing has moved yet."
  exit 1
fi

# And the moved-to database is the one running.
docker ps --format '{{.Names}} {{.Ports}}' | grep -q "$PORT" || {
  echo "FAIL: nothing is listening on the port the secret names ($PORT)"
  echo "      The secret was updated but the database is not there."
  exit 1; }

# The old one must be gone, or "it still works" proves nothing - the
# application could be reaching the original.
if docker ps --format '{{.Names}}' | grep -qx 'shopdb'; then
  echo "FAIL: the original database container is still running"
  echo "      Remove it, so that connecting proves the application followed the"
  echo "      endpoint rather than never having left."
  exit 1
fi

# And the application, unchanged, connects to where the secret now points.
OUT=$("$APP" 2>&1)
echo "$OUT" | grep -qi 'connected as' || {
  echo "FAIL: the application does not connect after the move"
  echo "$OUT" | tail -3
  echo "      The endpoint in the secret and the running database disagree."
  exit 1; }
echo "$OUT" | grep -q "$PORT" || {
  echo "FAIL: the application connected, but not to the port in the secret"
  echo "      It is getting the endpoint from somewhere other than the secret."
  exit 1; }

echo "PASS - the database moved to port $PORT, one secret was updated, and the application followed untouched"
exit 0
