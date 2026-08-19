# Build, scan and push an image from a pipeline

The pipeline you are replacing builds an image and pushes it as `latest`. Nobody
can say which commit is in production, the scan runs *after* the push, and the
registry password is an environment variable in the job configuration.

You will fix all three, and then prove the fix by breaking it on purpose.

## What is being set up for you

- **Jenkins**, with a Docker client and the pipeline plugins
- **A private registry** on `localhost:5000` that returns `401` without a
  password — so "no credential in the log" is a claim with something behind it
- **Trivy**, with its 108 MiB vulnerability database already downloaded

Nothing here touches Docker Hub, and no account of yours is involved. The
registry, the credential and the images all live on this throwaway machine.

## One thing to know before you start

This scenario mounts `/var/run/docker.sock` into the Jenkins container. That is
a real grant — anything that can reach the host's Docker socket can start a
privileged container — and it is here because a pipeline that builds images
cannot be demonstrated without a Docker daemon. It is the right call for this
lab and the wrong one almost everywhere it is merely convenient.

Setup runs in the background and takes a few minutes. Step 1 waits for it.
