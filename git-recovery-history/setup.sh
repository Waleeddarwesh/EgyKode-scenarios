#!/bin/bash
# Five commits, and a secret committed three commits back — the situation you
# discover rather than the one you create. Finding it already in history is
# what actually happens.
set -e

git config --global user.email "learner@egykode.com"
git config --global user.name "Learner"
git config --global init.defaultBranch main
git config --global --add safe.directory /root/shop

mkdir -p /root/shop && cd /root/shop
git init -q

for i in 1 2; do
  echo "line $i" >> app.txt
  git add app.txt
  git commit -qm "commit $i"
done

# The accident: a real-looking key, committed and then "removed" in the next
# commit — which is exactly the mistake that leaves it in history forever.
printf 'AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMIK7MDENGbPxRfiCY\n' > .env
git add .env
git commit -qm "add config"

git rm --cached .env -q
echo ".env" > .gitignore
git add .gitignore
git commit -qm "stop tracking .env"

for i in 5 6; do
  echo "line $i" >> app.txt
  git commit -qam "commit $i"
done

echo "Repository ready at /root/shop with 6 commits."
