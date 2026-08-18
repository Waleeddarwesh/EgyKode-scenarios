#!/bin/bash
# Compared against the certificate the server is serving right now, so a
# hand-written file does not pass.
fail() { echo "$1"; exit 1; }
F=/root/findings/cert.txt

[ -s "$F" ] || fail "No /root/findings/cert.txt yet. Capture the subject, issuer and dates from port 8443."

for field in subject issuer notAfter; do
  grep -qi "$field" "$F" || fail "$F has no '$field'. Use: openssl x509 -noout -subject -issuer -dates"
done

live=$(echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
       | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
[ -n "$live" ] || fail "Port 8443 is not serving a certificate right now. Report it."

grep -qF "$live" "$F" \
  || fail "The notAfter in $F does not match what 8443 is currently serving. Re-run the command and capture its real output."

echo "PASS"
