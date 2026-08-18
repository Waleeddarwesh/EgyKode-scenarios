# Done

- **`defaults` or `vars` decides whether anyone else can use your role.**
  `defaults` is overridable by inventory, playbook and `--extra-vars`; `vars` is
  effectively not. Anything a caller might reasonably change goes in `defaults`
- **The directory layout is the wiring.** Ansible finds `tasks/`, `handlers/`,
  `templates/` and `files/` by name — there is nothing to register
- **`templates/` renders, `files/` copies.** A file with no `{{ }}` belongs in
  `files/`, where nothing can interpolate it by accident
- **`validate:` means a broken config never reaches the service.** The template
  is checked as a temporary file and only installed if it parses
- **The notify string must match the handler name exactly**, and a mismatch is
  silent. Nothing errors; the service simply never restarts
- **Handlers are deduplicated and deferred.** Ten tasks can notify one handler
  and the service restarts once, at the end, after everything has converged
- **`changed=0` is the definition of idempotent**, and it is a number in the
  recap rather than a claim in a README
- **`--check --diff` is the closest Ansible gets to a plan.** It is the first
  command to run when a playbook restarts production every night

The two ways it breaks, both of which you produced deliberately:

**`shell` and `command` cannot know whether they needed to run**, so they always
report changed. Use a real module, or `creates:` to name what the work produces.

**A template that renders differently every run** — a timestamp, a random value,
anything that moves — defeats the checksum, rewrites the file, and notifies the
handler. Every run. That one arrives disguised as a helpful comment.

---

## Where this fits

**Phase: Infrastructure as Code** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Terraform builds the machines; Ansible decides what is on them. The Jenkins host
later in the path is provisioned by a role shaped exactly like this one, and it
runs on a schedule — which is only safe because a converged run changes nothing
and restarts nothing. A playbook that reports `changed` every time cannot be
automated at all; it can only be run by a person watching it.
