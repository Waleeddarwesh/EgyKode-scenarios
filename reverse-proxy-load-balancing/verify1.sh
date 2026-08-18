#!/bin/bash
# Both backends must actually answer. Reading the upstream block would prove
# the file was written, not that traffic reaches two places.
fail() { echo "$1"; exit 1; }
cd /root/proxy 2>/dev/null || fail "No /root/proxy directory."

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx proxy \
  || fail "The proxy is not running. Run: docker compose up -d"

# Sampled across a window rather than once. nginx marks a backend down for
# fail_timeout when it was not ready at startup, so a single burst taken too
# early sees one backend and reports a configuration error that is not there.
seen=0
for attempt in 1 2 3 4 5; do
  seen=$(for i in $(seq 1 8); do curl -s --max-time 3 localhost:8080; echo; done | sort -u | grep -c .)
  [ "$seen" -ge 2 ] && break
  sleep 4
done
[ "$seen" -ge 2 ] || fail "Only one distinct backend answered over 20 seconds. Both app1 and app2 must be in the upstream block, and both running."

# The forwarding headers are the other half of the step.
cfg=$(cat conf.d/default.conf 2>/dev/null)
for h in X-Real-IP X-Forwarded-For X-Forwarded-Proto Host; do
  echo "$cfg" | grep -q "$h" || fail "conf.d/default.conf does not set $h. The backend cannot see the real client without it."
done

echo "PASS"
