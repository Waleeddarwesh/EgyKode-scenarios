# Two gateways that are not alike

```
cd ~/network
cat > gateways.tf <<'TF'
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "egykode-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "egykode-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["us-east-1a"].id

  tags = { Name = "egykode-nat" }

  # The gateway is useless until the VPC has a way out, and Terraform cannot
  # infer that from any reference between them.
  depends_on = [aws_internet_gateway.main]
}
TF
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

```
awslocal ec2 describe-internet-gateways \
  --query 'InternetGateways[].[InternetGatewayId,Attachments[0].VpcId]' --output text
awslocal ec2 describe-nat-gateways \
  --query 'NatGateways[].[NatGatewayId,State,SubnetId]' --output text
awslocal ec2 describe-addresses \
  --query 'Addresses[].[PublicIp,AllocationId]' --output text
```{{exec}}

## The differences that matter

| | Internet Gateway | NAT Gateway |
| --- | --- | --- |
| Direction | **Both ways** | **Outbound only** |
| Cost | Free | **Per hour, plus per GB** |
| Placement | On the VPC | In a **subnet** |
| How many | One per VPC | One per AZ, if you want AZ-independence |

**The internet gateway is free and bidirectional.** It is what lets a public
instance be reached from outside — and what lets it reach out.

**The NAT gateway is one-directional and it bills by the hour**, around $0.045
plus data processing, whether or not anything uses it. That is roughly $32 a
month per gateway, and it is consistently the largest surprise on a first AWS
bill. A private instance can start a connection through it; nothing outside can
start a connection back. That asymmetry is the entire point.

**The NAT gateway lives in a public subnet.** This catches people every time:
it needs a route to the internet gateway to do its job, so putting it in the
private subnet it serves creates a loop where nothing works and nothing errors.

## The dependency Terraform cannot see

`depends_on = [aws_internet_gateway.main]` is there because nothing in the NAT
gateway's arguments refers to the internet gateway. Terraform builds its graph
from references, so without that line it may create the NAT gateway first — in a
VPC with no way out — and on real AWS the result is a gateway stuck in `pending`
and then `failed`.

**An explicit `depends_on` is for exactly this: a real dependency with no
reference to carry it.** Most of the time a reference already exists and adding
`depends_on` is noise.

## One NAT gateway, or one per zone

This configuration has one, in `us-east-1a`. If that zone fails, private subnets
in `us-east-1b` lose outbound access — their route still points at a gateway in
a dead zone.

One per AZ removes the dependency and doubles the bill. **That is the trade,
stated plainly**, and it is a decision to take deliberately rather than
discover during an outage.

**Done when:** an internet gateway is attached to the VPC, and a NAT gateway is
available in a public subnet with an Elastic IP.
