#!/bin/bash
# This runs in the background while the intro is read. The Jenkins image is
# large and the plugin install adds to it, so step 1 waits for readiness rather
# than assuming it.
mkdir -p /root/ci
cd /root/ci

cat > Dockerfile <<'DOCKER'
FROM jenkins/jenkins:lts-jdk17
RUN jenkins-plugin-cli --plugins configuration-as-code matrix-auth
DOCKER

cat > casc.yaml <<'YML'
jenkins:
  systemMessage: "EgyKode CI"
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: adminpass
  authorizationStrategy:
    globalMatrix:
      entries:
        - user:
            name: admin
            permissions:
              - "Overall/Administer"
YML

cat > compose.yaml <<'YML'
services:
  jenkins:
    build: .
    image: egykode-jenkins
    environment:
      JAVA_OPTS: "-Djenkins.install.runSetupWizard=false"
      CASC_JENKINS_CONFIG: /var/jenkins_conf/casc.yaml
    ports:
      - "8080:8080"
    volumes:
      - jenkins_home:/var/jenkins_home
      - ./casc.yaml:/var/jenkins_conf/casc.yaml:ro

volumes:
  jenkins_home:
YML

docker compose build >/dev/null 2>&1
docker compose up -d >/dev/null 2>&1
echo done
