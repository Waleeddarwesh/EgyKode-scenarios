# Reachable is not the same as working

Port 8444 fails. Before touching certificates, settle whether the network is
even involved.

```
nc -vz localhost 8444
curl -sS --max-time 5 https://localhost:8444/ ; echo "exit=$?"
```{{exec}}

`nc` connects. `curl` does not. That single pair of results removes firewalls,
security groups and routing from the investigation entirely — the packet
arrived, something answered, and the failure is TLS or above.

Record both:

```
{ echo "TCP:"; nc -vz localhost 8444 2>&1;
  echo "TLS:"; curl -sS --max-time 5 https://localhost:8444/ 2>&1; echo "exit=$?"; } \
  | tee /root/findings/layers.txt
```{{exec}}

**You should see** a successful TCP connection and a TLS failure on the same
port. That contradiction is the diagnosis.
