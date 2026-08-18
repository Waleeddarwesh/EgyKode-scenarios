# Done

The order is the skill, not the commands:

1. **What is it?** — `ss -ltnp` goes from a port to a process
2. **What does systemd think?** — `systemctl status` gives state and exit code
3. **What did the application say?** — `journalctl -u` gives its own words
4. **Is the config even valid?** — `nginx -t` names the file and the line

Step 4 is the one people reach for last and should reach for second. A
config test answers in a second what reading a journal answers in five minutes.

The [EgyKode lab](https://egykode.com/en/labs/lab-linux-processes-services-logs/)
covers signals, what a reload does that a restart does not, and why a service's
journal can be completely empty.

---

## Where this fits

**Phase: Foundations** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is how you will debug the platform when it is running: port to process, systemd to journal, config test before guesswork. The same sequence works on the Jenkins host, the Kubernetes nodes, and the database instance.
