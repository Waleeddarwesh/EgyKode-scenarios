# Done

Three failures, three different layers, and none of them fixed by retrying:

- **TCP connects, TLS does not** — the network is fine; stop looking at firewalls
- **Expired** — nothing is wrong with the configuration; the clock moved
- **Wrong subject name** — the certificate is valid, for somebody else

The habit worth keeping is `-k`. If skipping verification makes the request
work, you have proved the transport and the server are fine and the
certificate is the only thing at fault. It is a diagnostic, never a fix.

The [EgyKode lab](https://egykode.com/en/labs/lab-http-tls-troubleshooting/)
covers what `SSL_ERROR_SYSCALL` implies, how to read a full chain, and why
`time_appconnect` tells you whether the handshake is your latency.

---

## Where this fits

**Phase: Operating it** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform terminates TLS at its load balancer with a certificate from ACM. Reading a certificate from the command line and separating a transport failure from a certificate failure is how you diagnose that without a browser.
