#!/bin/bash
# nginx installed and running, so there is a real service with a real journal
# to interrogate. Installed here rather than by the learner: the lesson is
# diagnosis, not apt.
set -e

if ! command -v systemctl >/dev/null 2>&1; then
  echo "This scenario needs systemd, which is not present. Please report it." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq nginx lsof >/dev/null 2>&1

systemctl enable --now nginx >/dev/null 2>&1
# Keep a pristine copy so the learner can always get back.
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig

echo "Ready. nginx is running and listening."
