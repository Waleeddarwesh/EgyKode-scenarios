#!/bin/bash
# A repository with enough history to branch from, and a second "colleague"
# commit already on main so the conflict in step 2 is real rather than staged
# by the learner against themselves.
set -e

git config --global user.email "learner@egykode.com"
git config --global user.name "Learner"
git config --global init.defaultBranch main

mkdir -p /root/shop && cd /root/shop
git init -q

cat > app.py <<'PY'
PRICE = 100
def total(qty):
    return PRICE * qty
PY
git add app.py && git commit -q -m "Add pricing"

# The colleague's change, already on main. The learner's branch will touch the
# same line, which is what produces a genuine conflict rather than a contrived
# one.
cat > app.py <<'PY'
PRICE = 120
def total(qty):
    return PRICE * qty
PY
git add app.py && git commit -q -m "Raise price to 120"

echo "Repository ready at /root/shop"
