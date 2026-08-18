# An administrative user, and a key that works

Root should not be a login account. The moment several people share one, every
action on the machine becomes anonymous — and `sudo` exists precisely so the
log can name who did what.

```
adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
id deploy
```{{exec}}

`--disabled-password` sets no password at all. That is deliberate: this account
will be reachable by key only, and an account with no password cannot have a
weak one.

Now generate a key and install it — **with the permissions people usually get
wrong the first time**:

```
ssh-keygen -t ed25519 -C "deploy@egykode" -f /root/.ssh/egykode -N ""
mkdir -p /home/deploy/.ssh
cp /root/.ssh/egykode.pub /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
chmod 777 /home/deploy/.ssh
chmod 666 /home/deploy/.ssh/authorized_keys
ls -ld /home/deploy/.ssh /home/deploy/.ssh/authorized_keys
```{{exec}}

Ed25519 rather than RSA: shorter, faster, and no key-size decision to get wrong.

The key is installed, owned by the right user, and contains exactly the right
public key. Try it:

```
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost whoami
```{{exec}}

**Permission denied.** Nothing is wrong with the key.

Ask the server why:

```
journalctl -u ssh --no-pager -n 20 | grep -i "authentication refused" || tail -20 /var/log/auth.log | grep -i refused
```{{exec}}

```
Authentication refused: bad ownership or modes for file /home/deploy/.ssh/authorized_keys
```

It names whichever of the two it checked first; fix both. Note also what the
client was told a moment ago — `Permission denied (publickey,password)` — which
says nothing at all about the real reason.

**sshd refuses to read an `authorized_keys` that other users could write to**,
and the client is told only "Permission denied". If key authentication ever
fails for no visible reason, these two modes are the first thing to check —
before the key, before the config, before anything else.

```
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost 'whoami'
```{{exec}}

`deploy`. The account is reachable by key.

## Administering the machine is a second question

Being in the `sudo` group is not the same as being able to use `sudo` from a
script:

```
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost 'sudo -n true'
```{{exec}}

```
sudo: a password is required
```

That is correct behaviour, not a fault. `sudo` wants to re-authenticate the
human, `-n` forbids prompting, and this account has no password at all — so
there is nothing to type even if something were there to type it into.

An account that must run commands unattended needs an explicit rule, and the
rule should name the commands rather than hand over the machine:

```
tee /etc/sudoers.d/deploy <<'EOF'
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl reload ssh, /usr/bin/systemctl status ssh
EOF
chmod 440 /etc/sudoers.d/deploy
visudo -c -f /etc/sudoers.d/deploy
```{{exec}}

**`visudo -c` before you trust it.** A syntax error in a sudoers file can leave
nobody on the machine able to use `sudo`, and that is not a thing you find out
gently.

Now the difference is visible:

```
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost 'sudo -n systemctl reload ssh && echo "reloaded"'
ssh -i /root/.ssh/egykode -o BatchMode=yes -o StrictHostKeyChecking=no deploy@localhost 'sudo -n cat /etc/shadow'
```{{exec}}

The first works. The second says `a password is required` — which, for an
account with no password, means never.

That is least privilege as something the machine enforces: `NOPASSWD: ALL`
would have been one word shorter and would have handed every future attacker
with this key a root shell.

**Done when:** `deploy` exists, is in the `sudo` group, key login works, and the
sudoers rule grants the named commands and nothing else.
