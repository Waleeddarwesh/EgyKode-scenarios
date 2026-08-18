One proxy, two backends, and the three questions that come up the moment
something is in front of your application.

**What you will do**

1. **Balance across two backends** — and prove both are being used
2. **Stop one** — and keep serving the client without an error
3. **Produce a 502 and a 504** — deliberately, and know which is which

The difference between those two codes tells you *where* to look, which is why
producing them on purpose is worth more than reading about them.

```
cd /root/proxy && docker compose version
```{{exec}}
