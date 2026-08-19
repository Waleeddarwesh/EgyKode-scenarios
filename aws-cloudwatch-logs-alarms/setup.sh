#!/bin/bash
# CloudWatch Logs, custom metrics and alarms against LocalStack.
#
# Pinned to 3.8. The `latest` tag now requires an auth token and quits with
# exit code 55 and "License activation failed" - which reads as a broken
# environment rather than a licensing change, so it is worth not discovering
# by accident.
echo "Installing the AWS CLI..."
apt-get update -qq >/dev/null 2>&1

# No apt attempt first, deliberately. The other LocalStack scenarios try apt
# and fall back, which is right for them; here the pinned installer runs
# unconditionally anyway, so an apt install would only add a *second* aws - v1
# at /usr/bin/aws, v2 at /usr/local/bin/aws - and which one answers would come
# down to PATH order. One binary, chosen on purpose.
#
# (Ubuntu 24.04 has no awscli package at all: apt-cache policy reports
# "Candidate: (none)". So on 24.04 the apt path never worked; on 22.04 it
# installed v1, which is not what these labs are written against.)

# The version is pinned, and not for the usual reproducibility reasons.
#
# Amazon CloudWatch is migrating from the AWS Query protocol to AWS JSON 1.0,
# and current AWS CLI v2 already sends the new format. LocalStack still parses
# the old one, so every CloudWatch call against it fails with HTTP 500 and
# "Operation detection failed. Missing Action in request for query-protocol
# service ServiceModel(cloudwatch)". Reproduced here with aws-cli 2.36.26
# against LocalStack 3.8 and 4.0 alike; it is upstream issue
# localstack/localstack#13028, still open, with no environment variable or
# client setting that forces the old protocol.
#
# CloudWatch Logs is unaffected - it was already JSON - which is why the log
# half of this scenario works with any CLI and the metric half does not.
#
# So: a CLI old enough to predate the change. Unpin this once LocalStack
# supports the new protocol, and delete the smoke test below with it.
AWSCLI_VERSION=2.15.30
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip curl >/dev/null 2>&1
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" -o /tmp/awscliv2.zip 2>/dev/null
unzip -q -o /tmp/awscliv2.zip -d /tmp 2>/dev/null
/tmp/aws/install --update >/dev/null 2>&1
command -v aws >/dev/null 2>&1 || echo "WARNING: the AWS CLI did not install - every step below will fail"
aws --version 2>&1 | head -1

# The credentials are deliberately worthless; LocalStack checks the shape of a
# request, not who sent it.
mkdir -p /root/.aws
printf '[default]\naws_access_key_id = test\naws_secret_access_key = test\nregion = us-east-1\n' > /root/.aws/credentials
printf '[default]\nregion = us-east-1\noutput = json\n' > /root/.aws/config

# awslocal is the same CLI with the endpoint already set, so the commands in
# these steps read the way they would against real AWS.
cat > /usr/local/bin/awslocal <<'WRAP'
#!/bin/bash
exec aws --endpoint-url=http://localhost:4566 "$@"
WRAP
chmod +x /usr/local/bin/awslocal

echo "Starting LocalStack (this pulls an image; give it a minute)..."
docker rm -f localstack >/dev/null 2>&1
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=logs,cloudwatch,ssm,ec2,iam,sts -e DEBUG=0 \
  localstack/localstack:3.8 >/dev/null 2>&1

echo "Waiting for CloudWatch Logs..."
for i in $(seq 1 60); do
  if curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -qE '"logs": *"(available|running)"'; then
    echo "LocalStack is ready."
    break
  fi
  sleep 3
done

# A small application that writes the kind of log lines the steps go looking
# for. Written here rather than typed, so the step is about CloudWatch rather
# than about composing log lines.
mkdir -p /root/ops
cat > /root/ops/app.log <<'LOG'
INFO  startup complete in 412ms
INFO  GET /healthz 200 3ms
ERROR database timeout after 5000ms
INFO  GET /api/orders 200 88ms
ERROR upstream payments returned 503
INFO  GET /api/orders 200 91ms
LOG

# Smoke-test CloudWatch before the learner meets it.
#
# The failure this guards against is not subtle to read but is very hard to
# attribute: every metric command returns HTTP 500 for a protocol reason that
# has nothing to do with anything the learner typed. Better to say so here,
# once, than to let it surface as a mystery in step 1.
if aws --endpoint-url=http://localhost:4566 cloudwatch put-metric-data \
     --namespace EgyKode/Setup --metric-name SetupCheck --value 1 >/dev/null 2>&1; then
  echo "CloudWatch metrics: OK"
else
  echo "WARNING: CloudWatch metric calls are failing against LocalStack."
  echo "         This is the query-protocol mismatch, not anything you did:"
  echo "         the pinned AWS CLI ($AWSCLI_VERSION) may still be too new."
  echo "         Steps 1 and 3 will not work; step 2 (logs) is unaffected."
fi

echo done
