#!/usr/bin/env bash
# Architectural guardrails. Each block is one CLAUDE.md invariant turned
# into a grep / git command. Cheap and deterministic — safe to run on
# every commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "  FAIL: $*" >&2; exit 1; }
ok()   { echo "  ok: $*"; }

cd "$ROOT"

echo "[invariants] no ORM imports in backend..."
if grep -rEn 'from sqlalchemy|^import sqlalchemy|from sqlmodel|^import sqlmodel|from peewee|^import peewee|from tortoise|^import tortoise' backend/src/ 2>/dev/null; then
  fail "ORM import detected in backend/src/. The 'No ORM' rule is in CLAUDE.md."
fi
ok "no ORM imports"

echo "[invariants] DB table is geo_region, not geography..."
# Quick scan for accidental "FROM geography" / "JOIN geography" usages.
if grep -rEn '\b(FROM|JOIN|UPDATE|INTO)\s+geography\b' backend/src/ db/ 2>/dev/null; then
  fail "Found 'geography' used as a table name. The table is 'geo_region' (geography is the PostGIS type)."
fi
ok "geo_region naming respected"

echo "[invariants] no DROP TABLE in seed files..."
if grep -rEn '\bDROP\s+TABLE\b' db/0[0-9][0-9]_seed_*.sql 2>/dev/null; then
  fail "Seed file contains DROP TABLE. Seeds must be additive (DELETE-by-prefix only)."
fi
ok "seeds are additive"

echo "[invariants] every db/0NN_seed file has an idempotent DELETE..."
for f in db/0[0-9][0-9]_seed_*.sql; do
  [[ -f "$f" ]] || continue
  if ! grep -qE '^(DELETE|--.*idempotent)' "$f"; then
    fail "$f doesn't appear idempotent (no top-level DELETE / no idempotency note)."
  fi
done
ok "all seed files declare idempotency"

echo "[invariants] spec files unmodified vs main..."
for f in schema_v0.3.md editorial_policy_v0.3.md template_v0.3.xlsx ingest/ingest.py; do
  if git diff --quiet origin/main -- "$f" 2>/dev/null; then
    :
  else
    # Only fail if the file has staged or committed differences from origin/main
    # (working-tree changes are fine — agents may be experimenting locally).
    if ! git diff --quiet origin/main HEAD -- "$f" 2>/dev/null; then
      fail "$f differs from origin/main. Spec files / ingest.py are read-only per CLAUDE.md."
    fi
  fi
done
ok "spec files untouched"

echo "[invariants] resolver does not collapse perspectives..."
# Sanity check: resolve_world's return must be keyed by perspective id and
# include the precomputed disagreement side-channel.
if ! grep -q '"_disagreed_carrier_ids"' backend/src/resolver.py; then
  fail "resolver.py no longer surfaces _disagreed_carrier_ids — diff overlay would silently break."
fi
if ! grep -q "for pid in perspective_ids" backend/src/resolver.py; then
  fail "resolver.py no longer iterates perspective_ids — looks like perspectives are being merged."
fi
ok "resolver keeps perspectives separate"

echo "[invariants] all green"
