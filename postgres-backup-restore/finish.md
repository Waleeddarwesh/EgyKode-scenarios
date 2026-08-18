# Done

- **`-Fc` carries a table of contents**, so `pg_restore --list` can read the
  archive back without touching a database. That single command is the
  difference between having a backup and having a file
- **Verify inside the backup script**, and delete anything that fails. A script
  that checks only "did the file appear" reports success for weeks
- **Count the tables too.** An empty dump is a perfectly valid archive, and the
  file size will not tell you — dump the wrong database and you get a readable
  file containing nothing
- **A corrupted archive looks identical on disk.** Same size, same name, same
  timestamp. Only the tool that has to read it can tell
- **RTO is what you measured**, not what you hoped. It includes starting the
  service and confirming the data, not just the `pg_restore` line
- **RTO and RPO are different promises.** Restoring faster does nothing for the
  RPO — that is set by how often you back up, and nightly means up to a day of
  writes gone
- **Check a total, not just row counts.** Counts prove a restore ran; a checksum
  proves it restored the right rows
- **Verify the archive before destroying the database.** Under pressure the
  instinct is to clear the broken thing first, and that ordering turns a corrupt
  backup into permanent data loss

The drill is the deliverable. A runbook nobody has followed is a document, and
the failure it eventually catches is always a change somebody made months
earlier to something they did not know was in the recovery path.

---

## Where this fits

**Phase: Production** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's database is the one component whose loss is not recoverable by
redeploying. Everything else in the path — the cluster, the images, the
manifests — can be rebuilt from Git in minutes. This cannot, and the difference
between a backup and a tested restore is the whole of that gap.
