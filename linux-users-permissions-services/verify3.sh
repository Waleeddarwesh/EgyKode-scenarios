#!/bin/bash
# Two separate questions, because they fail independently and a learner who
# conflates them is exactly who this step is for.
fail() { echo "$1"; exit 1; }

command -v nginx >/dev/null 2>&1 || fail "nginx is not installed yet. Run: sudo apt-get install -y nginx"

systemctl is-active --quiet nginx \
  || fail "nginx is installed but not running. Run: sudo systemctl start nginx"

# The criterion the lab actually makes: it comes back after a reboot. That is
# what `is-enabled` answers, without needing to reboot anything.
state=$(systemctl is-enabled nginx 2>/dev/null)
[ "$state" = "enabled" ] \
  || fail "nginx is running but 'systemctl is-enabled nginx' says '$state'. It will not come back after a reboot. Run: sudo systemctl enable nginx"

echo "PASS"
