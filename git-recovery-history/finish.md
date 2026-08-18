# Done

Three recoveries, and one that is not a recovery at all:

- **A hard reset** is undone from the reflog. Local work is almost never lost.
- **A deleted branch** is a name removed, not a commit destroyed.
- **A secret in history** is different in kind. You rewrote every commit and
  dropped the backups, and the key is genuinely gone from this repository.

And still not safe. Anyone who cloned before the rewrite has it, and every
fork and CI cache may too. **The only real fix is to rotate the key.** History
rewriting limits the exposure; it does not end it.

The [EgyKode lab](https://egykode.com/en/labs/lab-git-recovery-history/) covers
when `revert` is correct and `reset` is not — a judgement no verification
script can check.

---

## Where this fits

**Phase: Foundations** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Everything in the platform is delivered by a commit — the manifests Argo CD watches, the Jenkinsfile, the Terraform. Recovering work and removing a secret from history are the two Git skills the rest of the build depends on.
