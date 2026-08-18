# Done

- **Static files never reach Gunicorn.** Every worker serving a stylesheet is a
  worker not serving a request, and nginx reads files for a living
- **`remote_addr` is the proxy, and always will be** — the TCP connection really
  does come from nginx. `X-Real-IP` and `X-Forwarded-For` are the only reason
  the application can know otherwise, and they exist because you set them
- **`$proxy_add_x_forwarded_for` appends.** Behind a second proxy the header is a
  list, client leftmost — which is why trusting the last entry lets anyone forge
  their own address
- **`depends_on` without a condition waits for a container, not a service.** The
  window is about a second here and much longer on a loaded CI runner. Neither
  outcome is guaranteed, which is the actual problem
- **`condition: service_healthy` makes the ordering deterministic**, and you
  measured it: the app started five seconds after the database, because Compose
  held it
- **A healthcheck is worth exactly what its `test` asks.** `pg_isready` asks
  whether the database will accept a connection. A check that a port is open, or
  that returns 200 unconditionally, answers an easier question and reports the
  same green
- **A named volume outlives the container.** `down` keeps it, `down -v` deletes
  it, and no `volumes:` entry at all means the data was in the container layer
  the whole time — which works perfectly until the first restart

---

## Where this fits

**Phase: Build & Containers** — part of [Build the Production Platform](https://egykode.com/en/labs/).

This is the platform's application stack in miniature, and the same three
questions follow it into Kubernetes: what serves static content, how one
workload waits for another to be genuinely ready, and where the data lives when
the container is replaced. There the answers are an Ingress, a readiness probe,
and a PersistentVolumeClaim — different objects, same three failures.
