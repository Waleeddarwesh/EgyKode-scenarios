#!/bin/bash
D=/root/ansible
R=$D/roles/webserver
cd "$D" 2>/dev/null || { echo "FAIL: no $D"; exit 1; }

# Both guards must be in place, and the archive task must still be there -
# deleting it converges the playbook without teaching anything.
grep -q "app.tar.gz" "$R/tasks/main.yml" || {
  echo "FAIL: the archive task is gone - fix it rather than remove it"; exit 1; }

grep -qE "ansible\.builtin\.(shell|command): *tar" "$R/tasks/main.yml" && {
  echo "FAIL: the archive is still unpacked with shell, which always reports changed"
  echo "      Use unarchive, or add creates: to tell Ansible when the work is done."
  exit 1; }
grep -qE "creates:|ansible\.builtin\.unarchive" "$R/tasks/main.yml" || {
  echo "FAIL: the archive task has neither a real module nor a creates: guard"; exit 1; }

grep -q "ansible_date_time" "$R/templates/nginx.conf.j2" && {
  echo "FAIL: the template still renders a timestamp, so its checksum differs every run"
  exit 1; }

# The measurement that settles it. Converge, then run twice and require both
# runs to be quiet - one quiet run can happen by chance after a change.
ansible-playbook -i inventory site.yml >/dev/null 2>&1
for N in 1 2; do
  ansible-playbook -i inventory site.yml >/tmp/v4-$N.log 2>&1 || {
    echo "FAIL: run $N failed:"; tail -6 /tmp/v4-$N.log; exit 1; }
  C=$(grep -oE "changed=[0-9]+" /tmp/v4-$N.log | head -1 | cut -d= -f2)
  [ "${C:-1}" -eq 0 ] || {
    echo "FAIL: run $N reports changed=$C, expected 0"
    grep -B1 "^changed:" /tmp/v4-$N.log | grep "TASK" | head -3
    exit 1; }
  grep -q "RUNNING HANDLER" /tmp/v4-$N.log && {
    echo "FAIL: a handler fired on converged run $N - the service restarts every time"; exit 1; }
done

systemctl is-active --quiet nginx || { echo "FAIL: nginx is not running"; exit 1; }

echo "PASS - the archive task is guarded, the template is stable, and two consecutive runs change nothing"
exit 0
