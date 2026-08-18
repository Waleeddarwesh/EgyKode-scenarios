The playbook works. Running it twice restarts production, because every task
reports `changed` whether or not anything changed.

Idempotency is not a property you assert in a README. It is a number in the play
recap, and either it is zero on the second run or the playbook is unsafe to run
on a schedule, in CI, or at three in the morning.

**What you will do**

1. **Lay out a role** and make the one decision inside it that decides whether
   anybody else can use it
2. **Restart the service exactly once**, at the end, through a handler
3. **Demonstrate `changed=0`** rather than claiming it
4. **Break idempotency on purpose**, two ways, and fix both

Everything runs against this machine, so `ansible_connection=local` — the same
role would run over SSH against a hundred hosts without a line changing.

```
ansible --version | head -2
systemctl is-active nginx || echo "nginx is not installed yet - that is the role's job"
```{{exec}}
