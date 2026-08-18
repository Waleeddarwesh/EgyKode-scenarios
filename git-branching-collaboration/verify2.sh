#!/bin/bash
# The resolved file is the evidence. A rebase left mid-flight, or markers left
# in the file, both fail — either means the conflict was not actually resolved.
cd /root/shop 2>/dev/null || { echo "No repository at /root/shop"; exit 1; }

# Explicit if, not `[ a ] || [ b ] && { }` — that parses as `(a||b) && c` and
# happens to be right here, which is exactly how it survives until someone
# edits it and it silently stops firing.
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  echo "FAIL: a rebase is still in progress — finish it with git rebase --continue"
  exit 1
fi

git switch feature/discount -q 2>/dev/null

grep -qE '^(<<<<<<<|=======|>>>>>>>)' app.py && {
  echo "FAIL: conflict markers are still in app.py"; exit 1; }

git merge-base --is-ancestor main feature/discount || {
  echo "FAIL: the branch is not rebased onto main"; exit 1; }

grep -qE '^PRICE = [0-9]+' app.py || {
  echo "FAIL: PRICE is missing or malformed in app.py"; exit 1; }

grep -q "def discounted" app.py || {
  echo "FAIL: the discount function was lost during the resolution"; exit 1; }

echo "PASS"
exit 0
