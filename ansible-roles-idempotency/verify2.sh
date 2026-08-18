#!/bin/bash
D=/root/ansible
R=$D/roles/webserver
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

[ -f "$R/handlers/main.yml" ] || { echo "FAIL: no handlers/main.yml"; exit 1; }
[ -f site.yml ] || { echo "FAIL: no site.yml"; exit 1; }
[ -f inventory ] || { echo "FAIL: no inventory"; exit 1; }

# The notify string and the handler name have to match exactly, or the
# notification matches nothing and the service is never restarted - with no
# error anywhere.
HANDLER=$(grep -A1 "^- name:" "$R/handlers/main.yml" | grep "^- name:" | head -1 | sed 's/^- name: *//')
[ -n "$HANDLER" ] || { echo "FAIL: no named handler in handlers/main.yml"; exit 1; }
grep -q "notify: *$HANDLER" "$R/tasks/main.yml" || {
  echo "FAIL: no task notifies '$HANDLER' - check the notify string matches the handler name exactly"
  exit 1; }

systemctl is-active --quiet nginx || { echo "FAIL: nginx is not running"; exit 1; }
[ -f /etc/nginx/nginx.conf ] || { echo "FAIL: /etc/nginx/nginx.conf does not exist"; exit 1; }
grep -q "Managed by Ansible" /etc/nginx/nginx.conf || {
  echo "FAIL: the running nginx.conf was not rendered from the role's template"; exit 1; }

# The criterion: a config change triggers exactly one restart. Force a change
# through an extra-var, count the handler invocations, and confirm the process
# was actually replaced.
PID_BEFORE=$(systemctl show nginx -p MainPID --value)
ansible-playbook -i inventory site.yml -e webserver_worker_connections=999 >/tmp/v2.log 2>&1 || {
  echo "FAIL: the playbook does not run cleanly:"; tail -6 /tmp/v2.log; exit 1; }

HANDLERS=$(grep -c "RUNNING HANDLER" /tmp/v2.log)
[ "$HANDLERS" -eq 1 ] || {
  echo "FAIL: $HANDLERS handler block(s) ran on a config change, expected exactly 1"
  echo "      Restarting inline in a task bounces the service once per task."
  exit 1; }

PID_AFTER=$(systemctl show nginx -p MainPID --value)
[ "$PID_BEFORE" != "$PID_AFTER" ] || {
  echo "FAIL: the config changed but nginx was never restarted (pid stayed $PID_BEFORE)"
  echo "      The notify string probably does not match the handler name."
  exit 1; }

grep -q "999" /etc/nginx/nginx.conf || {
  echo "FAIL: the new value did not reach /etc/nginx/nginx.conf"; exit 1; }

# Put it back so the next step starts from the role's own defaults.
ansible-playbook -i inventory site.yml >/dev/null 2>&1

echo "PASS - one handler, one restart, and the rendered value reached the running server"
exit 0
