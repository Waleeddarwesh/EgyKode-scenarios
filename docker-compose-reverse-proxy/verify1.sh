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

docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -q proxy || {
  echo "FAIL: the proxy container is not running"; docker compose ps 2>/dev/null | tail -4; exit 1; }
docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -q '^app$' || {
  echo "FAIL: the app container is not running"; exit 1; }

# Static must be served by nginx from disk. If it were proxied, this would
# still return the file on a stack where nginx forwards everything - so check
# the header nginx sets and Gunicorn does not.
wait_for_http http://localhost:8080/static/hello.txt || {
  echo "FAIL: nothing answers on http://localhost:8080/ after 60s"
  docker compose ps 2>/dev/null | tail -4
  exit 1; }

BODY=$(curl -s --max-time 10 http://localhost:8080/static/hello.txt)
echo "$BODY" | grep -q "served by nginx" || {
  echo "FAIL: /static/hello.txt did not return the expected content"; exit 1; }
SERVER=$(curl -s -I --max-time 10 http://localhost:8080/static/hello.txt | grep -i '^server:')
echo "$SERVER" | grep -qi nginx || {
  echo "FAIL: /static/ is not being served by nginx ($SERVER)"; exit 1; }

# The dynamic path has to reach Gunicorn, which the static path never does.
DYN=$(curl -s --max-time 10 http://localhost:8080/)
echo "$DYN" | grep -q "remote_addr=" || {
  echo "FAIL: / did not reach the application"; echo "      got: $DYN"; exit 1; }

# The criterion: the app can see the real client, not the proxy. A missing or
# empty X-Real-IP is the default behaviour, so this is the check that matters.
RIP=$(echo "$DYN" | grep '^x_real_ip=' | cut -d= -f2)
[ -n "$RIP" ] && [ "$RIP" != "-" ] || {
  echo "FAIL: the application sees x_real_ip='$RIP' - it cannot tell who is calling it"
  echo "      proxy_set_header X-Real-IP \$remote_addr;"
  exit 1; }
XFF=$(echo "$DYN" | grep '^x_forwarded_for=' | cut -d= -f2)
[ -n "$XFF" ] && [ "$XFF" != "-" ] || {
  echo "FAIL: X-Forwarded-For is not being set"; exit 1; }

echo "PASS - nginx serves the static file, Gunicorn answers /, and the client IP survives ($RIP)"
exit 0
