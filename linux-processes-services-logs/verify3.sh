#!/bin/bash
# The service must be genuinely running with a valid config. Checking only
# is-active would pass on a service that was never broken in the first place,
# so the config is tested too.
fail() { echo "$1"; exit 1; }

systemctl is-active --quiet nginx \
  || fail "nginx is not running. Fix the configuration error, then: systemctl restart nginx"

nginx -t >/dev/null 2>&1 \
  || fail "nginx is running on an old process but its configuration is still invalid. Run 'nginx -t' to see the file and line."

# Evidence that the break-and-fix cycle actually happened.
#
# Without this the check passed before the learner did anything at all:
# setup leaves nginx running with a valid config, so is-active and nginx -t
# were both satisfied by the starting state. A criterion met by setup is not
# a criterion.
if ! journalctl -u nginx --no-pager 2>/dev/null | grep -qiE "failed|invalid|unknown directive|test failed"; then
  fail "nginx is healthy, but its journal shows it never failed. Break it as the step describes, diagnose it, then fix it."
fi

grep -q '^user ' /etc/nginx/nginx.conf \
  || fail "The 'user' directive in /etc/nginx/nginx.conf is still wrong. Correct it, then restart."

echo "PASS"
