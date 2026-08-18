#!/bin/bash
# The artefact proves the reader used the journal rather than guessed. It does
# not prove they understood it — that criterion stays on EgyKode as reasoning.
fail() { echo "$1"; exit 1; }

command -v journalctl >/dev/null 2>&1 || fail "journalctl is not available in this environment."

[ -f /root/nginx-last50.log ] \
  || fail "No /root/nginx-last50.log yet. Run: journalctl -u nginx -n 50 --no-pager > /root/nginx-last50.log"

[ -s /root/nginx-last50.log ] \
  || fail "/root/nginx-last50.log is empty. The journal had nothing for nginx — check the unit name."

# It must be the journal for that unit, not an unrelated file with the name.
grep -qiE 'nginx|systemd' /root/nginx-last50.log \
  || fail "/root/nginx-last50.log does not look like nginx's journal. Redirect the output of: journalctl -u nginx -n 50 --no-pager"

echo "PASS"
