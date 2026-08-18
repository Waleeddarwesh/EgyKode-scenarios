# Two resources, one apply

A data source first. It asks AWS a question at plan time rather than hardcoding
the answer:

```
cd ~/infra
cat > main.tf <<'TF'
data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["*"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name        = "egykode-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "egykode-${var.environment}-app"
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.app.id
  associate_public_ip_address = true

  tags = {
    Name        = "egykode-${var.environment}-app"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "assets" {
  bucket = "${var.bucket_name}-${var.environment}"

  tags = {
    Environment = var.environment
  }
}
TF
cat > outputs.tf <<'TF'
output "instance_id" {
  description = "Id of the application instance"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public address of the application instance"
  value       = aws_instance.app.public_ip
}

output "bucket_name" {
  description = "Name of the asset bucket"
  value       = aws_s3_bucket.assets.bucket
}
TF
terraform init -input=false > /dev/null
echo written
```{{exec}}

**Hardcoding an AMI id is how a configuration becomes region-locked and stale.**
The same image has a different id in every region, and the id you wrote down
last year is now a machine with unpatched packages.

Nothing here says what order to build in. `aws_instance.app` refers to
`aws_subnet.app.id`, which refers to `aws_vpc.main.id`, and Terraform reads those
references as a dependency graph — VPC, then subnet, then instance, with the
bucket built in parallel because nothing connects it to any of them.

```
cd ~/infra
terraform apply -auto-approve -input=false | tail -8
```{{exec}}

Four resources. Read the outputs:

```
cd ~/infra
terraform output
```{{exec}}

An instance id, a public address, a bucket name — the values another
configuration or a deploy script would consume.

## Confirm it against the API

The apply says what Terraform believes. Ask AWS:

```
awslocal ec2 describe-instances \
  --filters Name=tag:Environment,Values=dev \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' --output text
awslocal s3 ls
```{{exec}}

`t3.micro`, running, and the bucket is listed. **The instance type came from
`var.instance_type`** — change the variable and the same configuration builds a
different size, which is the entire reason it is a variable and not a literal.

```
cd ~/infra
terraform plan -var instance_type=t3.small | grep -E "must be replaced|instance_type|# aws_instance" | head -5
```{{exec}}

Note `must be replaced` and the `-/+` on that resource. Some attributes can be
changed in place; instance type cannot, so Terraform would destroy and recreate.
**That is the line you look for in every plan**, and it is why the next step is
about reading plans rather than running them.

**Done when:** an instance and a bucket exist, the instance is `t3.micro`, and
the three outputs have values.
