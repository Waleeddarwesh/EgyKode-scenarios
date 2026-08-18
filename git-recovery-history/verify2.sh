#!/bin/bash
# Any branch pointing at the orphaned commit counts. The lesson is that the
# commit survived and can be reached again, not that a particular name was used.
fail() { echo "$1"; exit 1; }
cd /root/shop 2>/dev/null || fail "No repository at /root/shop."

# The work must exist as a commit somewhere reachable.
target=$(git log --all --format='%H %s' | awk '$2=="feature" && $3=="work" {print $1; exit}')
[ -n "$target" ] || target=$(git log --all --oneline --grep='feature work' --format='%H' | head -1)
[ -n "$target" ] || fail "No commit called 'feature work' is reachable from any branch. Recover it from the reflog: git branch feature-restored <hash>"

# It must not be the deleted branch still being alive — that would mean the
# delete never happened and nothing was recovered.
git show-ref --verify --quiet refs/heads/feature \
  && fail "The 'feature' branch still exists, so nothing was deleted or recovered. Run: git branch -D feature"

# And some branch other than main must point at it.
found=""
for ref in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  [ "$ref" = "main" ] && continue
  if git merge-base --is-ancestor "$target" "$ref" 2>/dev/null; then found="$ref"; break; fi
done
[ -n "$found" ] || fail "The commit survives in the reflog but no branch points at it yet. Create one: git branch feature-restored <hash>"

echo "PASS"
