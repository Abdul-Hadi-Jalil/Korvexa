#!/usr/bin/env sh
set -e

# Migrations are the source of truth for the schema: apply them on every boot
# so a fresh container (or a deploy) always converges to head before serving.
echo "Running database migrations..."
alembic upgrade head

if [ "${SEED_DEMO:-false}" = "true" ]; then
  echo "SEED_DEMO=true -> seeding demo data..."
  python -m app.seed || echo "Seed skipped/failed (non-fatal)."
fi

echo "Starting Uvicorn on 0.0.0.0:${PORT:-8000}..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
