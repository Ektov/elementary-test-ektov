#!/usr/bin/env bash
# Truncate all data in schema `elementary` (demo_db).
# Usage:
#   ./scripts/truncate_elementary.sh
#   ./scripts/truncate_elementary.sh --docker   # via docker compose postgres

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL="${ROOT}/scripts/truncate_elementary.sql"

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
PGDATABASE="${PGDATABASE:-demo_db}"

if [[ "${1:-}" == "--docker" ]]; then
  echo "Truncating elementary via docker compose service postgres..."
  docker compose -f "${ROOT}/docker-compose.yml" exec -T postgres \
    psql -U postgres -d demo_db -v ON_ERROR_STOP=1 -f - <"${SQL}"
else
  echo "Truncating elementary on ${PGHOST}:${PGPORT}/${PGDATABASE}..."
  export PGPASSWORD
  psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" \
    -v ON_ERROR_STOP=1 -f "${SQL}"
fi

echo "OK: elementary schema tables are empty."
