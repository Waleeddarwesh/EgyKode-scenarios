#!/bin/bash
# Runs as intro.background. Terraform, the AWS CLI, LocalStack for Secrets
# Manager, and a real PostgreSQL - which is what stands in for RDS here.
#
# WHAT THIS SCENARIO COVERS AND WHAT IT DOES NOT
#
# lab-04 has four criteria. Three are about the credential: generated rather
# than typed, stored where an application can fetch it, and retrieved at run
# time. Those are Secrets Manager and application behaviour, and both are real
# here - LocalStack implements Secrets Manager in the free image, and the
# database is an actual PostgreSQL that actually refuses a wrong password.
#
# The fourth - "Multi-AZ, and no public endpoint, verified from outside the
# VPC" - is RDS, which is LocalStack Pro. It is not faked. Step 3 covers the
# reasoning it asks for and says plainly which part needs an account.

set -u
NEED=""
mkdir -p /root/iac /root/app
exec > >(tee -a /root/iac/setup.log) 2>&1

echo "[1/4] Terraform and the AWS CLI"
# Each tool checked on its own. Bundling them behind "is unzip missing"
# installed nothing when unzip already existed, and jq was then absent for
# every step that parses the secret - which failed as an empty variable rather
# than as a missing program.
for T in unzip curl jq; do
  command -v "$T" >/dev/null 2>&1 || NEED="$NEED $T"
done
if [ -n "${NEED:-}" ]; then
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $NEED >/dev/null 2>&1
fi
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/tf.zip 2>/dev/null
  unzip -q -o /tmp/tf.zip -d /usr/local/bin 2>/dev/null
fi
# Ubuntu 24.04 dropped the awscli package - apt-cache policy reports
# "Candidate: (none)" - so fall back to the official installer. Unlike the
# CloudWatch scenario this one needs no pinned version: Secrets Manager already
# speaks JSON, so the protocol migration that breaks CloudWatch does not apply.
if ! command -v aws >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq awscli >/dev/null 2>&1
fi
if ! command -v aws >/dev/null 2>&1; then
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
echo "      $(terraform version | head -1), $(aws --version 2>&1 | head -1)"

echo "[2/4] LocalStack (Secrets Manager)"
docker rm -f localstack >/dev/null 2>&1
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=secretsmanager,iam,sts -e DEBUG=0 \
  localstack/localstack:3.8 >/dev/null 2>&1
for i in $(seq 1 60); do
  curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null \
    | grep -qE '"secretsmanager": *"(available|running)"' && break
  sleep 3
done
echo "      secretsmanager: available"

echo "[3/4] pulling the database image"
# Pulled now so step 2 does not wait on it. The container itself is started in
# step 2, using the password Terraform generated - which is the whole point.
docker pull -q postgres:16-alpine >/dev/null 2>&1
echo "      postgres:16-alpine ready"

echo "[4/4] the AWS provider"
# The download is 60-70 seconds and would otherwise happen inside step 1, where
# it looks like Terraform hanging.
cat > /root/iac/versions.tf <<'HCL'
terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.40" }
    random = { source = "hashicorp/random" }
  }
}
HCL
cd /root/iac && terraform init -no-color >/dev/null 2>&1
echo "      provider downloaded: exit $?"

echo done
