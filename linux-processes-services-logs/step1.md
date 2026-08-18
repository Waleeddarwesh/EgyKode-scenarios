# What holds the port

Four ways to ask, and one worth memorising:

```
ss -ltnp | grep ':80'
lsof -i :80
pgrep -a nginx
ps aux --sort=-%mem | head -5
```{{exec}}

`ss -ltnp` is the one: **l**istening, **t**cp, **n**umeric, with the **p**rocess.
Numeric matters — without `-n` it resolves names and hangs when DNS is slow,
which is exactly when you are debugging.

Now hold port **8080** yourself, so there is something new to find:

```
nohup python3 -m http.server 8080 >/tmp/http.log 2>&1 &
sleep 1
ss -ltnp | grep ':8080'
```{{exec}}

**You should see** the port, the PID and the command that owns it.
