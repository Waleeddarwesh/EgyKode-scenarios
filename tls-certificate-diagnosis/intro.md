Three HTTPS endpoints are running on this machine. One works. Two are broken,
each for a different reason, and neither will tell you which unless you ask
properly.

| Port | |
| --- | --- |
| 8443 | works |
| 8444 | broken |
| 8445 | broken, differently |

**What you will do**

1. **Read a certificate** — subject, issuer and expiry, without a browser
2. **Separate the layers** — prove a port is reachable even when TLS fails
3. **Diagnose both failures** — and name the reason for each

Findings go in `/root/findings`, so you finish holding the evidence.

```
ss -ltn | grep -E '844[345]'
```{{exec}}
