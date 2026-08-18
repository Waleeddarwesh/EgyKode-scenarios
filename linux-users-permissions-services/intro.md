You have been handed a server somebody else built. A colleague needs to deploy
to it, and `/opt/app` is owned by `root`.

**What you will do**

1. **Create an account for the job** — not for a person
2. **Set permissions that hold** — when a second engineer arrives
3. **Enable a service** — so it comes back after a reboot

This is a real Ubuntu machine with systemd. Nothing is simulated.

See what you have inherited:

```
ls -ld /opt/app && cat /opt/app/VERSION
```{{exec}}
