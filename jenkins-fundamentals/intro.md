Two things that decide whether a Jenkins is a build server or a liability:
where its configuration lives, and who is allowed to start a build.

**What you will do**

1. **Put `JENKINS_HOME` on a named volume** and prove it survives — because
   everything Jenkins knows lives in that one directory
2. **Create a read-only user** and demonstrate they cannot start a build, rather
   than assuming the permission matrix says what you meant

Jenkins is being built and started in the background as you read this — the
image is large, so give it a couple of minutes. Step 1 waits for it properly.

```
cd /root/ci
docker compose ps --format '{{.Service}}\t{{.Status}}' 2>/dev/null || echo "still building"
```{{exec}}
