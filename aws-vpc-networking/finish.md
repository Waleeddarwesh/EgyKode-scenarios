# Done

- **"Public" and "private" are route table entries**, not settings. `0.0.0.0/0`
  to an internet gateway or to a NAT gateway — swap those two targets and the
  tags lie while the behaviour reverses
- **A subnet with no association silently uses the main route table**, which has
  no internet route. Nothing errors; instances simply reach nothing
- **The NAT gateway goes in a public subnet.** It needs the internet gateway to
  do its job, so placing it in the private subnet it serves creates a loop that
  fails quietly
- **`depends_on` is for a real dependency with no reference to carry it.** The
  NAT gateway names no internet gateway anywhere in its arguments, so without it
  Terraform may build them in the wrong order
- **Leave gaps in your CIDR layout.** Private subnets at `.10` and `.11` mean a
  third availability zone can be added without renumbering anything
- **An internet gateway is free and bidirectional; a NAT gateway bills by the
  hour and only goes outward.** About $32 a month, per gateway, whether or not
  anything uses it
- **One NAT gateway is a single point of failure across zones.** One per AZ
  removes it and doubles the cost. Decide that deliberately
- **Check the Elastic IP after any destroy.** Deleting a NAT gateway does not
  release its address, and an unattached address bills by the hour

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the network everything else in the platform sits inside. The EKS nodes
go in the private subnets and reach the internet through this NAT gateway; the
load balancer goes in the public ones; the database gets a subnet group spanning
both availability zones. Every one of those depends on a layout that was right
at creation time, because subnets, CIDRs and availability zones cannot be
changed afterwards — only rebuilt.
