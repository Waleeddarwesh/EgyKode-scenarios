# Done

- **Pin the provider.** `~> 5.0` accepts 5.90 and refuses 6.0, because a major
  version is where arguments get renamed and defaults change
- **Type and validate your variables.** `environment = "production"` was caught
  locally, in a second, with no API call — the alternative is a fourth
  environment nobody planned
- **A plan is a diff, not a script.** Configuration, state and reality; the plan
  is the difference between them, which is why the second apply does nothing and
  why nothing in your code needs an "if it does not exist" check
- **The configuration wins.** A tag added by hand appeared in the next plan as a
  removal. That is the point of writing infrastructure down, and it is why plans
  get read rather than skimmed
- **State is the only link between your name and the real id.** Lose it and
  Terraform stops knowing that the instance in the account is yours — the next
  apply builds a second one
- **State holds every attribute in plain text**, generated passwords included.
  It belongs in a versioned, encrypted bucket, never in Git
- **`must be replaced` is the line to look for.** Some attributes change in
  place; instance type is not one of them
- **A successful destroy is not proof.** Check the account. Terraform reports
  what it asked for, and the things that keep billing — unattached volumes,
  snapshots, Elastic IPs — are usually the ones it never managed

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the smallest complete loop in the platform: describe, plan, apply,
inspect state, destroy. The remote-state lab moves that state file somewhere a
team can share and adds the lock that keeps two applies apart. The modules lab
takes this single configuration and splits it into pieces that can be called
more than once. Both assume you can read a plan and say what state is for, which
is what you just did.
