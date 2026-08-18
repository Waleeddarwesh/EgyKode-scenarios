# Break it on purpose

There are two ways a task quietly stops being idempotent, and both look
perfectly reasonable in review.

## One: `command` and `shell` always report changed

```
cd ~/ansible
mkdir -p /opt/app
tar czf /tmp/app.tar.gz -C /etc hostname

cat >> roles/webserver/tasks/main.yml <<'YML'

- name: Unpack the application bundle
  ansible.builtin.shell: tar xzf /tmp/app.tar.gz -C /opt/app
YML

ansible-playbook -i inventory site.yml | tail -3
ansible-playbook -i inventory site.yml | tail -3
```{{exec}}

`changed=1` on both runs, forever.

**`shell` and `command` have no idea what state they produce.** Ansible cannot
inspect a shell pipeline to work out whether it needed to run, so it assumes the
worst and reports a change every time. Add a `notify` to a task like that and
the service restarts on every run for the rest of its life.

Two fixes, and the second is better:

```
cd ~/ansible
python3 - <<'PY'
import io
p = "roles/webserver/tasks/main.yml"
s = io.open(p).read()
s = s.replace("""- name: Unpack the application bundle
  ansible.builtin.shell: tar xzf /tmp/app.tar.gz -C /opt/app""",
"""- name: Unpack the application bundle
  ansible.builtin.unarchive:
    src: /tmp/app.tar.gz
    dest: /opt/app
    remote_src: true
    creates: /opt/app/hostname""")
io.open(p, "w").write(s)
print("switched to unarchive with creates:")
PY
ansible-playbook -i inventory site.yml | tail -3
ansible-playbook -i inventory site.yml | tail -3
```{{exec}}

`changed=0`.

- **`creates:`** tells Ansible what the work produces. If that path exists, the
  task is skipped. It works on `command` and `shell` too, and it is the minimum
  acceptable guard on either
- **A real module** — `unarchive` here — knows how to check state itself, and
  can also fix ownership, modes and partial extractions. Reach for the module
  first; reach for `creates:` when no module exists

## Two: a template that renders differently every run

```
cd ~/ansible
sed -i '1a # Rendered {{ ansible_date_time.iso8601 }}' roles/webserver/templates/nginx.conf.j2
ansible-playbook -i inventory site.yml | tail -3
sleep 2
ansible-playbook -i inventory site.yml | tail -3
```{{exec}}

`changed=1` every time — **and a handler notification with it**, so nginx
restarts on every run.

This one is worse than the shell task, because it looks like documentation.
Somebody added a helpful "rendered at" comment, and turned a converged
configuration management run into a rolling restart of the fleet.

The checksum is the whole mechanism: `template` compares what it renders against
what is on disk. Anything that differs between two renders — a timestamp, a
random value, a counter, a `lookup` of something that moves — defeats it.

```
cd ~/ansible
sed -i '/Rendered {{ ansible_date_time/d' roles/webserver/templates/nginx.conf.j2
ansible-playbook -i inventory site.yml | tail -3
ansible-playbook -i inventory site.yml | tail -3
```{{exec}}

Back to `changed=0`.

**Anything genuinely dynamic belongs outside the managed file.** If the render
time really must be recorded, write it to a separate file that nothing notifies
on — never into the file whose checksum decides whether the service restarts.

## The general rule

A task is idempotent when Ansible can answer *"is this already done?"* before
acting. Modules answer it by inspecting state; `creates:` answers it with a
path; `shell` cannot answer it at all.

**Done when:** the archive task no longer reports changed, the template has no
timestamp, and a second run reports `changed=0`.
