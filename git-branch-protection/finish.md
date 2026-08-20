# Done

Four rules, each one watched doing its job and then watched letting the change
through once the reason was gone.

**What you can now do**

- Protect a branch so the *server* refuses direct pushes, and explain why that
  is different in kind from a local hook anyone can skip with `--no-verify`
- Require a status check by context name, and recognise the two ways it goes
  wrong: a context nothing posts blocks every merge, and a typo'd one blocks
  nothing
- Route review by path with CODEOWNERS, and check the behaviour rather than the
  file — including the control case, where an unowned path requests nobody
- Say what "require branches to be up to date" costs and what it buys

**The failure that setting exists for**

Two pull requests, each green, each touching different files. No conflict, so
Git merges both happily, and `main` is broken by a combination neither build
ever saw. A function renamed in one, a new caller added in the other. Requiring
up-to-date means the branch is tested against what `main` is, not against what
it was when you started.

The price is real: on a busy repository every merge invalidates every other open
PR. That is what merge queues solve — batch the pending changes, test them
together once, merge the batch. Turn the rule on when a broken `main` costs more
than the waiting; reach for a queue when the waiting starts costing more.

**The one thing that is not portable**

CODEOWNERS is a regular expression here and a gitignore glob on GitHub. Nothing
told you — the file parsed and no reviewer appeared. Whichever forge you are on,
open one pull request that *should* match and one that *should not*, and look at
who was requested. Two minutes, and it is the only way to know the rule is
routing review rather than just existing.

**Next**

The check that was reported by hand here is what a pipeline posts at the end of
a build. Wiring one up — build, scan, and a status the branch protection then
depends on — is the CI lab.
