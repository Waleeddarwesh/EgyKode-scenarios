# Done

You took a commit to a scanned, tagged image in a registry, and then proved the
gate by making it fire.

**What you can now do**

- Tag an image with the commit that built it, computing the tag *after*
  `checkout scm` — because `env.GIT_COMMIT` does not exist before it
- Keep a registry credential out of both the build log and the process table,
  with `withCredentials` and `--password-stdin`
- Place a scan so that it blocks a push rather than describing one that already
  happened

**The finding worth carrying out of here**

`--ignore-unfixed` and an end-of-life base image cancel each other out. An EOL
distribution ships no fixes, so almost everything it carries is `unfixed`, which
is precisely what the flag discards — `ubuntu:18.04` scans clean for the worst
possible reason. If you want a gate you can trust, test it against a frozen
snapshot of a distribution that *is* still shipping fixes, where the findings are
real and actionable.

A base image is a photograph, not a living thing. The gap between it and the
fixes that exist only widens, so `docker build --pull` on a schedule is not
housekeeping — it is the only thing that moves the image forward.

**Next**

The same machinery scales up: a multibranch pipeline where feature branches
build and scan while only `main` publishes, with a quality gate alongside the
vulnerability one.
