# Derives DATABASE_URL from the PG_* settings. Sourced by the entrypoint and
# by the commands an admin runs with `docker exec`, which don't see the
# variables the entrypoint exports.
: "${PG_HOST:=}"
: "${PG_PORT:=5432}"
: "${PG_USER:=anchor}"
: "${PG_PASSWORD:=password}"
: "${PG_DATABASE:=anchor}"

# Decide embedded vs external based on PG_HOST
if [ -z "$PG_HOST" ]; then
  USE_EMBEDDED_POSTGRES=1
  DATABASE_URL="postgresql://${PG_USER}:${PG_PASSWORD}@127.0.0.1:${PG_PORT}/${PG_DATABASE}"
else
  USE_EMBEDDED_POSTGRES=0
  DATABASE_URL="postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}"
fi
export DATABASE_URL
