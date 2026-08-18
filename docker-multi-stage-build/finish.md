# Done

You shipped three images and measured the difference between them: a build
stage that never leaves the builder, and a process that does not run as root.

Both are the default expectation in production, and neither is the default in
Docker.

Return to EgyKode to record what you proved. The remaining criterion there —
a container that refuses to start until its database is reachable — needs a
second service and is not part of this environment.
