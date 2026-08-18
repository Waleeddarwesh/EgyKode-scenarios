#!/bin/bash
# Three local HTTPS endpoints: one valid, one expired, one for the wrong host.
#
# Generated here rather than pointing at badssl.com or similar. A scenario that
# depends on somebody else's test site fails the day they reorganise it, and
# the learner is left debugging the exercise instead of a certificate.
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
# faketime is how the expired certificate is made: signing it as of two months
# ago is reliable, where negative -days and -not_after flags are not portable.
apt-get install -y -qq openssl curl iproute2 netcat-openbsd faketime >/dev/null 2>&1

CERTS=/root/certs
mkdir -p "$CERTS" /root/findings
cd "$CERTS"

# A private CA, so each broken endpoint is broken for exactly one reason
# rather than merely for being self-signed.
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 3650 \
  -subj "/CN=EgyKode Lab CA" >/dev/null 2>&1

csr() { openssl req -newkey rsa:2048 -nodes -keyout "$1.key" -out "$1.csr" -subj "/CN=$2" >/dev/null 2>&1; }
sign() { openssl x509 -req -in "$1.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -out "$1.crt" -days "$2" >/dev/null 2>&1; }

csr good localhost;                     sign good 365
csr wronghost not-localhost.example;    sign wronghost 365
csr expired localhost
# Signed as of 60 days ago with 30 days of life: expired a month back.
faketime '60 days ago' openssl x509 -req -in expired.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out expired.crt -days 30 >/dev/null 2>&1

# Trust the CA, so the good endpoint verifies cleanly and the other two fail
# for their own distinct reason.
cp ca.crt /usr/local/share/ca-certificates/egykode-lab-ca.crt
update-ca-certificates >/dev/null 2>&1

serve() { nohup openssl s_server -accept "$1" -cert "$2" -key "$3" -www >/dev/null 2>&1 & }
serve 8443 "$CERTS/good.crt"      "$CERTS/good.key"
serve 8444 "$CERTS/expired.crt"   "$CERTS/expired.key"
serve 8445 "$CERTS/wronghost.crt" "$CERTS/wronghost.key"
sleep 2

for p in 8443 8444 8445; do
  ss -ltn | grep -q ":$p" || { echo "Port $p did not come up. Please report it." >&2; exit 1; }
done
echo "Ready. HTTPS on 8443 (valid), 8444 (expired), 8445 (wrong host)."
