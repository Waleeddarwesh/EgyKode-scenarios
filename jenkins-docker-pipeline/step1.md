# A pipeline that tags with the commit

Setup is fetching Jenkins, Trivy's 108 MiB database and a private registry.
Wait for it — first boot takes a few minutes:

```
tail -n 3 /root/ci/setup.log
for i in $(seq 1 90); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -u admin:adminpass http://localhost:8080/api/json)
  [ "$CODE" = "200" ] && break
  printf "."
  sleep 5
done
echo
echo "jenkins answered with $CODE"
```{{exec}}

## What you are building against

A registry that asks for a password, so "no credential in the log" is a real
claim rather than a hypothetical one:

```
curl -s -o /dev/null -w 'anonymous pull: %{http_code}\n' http://localhost:5000/v2/_catalog
curl -s -u ci:ci-lab-password http://localhost:5000/v2/_catalog
```{{exec}}

`401` without credentials. That registry is the only place this lab pushes to —
nothing here touches Docker Hub or any account of yours.

## The Jenkinsfile

```
cat > /root/app/Jenkinsfile <<'GROOVY'
pipeline {
  agent any

  environment {
    REGISTRY = 'localhost:5000'
    IMAGE    = 'platform/api'
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.TAG = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
        }
        echo "building ${env.TAG}"
      }
    }

    stage('Unit tests') {
      steps { sh 'make test' }
    }

    stage('Build image') {
      steps { sh 'docker build -t $REGISTRY/$IMAGE:$TAG .' }
    }

    stage('Scan image') {
      steps {
        sh '''
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v trivy-cache:/root/.cache \
            aquasec/trivy:latest image \
            --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln \
            $REGISTRY/$IMAGE:$TAG
        '''
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'registry',
          usernameVariable: 'REG_USER',
          passwordVariable: 'REG_PASS')]) {
          sh '''
            echo "$REG_PASS" | docker login $REGISTRY -u "$REG_USER" --password-stdin
            docker push $REGISTRY/$IMAGE:$TAG
            docker logout $REGISTRY
          '''
        }
      }
    }
  }
}
GROOVY
cd /root/app && git add Jenkinsfile && git commit -qm "Add the pipeline" && git log --oneline -1
```{{exec}}

**The tag is computed after `checkout scm`, not in `environment {}`.** That block
is evaluated before any stage runs, so `env.GIT_COMMIT` is still null there — the
pipeline would fail on `Cannot invoke method take() on null object`, and the fix
people usually reach for is hardcoding a tag.

## Create the job and run it

The crumb is session-bound: a `curl` that fetches one and posts without the
matching cookie gets `403` even as an administrator. Hence the cookie jar.

```
cd /root/ci
CRUMB=$(curl -s -c /tmp/ck -u admin:adminpass http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
cat > job.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<flow-definition plugin="workflow-job">
  <description>Build, scan and push the platform image</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>/srv/app</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
XML
curl -s -o /dev/null -w 'create job: %{http_code}\n' -b /tmp/ck -u admin:adminpass \
  -H "$CRUMB" -H "Content-Type: application/xml" \
  --data-binary @job.xml "http://localhost:8080/createItem?name=platform-image"
```{{exec}}

Watch it. The first run builds an image and downloads nothing else — the Trivy
database was fetched during setup:

```
cd /root/ci
# Claim the build number BEFORE triggering, and wait on that number.
#
# Waiting on lastBuild does not work: a POSTed build sits in the queue for a
# moment, during which lastBuild still points at the *previous* run, whose
# result is already final. The loop would read that stale result and return
# instantly, reporting the wrong build as this one's outcome.
N=$(curl -s -u admin:adminpass http://localhost:8080/job/platform-image/api/json | jq -r '.nextBuildNumber')
CRUMB=$(curl -s -c /tmp/ck -u admin:adminpass http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ": " + .crumb')
curl -s -o /dev/null -w 'start build: %{http_code}\n' -b /tmp/ck -u admin:adminpass \
  -H "$CRUMB" -X POST "http://localhost:8080/job/platform-image/build"
for i in $(seq 1 90); do
  R=$(curl -s -u admin:adminpass "http://localhost:8080/job/platform-image/$N/api/json" 2>/dev/null \
      | jq -r '.result // "RUNNING"' 2>/dev/null)
  case "$R" in SUCCESS|FAILURE|ABORTED|UNSTABLE) break ;; esac
  printf "."
  sleep 5
done
echo
echo "build #$N result: $R"
curl -s -u admin:adminpass "http://localhost:8080/job/platform-image/$N/consoleText" | grep -E "building |unit tests|Total:|digest:" | head
```{{exec}}

## What reached the registry

```
SHA=$(cd /root/app && git rev-parse --short=7 HEAD)
echo "HEAD is $SHA"
curl -s -u ci:ci-lab-password http://localhost:5000/v2/platform/api/tags/list
```{{exec}}

One tag, and it is the commit. **Not `latest`** — which is not a version but a
label meaning "whatever was pushed most recently", so two deploys of the same
manifest can produce two different containers and a rollback has nothing to
roll back to.

**Done when:** the build succeeded and the registry holds `platform/api` tagged
with the short SHA of `HEAD`.
