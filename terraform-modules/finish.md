# Done

- **A module takes what it needs as an input.** The compute module never
  mentions a VPC, so it works with a network this configuration built, a
  network another team built, or one that predates Terraform entirely
- **Every lookup is a coupling.** A `data "aws_vpc"` filtered by tag would have
  tied the compute module to one naming convention, made it untestable alone,
  and hidden the dependency from Terraform's graph — a runtime query is not a
  reference, so nothing would order the two
- **Compute, do not enumerate.** `cidrsubnet` derives each subnet from whatever
  CIDR the module is given, which is why the second call needed no new inputs
- **`for_each`, not `count`.** Positional addressing means removing one AZ
  renumbers everything after it and Terraform recreates the lot. Keyed
  addressing leaves the others alone
- **The module instance is part of the resource address.**
  `module.network.aws_vpc.this` and `module.network_staging.aws_vpc.this` are
  what keep two calls from colliding — and what lets you target one
- **No ids anywhere.** `module.network.subnet_ids[0]` is a reference, and the
  reference is both the wiring and the ordering

Reach for `for_each` on the module itself when the second near-identical block
appears, not before. A `for_each` written for a single caller is harder to read
than the block it replaced.

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's network is a module exactly like this one, and the reason it is a
module is that dev and production have to be the same shape with different
numbers. Every environment you add from here is a block and a CIDR rather than a
copied directory — which matters most on the day something needs changing in all
of them at once.
