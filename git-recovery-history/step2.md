# Restore a deleted branch

Make a branch with work on it, then delete it the way Git makes you confirm you
mean it:

```
cd /root/shop
git switch -c feature
echo "feature work" >> app.txt
git commit -qam "feature work"
git switch main
git branch -D feature
```{{exec}}

`-D` is the "yes I know it is unmerged" delete. Git even prints the hash it is
about to orphan.

The commit is still there. Find it:

```
git reflog | grep -i feature
```{{exec}}

Create a branch pointing at that hash — replace `<hash>` with what you see:

```
git branch feature-restored <hash>
```

**You should see** `git log --oneline feature-restored` include the
"feature work" commit.
