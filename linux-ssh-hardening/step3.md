# The rule you add before you turn it on

A firewall is the shortest path to locking yourself out of a remote machine,
and it is always the same mistake: turning it on before allowing the port you
are connected over.

The order is the whole lesson:

```
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw show added
```{{exec}}

`ufw allow 22/tcp` **before** `ufw enable`. Reverse those two lines on a server
you reach over SSH and the connection dies with the command that caused it, on
a machine that is now refusing the only way back in.

## Why this scenario stops here

The last command would be `ufw enable`. It is deliberately not run.

This machine is a shared sandbox reached through a browser, and a default-deny
policy applied to it can take the terminal you are reading this in along with
the traffic it was meant to block. On your own server the enable step is the
point of the exercise; here it would only demonstrate the failure mode.

The rules above are recorded and would take effect the moment the firewall came
up. Confirm they are there:

```
ufw show added
grep DEFAULT_INPUT_POLICY /etc/default/ufw
```{{exec}}

`DROP` on input, with an explicit allow for 22. That is a working ruleset,
staged and waiting.

## The argument for all of it

```
journalctl -u ssh --no-pager | grep -ci "failed password" || echo 0
```{{exec}}

On this fresh sandbox the number is small. Run the same command on any host
that has been on the public internet for a day and it is usually in the
thousands — every one of them a login attempt against a password that no longer
exists on your machine, because of step 2.

That is the number that makes key-only authentication worth the ten minutes it
costs.

**Done when:** incoming traffic defaults to deny, and 22/tcp is explicitly
allowed.
