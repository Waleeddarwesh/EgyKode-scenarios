#!/bin/bash
# Three tools, none of which are on the base image. Each install is guarded so
# a re-run costs nothing.
command -v unzip >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip curl >/dev/null 2>&1
}

if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/tf.zip 2>/dev/null
  unzip -q -o /tmp/tf.zip -d /usr/local/bin 2>/dev/null
fi

command -v trivy >/dev/null 2>&1 || \
  curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh 2>/dev/null | sh -s -- -b /usr/local/bin >/dev/null 2>&1

command -v tflint >/dev/null 2>&1 || \
  curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh 2>/dev/null | bash >/dev/null 2>&1

mkdir -p /root/infra
echo done
