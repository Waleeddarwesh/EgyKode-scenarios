# A credential no human ever sees

The usual database password was chosen by somebody, typed into a Terraform
variable, pasted into a Slack message so the application team could configure
their side, and has been the same for two years because rotating it means
finding everywhere it went.

You are going to build the other version: a password Terraform generates,
stores in Secrets Manager with the endpoint beside it, and that the application
fetches at run time — so rotating it is one API call and moving the database is
one update.

## What is real here, and what is not

The database is a **real PostgreSQL**. It really refuses a wrong password,
which is what makes step 2's test mean anything. Secrets Manager is **really
running** — it is in the free LocalStack image — so the storage, versioning and
retrieval are genuine.

**RDS itself is not.** The lab's first criterion is "the database is Multi-AZ
and has no public endpoint, verified from outside the VPC", and creating an RDS
instance against the free image returns `API for service 'rds' not yet
implemented or pro feature`.

That criterion is **not simulated**. A fake `MultiAZ: true` in a response would
teach you that you had verified something you had not, which is worse than
being told where the boundary is. Step 3 covers the reasoning the lab asks for —
what Multi-AZ protects against and what it does not — and says plainly which
part needs an account.

The three criteria about the credential are the ones that transfer to every
database you will ever run, managed or otherwise, and those are real here.

## What you will end up with

- A 24-character password that exists in Secrets Manager and in no
  configuration file — and one place you might not expect, which step 1 makes
  you look at
- An application whose entire configuration is the *name of a secret*
- A database that moves, and an application that follows it without being
  edited, redeployed, or restarted with new settings

Setup installs Terraform and downloads the AWS provider, which takes about a
minute. Step 1 waits for it.
