#!/bin/bash
# Searches the repository the way an attacker with a clone would. Anything less
# — checking the working tree, or only HEAD — passes while the key is still
# one `git log -S` away.
fail() { echo "$1"; exit 1; }
cd /root/shop 2>/dev/null || fail "No repository at /root/shop."

SECRET='wJalrXUtnFEMIK7MDENG'

# Reachable from any ref, at any point in history.
hits=$(git log --all --oneline -S "$SECRET" 2>/dev/null | wc -l)
[ "$hits" -eq 0 ] \
  || fail "The key is still in $hits commit(s) reachable from a ref. Rewrite history with filter-branch, then drop refs/original."

# filter-branch's own backup. Leaving it behind is the most common way this
# job is declared finished while the secret is still there.
[ -d .git/refs/original ] \
  && fail "refs/original/ still holds the pre-rewrite commits, and the key with them. Run: rm -rf .git/refs/original"

# Every object, not only the reachable ones. `rev-list --all` walks refs, so it
# reported success while the blob still sat in the object database behind an
# unexpired reflog - one `git fsck --lost-found` away from being read again.
if git cat-file --batch-all-objects --batch 2>/dev/null | grep -q "$SECRET"; then
  fail "The key still exists as an object in this repository. Run: git reflog expire --expire=now --all && git gc --prune=now"
fi

echo "PASS"
