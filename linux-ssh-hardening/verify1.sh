#!/bin/bash
id deploy >/dev/null 2>&1 || { echo "FAIL: there is no deploy user"; exit 1; }

id -nG deploy | grep -qw sudo || {
  echo "FAIL: deploy is not in the sudo group - it can log in but cannot administer anything"; exit 1; }

[ -f /root/.ssh/egykode ] || {
  echo "FAIL: /root/.ssh/egykode does not exist - generate the key pair"; exit 1; }

# The permissions are the lesson, so check them directly rather than inferring
# them from a successful login.
DIRMODE=$(stat -c %a /home/deploy/.ssh 2>/dev/null)
KEYMODE=$(stat -c %a /home/deploy/.ssh/authorized_keys 2>/dev/null)
[ "$DIRMODE" = "700" ] || {
  echo "FAIL: /home/deploy/.ssh is mode ${DIRMODE:-missing}, must be 700"; exit 1; }
[ "$KEYMODE" = "600" ] || {
  echo "FAIL: authorized_keys is mode ${KEYMODE:-missing}, must be 600"; exit 1; }

# The only proof that matters: sshd actually accepts the key. BatchMode stops
# it falling back to a password prompt, which would otherwise hang here and
# could pass this check using an authentication method the lab is removing.
OUT=$(ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 deploy@localhost whoami 2>&1)
[ "$OUT" = "deploy" ] || {
  echo "FAIL: key login as deploy did not work"
  echo "      ssh said: $OUT"
  exit 1; }

SSH="ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 deploy@localhost"

# The granted command must work unattended.
GRANTED=$($SSH 'sudo -n systemctl status ssh >/dev/null && echo ok' 2>&1)
echo "$GRANTED" | grep -q ok || {
  echo "FAIL: deploy cannot run the command the sudoers rule grants: $GRANTED"
  echo "      Check /etc/sudoers.d/deploy and validate it with visudo -c"
  exit 1; }

# And nothing beyond it. A rule of NOPASSWD: ALL satisfies the check above just
# as well, while granting a root shell to anyone holding this key - so the
# refusal is the half worth testing.
DENIED=$($SSH 'sudo -n cat /etc/shadow' 2>&1)
echo "$DENIED" | grep -qi "password is required" || {
  echo "FAIL: deploy can run commands the rule was not supposed to grant"
  echo "      sudo -n cat /etc/shadow returned: $DENIED"
  echo "      The rule should name specific commands, not ALL."
  exit 1; }

echo "PASS - deploy exists, key login works, sudo is scoped to the granted commands"
exit 0
