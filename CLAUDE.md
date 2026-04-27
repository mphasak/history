# CLAUDE.md — Human History Simulator

## What this is

A scrubbable spatiotemporal map of human history. Pick a year, pan the world,
click on a place to see who lived there and what they carried (genes, languages,
technologies, ideologies). The map shows carriers, their trait mixes, and the
propagation events that link them across time.

Perspectives are one feature among several — they let multiple scholarly
traditions coexist on the same coordinates so users can flip between curated
worldviews instead of being handed a single "official" reading. Useful for
contested topics, but not the headline. The Indo-Aryan debate (`PERSP_INDIAN_AMT`
vs `PERSP_INDIAN_OOI`) is one demo, not the thesis.

See `plan.md` for scope; `schema_v0.3.md` for the data model;
`editorial_policy_v0.3.md` for governance.

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

### Paleo features use a NULL-geometry sentinel for "disappeared"

`physical_feature_snapshot.geometry` is nullable. A snapshot with `geometry IS NULL`
at year Y means "this feature is gone as of Y". The `/paleo-basemap` endpoint
returns the latest snapshot ≤ year via `DISTINCT ON (feature_id) ... ORDER BY
feature_id, as_of_year DESC`, so the NULL row wins for years past disappearance.
Frontend filters out null geometries before rendering. Use this pattern when
adding more paleo features rather than introducing a `valid_until_year` column.

### Carrier `extent` is sparse; the resolver buffers centroids by carrier type

The seed spreadsheet only populates `carrier.centroid`. `resolve_world` falls
back to `ST_Buffer(centroid, RADIUS)` where RADIUS comes from
`_CARRIER_DEFAULT_RADIUS_M` keyed by `carrier.type` — that way fill-mode
rendering always has a polygon. The carrier view exposes `extent_is_real` so
the UI can dash-outline buffered extents.

### `paleo-seed` compose service runs every `docker compose up`

`db/003_seed_paleo_features.sql` is applied by a dedicated `paleo-seed` service
that runs after `ingest`. It is idempotent (DELETE+INSERT keyed on
`PF_PALEO_*` IDs) so existing pgdata volumes pick up edits without requiring
`docker compose down -v`. New paleo features should follow the same ID prefix
convention.

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
| `backend/src/routes/world.py` | `GET /world` and `GET /world/at` — drive the main map and click-at-point lookups |
| `backend/src/routes/basemap.py` | `GET /paleo-basemap` — returns paleo feature polygons + sea level for a year |
| `backend/src/routes/claim.py` | `GET /claim/:id` — per-Perspective claim stances |
| `db/001_schema.sql` | Full DDL (generated from schema_v0.3.md) |
| `db/003_seed_paleo_features.sql` | Hand-authored land-bridge / ice-sheet polygons; applied by the `paleo-seed` compose service |
| `ingest/ingest.py` | Spreadsheet → Postgres; idempotent |
| `frontend/src/state.ts` | Zustand store: year, bbox, activePerspectives, renderMode, vizMode, clickPoint |
| `frontend/src/components/Map.tsx` | MapLibre wrapper; export is `WorldMap` (not `Map`); also exports `DOMAIN_COLORS` used by `Legend` |
| `frontend/src/components/Legend.tsx` | Bottom-left legend; swaps content based on vizMode and active paleo features |
| `frontend/src/components/ClickPointPanel.tsx` | Right-side picker shown when an empty map point is clicked |

---

## Phase 0 acceptance demo

The base flow exercises the core map:

1. `docker compose up`
2. Open http://localhost:5173
3. Slide the year, pan the map, click on a carrier — detail panel shows who
   lived there at that year, with their trait mix and supporting claims.

The Perspectives feature is exercised by an additional Indo-Aryan demo:

1. Set Perspective picker to **PERSP_INDIAN_AMT** + **PERSP_INDIAN_OOI**
2. Slide year to **-1700**
3. Click the dot in NW South Asia
4. Detail panel: AMT column shows 55% ANI / 30% ASI / 15% Steppe_MLBA with the
   Steppe migration claim **endorsed**; OOI column shows same signal but with
   the claim **nuanced** ("interpreted as much earlier and/or bidirectional")
5. Toggle **Diff Overlay** — the disputed carrier renders in red
