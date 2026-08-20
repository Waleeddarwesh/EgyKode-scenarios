# The application reads it at run time

Start the database with the password Terraform generated. Note that you never
see it — it goes from Secrets Manager into the container and nowhere else:

```
PW=$(awslocal secretsmanager get-secret-value --secret-id platform/db/credentials \
  --query SecretString --output text | jq -r .password)
docker rm -f shopdb >/dev/null 2>&1
docker run -d --name shopdb -p 5432:5432 \
  -e POSTGRES_USER=app -e POSTGRES_PASSWORD="$PW" -e POSTGRES_DB=shop \
  postgres:16-alpine >/dev/null
for i in $(seq 1 30); do
  docker exec shopdb pg_isready -U app >/dev/null 2>&1 && break
  sleep 2
done
docker exec shopdb pg_isready -U app
```{{exec}}

## The application

No credentials in it. It knows one thing — the *name of the secret*:

```
mkdir -p /root/app
cat > /root/app/run.sh <<'SH'
#!/bin/bash
# The only configuration this application has is which secret to read.
SECRET_ID="${SECRET_ID:-platform/db/credentials}"

CREDS=$(awslocal secretsmanager get-secret-value \
          --secret-id "$SECRET_ID" --query SecretString --output text) || {
  echo "could not read $SECRET_ID"; exit 1; }

DB_USER=$(echo "$CREDS" | jq -r .username)
DB_PASS=$(echo "$CREDS" | jq -r .password)
DB_HOST=$(echo "$CREDS" | jq -r .host)
DB_PORT=$(echo "$CREDS" | jq -r .port)
DB_NAME=$(echo "$CREDS" | jq -r .dbname)

echo "connecting to $DB_HOST:$DB_PORT/$DB_NAME as $DB_USER"

# A client OUTSIDE the database container, over the published port.
#
# Connecting with `docker exec` into the database instead would prove nothing:
# the official Postgres image ships "host all all 127.0.0.1/32 trust", so a
# connection made from inside the container is accepted with ANY password.
# The wrong-password test below only means something over a real socket.
docker run --rm --network host -e PGPASSWORD="$DB_PASS" postgres:16-alpine \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
  "select 'connected as ' || current_user || ' to ' || current_database();"
SH
chmod +x /root/app/run.sh
/root/app/run.sh
```{{exec}}

It connected, and there is no password in the script. Check:

```
grep -icE 'password *= *["a-z0-9]|PGPASSWORD=[^"$]' /root/app/run.sh || true
echo "--- what the application actually contains ---"
grep -n 'SECRET_ID' /root/app/run.sh
```{{exec}}

**The application's entire configuration is a secret name.** That is the shape
worth copying: not "the password is in an environment variable instead of the
code" — which just moves it — but "the application asks, at run time, and holds
nothing".

## Why at run time, and not at deploy time

An image built with the credential baked in has it forever, in every layer, in
every registry that ever held it. An environment variable set at deploy time is
better and still means a rotation is a redeploy of everything that uses it.

Fetching at run time means **rotation is one API call and a restart**, and the
application never has to be rebuilt to change a password.

```
echo "--- prove it is fetched, not remembered: break the secret and re-run ---"
awslocal secretsmanager put-secret-value --secret-id platform/db/credentials \
  --secret-string '{"username":"app","password":"wrong-on-purpose","host":"127.0.0.1","port":5432,"dbname":"shop"}' \
  >/dev/null
/root/app/run.sh 2>&1 | tail -3
```{{exec}}

**It failed authentication** — because it read the new value, not a cached one.
A wrong password producing a real refusal is the proof that the database is
real and the fetch is live.

Put it back:

```
# Read it back out of state with jq, exactly as step 1 did.
#
# `terraform output -raw db_password` is the tempting form and there is no such
# output - Terraform then prints a warning on stdout, which a command
# substitution captures as if it were the value. That warning text ends up
# written into the secret as the password, and the next thing to read it fails
# authentication for reasons that look nothing like the cause.
PW=$(jq -r '.resources[] | select(.type=="random_password") | .instances[0].attributes.result' \
  /root/iac/terraform.tfstate)
awslocal secretsmanager put-secret-value --secret-id platform/db/credentials \
  --secret-string "$(jq -nc --arg p "$PW" '{username:"app",password:$p,host:"127.0.0.1",port:5432,dbname:"shop"}')" \
  >/dev/null
/root/app/run.sh | tail -2
```{{exec}}

**Done when:** the application connects using credentials it fetched at run
time, and holds none of its own.
