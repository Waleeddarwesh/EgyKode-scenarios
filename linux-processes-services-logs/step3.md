# Break it, then fix it

Introduce a real error into the configuration:

```
sed -i 's/^user /usr /' /etc/nginx/nginx.conf
systemctl restart nginx
systemctl status nginx --no-pager | head -5
```{{exec}}

The restart fails. Now work it properly, in order — not by editing at random:

```
journalctl -u nginx -n 20 --no-pager
nginx -t
```{{exec}}

`nginx -t` names the file **and the line**. Most daemons have an equivalent
(`sshd -t`, `apachectl configtest`), and it is always faster than reading a
journal backwards.

Fix it and confirm:

```
sed -i 's/^usr /user /' /etc/nginx/nginx.conf
nginx -t
systemctl restart nginx
systemctl is-active nginx
```{{exec}}

**You should see** `nginx: configuration file /etc/nginx/nginx.conf test is
successful` and then `active`.
