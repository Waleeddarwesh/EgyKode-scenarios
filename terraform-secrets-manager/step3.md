# Move the database, change one thing

The endpoint went into the secret alongside the password in step 1. Here is
what that bought.

Pretend a failover happened, or a restore, or a move to another region — the
database is now somewhere else:

```
PW=$(awslocal secretsmanager get-secret-value --secret-id platform/db/credentials \
  --query SecretString --output text | jq -r .password)
docker rm -f shopdb-new >/dev/null 2>&1
docker run -d --name shopdb-new -p 5433:5432 \
  -e POSTGRES_USER=app -e POSTGRES_PASSWORD="$PW" -e POSTGRES_DB=shop \
  postgres:16-alpine >/dev/null
for i in $(seq 1 30); do docker exec shopdb-new pg_isready -U app >/dev/null 2>&1 && break; sleep 2; done
docker rm -f shopdb >/dev/null 2>&1
echo "the old database is gone; the new one is on port 5433"
/root/app/run.sh 2>&1 | tail -2
```{{exec}}

The application is broken, correctly — it is still being told to connect to the
old endpoint.

## One update, and nothing else

```
awslocal secretsmanager put-secret-value --secret-id platform/db/credentials \
  --secret-string "$(jq -nc --arg p "$(jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' /root/iac/terraform.tfstate)" \
    '{username:"app",password:$p,host:"127.0.0.1",port:5433,dbname:"shop"}')" >/dev/null
sed -n 's/.*"port": *\([0-9]*\).*/secret now points at port \1/p' <<< "$(awslocal secretsmanager get-secret-value --secret-id platform/db/credentials --query SecretString --output text)"
/root/app/run.sh 2>&1 | tail -2
```{{exec}}

**The application was not changed, redeployed or restarted with new
configuration.** One secret moved and it followed.

Now imagine the alternative — the host in an environment variable, a Helm
value, a ConfigMap and two `.env` files. A failover at 3am becomes a hunt for
every place the endpoint was written down, performed by whoever is on call.

## What Multi-AZ protects against

This is the reasoning the lab asks for, and it is worth being exact because
Multi-AZ is oversold constantly.

**It protects against**: the loss of an availability zone, the failure of the
instance's host, and the storage underneath it. AWS keeps a synchronous standby
in another AZ and fails over to it, typically in a minute or two. Also planned
work — patching and minor upgrades happen on the standby first, so the outage is
one failover rather than the full maintenance window.

**It does not protect against** — and every item here has taken a production
database down:

| Not protected | Why |
| --- | --- |
| `DROP TABLE` | Replicated to the standby immediately and faithfully |
| A bad migration | Same. Synchronous replication is not a delay |
| Corruption written by the application | It is valid data as far as the database is concerned |
| Deleting the instance | The standby goes with it |
| Region loss | The standby is in another AZ, not another region |

**Multi-AZ is availability, not durability.** The thing that protects you from
the list above is backups you have restored from — which is a different lab, and
the reason it exists.

And the failover is not free: connections drop and the endpoint's DNS
repoints, so an application that resolved the address once at startup keeps
trying a machine that is gone. Which is the same lesson as the one you just
performed by hand.

## What this environment could not show you

The lab's first criterion is "the database is Multi-AZ and has no public
endpoint, verified from outside the VPC". That is RDS, and RDS is not in the
free LocalStack image — creating one returns `API for service 'rds' not yet
implemented or pro feature`.

It is not simulated here, because a fake `MultiAZ: true` in a response would
teach you that you had verified something you had not. The credential handling
in steps 1 and 2 is real; the managed-database behaviour needs an account, and
the cloud version of this lab is where it belongs.

**Done when:** the database moved, you updated one secret, and the application
followed without being touched.
