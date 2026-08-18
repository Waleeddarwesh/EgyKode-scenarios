#!/bin/bash
# The diagnostic tools, and a directory for the findings. Each step writes what
# it learned to a file, because diagnosis leaves no state behind otherwise —
# and a verification with nothing to inspect is not a verification.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq dnsutils iproute2 curl netcat-openbsd >/dev/null 2>&1
mkdir -p /root/findings
echo "Ready. Findings go in /root/findings."
