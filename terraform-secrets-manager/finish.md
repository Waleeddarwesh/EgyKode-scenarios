# Done

A password nobody chose, stored where an application can ask for it, and a
database that moved without the application noticing.

**What you can now do**

- Generate a credential with `random_password` and hand it straight to Secrets
  Manager, so it exists in no configuration file and no chat message
- Say where it *does* exist — `terraform.tfstate`, in plaintext — and act on
  that: never commit state, encrypt it remotely, treat the file as the
  credential it contains
- Store the endpoint alongside the password, so an application that reads one
  secret has everything it needs to connect
- Fetch at run time rather than at build or deploy time, and prove it by
  rotating the secret and watching the application follow
- State what Multi-AZ protects against — zone loss, host failure, planned
  maintenance — and what it does not: `DROP TABLE`, a bad migration, corruption
  the application wrote, a deleted instance, a lost region

**The two sentences worth keeping**

*Multi-AZ is availability, not durability.* The standby is synchronous, so it
receives your mistakes as faithfully as your data. Backups you have restored
from are the other half, and they are a different lab for a reason.

*A secret's value is only half of it.* The endpoint is the half that changes
during an incident, and every place it was written down is a place someone has
to find at 3am. One fetch, one secret, one update.

**What needed an account**

RDS itself — Multi-AZ, the private endpoint, and verifying both from outside
the VPC. Not faked here. The cloud version of this lab is where that belongs,
and it is worth doing once on a free-tier instance you then delete.

**Next**

The password is safe and the database is still one disk in one place. Taking a
backup, corrupting the data on purpose, and restoring from it — while timing
how long it took — is what turns this into something you would trust.
