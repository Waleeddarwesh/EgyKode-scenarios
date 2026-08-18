# Done

- **Round robin is the default** — two servers in an upstream is the whole
  configuration
- **`max_fails` / `fail_timeout`** — a passive health check paid for by real
  traffic rather than a separate probe
- **The four headers** — without them the application sees the proxy, not the
  client, and every log and redirect is wrong
- **502 is absence, 504 is slowness** — one sends you to the backend, the other
  sends you to what the backend is waiting on

That last distinction is the one worth carrying to an incident. A 502 means
look behind the proxy. A 504 means the thing behind it is alive and stuck,
which is a completely different investigation.

The [EgyKode lab](https://egykode.com/en/labs/lab-reverse-proxy-load-balancing/)
covers active health checks and why `X-Forwarded-For` appends rather than
replaces.

---

## Where this fits

**Phase: The application, in containers** — part of [Build the Production Platform](https://egykode.com/en/labs/).

nginx sits in front of Gunicorn in the platform, exactly as it sits in front of the backends here. The forwarded headers and the 502/504 distinction carry straight through to the AWS load balancer and the Kubernetes Ingress later on.
