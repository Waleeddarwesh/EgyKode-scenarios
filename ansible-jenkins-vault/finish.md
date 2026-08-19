# Done

One playbook, a bare host, and a Jenkins that is actually serving — then proof
that running it again changes nothing, a secret that never touched the
repository, and a check that fails when you break the host.

**What you can now do**

- Compose roles so that "install Jenkins" is separable concerns rather than one
  long script, using `ansible.builtin.package` so the role is not welded to one
  distribution
- Write tasks that declare state, and recognise the two that usually break
  idempotency — `command`/`shell` without `changed_when`, and `>>` into a file
- Read a value from Vault at run time, keep the token in the environment, and
  keep both out of the logs with `no_log`
- Write assertions that fail, and prove they fail by breaking something on
  purpose

**The three failures worth remembering**

Each of these cost real time here, and each points somewhere other than its
cause:

| Symptom | Actual cause |
| --- | --- |
| `NO_PUBKEY 7198F4B714ABFC68` from `apt-get update` | Jenkins rotated its signing key; `jenkins.io-2023.key` still downloads and no longer matches |
| `jenkins.service` fails to start, package installed fine | Jenkins needs Java 21 or 25 and refuses 17 |
| `No such file or directory: b'command'` | `command -v` is a shell builtin, so it needs `ansible.builtin.shell`, not `ansible.builtin.command` |

**Why the verify play is the part that survives**

Provisioning happens once. Drift happens continuously — someone stops a service
to debug it, a disk fills, an unrelated update downgrades a package. The verify
play is the only thing here designed to run every night, and it is the reason
you find out by email rather than during an incident.

Run it on a schedule and treat a failure as a page. A check nobody runs is
documentation.

**Next**

The same host, driven from a pipeline rather than by hand: Jenkins building,
scanning and pushing an image, with the credential kept out of the build log.
