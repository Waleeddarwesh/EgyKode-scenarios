#!/bin/bash
# Assert what the scenario depends on, rather than discovering it three steps
# later as a confusing failure the learner will assume is theirs.
set -e

if ! command -v systemctl >/dev/null 2>&1; then
  echo "This scenario needs systemd, which is not present. Please report it." >&2
  exit 1
fi

# A directory somebody else already created, owned by root — which is the
# situation the lab starts from.
mkdir -p /opt/app
echo "release 1" > /opt/app/VERSION
chown -R root:root /opt/app
chmod 755 /opt/app

echo "Ready. A root-owned /opt/app is waiting."
