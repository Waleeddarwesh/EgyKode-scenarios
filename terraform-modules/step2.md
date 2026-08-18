# The compute module, which knows nothing about VPCs

```
mkdir -p ~/platform/modules/compute && cd ~/platform/modules/compute

cat > variables.tf <<'TF'
variable "name" {
  description = "Name for the instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet to place the instance in"
  type        = string
}

variable "instance_type" {
  description = "Instance size"
  type        = string
  default     = "t3.micro"
}
TF

cat > main.tf <<'TF'
data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["*"]
  }
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = { Name = var.name }
}
TF

cat > outputs.tf <<'TF'
output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}
TF
ls
```{{exec}}

Look at what is **not** in that module.

There is no `vpc_id`. There is no `aws_vpc` resource and no `data "aws_vpc"`
lookup. There is no `cidr_block`, no availability zone, and nothing that names
the network module. The compute module is handed a subnet id as a string and
has no opinion about where it came from.

## Why that restraint is the whole design

Suppose the compute module did look up the VPC — `data "aws_vpc"` filtered by a
name tag, say. Three things would immediately be true:

- **It would only work with networks built by that other module**, because it
  would depend on that module's tagging convention. Hand it a subnet from an
  existing corporate VPC and the lookup finds nothing
- **It could not be tested on its own.** Every plan would need a VPC that
  matches the filter to exist first
- **The dependency would be invisible.** Terraform builds its graph from
  references between resources. A `data` lookup by tag is a runtime query, not a
  reference, so nothing guarantees the VPC is created before the lookup runs —
  and the failure appears as an empty result rather than a dependency error

Passing `subnet_id` in makes the dependency **explicit and visible**: the value
flows from one module's output to another's input, and Terraform can see it.

That is the general rule, and it is worth stating plainly: **a module should
take what it needs as an input, not go looking for it.** Every lookup a module
performs is a coupling to something outside its control.

## Wire them together

```
cd ~/platform
cat > main.tf <<'TF'
module "network" {
  source = "./modules/network"

  name       = "demo"
  cidr_block = "10.20.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}

module "app" {
  source = "./modules/compute"

  name      = "demo-app"
  subnet_id = module.network.subnet_ids[0]
}
TF

cat > outputs.tf <<'TF'
output "network_vpc" {
  value = module.network.vpc_id
}

output "app_instance" {
  value = module.app.instance_id
}
TF
terraform init -input=false > /dev/null
terraform apply -auto-approve -input=false | tail -3
terraform output
```{{exec}}

**There is not a single id written down anywhere.** `module.network.subnet_ids[0]`
is a reference, and the reference is what tells Terraform to build the subnet
before the instance. Change the CIDR and everything downstream follows; no
lookup table, no second place to edit.

Confirm the instance really landed in the module's subnet:

```
cd ~/platform
INSTANCE=$(terraform output -raw app_instance)
awslocal ec2 describe-instances --instance-ids $INSTANCE \
  --query 'Reservations[].Instances[].[InstanceId,SubnetId,PrivateIpAddress]' --output text
awslocal ec2 describe-subnets --subnet-ids $(terraform output -json | grep -o 'subnet-[a-z0-9]*' | head -1) \
  --query 'Subnets[].[SubnetId,CidrBlock]' --output text 2>/dev/null
```{{exec}}

The private address is inside `10.20.0.0/24` — the subnet the network module
computed, handed to a module that has never heard of a VPC.

**Done when:** an instance exists in a subnet belonging to the module's VPC, and
`modules/compute` contains no reference to `aws_vpc`.
