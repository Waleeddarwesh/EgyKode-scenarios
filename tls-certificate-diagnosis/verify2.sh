#!/bin/bash
# Both halves must be present: a capture showing only the failure proves
# nothing, because it cannot distinguish an unreachable port from a bad
# certificate — which is the entire point of the step.
fail() { echo "$1"; exit 1; }
F=/root/findings/layers.txt

[ -s "$F" ] || fail "No /root/findings/layers.txt yet. Capture the TCP result and the TLS result together."

grep -qiE 'succe|open|connected' "$F" \
  || fail "$F shows no successful TCP connection. Run: nc -vz localhost 8444"

grep -qiE 'certificate|ssl|tls' "$F" \
  || fail "$F shows no TLS error. Run curl against the same port and capture what it says."

# The environment must still behave that way, so the file reflects reality.
nc -z localhost 8444 2>/dev/null || fail "Port 8444 is not accepting connections now. Report it."
curl -sS --max-time 5 https://localhost:8444/ >/dev/null 2>&1 \
  && fail "Port 8444 now succeeds over TLS, so the contradiction the step relies on is gone. Report it."

echo "PASS"
