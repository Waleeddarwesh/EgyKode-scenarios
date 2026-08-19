#!/bin/bash
# Criterion 2: the second run reports changed=0.
#
# Checked by running it, not by reading the learner's terminal. And run TWICE,
# because one quiet run immediately after a change can happen by accident - a
# package that was already current, a service that happened to be up. Two
# consecutive quiet runs cannot.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
export VAULT_TOKEN=${VAULT_TOKEN:-egykode-root}
A=/root/ansible
cd "$A" 2>/dev/null || { echo "FAIL: no $A"; exit 1; }
[ -f site.yml ] || { echo "FAIL: no site.yml - finish step 1 first"; exit 1; }

for RUN in 1 2; do
  OUT=$(ansible-playbook site.yml 2>&1)
  RC=$?
  if [ "$RC" -ne 0 ]; then
    echo "FAIL: run $RUN of site.yml exited $RC"
    echo "$OUT" | grep -E "fatal:|failed=" | head -3
    exit 1
  fi

  CHANGED=$(echo "$OUT" | sed -n 's/.*changed=\([0-9]*\).*/\1/p' | head -1)
  case "$CHANGED" in ''|*[!0-9]*) CHANGED=-1 ;; esac
  if [ "$CHANGED" -ne 0 ]; then
    echo "FAIL: run $RUN reported changed=$CHANGED, expected 0"
    echo ""
    echo "$OUT" | grep -B1 "^changed:" | head -6
    echo ""
    echo "      A task that reports a change on an unchanged host is usually"
    echo "      command or shell, which cannot know whether it changed"
    echo "      anything and so assumes it did. Add changed_when: false to the"
    echo "      ones that only read, or creates:/removes: to the ones that"
    echo "      produce a file."
    exit 1
  fi

  # A handler firing on a converged run is the real outage: a service
  # restarting on every scheduled run, which reads as "idempotent enough"
  # until it happens during traffic.
  if echo "$OUT" | grep -q "RUNNING HANDLER"; then
    echo "FAIL: run $RUN fired a handler on an already-converged host"
    echo "      Something notified it that had not really changed. On a"
    echo "      schedule this restarts the service every time it runs."
    exit 1
  fi
done

# And it must still be serving afterwards: a playbook can reach changed=0 by
# doing nothing at all, including to a host that is broken.
ACTIVE=$(systemctl is-active jenkins 2>/dev/null)
[ "$ACTIVE" = "active" ] || {
  echo "FAIL: two clean runs, but jenkins is $ACTIVE"
  echo "      changed=0 on a broken host is not idempotence, it is absence."
  exit 1; }

echo "PASS - two consecutive runs reported changed=0, no handlers fired, Jenkins still active"
exit 0
