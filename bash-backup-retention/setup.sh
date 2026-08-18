#!/bin/bash
# Data to back up, and one backup that is already too old to keep — so the
# retention rule has something real to delete rather than a file the learner
# has to fabricate.
set -e

mkdir -p /srv/data /var/backups/app /root/bin
printf 'row %s\n' 1 2 3 4 5 > /srv/data/records.csv

# Dated 30 days ago. `find -mtime` reads mtime, so the timestamp is the thing
# that matters, not the name.
touch -d '30 days ago' /var/backups/app/db-old.sql.gz
printf 'stale\n' | gzip -c > /var/backups/app/db-old.sql.gz.tmp
mv /var/backups/app/db-old.sql.gz.tmp /var/backups/app/db-old.sql.gz
touch -d '30 days ago' /var/backups/app/db-old.sql.gz

echo "Ready: data in /srv/data, one 30-day-old backup in /var/backups/app."
