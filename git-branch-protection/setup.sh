#!/bin/bash
# Runs as intro.background. Starts a real Git forge, because every criterion in
# this lab is a *server* behaviour.
#
# WHY A FORGE AND NOT A BARE REPOSITORY
#
# Three of the four criteria - a rejected push, a merge blocked by a failing
# check, a reviewer requested automatically - are things a Git server does.
# `git init --bare` plus a hook could fake the first and cannot do the other
# two at all, because there is no pull request for them to happen to.
#
# Gitea is a real forge that implements all four, so the rejections here are
# genuine: the server declines, exactly as GitHub would. The syntax of one file
# differs and step 3 says where.

set -u
mkdir -p /root/forge
exec > >(tee -a /root/forge/setup.log) 2>&1

echo "[1/5] starting Gitea"
docker rm -f gitea >/dev/null 2>&1
docker run -d --name gitea --restart=unless-stopped -p 3000:3000 \
  -e GITEA__database__DB_TYPE=sqlite3 \
  -e GITEA__security__INSTALL_LOCK=true \
  -e GITEA__server__ROOT_URL=http://localhost:3000/ \
  -e GITEA__server__DISABLE_SSH=true \
  -e GITEA__service__DISABLE_REGISTRATION=true \
  gitea/gitea:1.22 >/dev/null 2>&1

echo "[2/5] waiting for it to answer"
for i in $(seq 1 60); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:3000/ 2>/dev/null)
  [ "$CODE" = "200" ] && break
  sleep 3
done
echo "      gitea http: ${CODE:-none}"

echo "[3/5] two users"
# As the git user, not root: run as root the command appears to succeed and
# creates nothing, which is a silent failure worth avoiding here.
docker exec -u git gitea gitea admin user create \
  --username ci --password 'CiPassw0rd!' --email ci@egykode.local \
  --admin --must-change-password=false >/dev/null 2>&1
docker exec -u git gitea gitea admin user create \
  --username platform-lead --password 'LeadPassw0rd!' --email lead@egykode.local \
  --must-change-password=false >/dev/null 2>&1
docker exec -u git gitea gitea admin user list 2>/dev/null | awk 'NR>1 {print "      user: " $2}'

echo "[4/5] a repository, with the lead able to review it"
A="http://ci:CiPassw0rd!@localhost:3000"
curl -s -X POST "$A/api/v1/user/repos" -H "Content-Type: application/json" \
  -d '{"name":"platform","auto_init":true,"default_branch":"main"}' >/dev/null 2>&1
# CODEOWNERS can only request a reviewer who can actually review, so the lead
# needs write access. Without it the entry is silently ignored.
curl -s -X PUT "$A/api/v1/repos/ci/platform/collaborators/platform-lead" \
  -H "Content-Type: application/json" -d '{"permission":"write"}' >/dev/null 2>&1

echo "[5/5] a working copy"
command -v git >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git >/dev/null 2>&1
}
git config --global user.email ci@egykode.local
git config --global user.name "CI"
git config --global init.defaultBranch main
rm -rf /root/platform
git clone -q "$A/ci/platform.git" /root/platform 2>/dev/null
echo "      cloned to /root/platform"

echo done
