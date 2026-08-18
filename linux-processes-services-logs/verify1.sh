#!/bin/bash
# Checks the machine's actual network state. Whether the learner found it with
# ss, lsof or fuser is not the lesson.
fail() { echo "$1"; exit 1; }

ss -ltn 2>/dev/null | grep -q ':8080' \
  || fail "Nothing is listening on 8080 yet. Start the server from the step, then check with: ss -ltnp | grep ':8080'"

# A listening socket with no identifiable owner would make the exercise
# pointless — the whole skill is going from port to process.
owner=$(ss -ltnp 2>/dev/null | awk '/:8080/ {print $0}' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
[ -n "$owner" ] || fail "Port 8080 is held but no PID is visible. Run ss with -p as root: ss -ltnp"
kill -0 "$owner" 2>/dev/null || fail "The PID holding 8080 is not alive any more. Start it again."

echo "PASS"
