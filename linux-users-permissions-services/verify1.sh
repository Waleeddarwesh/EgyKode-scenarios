#!/bin/bash
# State, not history. Whether the learner typed useradd or edited /etc/passwd
# by hand is not the lesson; the account existing in the right group is.
fail() { echo "$1"; exit 1; }

id deploy >/dev/null 2>&1 || fail "No user called 'deploy' yet. Create it with useradd."

getent group deployers >/dev/null 2>&1 || fail "No group called 'deployers'. Create it with groupadd first."

primary=$(id -gn deploy 2>/dev/null)
[ "$primary" = "deployers" ] || fail "deploy's primary group is '$primary', not 'deployers'. Use --gid deployers."

# A locked password shows as ! or * in the shadow field.
pw=$(getent shadow deploy | cut -d: -f2)
case "$pw" in
  "!"*|"*"*) ;;
  *) fail "deploy's password is not locked. Run: sudo passwd -l deploy" ;;
esac

echo "PASS"
