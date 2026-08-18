# Two broken certificates

Both endpoints fail. They fail for different reasons, and the error text is
where the difference lives.

```
curl -sS --max-time 5 https://localhost:8444/ 2>&1 | head -2
curl -sS --max-time 5 https://localhost:8445/ 2>&1 | head -2
```{{exec}}

One has **expired**. The other presents a certificate for **a different name**
than the one you asked for. Neither is a network problem, and neither is fixed
by retrying.

Confirm the diagnosis by skipping verification. If `-k` works, the transport is
fine and the certificate is the only thing wrong:

```
curl -sk --max-time 5 -o /dev/null -w 'insecure fetch: %{http_code}\n' https://localhost:8444/
```{{exec}}

Record both, with the dates that prove the first one:

```
{ echo "8444:"; curl -sS --max-time 5 https://localhost:8444/ 2>&1 | head -1;
  openssl x509 -in /root/certs/expired.crt -noout -dates;
  echo "8445:"; curl -sS --max-time 5 https://localhost:8445/ 2>&1 | head -1;
  openssl x509 -in /root/certs/wronghost.crt -noout -subject; } \
  | tee /root/findings/diagnosis.txt
```{{exec}}

**You should see** an expiry date in the past for one, and a subject that is
not `localhost` for the other.
