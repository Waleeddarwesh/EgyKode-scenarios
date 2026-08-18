# Done

- **The state bucket cannot be created by the backend that uses it.** That is
  not a design flaw to route around — it is why the bucket is a small separate
  configuration, applied once
- **Versioning is the setting you will be glad of.** State is the only record of
  what exists, and a truncated write is recoverable only from the previous
  version
- **State holds every value Terraform touched**, passwords included, in plain
  text. Encryption and a public access block are not paperwork
- **`LockID` is not a name you may choose.** A different hash key means the
  backend writes a lock nothing reads
- **Migration copies a file; it touches no resources.** The proof is a plan that
  reports no changes, and it is worth running every time
- **The leftover `terraform.tfstate` is stale** after a migration. Its timestamp
  stops moving. Delete it before somebody trusts it
- **`key` separates configurations inside one bucket** — and two configurations
  sharing a key is a quiet way for one to delete the other's resources
- **The lock table always has a `-md5` row.** It is a digest, not a lock. "There
  is a row in the table" is not "something is locked"
- **`force-unlock` takes one specific ID** because you are meant to read `Who`
  and `Created` first. The error prints `RequestID` too, and using that one does
  nothing at all
- **`-lock=false` is not the fix.** It disables locking rather than releasing the
  lock, which reintroduces exactly the concurrent write the lock prevents

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Everything the platform builds in AWS is tracked in this state file. Once CI
applies Terraform, the lock is what stops a scheduled drift check and a merge to
main from writing at the same moment — and the versioned bucket is what you
restore from when something writes state you did not intend. The gate scenario
put checks in front of the apply; this puts the state somewhere the whole team,
and the pipeline, can safely share.
