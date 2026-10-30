#!/bin/sh
set -eu

# =============================================================================
# Anchor Docker Entrypoint
# =============================================================================
# Initializes environment, starts embedded Postgres (if enabled), runs
# database migrations, then hands off to supervisord for process management.
# =============================================================================

# -----------------------------------------------------------------------------
# Environment defaults
# -----------------------------------------------------------------------------
. /app/anchor-env.sh

# Generate JWT_SECRET if not provided (persisted in /data for consistency)
JWT_SECRET_FILE="/data/.jwt_secret"
if [ -z "${JWT_SECRET:-}" ]; then
  if [ -f "$JWT_SECRET_FILE" ]; then
    JWT_SECRET=$(cat "$JWT_SECRET_FILE")
  else
    JWT_SECRET=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    mkdir -p /data
    echo "$JWT_SECRET" > "$JWT_SECRET_FILE"
    chmod 600 "$JWT_SECRET_FILE"
    echo "[anchor] Generated new JWT_SECRET"
  fi
fi

# Export for supervisord
export DATABASE_URL JWT_SECRET
export OIDC_ENABLED="${OIDC_ENABLED:-}"
export OIDC_PROVIDER_NAME="${OIDC_PROVIDER_NAME:-}"
export OIDC_ISSUER_URL="${OIDC_ISSUER_URL:-}"
export OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-}"
export OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-}"
export DISABLE_INTERNAL_AUTH="${DISABLE_INTERNAL_AUTH:-}"
export APP_URL="${APP_URL:-}"

if [ "$USE_EMBEDDED_POSTGRES" = "1" ]; then
  echo "[anchor] Using embedded Postgres"
else
  echo "[anchor] Using external Postgres: ${PG_HOST}:${PG_PORT}"
fi

# -----------------------------------------------------------------------------
# Start embedded Postgres (if no PG_HOST provided)
# -----------------------------------------------------------------------------
if [ "$USE_EMBEDDED_POSTGRES" = "1" ]; then
  echo "[anchor] Starting embedded Postgres..."
  
  # Ensure data directory permissions
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"
  
  # Set postgres environment
  export POSTGRES_USER="$PG_USER"
  export POSTGRES_PASSWORD="$PG_PASSWORD"
  export POSTGRES_DB="$PG_DATABASE"
  
  /usr/local/bin/docker-entrypoint.sh postgres \
    -c listen_addresses=127.0.0.1 \
    -p "${PG_PORT}" &

  echo "[anchor] Waiting for Postgres..."
  for i in $(seq 1 60); do
    pg_isready -h 127.0.0.1 -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DATABASE}" >/dev/null 2>&1 && break
    sleep 1
  done

  if ! pg_isready -h 127.0.0.1 -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DATABASE}" >/dev/null 2>&1; then
    echo "[anchor] ERROR: Postgres did not become ready"
    exit 1
  fi
  echo "[anchor] Postgres ready"
fi

# -----------------------------------------------------------------------------
# Run database migrations
# -----------------------------------------------------------------------------
echo "[anchor] Running migrations..."
cd /app/server
./node_modules/.bin/prisma migrate deploy

# -----------------------------------------------------------------------------
# Start supervisord (manages API + Web processes)
# -----------------------------------------------------------------------------
echo "[anchor] Starting services..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
