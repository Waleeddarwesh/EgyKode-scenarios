#!/bin/bash
echo "Installing Ansible..."
if ! command -v ansible-playbook >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ansible curl >/dev/null 2>&1
fi

# nginx is deliberately absent: installing it is the role's first job, and a
# package that is already there would hide the difference between the first run
# and the second.
DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq nginx nginx-common >/dev/null 2>&1
rm -rf /etc/nginx

mkdir -p /root/ansible
echo done
