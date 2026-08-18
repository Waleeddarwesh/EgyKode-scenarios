# Where public and private are actually decided

Nothing you have built so far is public or private. Four subnets exist, two
gateways exist, and no traffic can leave any of them. Look:

```
cd ~/network
VPC=$(terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2)
awslocal ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC \
  --query 'RouteTables[].[RouteTableId,Associations[0].Main,Routes[].DestinationCidrBlock]' \
  --output text
```{{exec}}

One route table — the VPC's **main** table, created automatically, with a single
local route for `10.0.0.0/16` and nothing else. Every subnet you made is
currently using it, because a subnet with no explicit association falls back to
the main table.

That is the default state: everything can talk inside the VPC, and nothing can
reach out.

```
cd ~/network
cat > routes.tf <<'TF'
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id     # <- this line
  }

  tags = { Name = "egykode-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id      # <- and this one
  }

  tags = { Name = "egykode-private" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
TF
terraform apply -auto-approve -input=false | tail -3
```{{exec}}

## The line that decides

```
cd ~/network
for T in public private; do
  RT=$(terraform state show aws_route_table.$T | grep -E "^ *id " | head -1 | cut -d'"' -f2)
  echo "== $T ($RT)"
  awslocal ec2 describe-route-tables --route-table-ids $RT \
    --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]' --output text
done
```{{exec}}

There it is:

```
== public
0.0.0.0/0    igw-...       None
== private
0.0.0.0/0    None          nat-...
```

**Same destination, different target.** `0.0.0.0/0` to an internet gateway makes
every subnet associated with that table public. `0.0.0.0/0` to a NAT gateway
makes them private. Swap those two targets and the tags still say `public` and
`private` while the behaviour is exactly reversed — which is why "the difference
is in the route table, not the name" is worth saying out loud.

Nothing in AWS records the words. Grep for them:

```
awslocal ec2 describe-subnets --filters Name=vpc-id,Values=$(cd ~/network && terraform output -raw vpc_id 2>/dev/null || terraform state show aws_vpc.main | grep -E "^ *id " | head -1 | cut -d'"' -f2) \
  --query 'Subnets[].[SubnetId,MapPublicIpOnLaunch]' --output text
```{{exec}}

A subnet knows its CIDR, its zone, and whether it hands out public addresses. It
does not know whether it is public.

## Why inbound cannot reach the private subnets

A NAT gateway performs source translation for connections **started from
inside**. It keeps no rule that would let an outside host open a connection
inward, and there is no route into the private subnets from the internet
gateway — the private route table does not reference it at all.

So the asymmetry in criterion two is a property of the routing, not of a
firewall: outbound has a path, inbound has none.

> LocalStack answers the AWS API faithfully but does not forward real packets,
> so what you have just proved is the routing. On a real account the next step
> is to launch an instance in a private subnet and confirm `curl` works outbound
> while a connection attempt inbound times out.

## Now make the plan quiet

```
cd ~/network
terraform apply -auto-approve -input=false | tail -2
terraform plan -detailed-exitcode -input=false > /dev/null; echo "exit code: $?"
```{{exec}}

Exit `0` — configuration and reality agree.

**Done when:** the public route table sends `0.0.0.0/0` to the internet gateway,
the private one sends it to the NAT gateway, all four subnets are explicitly
associated, and a plan reports no changes.
