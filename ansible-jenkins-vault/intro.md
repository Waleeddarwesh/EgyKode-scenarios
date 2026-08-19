# A build host you can rebuild

The instance is bare. By the end of this you will have one playbook that turns
it into a working Jenkins, a proof that running it again does nothing, an admin
password that exists in Vault rather than in your repository, and a verify play
that refuses to pass when the host is broken.

That last one is the difference between provisioning and operations. A
playbook that ends `failed=0` proves the tasks ran; it says nothing about
whether the service is still alive thirty seconds later.

## What is being set up for you

- **Ansible**, running against this machine with `ansible_connection=local` —
  the same playbook works over SSH against a fleet without a line changing
- **A Vault dev server** on `127.0.0.1:8200`, holding one secret
- **Nothing else.** No Java, no Jenkins, no git. Installing those is the
  playbook's job, and a package that was already there would hide the
  difference between the first run and the second.

## Two things this environment changed

The lab this comes from provisions **Amazon Linux with `dnf`**; this free
environment is Ubuntu. The roles here use `ansible.builtin.package`, which
dispatches to whichever package manager the host has — so the same role serves
both, which is what a role written for other people looks like anyway. Only the
Jenkins repository task is genuinely distro-specific, and it is marked.

And two things that were true when that lab was written are no longer true, both
of which you will hit if you follow any current tutorial:

- **Jenkins requires Java 21 or 25.** On 17 it installs cleanly and then
  refuses to start.
- **The Debian and RPM signing key rotated in December 2025.** The old
  `jenkins.io-2023.key` still downloads, and no longer matches what the
  repository is signed with.

Both fail in ways that point somewhere else. That is most of why they are here.

Setup takes about a minute and a half. Step 1 waits for it.
