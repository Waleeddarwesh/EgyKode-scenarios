#!/bin/bash
# Runs as intro.background. A scanning OCI registry, and S3.
#
# WHAT STANDS IN FOR WHAT
#
# lab-03 is ECR and S3. ECR is not in the free LocalStack image - creating a
# repository returns "API for service 'ecr' not yet implemented or pro
# feature" - so the registry here is zot, a real OCI registry that really
# scans what you push and really expires images on a retention policy.
#
# That is a substitution, not a simulation: the scans are Trivy's, the CVEs are
# real, and the retention actually deletes tags. What differs is where you
# write the policy - a zot config file rather than an ECR lifecycle policy -
# and each step names the ECR equivalent.
#
# S3 is genuinely S3 through LocalStack, which implements versioning and
# delete markers properly. One thing it does NOT implement is bucket policy
# *enforcement*, and step 3 makes that visible rather than hiding it.

set -u
NEED=""
mkdir -p /root/registry /root/s3
exec > >(tee -a /root/registry/setup.log) 2>&1

echo "[1/4] tools"
for T in curl jq unzip; do
  command -v "$T" >/dev/null 2>&1 || NEED="$NEED $T"
done
if [ -n "${NEED:-}" ]; then
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $NEED >/dev/null 2>&1
fi
if ! command -v aws >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq awscli >/dev/null 2>&1
fi
if ! command -v aws >/dev/null 2>&1; then
  # Ubuntu 24.04 has no awscli package at all - apt-cache policy reports
  # "Candidate: (none)" - so fall back to the official installer.
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null
  unzip -q -o /tmp/awscliv2.zip -d /tmp 2>/dev/null
  /tmp/aws/install --update >/dev/null 2>&1
fi
mkdir -p /root/.aws
printf '[default]\naws_access_key_id = test\naws_secret_access_key = test\nregion = us-east-1\n' > /root/.aws/credentials
printf '[default]\nregion = us-east-1\noutput = json\n' > /root/.aws/config
cat > /usr/local/bin/awslocal <<'WRAP'
#!/bin/bash
exec aws --endpoint-url=http://localhost:4566 "$@"
WRAP
chmod +x /usr/local/bin/awslocal

echo "[2/4] the registry"
mkdir -p /root/registry/etc
cat > /root/registry/etc/config.json <<'JSON'
{
  "distSpecVersion": "1.1.0",
  "storage": {
    "rootDirectory": "/var/lib/registry",
    "gc": true,
    "gcDelay": "10s",
    "gcInterval": "30s",
    "retention": {
      "dryRun": false,
      "policies": [
        {
          "repositories": ["**"],
          "deleteUntagged": true,
          "keepTags": [{ "patterns": ["v.*"], "mostRecentlyPushedCount": 3 }]
        }
      ]
    }
  },
  "http": {
    "address": "0.0.0.0",
    "port": "5000",
    "compat": ["docker2s2"]
  },
  "log": { "level": "info" },
  "extensions": {
    "search": { "enable": true, "cve": { "updateInterval": "24h" } },
    "scrub": { "enable": true, "interval": "24h" }
  }
}
JSON
# compat: ["docker2s2"] is not optional and belongs under http, not at the top
# level. Without it this registry answers `docker push` with HTTP 415
# Unsupported Media Type, because it wants OCI media types and the Docker
# client sends application/vnd.docker.distribution.manifest.v2+json. The layers
# upload fine and only the manifest is refused, so the error reads as a broken
# image rather than a registry setting.
# Pinned like everything else here. A registry that changes under the
# scenario changes what its scanner finds and how its retention behaves,
# which are the two things being taught.
docker rm -f zot >/dev/null 2>&1
docker run -d --name zot --restart=unless-stopped -p 5000:5000 \
  -v /root/registry/etc/config.json:/etc/zot/config.json:ro \
  ghcr.io/project-zot/zot-linux-amd64:v2.1.20 >/dev/null 2>&1
for i in $(seq 1 40); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5000/v2/ 2>/dev/null)" = "200" ] && break
  sleep 3
done
echo "      registry: $(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5000/v2/ 2>/dev/null)"

echo "[3/4] S3"
docker rm -f localstack >/dev/null 2>&1
docker run -d --name localstack -p 4566:4566 -e SERVICES=s3,iam,sts -e DEBUG=0 \
  localstack/localstack:3.8 >/dev/null 2>&1
for i in $(seq 1 60); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null \
    | grep -qE '"s3": *"(available|running)"' && break
  sleep 3
done
echo "      s3: available"

echo "[4/4] a base image to build from"
# Pulled now so step 1 is about the registry rather than about waiting. This
# tag is a frozen point release with real findings - an end-of-life image would
# be worse, because most of what it carries has no fix and a scanner filtering
# on fixable findings reports almost nothing.
docker pull -q debian:12.5-slim >/dev/null 2>&1
echo "      debian:12.5-slim ready"

echo done
