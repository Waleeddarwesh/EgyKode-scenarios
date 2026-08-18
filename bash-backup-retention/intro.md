There is data in `/srv/data` and a backup directory at `/var/backups/app` that
already holds one file from a month ago.

You will write `/root/bin/backup.sh` and make it trustworthy — which means four
specific things, none of them about taking the backup:

**What you will do**

1. **Fail on the first error** — instead of carrying on and reporting success
2. **Run twice safely** — without duplicating or corrupting the last backup
3. **Prune its own old backups** — so the disk does not decide for you
4. **Signal failure** — where something other than a log reader will see it

Start by looking at what you have:

```
ls -la /srv/data /var/backups/app
```{{exec}}
