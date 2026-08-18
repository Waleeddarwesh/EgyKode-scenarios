#!/bin/bash
# LocalStack stands in for AWS. S3 and DynamoDB are the two services this
# scenario needs, and both are in the free image - so the backend, the
# versioning, the encryption and the lock table all behave as they would in a
# real account, at no cost and with no credentials to leak.
echo "Installing Terraform..."
command -v unzip >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip curl >/dev/null 2>&1
}
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/tf.zip 2>/dev/null
  unzip -q -o /tmp/tf.zip -d /usr/local/bin 2>/dev/null
fi

echo "Starting LocalStack (this pulls an image; give it a minute)..."
docker rm -f localstack >/dev/null 2>&1
docker run -d --name localstack -p 4566:4566 \
  -e SERVICES=s3,dynamodb -e DEBUG=0 \
  localstack/localstack:3.8 >/dev/null 2>&1

echo "Waiting for S3 and DynamoDB..."
for i in $(seq 1 60); do
  if curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -qE '"s3": *"(available|running)"'; then
    echo "LocalStack is ready."
    break
  fi
  sleep 3
done

mkdir -p /root/platform
echo done
