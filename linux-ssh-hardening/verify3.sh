#!/bin/bash
command -v ufw >/dev/null 2>&1 || { echo "FAIL: ufw is not installed"; exit 1; }

# The default policy lives in this file whether or not the firewall is running,
# which is why it can be checked without enabling anything.
grep -q 'DEFAULT_INPUT_POLICY="DROP"' /etc/default/ufw 2>/dev/null || {
  echo "FAIL: incoming traffic does not default to deny"
  echo "      ufw default deny incoming"
  exit 1; }
grep -q 'DEFAULT_OUTPUT_POLICY="ACCEPT"' /etc/default/ufw 2>/dev/null || {
  echo "FAIL: outgoing traffic does not default to allow"
  echo "      ufw default allow outgoing"
  exit 1; }

# An allow rule for SSH has to exist alongside that deny, or enabling the
# firewall would be the last command this machine ever accepted.
ADDED=$(ufw show added 2>/dev/null)
echo "$ADDED" | grep -qE "allow (22|OpenSSH|ssh)" || {
  echo "FAIL: no rule allows SSH. Rules currently staged:"
  echo "$ADDED"
  echo "      ufw allow 22/tcp"
  exit 1; }

# Nothing else should have been opened along the way. This is the "and nothing
# you did not intend" half, which is easy to lose while getting SSH working.
EXTRA=$(echo "$ADDED" | grep -E "^ufw allow" | grep -vE "allow (22|OpenSSH|ssh)" | grep -c .)
[ "$EXTRA" -eq 0 ] || {
  echo "FAIL: $EXTRA rule(s) allow something other than SSH:"
  echo "$ADDED" | grep -E "^ufw allow" | grep -vE "allow (22|OpenSSH|ssh)"
  exit 1; }

# Key login must still work. A firewall exercise that quietly broke SSH would
# otherwise pass every check above.
OUT=$(ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 deploy@localhost whoami 2>&1)
[ "$OUT" = "deploy" ] || { echo "FAIL: key login as deploy is broken: $OUT"; exit 1; }

echo "PASS - deny by default, SSH allowed, nothing else opened"
exit 0
