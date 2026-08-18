#!/bin/bash
# Both failure modes must be present and distinguishable. curl's exit codes are
# the machine-readable version of the lesson: 7 is refused, 28 is timed out.
fail() { echo "$1"; exit 1; }
F=/root/findings/reachability.txt

[ -s "$F" ] || fail "No /root/findings/reachability.txt yet. Capture both failures as the step describes."

grep -qiE 'refus' "$F" \
  || fail "$F shows no connection refused. Try a closed port on this machine: curl --max-time 5 http://127.0.0.1:9"

grep -qiE 'timed out|timeout' "$F" \
  || fail "$F shows no timeout. Try an address that routes nowhere: curl --max-time 5 http://203.0.113.1/"

# The two must be different results, not the same error twice.
grep -qi 'refus' "$F" && grep -qiE 'timed out|timeout' "$F" \
  || fail "$F needs both outcomes, so the difference between them is on record."

# Confirm the environment still behaves that way, so the file reflects reality.
curl -sS --max-time 5 http://127.0.0.1:9 >/dev/null 2>&1
[ $? -eq 7 ] || fail "A closed local port no longer refuses here, so the capture cannot be checked. Report it."

echo "PASS"
