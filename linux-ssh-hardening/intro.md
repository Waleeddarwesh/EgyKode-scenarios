A server is reachable on port 22 with password authentication and a shared root
login. It is being scanned within minutes of being created — that is not
paranoia, it is what the auth log says.

**The order matters more than the settings.** Every command below is arranged so
that the way back in exists before the way in is removed. Get that order wrong
on a machine you cannot physically reach and the lesson costs a support ticket.

**What you will do**

1. **Create an administrative user and install a key** — and meet the
   permissions rule that makes sshd ignore a perfectly good key without saying so
2. **Close password and root login** — then prove from a *new* connection that
   the door you still need is open
3. **Write the firewall rule that comes before the firewall**

Here is what the machine allows right now:

```
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication)'
```{{exec}}

`permitrootlogin` and `passwordauthentication` are the two lines this scenario
exists to change.
