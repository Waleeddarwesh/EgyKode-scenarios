# Fail on the first error

Write `/root/bin/backup.sh`. The first two lines matter more than the rest:

```
mkdir -p /root/bin
cat > /root/bin/backup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/app}"
SRC="${SRC:-/srv/data}"
STAMP="$(date +%Y-%m-%dT%H-%M-%S)"
TARGET="${BACKUP_DIR}/db-${STAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

# Write to a temporary name first: a partial file that is never renamed can
# never be mistaken for a good backup.
tmp="${TARGET}.partial"
# Guarantees the partial never survives, whether the script succeeds or dies
# at the first error. tar creates the file before it discovers the source is
# missing, so cleaning up only on the success path leaves rubbish behind.
trap 'rm -f "$tmp"' EXIT
tar -czf "$tmp" -C "$SRC" .

size=$(stat -c %s "$tmp")
if [ "$size" -lt 100 ]; then
  echo "backup is suspiciously small: ${size} bytes" >&2
  rm -f "$tmp"
  exit 1
fi

mv "$tmp" "$TARGET"
echo "wrote $TARGET"
EOF
chmod +x /root/bin/backup.sh
/root/bin/backup.sh
```{{exec}}

`set -e` exits on the first failing command. `-u` makes an unset variable an
error — which is what stops `rm -rf "$DIR"/*` becoming `rm -rf /*`.
`-o pipefail` fails a pipeline when *any* stage failed, not only the last.

Prove the failure path works, by pointing it at a source that does not exist:

```
SRC=/does/not/exist /root/bin/backup.sh; echo "exit=$?"
```{{exec}}

**You should see** a non-zero exit and **no** new file left behind.
