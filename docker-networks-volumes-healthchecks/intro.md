Three things that separate a stack that works on your machine from one that
works anywhere, and none of them are about the application.

**What you will do**

1. **Reach a service by name** — with no IP address written down anywhere
2. **Keep data across `down` and `up`** — and prove where it actually lives
3. **Wait for *ready*, not *started*** — the distinction that causes most
   "it works the second time" bugs

You will write the Compose file yourself in `/root/stack`.

```
cd /root/stack && docker compose version
```{{exec}}
