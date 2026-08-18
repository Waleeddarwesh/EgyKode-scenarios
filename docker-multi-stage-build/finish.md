# Done

You shipped three images and measured the difference between them: a build
stage that never leaves the builder, and a process that does not run as root.

Both are the default expectation in production, and neither is the default in
Docker.

Return to EgyKode to record what you proved. The remaining criterion there —
a container that refuses to start until its database is reachable — needs a
second service and is not part of this environment.

---

## Where this fits

**Phase: The application, in containers** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the image the platform ships. Everything afterwards — the ECR push, the Trivy scan, the Kubernetes Deployment, the Argo CD sync — carries this artefact, so its size and its user are decisions the whole build inherits.
