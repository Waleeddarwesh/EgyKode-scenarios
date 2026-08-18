#!/bin/bash
# State, not history of commands: does the branch exist, is it based on main,
# and is the discount actually in the file?
cd /root/shop 2>/dev/null || { echo "No repository at /root/shop"; exit 1; }

git rev-parse --verify feature/discount >/dev/null 2>&1 || {
  echo "FAIL: branch feature/discount does not exist"; exit 1; }

# Linear means main is an ancestor of the branch tip.
git merge-base --is-ancestor main feature/discount || {
  echo "FAIL: feature/discount is not rebased onto main"; exit 1; }

git show feature/discount:app.py 2>/dev/null | grep -q "def discounted" || {
  echo "FAIL: the discount function is not on the branch"; exit 1; }

echo "PASS"
exit 0
