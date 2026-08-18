#!/bin/bash
# Compares the captured answer against a live lookup, so a hand-typed file does
# not pass. The check reads; it resolves nothing into the file itself.
fail() { echo "$1"; exit 1; }
F=/root/findings/dns.txt

[ -s "$F" ] || fail "No /root/findings/dns.txt yet. Run: dig +noall +answer example.com | tee /root/findings/dns.txt"

grep -qE '[[:space:]]A[[:space:]]' "$F" \
  || fail "$F has no A record in it. Capture the answer section: dig +noall +answer example.com"

captured=$(grep -E '[[:space:]]A[[:space:]]' "$F" | awk '{print $NF}' | head -1)
echo "$captured" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' \
  || fail "No IPv4 address found in $F. The last field of the A record should be an address."

# The TTL is the field the step is actually about.
ttl=$(grep -E '[[:space:]]A[[:space:]]' "$F" | awk '{print $2}' | head -1)
echo "$ttl" | grep -qE '^[0-9]+$' \
  || fail "No TTL in $F. Use 'dig +noall +answer', which keeps the TTL column."

# And it must be a real answer for that name, not something typed in.
live=$(dig +short A example.com 2>/dev/null | grep -E '^[0-9]+\.' | head -5)
[ -n "$live" ] || fail "This environment cannot resolve example.com right now, so the capture cannot be checked. Report it."
echo "$live" | grep -qx "$captured" \
  || fail "The address in $F ($captured) is not one example.com currently resolves to. Re-run the dig and capture its real output."

echo "PASS"
