#!/bin/bash
# Proves failover by causing it, then restores what it changed. A check that
# left a backend stopped would break the next step.
fail() { echo "$1"; exit 1; }
cd /root/proxy 2>/dev/null || fail "No /root/proxy directory."

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx proxy \
  || fail "The proxy is not running. Run: docker compose up -d"

grep -q 'max_fails' conf.d/default.conf 2>/dev/null \
  || fail "No max_fails on the upstream servers. Without it nginx keeps sending traffic to a dead backend."

was_running=$(docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -cx app1)

docker compose stop app1 >/dev/null 2>&1
codes=$(for i in $(seq 1 8); do curl -s -o /dev/null -w '%{http_code} ' --max-time 3 localhost:8080; done)
# Restore before judging, so a failure still leaves the environment usable.
[ "$was_running" -eq 1 ] && docker compose start app1 >/dev/null 2>&1

# grep -v on the trailing empty field counted an eighth failure when all
# eight requests had in fact returned 200.
bad=$(echo "$codes" | tr ' ' '
' | grep -v '^$' | grep -vc '^200$' || true)
[ "$bad" -eq 0 ] \
  || fail "With app1 stopped, $bad of 8 requests did not return 200 (got: $codes). Both backends must be in the upstream so one can cover the other."

echo "PASS"
