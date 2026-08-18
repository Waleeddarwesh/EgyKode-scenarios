#!/bin/bash
# Cross-checked against the kernel's live answer, so the file has to be real.
fail() { echo "$1"; exit 1; }
F=/root/findings/route.txt

[ -s "$F" ] || fail "No /root/findings/route.txt yet. Run: ip route get 1.1.1.1 | tee /root/findings/route.txt"

dev=$(grep -o 'dev [^ ]*' "$F" | head -1 | awk '{print $2}')
[ -n "$dev" ] || fail "$F names no interface. The output of 'ip route get' contains 'dev <interface>'."

# The interface must exist on this machine.
ip link show "$dev" >/dev/null 2>&1 \
  || fail "$F names interface '$dev', which does not exist here. Capture the real output of: ip route get 1.1.1.1"

# And it must be the interface the kernel would actually choose right now.
live=$(ip route get 1.1.1.1 2>/dev/null | grep -o 'dev [^ ]*' | head -1 | awk '{print $2}')
[ "$dev" = "$live" ] \
  || fail "$F says '$dev' but the kernel currently routes 1.1.1.1 via '$live'. Re-run the command and capture its output."

grep -q 'src ' "$F" \
  || fail "$F has no 'src' address. Capture the whole line — the source address is part of the routing decision."

echo "PASS"
