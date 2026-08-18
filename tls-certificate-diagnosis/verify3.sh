#!/bin/bash
# Two distinct diagnoses, not one error twice. A capture that names only
# "certificate problem" has not separated them.
fail() { echo "$1"; exit 1; }
F=/root/findings/diagnosis.txt

[ -s "$F" ] || fail "No /root/findings/diagnosis.txt yet. Capture both failures and the evidence for each."

grep -qi 'expired' "$F" \
  || fail "$F does not identify the expired certificate. Look at port 8444 and its notAfter date."

grep -qiE 'subject name|does not match|not-localhost' "$F" \
  || fail "$F does not identify the wrong-host certificate. Look at port 8445 and the subject it presents."

# The expiry evidence must actually be in the past — the date is what proves it.
if grep -qi 'notAfter' "$F"; then
  when=$(grep -i 'notAfter' "$F" | head -1 | cut -d= -f2-)
  if [ -n "$when" ]; then
    end=$(date -d "$when" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    [ "$end" -ne 0 ] && [ "$end" -lt "$now" ] \
      || fail "The notAfter in $F is not in the past. Capture the dates from the expired certificate on 8444."
  fi
else
  fail "$F has no notAfter date. Include: openssl x509 -in /root/certs/expired.crt -noout -dates"
fi

echo "PASS"
