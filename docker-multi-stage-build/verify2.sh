#!/bin/bash
# Size is the whole point, so it is measured rather than assumed — and compared
# against the learner's own single-stage image rather than a number I guessed.
docker image inspect app:multi >/dev/null 2>&1 || {
  echo "FAIL: image app:multi does not exist"; exit 1; }

SINGLE=$(docker image inspect app:single --format '{{.Size}}' 2>/dev/null)
MULTI=$(docker image inspect app:multi --format '{{.Size}}' 2>/dev/null)

if [ -z "$SINGLE" ]; then
  echo "FAIL: app:single is missing — build it in step 1 so the two can be compared"; exit 1
fi

if [ "$MULTI" -ge "$SINGLE" ]; then
  echo "FAIL: app:multi ($((MULTI/1000000))MB) is not smaller than app:single ($((SINGLE/1000000))MB)"
  echo "      the build stage is probably still being shipped"
  exit 1
fi

docker run --rm app:multi python -c "import gunicorn" 2>/dev/null || {
  echo "FAIL: app:multi is smaller but gunicorn is not importable — the copy missed something"; exit 1; }

echo "PASS — $((SINGLE/1000000))MB down to $((MULTI/1000000))MB"
exit 0
