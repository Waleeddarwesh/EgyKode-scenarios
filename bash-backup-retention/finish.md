# Done

The script takes a backup, which was never the hard part. What you added is
everything around it:

- **`set -euo pipefail`** — it stops at the first error instead of reporting
  success after a failed dump
- **A `.partial` name** — a half-written file can never be mistaken for a good
  backup
- **A size check** — every command can exit 0 and still produce nothing
- **Retention on mtime** — the disk does not get to decide when to stop
- **`OnFailure=`** — a failure lands somewhere a check can see it

The one that catches people is the size check. `pg_dump | gzip > out.gz`
succeeds when `pg_dump` fails, because `gzip` compressed an empty stream
perfectly well.

The [EgyKode lab](https://egykode.com/en/labs/lab-22-bash-automation-backup-healthcheck/)
covers the `IFS` setting and the restore drill this scenario leaves out.

---

## Where this fits

**Phase: Operating it** — part of [Build the Production Platform](https://egykode.com/en/labs/).

The platform's database backup is this script with `pg_dump` in place of `tar`. The parts that matter — exit codes, the temporary name, the size check, retention, `OnFailure` — are identical, and they are what make a backup something you can rely on rather than hope for.
