# One restart, at the end, through a handler

```
cd ~/ansible
cat > roles/webserver/handlers/main.yml <<'YML'
---
- name: Restart the web server
  ansible.builtin.service:
    name: "{{ webserver_service }}"
    state: restarted
YML

mkdir -p roles/webserver/files
cat > roles/webserver/files/index.html <<'HTML'
<!doctype html>
<title>egykode</title>
<h1>Managed by Ansible</h1>
HTML

cat >> roles/webserver/tasks/main.yml <<'YML'

- name: Publish the landing page
  ansible.builtin.copy:
    src: index.html
    dest: /var/www/html/index.html
    owner: root
    group: root
    mode: "0644"
YML

cat > inventory <<'INI'
[web]
localhost ansible_connection=local
INI

cat > site.yml <<'YML'
---
- name: Configure the web tier
  hosts: web
  become: true

  roles:
    - webserver
YML
ls
```{{exec}}

The handler's **name is the contract**. `notify: Restart the web server` in the
task matches `- name: Restart the web server` in the handler, exactly, including
capitalisation. A typo there is not an error — the notification simply matches
nothing and the service is never restarted, which is the quietest failure in
this whole scenario.

Run it:

```
cd ~/ansible
ansible-playbook -i inventory site.yml | tail -14
```{{exec}}

Read the end of that output. The handler ran **after** the tasks, not between
them — `RUNNING HANDLER` appears once, below everything else.

## Why that ordering is the point

Suppose the role deployed three files and each restarted the service inline.
That is three restarts in one run: three windows where requests fail, on every
host, every time anything changes.

Handlers are **deduplicated and deferred**. Ten tasks can notify the same
handler; it runs once, at the end, after the configuration has finished
converging. And a handler only runs if something actually notified it, so a run
that changes nothing restarts nothing.

Confirm the service is up and serving the config you rendered:

```
systemctl is-active nginx
grep -E "worker_connections|listen" /etc/nginx/nginx.conf
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/
```{{exec}}

`768` and `listen 80`, straight from `defaults/main.yml`, through the template,
into the running server.

## Prove the handler is wired, not decorative

Change a value and watch exactly one restart happen:

```
cd ~/ansible
PID_BEFORE=$(systemctl show nginx -p MainPID --value)
ansible-playbook -i inventory site.yml -e webserver_worker_connections=1024 > /tmp/change.log
grep -c "RUNNING HANDLER" /tmp/change.log
tail -4 /tmp/change.log
PID_AFTER=$(systemctl show nginx -p MainPID --value)
echo "main pid $PID_BEFORE -> $PID_AFTER"
grep worker_connections /etc/nginx/nginx.conf
```{{exec}}

One handler block, `changed=2` in the recap, a new main PID, and `1024` in the
file. The configuration changed, so the handler fired — **once**.

**Done when:** the handler exists, the run restarts nginx exactly once, and the
service is active.
