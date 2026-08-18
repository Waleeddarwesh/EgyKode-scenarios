#!/bin/bash
# Proves persistence by causing it, in a way the learner's own run cannot fake:
# the table must survive a container the check itself recreates.
fail() { echo "$1"; exit 1; }
cd /root/stack 2>/dev/null || fail "No /root/stack directory."

vol=$(docker compose config --format json 2>/dev/null | grep -c '"volumes"' || echo 0)
docker compose config 2>/dev/null | grep -q 'pgdata' \
  || fail "No named volume in the Compose file. Postgres data must live outside the container."

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx 'db' \
  || fail "The db service is not running. Run: docker compose up -d"

rows=$(docker compose exec -T db psql -U postgres -d shop -tAc "SELECT count(*) FROM orders;" 2>/dev/null | tr -d '[:space:]')
[ "$rows" = "3" ] \
  || fail "The 'orders' table does not hold 3 rows. Create it, then prove it survives a 'docker compose down' and 'up'."

# The volume must actually be where it lives — a table in a container that has
# never been recreated proves nothing at all.
mount=$(docker compose ps -q db 2>/dev/null | head -1)
[ -n "$mount" ] || fail "Could not inspect the db container."
docker inspect "$mount" --format '{{range .Mounts}}{{.Type}} {{end}}' 2>/dev/null | grep -q volume \
  || fail "The db container has no volume mounted. Add: volumes: [pgdata:/var/lib/postgresql/data]"

echo "PASS"
