#!/bin/bash
# Runs as intro.background, while the intro is being read. There is a lot to
# fetch here and the scenario is unusable until it lands, so this echoes its
# progress into /root/ci/setup.log and step 1 waits on a bounded loop rather
# than assuming any of it finished.
#
# WHY THE DOCKER SOCKET IS MOUNTED HERE, WHEN NO OTHER SCENARIO DOES IT
#
# The lab's subject is a pipeline that builds an image, scans it and pushes it.
# An agent with no Docker daemon cannot demonstrate a single one of its four
# criteria - there is no image to tag, nothing to scan and nothing to push. So
# /var/run/docker.sock goes into the Jenkins container deliberately.
#
# That is a real grant: the socket is root on the host, and anything that can
# reach it can start a privileged container. It belongs here because the lab is
# *about* building images, and it does not belong anywhere it is merely
# convenient. Killercoda hands every learner a throwaway VM, which is the only
# reason this is acceptable at all.

set -u
mkdir -p /root/ci
cd /root/ci
exec > >(tee -a /root/ci/setup.log) 2>&1

echo "[1/6] a registry that demands a password"
# A password is what makes criterion 3 - "no credential appears in the build
# log" - a real claim rather than a hypothetical one. Nothing here is a
# credential for anything outside this throwaway VM.
mkdir -p /root/ci/auth
docker run --rm --entrypoint htpasswd httpd:2 -Bbn ci ci-lab-password > /root/ci/auth/htpasswd
docker rm -f registry >/dev/null 2>&1
docker run -d --name registry --restart=unless-stopped -p 5000:5000 \
  -v /root/ci/auth:/auth \
  -e REGISTRY_AUTH=htpasswd \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2 >/dev/null

echo "[2/6] the application repository"
# A real git repository, because criterion 1 is about the *commit* SHA. A
# directory of files would let the pipeline invent a tag from anything.
rm -rf /root/app
mkdir -p /root/app
cd /root/app
cat > Dockerfile <<'DOCKER'
FROM debian:12-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
CMD ["curl", "--version"]
DOCKER
cat > Makefile <<'MAKE'
test:
	@echo "unit tests passed"
MAKE
git init -q -b main
git config user.email ci@egykode.local
git config user.name "EgyKode CI"
git add -A
git commit -qm "The application image"
# Jenkins clones this over the filesystem. Marking it safe avoids git's
# dubious-ownership refusal when the clone runs as a different uid.
git config --global --add safe.directory /root/app
cd /root/ci

echo "[3/6] Trivy database, 108 MiB - the slowest thing here"
# Prefetched into a named volume the pipeline mounts, so the first build does
# not pay for it and a rate-limited pull fails here, visibly, instead of
# halfway through a build where it would look like a passing gate.
docker run --rm -v trivy-cache:/root/.cache/ aquasec/trivy:latest image --download-db-only >/dev/null 2>&1
echo "      trivy db: exit $?"

echo "[4/6] assert the gate actually has something to find"
# The failure this guards against is silent. --ignore-unfixed discards findings
# with no available fix, and an end-of-life distribution ships no fixes, so an
# EOL base image scans *clean* under this flag - ubuntu:18.04 reports nothing at
# all. A scenario built on one would teach that a vulnerable image passes.
#
# debian:12.5-slim is a frozen point release of a distribution that is still
# shipping fixes, which is the opposite case: the snapshot never rebuilds, so
# its packages fall further behind and the finding count grows over time.
# Measured at 15 distinct HIGH/CRITICAL against debian:12-slim's 0.
docker pull -q debian:12.5-slim >/dev/null 2>&1
FOUND=$(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache/ aquasec/trivy:latest image \
  --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln -f json debian:12.5-slim 2>/dev/null \
  | grep -o '"VulnerabilityID"' | wc -l)
# Rows, not distinct CVEs - one CVE spanning several packages counts once per
# package. Measured at 20 rows for 15 distinct CVEs. Only "more than none"
# matters here, and rows are what a grep can count without jq.
echo "      debian:12.5-slim finding rows: $FOUND"
if [ "$FOUND" -lt 1 ]; then
  echo "      WARNING: the vulnerable base image scans clean."
  echo "      Step 3 cannot demonstrate its gate. This means the Trivy database"
  echo "      failed to download, or debian:12.5-slim has been rebuilt."
fi

echo "[5/6] building Jenkins with a Docker client"
cd /root/ci
cat > Dockerfile <<'DOCKER'
FROM jenkins/jenkins:lts-jdk17
USER root
# make, because the pipeline's cheap-check stage runs "make test". The base
# image has no make and the failure is exit 127 from inside a sh step, which
# reads as a broken pipeline rather than a missing package.
RUN apt-get update \
 && apt-get install -y --no-install-recommends make \
 && rm -rf /var/lib/apt/lists/*
# The client only. The daemon is the host's, reached through the mounted
# socket - installing docker.io here would drag in a daemon that never runs.
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.3.1.tgz \
    | tar -xz -C /usr/local/bin --strip-components=1 docker/docker
# Pinning an old Jenkins does not work: 2.479.1 cannot install current plugins
# at all (scm-api wants 2.504.3). The floating lts tag is the supported path.
RUN jenkins-plugin-cli --plugins \
      configuration-as-code workflow-aggregator git credentials-binding
DOCKER

cat > casc.yaml <<'YML'
jenkins:
  systemMessage: "EgyKode CI"
  numExecutors: 2
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: adminpass
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              scope: GLOBAL
              id: registry
              username: ci
              password: ci-lab-password
              description: "The lab registry"
unclassified:
  location:
    url: http://localhost:8080/
YML

cat > compose.yaml <<'YML'
services:
  jenkins:
    build: .
    image: egykode-jenkins-docker
    # Host networking so that "localhost:5000" means the same thing to the
    # docker client inside this container and to the daemon it talks to. With
    # a bridge network the client would resolve localhost to itself, find no
    # registry, and docker login would fail before the daemon was ever asked.
    network_mode: host
    # Root, so the mounted socket is reachable without matching the host's
    # docker group id inside the image. A throwaway lab VM; not a pattern to
    # copy onto a shared controller.
    user: root
    environment:
      # ALLOW_LOCAL_CHECKOUT is required for the job to clone /srv/app. Current
      # git-plugin versions refuse a checkout whose remote is a local directory
      # and fail the build with "references a local directory, which may be
      # insecure" - hardening against a job on a shared controller reading
      # arbitrary paths off the host. This is a single-user throwaway VM whose
      # repository is a directory, so the risk it guards against does not
      # exist here. On a shared controller, serve the repo over git:// or
      # https:// instead of setting this.
      JAVA_OPTS: >-
        -Djenkins.install.runSetupWizard=false
        -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true
      CASC_JENKINS_CONFIG: /var/jenkins_conf/casc.yaml
    volumes:
      - jenkins_home:/var/jenkins_home
      - ./casc.yaml:/var/jenkins_conf/casc.yaml:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - /root/app:/srv/app

volumes:
  jenkins_home:
YML
# The Trivy cache is deliberately NOT mounted into Jenkins. The scan runs as
# "docker run -v trivy-cache:/root/.cache", and that flag is read by the host
# daemon, not by the container issuing it - a named volume resolves the same
# way whoever asks. A bind mount of /root/.cache would have silently pointed at
# the host's home directory instead of the Jenkins container's.

docker compose build >/dev/null 2>&1
echo "      build: exit $?"

echo "[6/6] starting Jenkins"
docker compose up -d >/dev/null 2>&1
echo "done - step 1 waits for Jenkins to answer"
