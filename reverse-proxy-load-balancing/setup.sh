#!/bin/bash
set -e
command -v docker >/dev/null 2>&1 || { echo "Docker is not available here. Please report it." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "The Docker daemon is not responding. Please report it." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is not available. Please report it." >&2; exit 1; }

mkdir -p /root/proxy
# Pulled up front so a step does not appear to hang on a first-time pull.
docker pull -q hashicorp/http-echo:1.0 >/dev/null 2>&1 || true
docker pull -q nginx:1.27-alpine >/dev/null 2>&1 || true
echo "Ready. Work in /root/proxy."
