# Done

You worked upwards, and stopped at each layer until it was proven:

1. **Name** — does it resolve, and for how long is that answer valid
2. **Route** — which interface and gateway, decided by the kernel not by you
3. **Reachability** — refused means something replied; timed out means nothing did

The one worth carrying: **how long the failure takes is part of the
diagnosis.** Instant means a host answered and declined. Five seconds of
silence means a packet went somewhere and died, and the cause is a firewall or
a route, never the application.

The [EgyKode lab](https://egykode.com/en/labs/lab-21-linux-networking-troubleshooting/)
adds the case where a service is bound to the wrong address — listening
perfectly, on an interface nobody can reach.

---

## Where this fits

**Phase: Foundations** — part of [Build the Production Platform](https://egykode.com/en/labs/).

When the platform's ingress stops answering, this is the order you work in. Name, route, reachability — before touching a security group or restarting a Pod.
