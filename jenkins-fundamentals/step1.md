# A Jenkins that survives being restarted

Wait for it to finish starting. First boot takes a minute or two:

```
cd /root/ci
for i in $(seq 1 60); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass http://localhost:8080/api/json)
  [ "$CODE" = "200" ] && break
  printf "."
  sleep 5
done
echo
echo "jenkins answered with $CODE"
curl -s -u admin:adminpass http://localhost:8080/api/json | jq -r '.mode, .numExecutors'
```{{exec}}

## Everything Jenkins knows is in one directory

```
cd /root/ci
docker compose exec -T jenkins ls /var/jenkins_home | head -12
docker volume ls | grep jenkins
```{{exec}}

Jobs, build history, credentials, plugins, the node configuration — all of it in
`JENKINS_HOME`. **There is no database.** That is convenient, and it means the
entire server is one directory that either persists or does not.

```
cd /root/ci
grep -A3 "volumes:" compose.yaml | head -6
```{{exec}}

`jenkins_home:/var/jenkins_home` — a **named volume**, which has a lifecycle
separate from the container.

## Prove it

Write something into Jenkins, then destroy the container:

```
cd /root/ci
CRUMB=$(curl -s -c /tmp/ck -u admin:adminpass http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
cat > job.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project>
  <description>Build the platform</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <triggers/>
  <builders>
    <hudson.tasks.Shell>
      <command>echo building the platform; sleep 2; echo done</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
XML
curl -s -o /dev/null -w 'create job: %{http_code}\n' -b /tmp/ck -u admin:adminpass \
  -H "$CRUMB" -H "Content-Type: application/xml" \
  --data-binary @job.xml "http://localhost:8080/createItem?name=platform-build"
curl -s -u admin:adminpass http://localhost:8080/api/json | jq -r '.jobs[].name'
```{{exec}}

Now take the container away entirely — not a restart, a delete:

```
cd /root/ci
docker compose down
docker compose ps -a --format '{{.Service}}' 2>/dev/null | wc -l
docker volume ls | grep jenkins_home
docker compose up -d
for i in $(seq 1 60); do
  curl -s -o /dev/null --max-time 5 -u admin:adminpass http://localhost:8080/api/json && break
  sleep 5
done
curl -s -u admin:adminpass http://localhost:8080/api/json | jq -r '.jobs[].name'
```{{exec}}

`platform-build` is still there. **A new container, the same Jenkins** — because
the state was never in the container.

Had `JENKINS_HOME` been left on the container's writable layer, that `down`
would have deleted every job, every credential and the build history, and the
next `up` would have presented a clean setup wizard as if nothing had happened.

**Done when:** Jenkins answers as `admin`, the `platform-build` job exists, and
`JENKINS_HOME` is on a named volume.
