# One playbook, several roles

Wait for setup, then look at what is *not* installed yet:

```
# These two come first. Without VAULT_ADDR the client defaults to HTTPS on the
# same port, never connects, and any wait loop below it spins forever.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=egykode-root
until command -v ansible-playbook >/dev/null 2>&1 && vault status >/dev/null 2>&1; do sleep 3; done
echo "ansible: $(ansible --version | head -1)"
echo "java:    $(command -v java || echo absent)"
echo "jenkins: $(systemctl is-active jenkins 2>/dev/null || echo absent)"
```{{exec}}

A bare host. Everything below is the playbook's job.

## Roles, because "install Jenkins" is four different concerns

```
cd /root/ansible
cat > roles/common/tasks/main.yml <<'YAML'
- name: Base packages every host gets
  ansible.builtin.package:
    name:
      - git
      - curl
      - unzip
    state: present
    update_cache: true
YAML

cat > roles/java/tasks/main.yml <<'YAML'
- name: Java runtime for Jenkins
  ansible.builtin.package:
    name: openjdk-21-jre-headless
    state: present
YAML
echo "common and java written"
```{{exec}}

**`ansible.builtin.package`, not `apt`.** The lab this comes from provisions
Amazon Linux with `dnf`; this environment is Ubuntu. `package` dispatches to
whichever package manager the host actually has, so one role serves both — and
that is the difference between a role you wrote for your laptop and one another
team can use.

**Java 21, and this is not a detail.** Jenkins refuses to start on Java 17:
`Running with Java 17 …, which is older than the minimum required version (Java
21). Supported Java versions are: [21, 25]`. Most tutorials still say 17, and
the failure appears as a service that will not start rather than as a package
error.

## The Jenkins role

```
cd /root/ansible
cat > roles/jenkins/tasks/main.yml <<'YAML'
- name: Jenkins repository key
  ansible.builtin.get_url:
    url: https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    dest: /usr/share/keyrings/jenkins-keyring.asc
    mode: "0644"

- name: Jenkins repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/"
    filename: jenkins
    state: present

- name: Jenkins package
  ansible.builtin.apt:
    name: jenkins
    state: present
    update_cache: true

- name: Jenkins running and enabled at boot
  ansible.builtin.systemd_service:
    name: jenkins
    state: started
    enabled: true
YAML

cat > site.yml <<'YAML'
- name: Build host
  hosts: build
  become: false
  roles:
    - common
    - java
    - jenkins
YAML
echo "jenkins role and site.yml written"
```{{exec}}

**The key is `jenkins.io-2026.key`.** Jenkins rotated its signing key in
December 2025 and the old `jenkins.io-2023.key` still downloads happily — it
simply no longer matches what the repository is signed with. The failure is
`NO_PUBKEY 7198F4B714ABFC68` from `apt-get update`, which reads as a network or
mirror problem and is neither.

## Run it

```
cd /root/ansible
export LANG=C.UTF-8 LC_ALL=C.UTF-8
time ansible-playbook site.yml
```{{exec}}

## Prove it is actually serving

```
systemctl is-active jenkins
for i in $(seq 1 60); do
  C=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8080/login)
  case "$C" in 200|403) break;; esac
  sleep 5
done
echo "jenkins http: $C"
git --version; java -version 2>&1 | head -1
```{{exec}}

`active`, and an HTTP answer on 8080. **A service that is `enabled` but not
`active` is the most common way this ends up "done" and broken** — enabled only
means it will start at next boot.

**Done when:** one playbook run leaves Jenkins active and answering, with the
toolchain present.
