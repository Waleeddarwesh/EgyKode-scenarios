# Done

Three properties, none of them about the application:

- **A name instead of an address** — nothing to update when a container restarts
- **A named volume** — `down` removes containers; only `down -v` removes data
- **`condition: service_healthy`** — the difference between a process existing
  and a database accepting connections

The third is the one that hides. Without it a stack fails on a cold start and
works on the retry, so it looks like a flaky application rather than a missing
four lines of Compose.

The [EgyKode lab](https://egykode.com/en/labs/lab-docker-networking-volumes-healthchecks/)
covers bind mounts versus volumes, and why two containers on separate networks
cannot see each other at all.

---

## Where this fits

**Phase: The application, in containers** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the platform's own stack in miniature: the application, PostgreSQL, a network they share by name, and a volume holding the data. `condition: service_healthy` is the line that stops the application starting before the database can answer.
