# The role layout, and one decision inside it

Ansible loads a role by directory name. Putting a file in the right place **is**
the wiring — there is no registration step:

```
mkdir -p ~/ansible/roles/webserver/{tasks,handlers,defaults,templates}
cd ~/ansible
find roles -type d | sort
```{{exec}}

```text
roles/webserver/
  tasks/main.yml       what to do
  handlers/main.yml    things triggered by notify
  defaults/main.yml    variables the caller may override
  vars/main.yml        variables the caller should not
  templates/           Jinja2, rendered onto the host
  files/               copied verbatim
```

## defaults or vars

Both hold variables. They differ in **precedence**, and that difference decides
whether anyone but you can use the role.

`defaults` sits near the bottom of the precedence order, so an inventory, a
playbook, or `--extra-vars` all override it. `vars` sits near the top and is
effectively unoverridable.

**Every value a caller might reasonably change belongs in `defaults`.** Put it
in `vars` and you have written a role that only works for your environment.

```
cd ~/ansible
cat > roles/webserver/defaults/main.yml <<'YML'
---
webserver_package: nginx
webserver_service: nginx
webserver_worker_processes: auto
webserver_worker_connections: 768
webserver_server_name: localhost
webserver_port: 80
YML

cat > roles/webserver/templates/nginx.conf.j2 <<'J2'
# Managed by Ansible. Local edits are overwritten.
user www-data;
worker_processes {{ webserver_worker_processes }};
pid /run/nginx.pid;

events {
    worker_connections {{ webserver_worker_connections }};
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    server {
        listen {{ webserver_port }};
        server_name {{ webserver_server_name }};
        root /var/www/html;
    }
}
J2
ls roles/webserver/defaults roles/webserver/templates
```{{exec}}

## Tasks that take their values from variables

```
cd ~/ansible
cat > roles/webserver/tasks/main.yml <<'YML'
---
- name: Install the web server package
  ansible.builtin.package:
    name: "{{ webserver_package }}"
    state: present

- name: Deploy the configuration
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: "0644"
    validate: "nginx -t -c %s"
  notify: Restart the web server

- name: Ensure the service is running and enabled
  ansible.builtin.service:
    name: "{{ webserver_service }}"
    state: started
    enabled: true
YML
cat roles/webserver/tasks/main.yml
```{{exec}}

**Every module here checks state before acting.** `package` does nothing if the
package is installed. `template` compares a checksum and rewrites only on a
difference. `service` starts nothing that is already running. That is where
idempotency comes from — not from anything you add on top.

**`validate:` is the line worth copying everywhere.** Ansible renders the
template to a temporary file, runs `nginx -t -c` against *that*, and installs it
only if it parses. A broken template can never take the service down, because
the broken version never reaches `/etc/nginx/nginx.conf`.

**Done when:** the role has `defaults`, `templates` and `tasks`, and no value in
`tasks/main.yml` is hardcoded.
