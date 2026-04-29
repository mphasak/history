#!/usr/bin/env bash
# Pre-flight: confirm the stack is up and reachable. Cheap sanity ping.
set -euo pipefail

API="${API_URL:-http://localhost:8000}"
DB_DSN="${DATABASE_URL:-postgresql://history_sim:dev@localhost:5433/history_sim}"

echo "[health] backend /healthz ..."
if ! curl -sfm 5 "$API/healthz" | grep -q '"status":"ok"'; then
  echo "  FAIL: backend not responding at $API"
  echo "  Hint: docker compose up -d backend" >&2
  exit 1
fi
echo "  ok"

echo "[health] postgres ..."
if ! PGCONNECT_TIMEOUT=3 psql "$DB_DSN" -tAc "SELECT 1" 2>/dev/null | grep -q 1; then
  echo "  FAIL: postgres not reachable at $DB_DSN"
  echo "  Hint: docker compose up -d postgres" >&2
  exit 1
fi
echo "  ok"

echo "[health] all green"
