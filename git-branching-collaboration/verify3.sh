#!/bin/bash
# Recovery is proven by the tree, not by the reflog being read.
cd /root/shop 2>/dev/null || { echo "No repository at /root/shop"; exit 1; }
git switch feature/discount -q 2>/dev/null || {
  echo "FAIL: branch feature/discount is missing"; exit 1; }

git show feature/discount:app.py 2>/dev/null | grep -q "def discounted" || {
  echo "FAIL: the discount function is not on the branch — the reset has not been recovered"; exit 1; }

# Two commits were removed; recovery must restore that depth.
[ "$(git rev-list --count feature/discount)" -ge 4 ] || {
  echo "FAIL: history is still short — the branch has not been restored"; exit 1; }

echo "PASS"
exit 0
