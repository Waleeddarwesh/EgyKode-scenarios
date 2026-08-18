# Done

- **Permissions before anything else.** sshd ignores an `authorized_keys` that
  other users could write to, and tells the client only "Permission denied".
  700 on the directory, 600 on the file
- **`(publickey)` in the denial message is the server's list**, not a guess
  about what you did wrong. Watching that parenthesis shrink is how you know a
  method is really off
- **`sshd -t` before every reload**, and `reload` rather than `restart` — one
  re-reads the config, the other drops every session including yours
- **`sshd -T` is the effective configuration**, drop-ins and defaults resolved.
  What you wrote and what is in force are not always the same file
- **Add the allow rule before enabling the firewall.** Every lockout story
  starts with those two commands in the other order
- **Test the route you still need first.** Key login was verified before
  password login was removed, which is what makes the change reversible

The one step deliberately not run here is `ufw enable`, because this sandbox is
reached through a browser and a default-deny policy could take the terminal
with it. On your own server that is the final command — and by then the allow
rule is already staged.

---

## Where this fits

**Phase: Foundations** — part of [Build the Production Platform](https://egykode.com/en/labs/).

Every machine in the platform is reached this way: a named administrative user,
a key, no passwords, no root login. The Jenkins host later in the path is
provisioned by Ansible over exactly this connection, and the deployment account
your pipeline uses is this account. Get the order wrong on a cloud instance and
the recovery is a console session you may not have set up yet.
