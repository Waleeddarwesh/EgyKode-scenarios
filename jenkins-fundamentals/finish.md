# Done

- **Everything Jenkins knows is in `JENKINS_HOME`.** There is no database. Jobs,
  history, credentials and plugins are one directory that either persists or
  does not
- **A named volume outlives the container.** You deleted the container entirely
  and the job was still there. On the container's writable layer, that `down`
  would have wiped every job and presented a fresh setup wizard as though
  nothing had happened
- **`allowsSignup: false`.** Jenkins with signup enabled and a reachable port is
  an open build server — an account anyone can create, running shell commands on
  your host
- **401 and 403 are different answers.** "I do not know who you are" versus "I
  know, and no". Anonymous gets 403 because it *is* an authenticated identity
  with no permissions
- **`Job/Read` and `Job/Build` are separate permissions**, one line apart. The
  viewer could see the job and was refused when starting it — 403 against the
  running server, not a reading of the matrix
- **The CSRF crumb is tied to the session.** Without it a link in an email could
  start a build, or delete a job, using whoever clicked it

Configuration as code is what made all of this reviewable: the users, the
permission matrix and the signup setting are a file you can diff, not a sequence
of clicks nobody recorded.

## One criterion this scenario does not cover

The lab also asks for **a job that builds automatically when a commit is
pushed**. That needs a repository Jenkins can be notified by, and doing it
honestly here would mean a bare repo and a `post-receive` hook standing in for a
webhook. It is covered in the local environment, where a real remote exists.

---

## Where this fits

**Phase: CI/CD** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the server the pipeline runs on. The next lab gives it something worth
building — an image tagged by commit, scanned before it ships — and both depend
on the two properties established here: a Jenkins whose configuration survives,
and one where the set of people who can start a build is a decision rather than
an accident.
