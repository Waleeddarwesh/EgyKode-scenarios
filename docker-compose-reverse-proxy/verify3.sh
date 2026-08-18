#!/bin/bash
D=/root/stack
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

wait_for_db() {
  for i in $(seq 1 30); do
    docker compose exec -T db pg_isready -U postgres -d platform >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

# The volume must be declared. Without it the data lives in the container layer
# and everything below would still pass right up until the first restart.
grep -q "pgdata:/var/lib/postgresql/data" compose.yaml 2>/dev/null || {
  echo "FAIL: the db does not mount a named volume at /var/lib/postgresql/data"
  echo "      Data written to that path goes into the container layer and dies with it."
  exit 1; }

docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q pgdata || {
  echo "FAIL: no pgdata volume exists"; exit 1; }

wait_for_db || { echo "FAIL: the database is not accepting connections"; exit 1; }

ROWS=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;" 2>/dev/null | tr -d '[:space:]')
[ "$ROWS" = "2" ] || {
  echo "FAIL: the orders table holds '${ROWS:-nothing}', expected 2 rows"
  echo "      Recreate the rows and take the stack down and up again."
  exit 1; }

# The rows existing proves nothing about persistence on their own - they may
# have been inserted a moment ago. Cycle the stack here and require them to
# survive it.
docker compose down >/dev/null 2>&1
docker compose up -d >/dev/null 2>&1
wait_for_db || { echo "FAIL: the database did not come back after down and up"; exit 1; }

AFTER=$(docker compose exec -T db psql -U postgres -d platform -tAc "SELECT count(*) FROM orders;" 2>/dev/null | tr -d '[:space:]')
[ "$AFTER" = "2" ] || {
  echo "FAIL: after down and up the orders table holds '${AFTER:-nothing}', expected 2"
  echo "      The data is not on a volume that outlives the container."
  exit 1; }

echo "PASS - two rows survived a full down and up on the named volume"
exit 0
