# Rules a server enforces, not conventions a team agrees to

Every criterion in this lab is something a **Git server** does. A push it
refuses. A merge it blocks. A reviewer it adds without being asked.

None of that can be shown with `git init --bare` and a hook, because three of
the four need a pull request to happen to. So this runs a real forge — Gitea —
on the machine in front of you, and every refusal you see comes from a server
declining, exactly as GitHub would.

## What you will make it do

- Reject a direct push to `main` with `pre-receive hook declined`
- Refuse a merge while a required status check is failing, and allow it when
  the same check passes
- Request a specific reviewer because a change touched a path they own
- Refuse a pull request that was branched before `main` moved, and accept it
  once it catches up

## Where this differs from GitHub, exactly

The mechanisms are the same and one file's syntax is not. **Gitea matches
CODEOWNERS paths as regular expressions; GitHub matches them as gitignore-style
globs.** So `infra/*` works on GitHub and silently matches nothing here, while
`infra/.*` works here.

That is worth meeting once. It is the shape of most forge-migration bugs: the
file parses, the setting looks right, nothing warns you, and the rule quietly
does not apply. Step 3 makes it happen and step 3's check names it.

Everything else — protection rules, required contexts, the up-to-date
requirement, the API shapes — behaves as you would expect elsewhere.

## Who you are

`ci`, an admin, with a clone already at `/root/platform`. There is a second
user, `platform-lead`, who can review the repository — which matters in step 3,
because CODEOWNERS ignores an owner who has no access.

Setup takes about a minute. Step 1 waits for it.
