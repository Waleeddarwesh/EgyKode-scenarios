# Two users, and the one who cannot build

Right now there is one user who can do everything. Add a second who can look and
not touch:

```
cd /root/ci
cat > casc.yaml <<'YML'
jenkins:
  systemMessage: "EgyKode CI"
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: adminpass
        - id: viewer
          password: viewerpass
  authorizationStrategy:
    globalMatrix:
      entries:
        - user:
            name: admin
            permissions:
              - "Overall/Administer"
        - user:
            name: viewer
            permissions:
              - "Overall/Read"
              - "Job/Read"
YML
docker compose restart jenkins > /dev/null
for i in $(seq 1 40); do
  curl -s -o /dev/null --max-time 5 -u admin:adminpass http://localhost:8080/api/json && break
  sleep 5
done
curl -s -u admin:adminpass http://localhost:8080/api/json > /dev/null && echo "jenkins is back"
```{{exec}}

**`allowsSignup: false` is the line that matters most.** Jenkins with signup
enabled and any port reachable is an open build server — anyone who can load the
page can create an account and, depending on the matrix, run shell commands on
your host.

## Verify each identity separately

```
J=http://localhost:8080
echo "admin:     $(curl -s -o /dev/null -w '%{http_code}' -u admin:adminpass $J/api/json)"
echo "viewer:    $(curl -s -o /dev/null -w '%{http_code}' -u viewer:viewerpass $J/api/json)"
echo "anonymous: $(curl -s -o /dev/null -w '%{http_code}' $J/api/json)"
echo "wrong pw:  $(curl -s -o /dev/null -w '%{http_code}' -u viewer:wrongpassword $J/api/json)"
```{{exec}}

```
admin:     200
viewer:    200
anonymous: 403
wrong pw:  401
```

Four different answers, and the last two are worth separating: **401 is "I do not
know who you are", 403 is "I know, and no".** Anonymous gets 403 because it is
authenticated as the anonymous user and that user has no permissions.

## The read-only user cannot start a build

Both can see the job:

```
J=http://localhost:8080
echo "admin sees job:  $(curl -s -o /dev/null -w '%{http_code}' -u admin:adminpass $J/job/platform-build/api/json)"
echo "viewer sees job: $(curl -s -o /dev/null -w '%{http_code}' -u viewer:viewerpass $J/job/platform-build/api/json)"
```{{exec}}

Now try to start one. Jenkins requires a CSRF crumb tied to the session, which
is why each request fetches its own:

```
J=http://localhost:8080
rm -f /tmp/vck /tmp/ack

VC=$(curl -s -c /tmp/vck -u viewer:viewerpass $J/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
echo "viewer builds: $(curl -s -o /dev/null -w '%{http_code}' -X POST -b /tmp/vck -u viewer:viewerpass -H "$VC" $J/job/platform-build/build)"

AC=$(curl -s -c /tmp/ack -u admin:adminpass $J/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
echo "admin builds:  $(curl -s -o /dev/null -w '%{http_code}' -X POST -b /tmp/ack -u admin:adminpass -H "$AC" $J/job/platform-build/build)"
sleep 8
curl -s -u admin:adminpass $J/job/platform-build/api/json | jq -r '.builds | length'
```{{exec}}

**`403` for the viewer, `201` for the admin**, and one build in the history.

That is the criterion — *demonstrated*, not read off a permissions matrix. A
matrix can look exactly right and grant the wrong thing, because `Job/Read` and
`Job/Build` are separate permissions and the difference is one line.

## Why the crumb exists

Without CSRF protection, a link in an email could start a build — or delete a
job — using the browser session of whoever clicked it, with no password
required. The crumb is tied to the session, which is why fetching one with
`curl` and using it without the matching cookie fails.

**Done when:** both users authenticate, the viewer can read the job and is
refused when starting a build, and a build exists in the history.
