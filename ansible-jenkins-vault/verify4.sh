#!/bin/bash
# Criterion 3: a verify playbook asserts each service and binary, and fails
# loudly when one is missing.
#
# Both halves are executed. Passing on a healthy host is easy and proves
# nothing on its own - a play with no assertions in it passes too. So this
# breaks the host on purpose, requires the play to notice, and puts it back.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
export VAULT_TOKEN=${VAULT_TOKEN:-egykode-root}
A=/root/ansible
cd "$A" 2>/dev/null || { echo "FAIL: no $A"; exit 1; }
[ -f verify.yml ] || { echo "FAIL: no $A/verify.yml"; exit 1; }

# It must actually assert. A play of bare commands reports success whatever it
# finds, because a task result nobody tests is not a check.
grep -qE 'failed_when|ansible\.builtin\.assert' verify.yml || {
  echo "FAIL: verify.yml contains no failed_when or assert"
  echo "      Without one, 'command -v git' returning 1 is just a task result."
  exit 1; }

# Half one: it passes on the host as it stands.
OUT=$(ansible-playbook verify.yml 2>&1); RC=$?
if [ "$RC" -ne 0 ]; then
  echo "FAIL: verify.yml does not pass against the working host"
  echo "$OUT" | grep -E "fatal:|failed:" | head -3
  exit 1
fi

# Half two: break something it claims to check, and require it to notice.
#
# git is chosen because it is easy to restore exactly. The trap makes sure it
# comes back even if this script is interrupted - leaving a learner's host
# without git would be a worse bug than the one being tested for.
HID=0
restore() { [ "$HID" = "1" ] && [ -f /usr/bin/git.egykode-hidden ] && mv /usr/bin/git.egykode-hidden /usr/bin/git; }
trap restore EXIT INT TERM

if [ -f /usr/bin/git ]; then
  mv /usr/bin/git /usr/bin/git.egykode-hidden && HID=1
else
  echo "FAIL: git is not at /usr/bin/git, so this check cannot be tested"
  exit 1
fi

BROKEN=$(ansible-playbook verify.yml 2>&1); BRC=$?
restore; HID=0

if [ "$BRC" -eq 0 ]; then
  echo "FAIL: verify.yml still passed with git removed from the host"
  echo ""
  echo "      It is not asserting what it appears to assert. A check that"
  echo "      cannot fail is worse than no check, because it is trusted."
  echo "      Make sure the binaries task uses failed_when on its result -"
  echo "      and note that 'command -v' is a shell builtin, so it needs"
  echo "      ansible.builtin.shell rather than ansible.builtin.command."
  exit 1
fi

# And it must name what was wrong, not merely exit non-zero.
echo "$BROKEN" | grep -q "git" || {
  echo "FAIL: verify.yml failed, but its output never mentions git"
  echo "      Failing loudly means the operator can see which assertion broke."
  exit 1; }

echo "PASS - verify.yml passes on a healthy host and fails, naming git, when it is removed"
exit 0
