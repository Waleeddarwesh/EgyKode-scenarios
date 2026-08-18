# changed=0, demonstrated

Run the playbook again, changing nothing:

```
cd ~/ansible
ansible-playbook -i inventory site.yml | tail -4
```{{exec}}

```
localhost : ok=5  changed=0  unreachable=0  failed=0
```

**`changed=0` is the definition.** Not "the playbook is safe to re-run" in a
README — this number, on this run.

Notice what did *not* happen: no `RUNNING HANDLER` block. The handler is only
notified by a task that reported a change, and nothing changed, so nginx was
never restarted. A run that changes nothing touches nothing.

```
systemctl show nginx -p MainPID --value
ansible-playbook -i ~/ansible/inventory ~/ansible/site.yml > /dev/null
systemctl show nginx -p MainPID --value
```{{exec}}

Same PID. The service was not restarted by a run that had nothing to do.

## Where the number comes from

Each module reports `changed` only when it altered something:

| Module | Decides by |
| --- | --- |
| `package` | Is it already installed? |
| `template` | Does the rendered checksum differ from the file? |
| `copy` | Same, against the source file |
| `service` | Is it already in the requested state? |

None of that is Ansible being clever about your playbook. It is each module
checking before acting — which is why `command` and `shell`, in the next step,
cannot do it.

## Finding the task that always changes

When the second run is not zero, this is the command:

```
cd ~/ansible
ansible-playbook -i inventory site.yml --check --diff | tail -12
```{{exec}}

`--check` is a dry run that changes nothing. `--diff` prints exactly what it
*would* alter, line by line. On a converged system it prints no diffs at all,
which is what you are looking at now.

Together they answer "what does this run want to change?" without changing it —
the closest Ansible gets to `terraform plan`, and the first thing to reach for
when a playbook restarts production every night.

**Done when:** a second run reports `changed=0` and the service is not
restarted.
