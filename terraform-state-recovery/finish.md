# Done

Four situations that all look like Terraform is broken, and four repairs that
touch no infrastructure at all.

- **Drift has two correct resolutions**, and they mean opposite things.
  `apply` reasserts the code; editing the code adopts the change. Choosing is
  not a Terraform question — it is asking whether the person who made the change
  knew something you did not
- **A resource outside state is invisible, not wrong.** It will not be updated by
  your code and not removed by `destroy`, and it outlives everyone who knew
  about it
- **Write the configuration before importing**, and treat the import as
  unfinished until `plan` is quiet. If they disagree, change the code — never
  apply and let Terraform "correct" a resource somebody is relying on
- **`import` writes only to state.** It is the one operation that adds a
  resource to Terraform's world while creating nothing
- **Versioning turns a deleted state file into a delete marker.** Remove the
  marker and the previous version is uncovered. Without versioning the recovery
  is importing everything by hand
- **A resource's address is its identity.** Renaming the label in your code is a
  destroy and recreate, and the diff is one word
- **`moved` is committed; `state mv` is not.** The command fixes your machine.
  The block fixes everyone's, including CI and the person doing this next year

The habit that makes all of it cheap: **`terraform state pull > backup.tfstate`
before anything unusual**, and never edit state in a text editor — the
subcommands write a valid file, an editor writes one that parses and lies.

---

## Where this fits

**Phase: Production** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Everything the platform builds in AWS is tracked in one state file, and the day
it disagrees with reality is not the day to be learning `import`. The
remote-state lab put that file somewhere versioned and locked; this is what that
versioning was for.
