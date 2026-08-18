#!/bin/bash
sshd -t 2>/dev/null || { echo "FAIL: sshd -t rejects the configuration - fix it before reloading"; exit 1; }

# sshd -T is the configuration as the daemon resolved it, drop-ins and defaults
# included. Reading the drop-in file instead would pass on a config that was
# written but never reloaded, or that a later file overrides.
EFF=$(sshd -T 2>/dev/null)

echo "$EFF" | grep -qi '^permitrootlogin no' || {
  echo "FAIL: root login is still permitted ($(echo "$EFF" | grep -i '^permitrootlogin'))"; exit 1; }
echo "$EFF" | grep -qi '^passwordauthentication no' || {
  echo "FAIL: password authentication is still enabled ($(echo "$EFF" | grep -i '^passwordauthentication'))"; exit 1; }

# The running daemon, not the file. A config that was edited but never reloaded
# passes every check above and protects nothing.
DENY=$(ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
          -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
          deploy@localhost whoami 2>&1)
echo "$DENY" | grep -qi "permission denied" || {
  echo "FAIL: a password-only login attempt was not refused: $DENY"; exit 1; }
# The server enumerates the methods it accepts in that message. If password is
# still in the list, the daemon has not picked up the new configuration.
echo "$DENY" | grep -qiE "password|keyboard-interactive" && {
  echo "FAIL: the daemon still offers password authentication: $DENY"
  echo "      Did you reload it?  systemctl reload ssh"
  exit 1; }

# The door that has to stay open. Everything above is worthless if this fails,
# and on a real host this is the check that decides whether you are locked out.
OUT=$(ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 deploy@localhost whoami 2>&1)
[ "$OUT" = "deploy" ] || {
  echo "FAIL: key login as deploy no longer works - this is the lockout the ordering exists to prevent"
  echo "      ssh said: $OUT"
  exit 1; }

echo "PASS - password and root login refused, key login as deploy still works"
exit 0
