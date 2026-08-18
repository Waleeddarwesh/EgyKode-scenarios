# A user for the job

Create the group first, then a user inside it. The group is what makes access
survivable when a second person needs the same access.

```
sudo groupadd --system deployers
sudo useradd --create-home --gid deployers --shell /bin/bash deploy
sudo passwd -l deploy
id deploy
```{{exec}}

`--gid deployers` puts the user in the group at creation. `passwd -l` locks the
password, so the account cannot be used for interactive password login — a key
is the only way in.

**You should see** `id deploy` report `deployers` as the primary group. The
numbers will differ; the group name is the part that matters.
