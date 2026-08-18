An application is waiting at `/root/app`. You will build it three ways and
measure the difference between them.

**What you will do**

1. **Build it naively** — one stage, compiler and all, then read the size
2. **Split the build** — two stages, so the build tools stay behind
3. **Drop root** — run the same image as a user that is not root

The sizes are real, and you will check them yourself rather than take the
lab's word for it.

Have a look at what you are starting from:

```
cd /root/app && ls -la
```{{exec}}
