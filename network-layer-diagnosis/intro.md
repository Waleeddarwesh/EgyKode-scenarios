Something cannot reach something else. The instinct is to start changing
things. The method is to find the lowest layer that is broken, and change
nothing until you have.

**What you will do**

1. **Resolve a name** — and read the TTL on the answer
2. **Read the route** — which interface and gateway a packet would use
3. **Tell refused from timed out** — two failures that mean opposite things

Each step writes its answer to `/root/findings`, so you finish with the
evidence rather than a memory of it.

```
ls /root/findings && ip -brief addr
```{{exec}}
