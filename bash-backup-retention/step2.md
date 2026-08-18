# Safe to run twice, and self-pruning

Two properties a scheduled job needs, and neither is about taking the backup.

**Running twice must not corrupt the last one.** Your script already timestamps
each archive and writes to a `.partial` name first, so this is close to free —
confirm it:

```
/root/bin/backup.sh
/root/bin/backup.sh
ls -la /var/backups/app
```{{exec}}

**Old backups must go, automatically.** There is a file in there dated 30 days
ago. Add retention to the end of the script:

```
cat >> /root/bin/backup.sh <<'EOF'

RETENTION_DAYS="${RETENTION_DAYS:-7}"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'db-*' -mtime "+${RETENTION_DAYS}" -delete
echo "pruned backups older than ${RETENTION_DAYS} days"
EOF
/root/bin/backup.sh
ls -la /var/backups/app
```{{exec}}

**You should see** several dated archives and **no** `db-old.sql.gz`.

`-mtime +7` reads the modification time, not the name — so a file whose name
lies about its date is still pruned correctly.
