#!/bin/bash
# Assert the environment before the learner discovers it three steps in.
set -e

command -v docker >/dev/null 2>&1 || { echo "Docker is not available here. Please report it." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "The Docker daemon is not responding. Please report it." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is not available. Please report it." >&2; exit 1; }

mkdir -p /root/stack
cd /root/stack

# Pulled up front: an image pull in the middle of a step reads as the step
# hanging, and a learner cannot tell that from a broken exercise.
docker pull -q postgres:16-alpine >/dev/null 2>&1 || true
docker pull -q alpine:3.20 >/dev/null 2>&1 || true

echo "Ready. Work in /root/stack. Docker and Compose are available."
