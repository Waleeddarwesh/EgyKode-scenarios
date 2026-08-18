# Close the doors, and prove it from a new session

The way in exists. Now remove the ways in you do not want:

```
tee /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
AllowUsers deploy
EOF
cat /etc/ssh/sshd_config.d/99-hardening.conf
```{{exec}}

A drop-in under `sshd_config.d/` rather than an edit to `sshd_config` means a
package upgrade cannot quietly revert any of this.

**Test the configuration before applying it. Always.**

```
sshd -t && echo "config is valid"
```{{exec}}

`sshd -t` parses the file without touching the running service. A typo here
followed by a `restart` is exactly how a remote machine becomes unreachable.

```
systemctl reload ssh
systemctl is-active ssh
```{{exec}}

**`reload`, not `restart`.** Reload re-reads the configuration and leaves
established sessions alone. Restart drops every connection — including the one
you would be sitting in, on a real server, with no way back if the new config
is wrong.

## Now prove all three routes, from new connections

The rule this whole scenario is built around: **verify the door you still need
is open before you would have closed your last session.**

```
echo "--- key login, which must still work:"
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost 'whoami'
```{{exec}}

`deploy`. That is the one that matters. Had this failed, you would still be
holding an open session and could undo the change — which is the entire reason
it is tested first.

```
echo "--- password authentication, which must be refused:"
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o BatchMode=yes \
    -o StrictHostKeyChecking=no deploy@localhost 'whoami'
```{{exec}}

```
Permission denied (publickey).
```

Read that message closely. **The server lists the methods it will accept**, and
the list now contains only `publickey`. Before the change it would have read
`(publickey,password)`. That parenthesis is the most under-read diagnostic in
SSH — it tells you what the server offers, not what you did wrong.

```
echo "--- root login, which must be refused:"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@localhost 'whoami'
echo "--- and the effective configuration, which is the real answer:"
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|allowusers)'
```{{exec}}

`sshd -T` prints the configuration **as the daemon resolved it**, drop-ins and
defaults included. It is the difference between what you wrote and what is in
force, and on a machine with several config files those are not always the same
thing.

**Done when:** root and password login are both off in the effective config,
and key login as `deploy` still works.
