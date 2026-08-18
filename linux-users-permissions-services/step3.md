# A service that survives a reboot

`enable` and `start` are different things, and nothing in the output of a
working service tells you which one you did.

```
sudo apt-get update -qq
sudo apt-get install -y -qq nginx
systemctl is-active nginx
systemctl is-enabled nginx
```{{exec}}

If `is-enabled` says anything other than `enabled`, the service is running now
and will be gone after a reboot.

```
sudo systemctl enable --now nginx
systemctl is-enabled nginx
```{{exec}}

**You should see** `enabled`. `--now` does both jobs at once.

A service that is started but not enabled works perfectly until the machine
reboots at 3am and never comes back — and that failure looks like a mystery
unless you know to check this one thing.
