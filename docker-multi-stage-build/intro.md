# Production-Grade Multi-Stage Dockerfile

An application is waiting at `/root/app`. You will build it three ways and
measure the difference:

1. one stage, everything in the final image
2. two stages, so the build tools stay behind
3. running as a user that is not root

The image sizes are real. Check them yourself with `docker images`.

```
cd /root/app && ls
```
