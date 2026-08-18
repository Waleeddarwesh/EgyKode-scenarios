#!/bin/bash
D=/root/stack
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

# The app installs Gunicorn at container start, so a fresh `up` legitimately
# takes a few seconds to answer. Wait for it, but bounded - a stack that never
# comes up still fails.
wait_for_http() {
  for i in $(seq 1 30); do
    if curl -s --max-time 5 "$1" >/dev/null 2>&1; then return 0; fi
    sleep 2
  done
  return 1
}

DB_ID=$(docker compose ps -q db 2>/dev/null)
APP_ID=$(docker compose ps -q app 2>/dev/null)
[ -n "$DB_ID" ] || { echo "FAIL: there is no db service running"; exit 1; }
[ -n "$APP_ID" ] || { echo "FAIL: there is no app service running"; exit 1; }

# A healthcheck that exists and a healthcheck that answers the right question
# are different things, but the first is a precondition for the second.
HEALTH=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$DB_ID" 2>/dev/null)
[ "$HEALTH" != "none" ] || {
  echo "FAIL: the db container has no healthcheck at all"; exit 1; }
[ "$HEALTH" = "healthy" ] || {
  echo "FAIL: the db reports '$HEALTH', not healthy"; exit 1; }

grep -q "condition: *service_healthy" compose.yaml 2>/dev/null || {
  echo "FAIL: the app does not depend on the db with condition: service_healthy"
  echo "      Plain depends_on waits for the container to start, not for the database to be usable."
  exit 1; }

# State, not configuration. If Compose had not waited, the app would have
# started within a moment of the database rather than several seconds later.
# StartedAt carries nanoseconds and a T separator, which neither busybox date
# nor GNU date will parse as given. Normalising first keeps this working on
# both - and an unparsable timestamp is an error here rather than a silently
# skipped check, which is how this comparison quietly did nothing at first.
epoch() {
  date -u -d "$(echo "$1" | sed 's/\..*Z$//; s/Z$//' | tr 'T' ' ')" +%s 2>/dev/null
}
DB_EPOCH=$(epoch "$(docker inspect -f '{{.State.StartedAt}}' "$DB_ID" 2>/dev/null)")
APP_EPOCH=$(epoch "$(docker inspect -f '{{.State.StartedAt}}' "$APP_ID" 2>/dev/null)")
[ -n "$DB_EPOCH" ] && [ -n "$APP_EPOCH" ] || {
  echo "FAIL: could not read the container start times to check the ordering"; exit 1; }
GAP=$((APP_EPOCH - DB_EPOCH))
[ "$GAP" -ge 2 ] || {
  echo "FAIL: the app started ${GAP}s after the db, too soon to have waited on its health"
  echo "      Recreate the stack so the ordering is measurable: docker compose down && docker compose up -d"
  exit 1; }

# The database must genuinely accept connections, which is what the check claims.
docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 || {
  echo "FAIL: pg_isready says the database is not accepting connections"; exit 1; }

# And the stack still has to work end to end.
wait_for_http http://localhost:8080/ || {
  echo "FAIL: the stack does not answer through the proxy after 60s"
  docker compose ps 2>/dev/null | tail -4
  exit 1; }
curl -s --max-time 10 http://localhost:8080/ 2>/dev/null | grep -q "remote_addr=" || {
  echo "FAIL: the proxy answers but the response did not come from the application"; exit 1; }

echo "PASS - the db is healthy, the app waited ${GAP:-?}s for it, and the stack answers"
exit 0
