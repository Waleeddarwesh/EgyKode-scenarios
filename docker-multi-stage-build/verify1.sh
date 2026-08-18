#!/bin/bash
# The image must exist and actually run. `docker images` alone would pass on a
# tag that points at a broken build.
docker image inspect app:single >/dev/null 2>&1 || {
  echo "FAIL: image app:single does not exist"; exit 1; }

docker run --rm app:single python -c "print('ok')" >/dev/null 2>&1 || {
  echo "FAIL: app:single exists but cannot run python"; exit 1; }

echo "PASS"
exit 0
