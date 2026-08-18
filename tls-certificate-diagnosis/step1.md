# Read the certificate

A browser shows you a padlock. The command line shows you the certificate.

```
echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```{{exec}}

Four facts, and each answers a different question: **subject** is who it claims
to be, **issuer** is who vouched for it, and the two dates are when that
vouching starts and stops.

Capture them:

```
echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates | tee /root/findings/cert.txt
```{{exec}}

**You should see** `subject=CN = localhost`, an issuer of `EgyKode Lab CA`, and
a `notAfter` roughly a year out. For a monitoring check you would keep only
`-enddate`, which is the field that turns into an outage on a Sunday.
