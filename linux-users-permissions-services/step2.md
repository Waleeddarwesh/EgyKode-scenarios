# Permissions that hold

Ownership decides who can write today. The setgid bit decides who can write to
the files created *tomorrow* — which is the part that breaks weeks later.

```
sudo chown -R root:deployers /opt/app
sudo chmod -R 2775 /opt/app
ls -ld /opt/app
```{{exec}}

The leading `2` is the setgid bit, and it is the part most guides omit. Without
it, a file created in `/opt/app` belongs to whoever made it, and the next
deployer cannot overwrite it.

Prove it rather than assume it:

```
sudo -u deploy touch /opt/app/test.txt
ls -l /opt/app/test.txt
```{{exec}}

**You should see** `drwxrwsr-x` on the directory — note the `s` where the group
execute bit would be — and the new file's group is `deployers`, not `deploy`.
