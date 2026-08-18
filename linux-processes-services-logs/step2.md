# Ask systemd, then ask the application

Two different questions, and people conflate them constantly.

```
systemctl status nginx --no-pager
journalctl -u nginx -n 20 --no-pager
```{{exec}}

`status` is systemd's opinion: is the unit active, what was the exit code, and
the last few lines it captured. `journalctl -u` is everything the service
itself said, for as long as the journal keeps it.

The state names are worth knowing exactly:

| State | Means |
| --- | --- |
| `active (running)` | Up |
| `inactive (dead)` | Stopped, and nothing tried to start it |
| `failed` | It tried and exited non-zero — read the logs |
| `activating` | Still starting, or stuck in a start loop |

Write the last 50 lines of nginx's own log to a file, so you have the answer
without scrolling a journal:

```
journalctl -u nginx -n 50 --no-pager > /root/nginx-last50.log
wc -l /root/nginx-last50.log
```{{exec}}

**You should see** a file with the service's own output in it.
