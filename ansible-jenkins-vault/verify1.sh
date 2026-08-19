#!/bin/bash
# Criterion 1: one playbook takes a bare instance to a working Jenkins with
# its toolchain.
#
# "Working" is the operative word, so this asks the host rather than the
# playbook. A run that ends failed=0 proves the tasks executed; it does not
# prove the service survived the thirty seconds after they did.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
A=/root/ansible

[ -f "$A/site.yml" ] || { echo "FAIL: no $A/site.yml"; exit 1; }

# Composed of roles, which is what makes this a playbook rather than a script.
grep -q 'roles:' "$A/site.yml" || {
  echo "FAIL: site.yml declares no roles"
  echo "      The point of the composition is that 'install Jenkins' is four"
  echo "      separable concerns, each reusable on its own."
  exit 1; }
for R in common java jenkins; do
  [ -f "$A/roles/$R/tasks/main.yml" ] || { echo "FAIL: no tasks for role $R"; exit 1; }
done

# Enabled AND active. Enabled alone only means "next boot", and it is the
# single most common way a host passes provisioning and fails a reboot.
systemctl is-enabled jenkins >/dev/null 2>&1 || {
  echo "FAIL: the jenkins service is not enabled at boot"; exit 1; }
ACTIVE=$(systemctl is-active jenkins 2>/dev/null)
if [ "$ACTIVE" != "active" ]; then
  echo "FAIL: the jenkins service is $ACTIVE, not active"
  echo "      journalctl -u jenkins -n 30 will say why. If it mentions Java,"
  echo "      note that Jenkins now requires 21 or 25 and refuses 17."
  exit 1
fi

# Serving, not merely running. Jenkins can be active for a minute before the
# HTTP listener is up, so this waits rather than judging the first attempt.
for i in $(seq 1 40); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8080/login)
  case "$CODE" in 200|403) break ;; esac
  sleep 5
done
case "$CODE" in
  200|403) ;;
  *) echo "FAIL: Jenkins is not answering on :8080 (got ${CODE:-nothing})"
     echo "      The unit is active but nothing is serving - check the journal."
     exit 1 ;;
esac

command -v java >/dev/null 2>&1 || { echo "FAIL: no java on PATH"; exit 1; }
JV=$(java -version 2>&1 | head -1)
case "$JV" in
  *\"21*|*\"25*) ;;
  *) echo "FAIL: $JV"
     echo "      Jenkins supports Java 21 and 25 only. It will not start on 17,"
     echo "      and the failure appears as a dead service rather than a"
     echo "      package error."
     exit 1 ;;
esac
command -v git >/dev/null 2>&1 || { echo "FAIL: no git on PATH - the common role did not run"; exit 1; }

echo "PASS - one playbook produced an active Jenkins answering on :8080, on $JV"
exit 0
