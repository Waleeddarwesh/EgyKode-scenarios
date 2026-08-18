#!/bin/bash
echo "Installing Terraform and the AWS CLI..."
command -v unzip >/dev/null 2>&1 || {
  apt-get update -qq >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip curl >/dev/null 2>&1
}
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/tf.zip 2>/dev/null
  unzip -q -o /tmp/tf.zip -d /usr/local/bin 2>/dev/null
fi
command -v aws >/dev/null 2>&1 || \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq awscli >/dev/null 2>&1

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
  -e SERVICES=s3,ec2,iam,sts -e DEBUG=0 \
  localstack/localstack:3.8 >/dev/null 2>&1

echo "Waiting for EC2 and S3..."
for i in $(seq 1 60); do
  if curl -s --max-time 5 http://localhost:4566/_localstack/health 2>/dev/null | grep -qE '"ec2": *"(available|running)"'; then
    echo "LocalStack is ready."
    break
  fi
  sleep 3
done

mkdir -p /root/platform
echo done
