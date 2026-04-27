# CLAUDE.md — Human History Simulator

## What this is

A spatiotemporal history map where **disagreement is structural**: two Perspectives
on the same (year, bbox) query return materially different worlds. The Indo-Aryan
debate is the canonical demo. See `plan.md` for scope; `schema_v0.3.md` for the
data model; `editorial_policy_v0.3.md` for governance.

---

## Running the stack

```bash
docker compose up          # Postgres (port 5433) + ingest + backend + frontend
```

- Postgres initializes via `db/001_schema.sql` and `db/002_indexes.sql`
- Ingest container seeds data from `template_v0.3.xlsx`
- Backend starts after ingest completes (`service_completed_successfully`)
- Frontend dev server at http://localhost:5173
- Backend API at http://localhost:8000 (OpenAPI at /docs)

**Outside Docker:**

```bash
# DB
psql 'postgresql://history_sim:dev@localhost:5433/history_sim'

# Ingest
python3 -m venv .venv && .venv/bin/pip install openpyxl "psycopg[binary]"
.venv/bin/python ingest/ingest.py template_v0.3.xlsx \
  --dsn 'postgresql://history_sim:dev@localhost:5433/history_sim'

# Backend
cd backend
pip install fastapi "uvicorn[standard]" "psycopg[binary]" psycopg-pool pydantic
DATABASE_URL='postgresql://history_sim:dev@localhost:5433/history_sim' \
  uvicorn src.main:app --port 8000 --reload

# Frontend
cd frontend && npm install
VITE_API_URL=http://localhost:8000 npm run dev
```

## Tests

```bash
cd backend
pip install pytest pytest-asyncio httpx
DATABASE_URL='postgresql://history_sim:dev@localhost:5433/history_sim' \
  API_URL='http://localhost:8000' \
  pytest tests/ -v
```

Resolver tests (`test_resolver.py`) hit the DB directly via async psycopg3.
Route tests (`test_routes.py`) hit the live uvicorn server — start it first.

---

## Critical non-obvious facts

### `geo_region`, not `geography`

The schema doc says `CREATE TABLE geography(...)` but PostGIS creates a TYPE
named `geography`. PostgreSQL won't let a table and a type share a name, so the
table is called **`geo_region`** everywhere: `db/001_schema.sql`, `ingest/ingest.py`,
and any raw SQL. Don't rename it back.

### Postgres is on port 5433

Port 5432 is occupied by another service on this machine. All DSNs use 5433 for
the host port. Inside Docker the containers still talk to `postgres:5432`.

### Claim IDs are bigserial and non-deterministic across re-ingests

`DELETE FROM claim` does not reset the sequence. After the first ingest run the
claims might be IDs 1–5; after a second run they'll be 6–10. Tests that need a
specific claim (e.g. the OOI nuances test) must discover the ID via:

```sql
SELECT subject_id FROM perspective_endorsement
WHERE perspective_id = 'PERSP_INDIAN_OOI' AND stance = 'nuances'
  AND lower(subject_type) = 'claim'
LIMIT 1;
```

### `subject_type` in `perspective_endorsement` is camelCase from the spreadsheet

The spreadsheet writes `Claim` and `TraitRelation`. The resolver normalizes these
via `_normalize_subject_type()` in `backend/src/resolver.py`. When writing new
resolver lookups always use the lowercase-snake form (`"claim"`, `"trait_relation"`)
as the key — the normalization map handles the translation.

### `domain_scope` must be cast to `text[]` in SQL

`perspective.domain_scope` is a `trait_domain[]` (custom enum array). psycopg3
returns custom enum arrays as a raw PostgreSQL literal string (`{genetic}`), not
a Python list. Any SELECT that reads this column must cast:

```sql
SELECT domain_scope::text[] AS domain_scope FROM perspective ...
```

See `backend/src/perspectives.py` for the pattern.

### `fraction` columns return `decimal.Decimal` from psycopg3

`carrier_trait_mix.fraction` is `numeric(4,3)`. psycopg3 maps this to Python
`Decimal`. Always `float(row["fraction"])` before arithmetic comparisons.

### No year 0

Years are BCE-negative, CE-positive, with no year 0 (`-1` = 1 BCE, `1` = 1 CE).
This applies to the slider, time-window queries, and display formatting.

---

## Architecture rules (from `plan.md` §4 and §9)

- **No ORM.** Write SQL directly. The schema is unusual enough that an ORM fights you.
- **No new frameworks** without asking the user. Stack is locked: FastAPI, psycopg3,
  React, MapLibre GL JS, Zustand, Tailwind.
- **Resolver never merges Perspectives.** `resolve_world()` returns a dict keyed
  by perspective ID. The frontend decides how to render them.
- **Don't modify `schema_v0.3.md`, `editorial_policy_v0.3.md`, or `template_v0.3.xlsx`.**
  They are the spec. If the code contradicts them, flag the contradiction.
- **Don't modify `ingest.py` substantively.** Small bug fixes are fine.
- **Don't implement anything from Phase 1+** (auth, governance UI, vector tiles,
  AI dramatizations, public deployment) without explicit instruction.

---

## Key files

| File | Purpose |
|------|---------|
| `backend/src/resolver.py` | Core Perspective resolution logic — most important module |
| `backend/src/perspectives.py` | `GET /perspectives` endpoint |
| `backend/src/routes/world.py` | `GET /world` — drives the main map |
| `backend/src/routes/claim.py` | `GET /claim/:id` — per-Perspective claim stances |
| `db/001_schema.sql` | Full DDL (generated from schema_v0.3.md) |
| `ingest/ingest.py` | Spreadsheet → Postgres; idempotent |
| `frontend/src/state.ts` | Zustand store: year, bbox, activePerspectives, renderMode |
| `frontend/src/components/Map.tsx` | MapLibre wrapper; export is `WorldMap` (not `Map`) |

---

## The killer demo (acceptance test for Phase 0)

1. `docker compose up`
2. Open http://localhost:5173
3. Set Perspective picker to **PERSP_INDIAN_AMT** + **PERSP_INDIAN_OOI**
4. Slide year to **-1700**
5. Click the dot in NW South Asia
6. Detail panel: AMT column shows 55% ANI / 30% ASI / 15% Steppe_MLBA with the
   Steppe migration claim **endorsed**; OOI column shows same signal but with the
   claim **nuanced** ("interpreted as much earlier and/or bidirectional")
7. Toggle **Diff Overlay** — the disputed carrier renders in red
