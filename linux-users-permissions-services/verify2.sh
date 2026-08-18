#!/bin/bash
# Inspects the filesystem. It creates nothing and changes nothing: a check that
# modifies the thing it checks can pass on its own side effects.
fail() { echo "$1"; exit 1; }

[ -d /opt/app ] || fail "/opt/app is missing."

group=$(stat -c %G /opt/app)
[ "$group" = "deployers" ] || fail "/opt/app's group is '$group', not 'deployers'. Run chown -R root:deployers /opt/app"

perms=$(stat -c %a /opt/app)
case "$perms" in
  2775|2*7*) ;;
  *) fail "/opt/app is mode $perms. It needs the setgid bit and group write — try chmod 2775." ;;
esac

# The setgid bit is the point of the step, so it is checked explicitly rather
# than inferred from the numeric mode.
ls -ld /opt/app | cut -c1-10 | grep -q 's' \
  || fail "The setgid bit is not set on /opt/app. Run: sudo chmod g+s /opt/app"

# Inheritance is what setgid is for, so a file created *by deploy* must prove
# it. Matching on group alone passed on setup's own VERSION file, which the
# chown -R had already put in the group — the check was satisfied by the
# starting state rather than by anything the learner did.
inherited=$(find /opt/app -mindepth 1 -maxdepth 1 -type f -user deploy -group deployers -print -quit 2>/dev/null)
[ -n "$inherited" ] || fail "No file created by 'deploy' has inherited the 'deployers' group yet. Run: sudo -u deploy touch /opt/app/test.txt"

echo "PASS"
