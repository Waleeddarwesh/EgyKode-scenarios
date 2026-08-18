#!/bin/bash
# Both codes are produced live, because a capture file could say anything. The
# environment is restored afterwards either way.
fail() { echo "$1"; exit 1; }
cd /root/proxy 2>/dev/null || fail "No /root/proxy directory."

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx proxy \
  || fail "The proxy is not running. Run: docker compose up -d"

restore() { docker compose start app1 app2 >/dev/null 2>&1; }

# 502: nothing behind the proxy.
docker compose stop app1 app2 >/dev/null 2>&1
code502=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 localhost:8080)
restore
[ "$code502" = "502" ] \
  || fail "With both backends stopped the proxy returned $code502, not 502. Check proxy_pass points at the upstream."

# 504: a route that answers too slowly for proxy_read_timeout.
grep -q 'proxy_read_timeout' conf.d/default.conf 2>/dev/null \
  || fail "conf.d/default.conf sets no proxy_read_timeout, so a slow backend can never produce a 504."

if ! docker compose ps --format '{{.Service}}' 2>/dev/null | grep -qx slow; then
  fail "No 'slow' service yet. Add it and a /slow location, so a backend can be slow rather than absent."
fi
sleep 2
code504=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 localhost:8080/slow)
[ "$code504" = "504" ] \
  || fail "The slow route returned $code504, not 504. proxy_read_timeout must be shorter than the backend's delay."

echo "PASS"
