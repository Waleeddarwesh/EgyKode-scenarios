#!/bin/bash
# Runs the learner's script in a sandbox copy, so the check proves behaviour
# rather than reading the source for the string "set -e" — which any script
# could contain in a comment while still swallowing errors.
fail() { echo "$1"; exit 1; }

S=/root/bin/backup.sh
[ -f "$S" ] || fail "No script at /root/bin/backup.sh yet."
[ -x "$S" ] || fail "$S is not executable. Run: chmod +x $S"

# It must succeed on good input and leave exactly one new archive.
sandbox=$(mktemp -d)
out=$(BACKUP_DIR="$sandbox" SRC=/srv/data "$S" 2>&1) || {
  rm -rf "$sandbox"; fail "The script failed on valid input: $out"
}
made=$(find "$sandbox" -maxdepth 1 -type f ! -name '*.partial' | wc -l)
[ "$made" -eq 1 ] || { rm -rf "$sandbox"; fail "Expected one archive, found $made."; }

# And it must fail on a missing source, leaving nothing behind — the whole
# point of set -e plus the temporary-name pattern.
sandbox2=$(mktemp -d)
if BACKUP_DIR="$sandbox2" SRC=/does/not/exist "$S" >/dev/null 2>&1; then
  rm -rf "$sandbox" "$sandbox2"
  fail "The script exited 0 with a source that does not exist. Add 'set -euo pipefail' so it stops at the first error."
fi
left=$(find "$sandbox2" -maxdepth 1 -type f | wc -l)
rm -rf "$sandbox" "$sandbox2"
[ "$left" -eq 0 ] || fail "The failed run left $left file(s) behind. Write to a .partial name and only rename on success."

echo "PASS"
