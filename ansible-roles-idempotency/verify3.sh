#!/bin/bash
D=/root/ansible
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

# Converge first, so this measures whether the playbook is idempotent rather
# than whether the learner happened to run it twice.
ansible-playbook -i inventory site.yml >/tmp/v3-first.log 2>&1 || {
  echo "FAIL: the playbook does not run cleanly:"; tail -6 /tmp/v3-first.log; exit 1; }

PID_BEFORE=$(systemctl show nginx -p MainPID --value)

ansible-playbook -i inventory site.yml >/tmp/v3.log 2>&1 || {
  echo "FAIL: the second run failed:"; tail -6 /tmp/v3.log; exit 1; }

CHANGED=$(grep -oE "changed=[0-9]+" /tmp/v3.log | head -1 | cut -d= -f2)
[ "${CHANGED:-1}" -eq 0 ] || {
  echo "FAIL: the second run reports changed=$CHANGED, expected 0"
  echo "      Which task changed:"
  grep -B1 "^changed:" /tmp/v3.log | grep "TASK" | head -3
  echo "      Find it with: ansible-playbook -i inventory site.yml --check --diff"
  exit 1; }

# A converged run must not restart anything. A handler that fires on every run
# is the outage this whole scenario exists to prevent.
grep -q "RUNNING HANDLER" /tmp/v3.log && {
  echo "FAIL: a handler ran on a converged run - something reports changed every time"; exit 1; }

PID_AFTER=$(systemctl show nginx -p MainPID --value)
[ "$PID_BEFORE" = "$PID_AFTER" ] || {
  echo "FAIL: nginx was restarted by a run that changed nothing ($PID_BEFORE -> $PID_AFTER)"; exit 1; }

# The service still has to be up and serving - a playbook that converges on a
# broken system is idempotent and useless.
systemctl is-active --quiet nginx || { echo "FAIL: nginx is not running"; exit 1; }
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null)
[ "$CODE" = "200" ] || { echo "FAIL: http://localhost/ returned $CODE, expected 200"; exit 1; }

echo "PASS - second run changed=0, no handler fired, nginx untouched and serving"
exit 0
