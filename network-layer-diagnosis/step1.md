# Does the name resolve

Before blaming anything above it, settle whether the name resolves at all.

```
dig +noall +answer example.com
```{{exec}}

The number before the record type is the **TTL** — how many more seconds
resolvers may keep serving this answer. It matters during a cutover: everyone
holding the old answer keeps it until that expires.

Capture the address and the TTL:

```
dig +noall +answer example.com | tee /root/findings/dns.txt
```{{exec}}

**You should see** an `A` record with an IP and a TTL. If you get nothing at
all, the failure is DNS and nothing above it is worth looking at yet.
