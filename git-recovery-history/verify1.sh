#!/bin/bash
# The repository's state, not the commands used to reach it. A learner who
# recovers with a hash from the reflog rather than HEAD@{1} has done the same
# thing and learned the same lesson.
fail() { echo "$1"; exit 1; }
cd /root/shop 2>/dev/null || fail "No repository at /root/shop."

count=$(git rev-list --count HEAD 2>/dev/null)
[ "$count" = "6" ] || fail "HEAD is at $count commit(s); it should be back to 6. Find the pre-reset entry in 'git reflog' and reset --hard to it."

# The reset must actually have happened — otherwise the step was skipped and
# the branch simply never moved. The reflog is where that evidence lives.
git reflog | grep -q "reset:" \
  || fail "No reset appears in the reflog. Run the 'git reset --hard HEAD~3' first, then recover from it."

echo "PASS"
