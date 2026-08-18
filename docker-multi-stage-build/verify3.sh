#!/bin/bash
# The running container's identity is the evidence — not the presence of a
# USER line, which can be written and then overridden.
docker image inspect app:nonroot >/dev/null 2>&1 || {
  echo "FAIL: image app:nonroot does not exist"; exit 1; }

UID_OUT=$(docker run --rm app:nonroot id -u 2>/dev/null)
[ -n "$UID_OUT" ] || { echo "FAIL: could not read the container's uid"; exit 1; }

if [ "$UID_OUT" = "0" ]; then
  echo "FAIL: the container still runs as root (uid 0)"; exit 1
fi

docker run --rm app:nonroot python -c "import gunicorn" 2>/dev/null || {
  echo "FAIL: runs as uid $UID_OUT but the app is broken — check the COPY and PYTHONPATH"; exit 1; }

echo "PASS — running as uid $UID_OUT"
exit 0
