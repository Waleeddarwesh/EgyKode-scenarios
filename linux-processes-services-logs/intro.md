A service is running on this machine. You are going to interrogate it the way
you would at 3am: find what holds a port, read what the service itself said,
then break it deliberately and work out why from the evidence.

**What you will do**

1. **Find the process behind a port** — by port, not by guessing
2. **Read a service's own logs** — rather than inferring from its status line
3. **Break it and fix it** — diagnose a real failure from the journal

Have a look at what is listening:

```
ss -ltnp
```{{exec}}
