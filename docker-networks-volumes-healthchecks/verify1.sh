#!/bin/bash
# Resolution is tested from inside the network, which is the only place the
# name exists. Reading compose.yaml would prove the file was written, not that
# the network works.
fail() { echo "$1"; exit 1; }
cd /root/stack 2>/dev/null || fail "No /root/stack directory."

[ -f compose.yaml ] || [ -f docker-compose.yaml ] || [ -f docker-compose.yml ] \
  || fail "No Compose file in /root/stack yet."

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx 'db' \
  || fail "The 'db' service is not running. Run: docker compose up -d"
docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx 'app' \
  || fail "The 'app' service is not running. Run: docker compose up -d"

# The actual claim: one service reaches the other by name.
docker compose exec -T app sh -c 'nc -z db 5432' >/dev/null 2>&1 \
  || fail "The app container cannot reach 'db' by name. Both services must be on the same Compose network."

# And no IP address is hardcoded anywhere, which is the habit being taught.
if grep -rEq '([0-9]{1,3}\.){3}[0-9]{1,3}' compose.yaml 2>/dev/null; then
  grep -rE '([0-9]{1,3}\.){3}[0-9]{1,3}' compose.yaml | grep -qv '0\.0\.0\.0' \
    && fail "The Compose file contains an IP address. Services should be reached by name."
fi

echo "PASS"
