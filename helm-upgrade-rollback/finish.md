# Done

- **Every revision lives in a Secret in the namespace.** That is why a rollback
  is instant — nothing is fetched, nothing is re-rendered — and also why the
  history dies with the namespace
- **`--wait` reports the failure. `--atomic` undoes it.** Same ninety seconds,
  same error, entirely different Monday
- **The failed revision stays in the history**, with its reason, permanently.
  A rollback that hid the attempt would make the postmortem guesswork
- **A rollback is a new revision**, so history is append-only and you can always
  move forward again
- **A rollback restores the whole revision.** Returning to revision 1 brought
  back its replica count too. It is a snapshot, not a targeted undo
- **`helm get values` is the tiebreaker** when the cluster and the repository
  disagree about what is running
- **`--reuse-values` carries forward the value you deliberately removed.**
  `--reset-values` with an explicit values file does not

The one habit worth taking from this whole scenario: **pin the chart version.**
An unpinned `helm upgrade` installs whatever is newest, so the identical command
does something different next week — and the revision you roll back to was built
from a chart you can no longer reproduce.

---

## Where this fits

**Phase: Kubernetes** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Argo CD later in the path renders charts exactly like this one and reconciles
them continuously, which changes where the safety comes from: there is no
`--atomic` on a sync, so the guard moves into health checks and sync windows.
Knowing what a Helm revision *is* — a complete stored snapshot, not a diff — is
what makes the GitOps version comprehensible rather than magic.
