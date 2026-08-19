# The credential that never reaches the log

The build in step 1 authenticated to a registry that returns `401` without a
password. So a password was used. Find it in the log:

```
curl -s -u admin:adminpass http://localhost:8080/job/platform-image/lastBuild/consoleText \
  > /tmp/build.log
wc -l /tmp/build.log
grep -c 'ci-lab-password' /tmp/build.log
grep -n 'Login Succeeded\|docker login\|REG_PASS' /tmp/build.log | head
```{{exec}}

Zero occurrences, and `Login Succeeded` is there. Both halves matter: a log with
no password in it proves nothing if nothing ever logged in.

## What is doing the masking

```
grep -n 'withCredentials' -A 6 /root/app/Jenkinsfile
```{{exec}}

`withCredentials` binds the values for the length of the block and registers
them with Jenkins' log filter, so any occurrence in the output is replaced with
`****` — including one printed by a command you did not write, such as a shell
trace. Outside the block the variables do not exist at all.

## Why `--password-stdin`, and not `-p`

The masking covers the log. It does not cover the process table, and every
process on the machine can read that. Watch Docker itself object:

```
docker login localhost:5000 -u ci -p ci-lab-password 2>&1 | head -3
docker logout localhost:5000 >/dev/null 2>&1
echo "---"
echo "ci-lab-password" | docker login localhost:5000 -u ci --password-stdin 2>&1 | head -2
docker logout localhost:5000 >/dev/null 2>&1
```{{exec}}

The first prints a warning because the password is an argument, visible in
`ps aux` to anyone on the agent for as long as the call runs. The second passes
it on stdin, which is not.

## Where the credential actually lives

```
docker exec -i $(docker ps -qf name=jenkins) \
  cat /var/jenkins_conf/casc.yaml | grep -A 8 'domainCredentials'
```{{exec}}

Declared once in Jenkins' own configuration, referenced by `credentialsId` in
the pipeline. **The Jenkinsfile is in Git and contains no secret** — which is
the property you are protecting, because a pipeline file is reviewed, forked and
copied far more often than a controller's configuration is.

## And why the tag is not `latest`

```
curl -s -u ci:ci-lab-password http://localhost:5000/v2/platform/api/tags/list
```{{exec}}

`latest` is not a version. It is a label meaning *whatever was pushed most
recently*, so the same deployment manifest applied twice can produce two
different containers, and a rollback has no earlier tag to return to. The commit
SHA ties one running container to exactly one commit — which is the question
asked during an incident, and the reason step 1 computed the tag from `git
rev-parse` rather than hardcoding one.

**Done when:** the build log contains no credential, the push authenticated
anyway, and only the commit tag is in the registry.
