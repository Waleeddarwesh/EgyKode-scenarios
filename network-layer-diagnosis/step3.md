# Refused is not timed out

Two failures that look similar in an application log and mean opposite things.

**Refused** — something answered, and said no. A host is there; nothing is
listening on that port.

```
curl -sS --max-time 5 http://127.0.0.1:9. ; echo "exit=$?"
nc -vz 127.0.0.1 9 2>&1 | tail -1
```{{exec}}

**Timed out** — nothing answered at all. A firewall dropped it, or the address
routes nowhere.

`203.0.113.1` is TEST-NET-3, reserved by RFC 5737 for documentation. Nothing
on the internet routes it, so a packet to it goes unanswered — a dropped
packet without needing firewall rules this sandbox may not permit.

```
time curl -sS --max-time 5 http://203.0.113.1/ ; echo "exit=$?"
```{{exec}}

Capture both, so the difference is on record:

```
{ echo "REFUSED:"; curl -sS --max-time 5 http://127.0.0.1:9 2>&1; echo "exit=$?";
  echo "TIMEOUT:"; curl -sS --max-time 5 http://203.0.113.1/ 2>&1; echo "exit=$?"; } \
  | tee /root/findings/reachability.txt
```{{exec}}

**You should see** an immediate refusal and a five-second wait. The time it
takes is itself the diagnosis: instant means something replied.
