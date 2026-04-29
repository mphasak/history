#!/usr/bin/env bash
# Run the unit/integration test suites. Backend = pytest inside the running
# `backend` container (so it can reach Postgres via Docker DNS); frontend =
# `tsc --noEmit`. We deliberately don't try to bring containers up here —
# health.sh validated that already.
set -euo pipefail

echo "[tests] copying current test files into backend container..."
docker compose cp ./backend/tests/test_resolver.py backend:/app/tests/test_resolver.py >/dev/null
docker compose cp ./backend/tests/test_routes.py   backend:/app/tests/test_routes.py   >/dev/null

echo "[tests] backend pytest..."
docker compose exec -T backend python -m pytest tests/ -q

echo "[tests] frontend tsc --noEmit..."
docker compose exec -T frontend sh -lc 'cd /app && npx tsc --noEmit'

echo "[tests] all green"
