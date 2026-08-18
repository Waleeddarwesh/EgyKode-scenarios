# Where would the packet go

The name resolved. The next question is not "can I ping it" — it is which
interface and gateway a packet would leave by.

```
ip route get 1.1.1.1
```{{exec}}

That one command answers what `ip route` and `ip addr` together only imply: the
kernel's actual decision for this destination, including the source address it
would use.

Capture it:

```
ip route get 1.1.1.1 | tee /root/findings/route.txt
```{{exec}}

**You should see** `via <gateway> dev <interface> src <your address>`. If there
is no route at all, that is your failure and no amount of retrying the
application will change it.
