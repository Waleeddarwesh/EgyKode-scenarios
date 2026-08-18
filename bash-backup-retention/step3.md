# A failure nobody has to read logs to notice

A backup that fails silently is worse than no backup: you believe you have one.

Schedule it with a systemd timer and attach a failure handler.

```
cat > /etc/systemd/system/db-backup.service <<'EOF'
[Unit]
Description=Application backup
OnFailure=db-backup-failed.service

[Service]
Type=oneshot
ExecStart=/root/bin/backup.sh
EOF

cat > /etc/systemd/system/db-backup-failed.service <<'EOF'
[Unit]
Description=Record that the backup failed

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'date -Is > /var/backups/app/LAST_FAILURE'
EOF

cat > /etc/systemd/system/db-backup.timer <<'EOF'
[Unit]
Description=Nightly application backup

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now db-backup.timer
systemctl list-timers db-backup.timer --no-pager
```{{exec}}

`Persistent=true` runs a missed job when the machine comes back. A cron job on
a machine that was asleep at 02:30 simply never runs, and nothing says so.

Now prove the alarm works — run the service against a source that does not
exist:

```
systemctl set-environment SRC=/does/not/exist
systemctl start db-backup.service
systemctl unset-environment SRC
ls -la /var/backups/app/LAST_FAILURE
```{{exec}}

**You should see** a `LAST_FAILURE` file containing a timestamp. That is
something a monitoring check can look at without anyone reading a journal.
