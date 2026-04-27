# Human History Simulator — Implementation Plan

> **For Claude Code, picking this up locally.** This document tells you what to build, in
> what order, and how to know when each piece is done. Read it once end to end before
> writing any code, then revisit each section as you reach it.

---

## 0. Read these first, in this order

Before writing a line of code, read:

1. **`schema_v0.3.md`** — the data model. Pay attention to §3 (entity tables), §4
   (Perspective resolution), and §6 (the six API read patterns). The Trait/Carrier/
   Perspective trio is the conceptual heart of the system; if you don't grok why
   `Trait` is domain-tagged and why `Perspective` is a top-level entity, the rest
   won't make sense.
2. **`editorial_policy_v0.3.md`** — the governance model, especially §1 (two-layer
   governance) and §3 (admission criteria). You don't need to implement governance in
   Phase 0, but the API and UI need to expose Perspectives in a way that's compatible
   with how governance will work later.
3. **`template_v0.3.xlsx`** — the seed dataset. Open it. Look at every sheet. The green
   rows are real data we want ingested, not just illustrative. The README sheet is the
   user-facing tour of the schema.
4. **`ingest.py`** — already written and dry-run-validated against the template. Read it
   to understand what shape the ingested database will have.

If anything in those documents contradicts this plan, **the documents win and you should
flag the contradiction**. This plan is the build order; the documents are the
specification.

---

## 1. What we're building

A scrubbable spatiotemporal map of human history. Users pick a year (slider from ~70,000
BCE to present), pan/zoom a world map, click on population groups or technologies or
ideologies to see their lineage backward and forward in time. The map shows carriers,
their trait mixes, propagation events that link them, and paleo features (land bridges,
ice sheets) that reshape the world over time.

**Perspectives** are one feature among several. They let multiple scholarly traditions
coexist on the same coordinates so users can flip between curated worldviews instead of
being handed a single "official" reading. Useful for contested topics, but not the only
reason to use the map. The Indo-Aryan question is one demo: under `PERSP_INDIAN_AMT` you
see a 2000-1500 BCE Steppe migration into NW South Asia; under `PERSP_INDIAN_OOI` you
don't. Most queries don't involve disagreement at all — they just answer "who was here,
when, and what were they carrying?"

Phase 0 (this plan) ships a thin slice that demonstrates this end to end on the seeded
data. Production launch and the governance/wiki layer come later.

---

## 2. Phase 0 scope (what to build, what to defer)

**In scope:**

- Postgres + PostGIS database with the v0.3 schema applied
- Working `ingest.py` run against `template_v0.3.xlsx`
- A FastAPI backend exposing the six read endpoints from `schema_v0.3.md` §6
- A React + MapLibre GL JS frontend with: world map, year slider, Perspective picker,
  click-to-inspect detail panel, and side-by-side / diff-overlay rendering modes
- Local development via Docker Compose (Postgres + backend + frontend)
- The Indo-Aryan demo working end-to-end as the acceptance test

**Explicitly deferred:**

- User accounts, authentication, anything multi-user
- The governance/wiki edit UI (Layer 1 of editorial policy)
- The Perspective admission workflow (Layer 2 of editorial policy)
- AI-generated dramatizations of historical events
- Vector tile generation / Tippecanoe pipeline (use GeoJSON directly until performance
  forces the upgrade)
- Public deployment, CDN, scaling
- Mobile UI polish (desktop-first; mobile should at least not be broken)
- Anything beyond the 13 example traits, 5 carriers, 7 perspectives currently in the
  seed data

If you find yourself wanting to build something not on the "in scope" list, stop and ask
the user.

---

## 3. Repository layout

```
history-simulator/
├── README.md                    # How to run, what's in the box
├── docker-compose.yml           # postgres + backend + frontend
├── plan.md                      # this file
├── schema_v0.3.md               # data model (reference, do not modify)
├── editorial_policy_v0.3.md     # governance (reference, do not modify)
├── template_v0.3.xlsx           # seed data (reference, do not modify here;
│                                #   user maintains the canonical copy elsewhere)
├── db/
│   ├── 001_schema.sql           # full DDL, generated from schema_v0.3.md
│   ├── 002_indexes.sql          # performance indexes (see §5.4 below)
│   └── 003_seed_geography.sql   # optional: world country boundaries from Natural Earth
├── ingest/
│   ├── ingest.py                # already written; copy from outputs
│   ├── pyproject.toml
│   └── README.md                # how to run ingestion
├── backend/
│   ├── pyproject.toml           # FastAPI + psycopg + pydantic
│   ├── src/
│   │   ├── main.py              # FastAPI app
│   │   ├── db.py                # connection pool
│   │   ├── models.py            # pydantic response models
│   │   ├── resolver.py          # Perspective resolution logic (§6)
│   │   ├── routes/
│   │   │   ├── world.py         # GET /world
│   │   │   ├── trait.py         # GET /trait/:id/lineage[-diff]
│   │   │   ├── claim.py         # GET /claim/:id
│   │   │   ├── carrier.py       # GET /carrier/:id/timeline
│   │   │   └── basemap.py       # GET /paleo-basemap
│   │   └── perspectives.py      # listing + metadata endpoint
│   └── tests/
│       ├── test_resolver.py     # the most important tests in the project
│       └── test_routes.py
└── frontend/
    ├── package.json             # vite + react + maplibre-gl
    ├── src/
    │   ├── App.tsx
    │   ├── components/
    │   │   ├── Map.tsx          # MapLibre wrapper
    │   │   ├── YearSlider.tsx
    │   │   ├── PerspectivePicker.tsx
    │   │   ├── DetailPanel.tsx
    │   │   ├── DiffOverlay.tsx
    │   │   └── LineageGraph.tsx # Sankey/tree viz for trait lineage
    │   ├── hooks/
    │   │   └── useWorldQuery.ts # fetches /world with current year + perspectives
    │   ├── api.ts               # typed client for the backend
    │   └── state.ts             # zustand store for year, bbox, active perspectives
    └── index.html
```

---

## 4. Tech choices (made already; don't re-litigate)

| Layer    | Choice                            | Why                                         |
| -------- | --------------------------------- | ------------------------------------------- |
| DB       | Postgres 16 + PostGIS 3.4         | Geographic types + JSON + maturity          |
| Backend  | FastAPI (Python 3.12)             | Matches ingest.py language; pydantic models |
| DB driver| psycopg 3 (binary)                | Modern, async-capable                       |
| Frontend | React + Vite + TypeScript         | Standard, fast dev loop                     |
| Map      | MapLibre GL JS (not Mapbox)       | Open-source, no token, good vector support  |
| Styling  | Tailwind CSS                      | Fast for utility UI; project is small       |
| State    | Zustand                           | Lighter than Redux for this scale           |
| Tests    | pytest (backend), Vitest (frontend) | Standard                                  |
| Dev env  | Docker Compose                    | Postgres + PostGIS one command              |

Do **not** introduce new frameworks without asking. Specifically: no Next.js, no GraphQL,
no ORM (write SQL directly — the queries are not complex and the schema is unusual
enough that an ORM will fight you).

---

## 5. Build order

Each step has a concrete acceptance test. Don't move on until the test passes.

### 5.1 Database bootstrap

**Task**: Translate `schema_v0.3.md` §3 into `db/001_schema.sql`. Add basic indexes in
`db/002_indexes.sql`.

The schema doc gives you the table definitions almost verbatim. Things to be careful
about:

- All `geography(*, 4326)` columns. Don't accidentally use `geometry`.
- The enums (`trait_domain`, `carrier_type`, `propagation_mechanism`, etc.) must be
  created before tables that reference them.
- Foreign keys: `trait_relation.child_id` and `parent_id` reference `trait(id)`;
  `carrier_trait_mix.carrier_id` references `carrier(id)`; `perspective_endorsement`
  references `perspective(id)` but its `subject_id` is polymorphic (text), so don't
  put an FK on it.
- The `claim` table has a polymorphic `(subject_type, subject_id)` pair — same deal,
  no FK, validated in application code.

**Indexes that matter** (put these in `002_indexes.sql`):

```sql
-- Time-window queries are the hottest path
CREATE INDEX idx_carrier_dates ON carrier (date_min_year, date_max_year);
CREATE INDEX idx_carrier_trait_mix_year ON carrier_trait_mix (as_of_year);
CREATE INDEX idx_propagation_event_dates ON propagation_event (date_min_year, date_max_year);

-- Spatial
CREATE INDEX idx_carrier_centroid ON carrier USING GIST (centroid);
CREATE INDEX idx_carrier_extent ON carrier USING GIST (extent);
CREATE INDEX idx_propagation_source_point ON propagation_event USING GIST (source_point);
CREATE INDEX idx_propagation_dest_point ON propagation_event USING GIST (destination_point);

-- Perspective lookups
CREATE INDEX idx_endorsement_perspective ON perspective_endorsement (perspective_id);
CREATE INDEX idx_endorsement_subject ON perspective_endorsement (subject_type, subject_id);

-- Claim subject lookups
CREATE INDEX idx_claim_subject ON claim (subject_type, subject_id);
CREATE INDEX idx_claim_source ON claim_source (claim_id);
```

**Acceptance test**: `psql` into the database and run all three SQL files in order with
no errors. `\dt` shows all tables. `\dT+ trait_domain` shows the enum with all 9 values.

### 5.2 Docker Compose

**Task**: A `docker-compose.yml` that brings up Postgres+PostGIS and (later) the backend
and frontend. For now just Postgres; add the others as you build them.

Use `postgis/postgis:16-3.4` as the image. Bind-mount `./db` into
`/docker-entrypoint-initdb.d` so the SQL files run automatically on first boot. Expose
port 5432 to localhost (this is dev-only).

**Acceptance test**: `docker compose up -d postgres && psql 'postgresql://history_sim:dev@localhost:5432/history_sim' -c '\dt'` lists all tables.

### 5.3 Run ingest.py

**Task**: Copy `ingest.py` and `template_v0.3.xlsx` into `ingest/`. Run it against the
running Postgres.

**Acceptance test**:
- `python ingest.py template_v0.3.xlsx --dry-run` reports OK with the row counts shown
  in section §3 of this plan.
- `python ingest.py template_v0.3.xlsx --dsn 'postgresql://history_sim:dev@localhost:5432/history_sim'` completes without errors.
- `psql -c 'SELECT count(*) FROM trait'` returns 18.
- `psql -c 'SELECT count(*) FROM perspective'` returns 7.
- `psql -c 'SELECT count(*) FROM perspective_endorsement'` returns 8.
- Re-running ingestion is idempotent (counts don't double).

### 5.4 Backend skeleton

**Task**: A FastAPI app that boots, has a connection pool, and serves a stub
`GET /healthz` plus `GET /perspectives` (list all perspectives with their metadata —
this is the simplest endpoint and exercises the DB connection).

Use `psycopg_pool.AsyncConnectionPool` for the pool. Lifespan management goes in
FastAPI's `lifespan` context manager.

The pydantic response models for `Perspective` should match the columns in the
`perspective` table 1:1.

**Acceptance test**:
- `curl localhost:8000/healthz` returns `{"status": "ok"}`.
- `curl localhost:8000/perspectives` returns a JSON array with 7 perspectives.
- `PERSP_REICH_2018` and `PERSP_POSTREICH_2025` both have `default_active: true`.

### 5.5 The resolver

**Task**: Implement `backend/src/resolver.py` per `schema_v0.3.md` §4. This is the
single most important module in the backend; everything else is a thin wrapper around it.

The resolver takes a list of active perspective IDs and a query (e.g. "all carriers
overlapping bbox B at year Y") and returns the resolved view of the world: which
carriers are present, which trait mixes apply, which claims are endorsed/rejected/
nuanced/asserted by which perspective.

Pseudocode (from schema doc):

```python
async def resolve_world(conn, year, bbox, perspective_ids):
    # 1. Fetch all candidate entities (carriers, mixes, propagation events, features)
    #    valid at `year`, intersecting `bbox`.
    # 2. For each entity, fetch any perspective_endorsement rows whose
    #    perspective_id IN perspective_ids AND subject matches the entity.
    # 3. Apply stance:
    #      'endorses' or absent: include with default values
    #      'rejects':            drop the entity from this perspective's view
    #      'nuances':            include with override_statement / override_quant
    #      'asserts':            include even if no default exists
    # 4. Return per-perspective views, keyed by perspective_id.
```

**Critical design point**: The resolver returns *separate views per active perspective*,
not one merged view. The frontend decides whether to render them side by side, diff,
or blend. The backend never produces a "merged truth."

**Acceptance test**: A pytest in `tests/test_resolver.py` that:
- Loads the seed data (use a Docker Compose-managed test database or testcontainers)
- Resolves the world at year -1700 with `[PERSP_REICH_2018]` active
- Asserts that `CARR_NW_SOUTH_ASIA_LATE_BRONZE` is present, with `STEPPE_MLBA` at 0.15
- Resolves the same query with `[PERSP_INDIAN_OOI]` active
- Asserts that `CLM_002` is returned with stance `nuances` and the override statement
  about timing/directionality
- Resolves with `[PERSP_REICH_2018, PERSP_INDIAN_OOI]` active
- Asserts that the response has *both* perspective views, distinct, not collapsed

This test, passing, is what proves the design works.

### 5.6 The six read endpoints

**Task**: Implement the routes from `schema_v0.3.md` §6. In order of importance:

1. `GET /world?year=Y&bbox=W,S,E,N&perspectives=P1,P2` — drives the main map.
2. `GET /carrier/:id/timeline?perspective=P` — drives the "watch this group evolve" view.
3. `GET /claim/:id?perspectives=P1,P2` — drives the detail panel's "why?" content.
4. `GET /trait/:id/lineage?perspective=P` — drives the lineage graph.
5. `GET /trait/:id/lineage-diff?perspectives=P1,P2` — the killer view; do this fifth
   only because it's the hardest. Returns both lineage trees with edges color-coded by
   which perspective(s) endorse each.
6. `GET /paleo-basemap?year=Y&perspective=P` — for the time-evolving basemap. Phase 0
   can return `physical_feature_snapshot` polygons + `paleoclimate_state.sea_level_meters`;
   actual coastline derivation happens client-side or as a Phase 1 enhancement.

All endpoints accept `?perspectives=` (comma-separated) and return per-perspective views
where applicable. The default perspective set is whichever perspectives have
`default_active=true` (currently `PERSP_REICH_2018` and `PERSP_POSTREICH_2025`).

**Acceptance test**: An integration test that walks all six endpoints with the
Indo-Aryan demo as the script:
- `/perspectives` returns 7 perspectives
- `/world?year=-1700&bbox=60,20,90,40&perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI`
  returns two perspective views with the carrier and mix differing
- `/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/timeline?perspective=PERSP_INDIAN_AMT`
  returns the steppe-mix snapshots
- `/claim/2?perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI` returns endorses + nuances
- `/trait/STEPPE_MLBA/lineage?perspective=PERSP_REICH_2018` returns the descent tree

### 5.7 Frontend skeleton

**Task**: Vite + React + TypeScript app with a MapLibre map, a year slider in the
footer, and a Perspective picker in the corner. No data yet — just the chrome.

MapLibre style: use a free vector tile provider (Maptiler free tier, OSM-based) or just
a flat raster basemap from an open source. Don't spend cycles on cartography here; the
custom rendering is on top of the basemap, not in it.

Year slider: range -70000 to 2025, with logarithmic spacing pre-Holocene (so the user
can actually scrub through 50,000 BCE without the slider being unusable). Use
`d3-scale` for this; `scaleSymlog` works.

Perspective picker: dropdown showing all admitted perspectives, with a multi-select.
Default to the two `default_active=true` perspectives.

**Acceptance test**: `npm run dev`, open browser, see a world map. Slide the year
slider; URL state updates. Toggle a perspective; URL state updates. No data renders
yet; that's fine.

### 5.8 World rendering

**Task**: Wire `GET /world` into the map. Each carrier renders as a circle at its
centroid (sized by some carrier-property like population estimate, or just constant
for Phase 0). When two perspectives are active, render in **side-by-side** mode: split
the viewport, two synchronized MapLibre instances.

When the user clicks a carrier, open the detail panel showing:
- The carrier's identity
- Its trait mix at the current year, *for each active perspective*
- The supporting claims with sources
- The `methodology_notes` for each active perspective (so the user knows what each lens
  privileges)

**Acceptance test**: At year -1700, with both Indian perspectives active, the user can
see two maps side-by-side, click on the NW South Asia carrier, and see different trait
mixes attributed to AMT vs OOI in the detail panel. **This is the killer demo and is the
acceptance test for Phase 0 as a whole.**

### 5.9 Diff-overlay mode

**Task**: A toggle that switches from side-by-side to a single-map diff overlay.
Carriers/features that all active perspectives agree on render solid; ones with
disagreement render with hatched fills. Hover or click shows the disagreement.

Hatched fills in MapLibre: use a `pattern` fill or, simpler, a repeating SVG image as a
sprite and reference it in the layer's `fill-pattern`.

This is the most visually demanding component. Budget time accordingly. If you can't get
hatching to look clean, fall back to outlined polygons with a red stroke for "disagreed."

**Acceptance test**: Same Indo-Aryan demo, but in diff-overlay mode. The disputed
carrier renders with a visual marker indicating disagreement. Clicking shows what
each perspective claims.

### 5.10 Lineage graph (stretch, optional for Phase 0)

**Task**: When the user clicks a Trait in the detail panel, render its lineage tree
using d3-sankey or react-flow. Edges are colored by which perspective endorses them.
For traits with multiple admitted lineage trees (Trumpism, Progressive Liberalism), the
graph shows all of them with color-coded edges.

This is the cleanest visualization of what makes the system different. If you have time,
do it. If you don't, skip it for Phase 0.

**Acceptance test**: Click on `IDEO_TRUMPISM`, see three different lineage trees overlaid
in three colors (academic-mainstream-left, conservative-intellectual, libertarian).

---

## 6. Things that will trip you up

**The seed dataset is small.** 18 traits, 5 carriers, 8 endorsements. Don't build
anything that assumes scale. Don't add caching. Don't paginate. The whole world fits in
RAM ten times over.

**`subject_id` in `claim` and `perspective_endorsement` is polymorphic text, not an FK.**
The application is responsible for validating it. Build a small helper that, given a
`(subject_type, subject_id)` pair, looks up the entity. Don't try to be clever with
SQL CHECK constraints across tables.

**Years are negative for BCE and there's no year 0.** -1 = 1 BCE, +1 = 1 CE. The seed
data uses negative integers consistently. Make sure your year slider, your time-window
queries, and your display formatting all agree on this.

**Coordinates can cross the antimeridian.** Beringia's bbox is `160,55,-150,72`. PostGIS
handles this if you use `geography` types and `ST_DWithin`; it does *not* handle this if
you naively use `BETWEEN` on lat/lon columns. Stick to PostGIS spatial functions.

**Trait-mix fractions for a carrier-year-domain should sum to ~1.0 but only within
domain.** A carrier can have a genetic mix summing to 1.0 *and* an ideological mix
summing to 1.0 *and* a linguistic mix summing to 1.0, all simultaneously. The validator
in `ingest.py` already enforces this; the resolver and frontend should respect it.

**Perspectives have `domain_scope`.** A genetic-only perspective like `PERSP_REICH_2018`
should not be shown as an option when the user is looking at ideological lineages. The
Perspective picker's filter logic depends on the current view's domain.

**The empirical-floor test (editorial policy §3.3) lives in the editorial layer, not
the schema.** Don't try to encode "this perspective fails the empirical-floor" in code;
that's a human judgment that a human board makes. The schema just stores
`status: 'admitted' | 'provisional' | 'rejected' | 'retired'`.

**Don't display retired or rejected perspectives by default.** They should be hidden
unless the user explicitly opts in (e.g., a "show deprecated perspectives" toggle).

---

## 7. What "Phase 0 done" looks like

A demo you can run on a laptop:

1. `docker compose up`
2. Wait 30 seconds for Postgres to boot and ingest to run
3. Open `http://localhost:5173`
4. World map loads with year slider at default (e.g. -2000)
5. Two perspectives active by default (`PERSP_REICH_2018`, `PERSP_POSTREICH_2025`)
6. User changes Perspective picker to `PERSP_INDIAN_AMT` and `PERSP_INDIAN_OOI`
7. User scrubs year slider to -1700
8. User clicks the carrier in NW South Asia
9. Detail panel shows two columns:
   - AMT: 55% ANI, 30% ASI, 15% Steppe_MLBA — endorses Steppe migration claim
   - OOI: same numerical signal but with override statement contesting timing/direction
10. User toggles to diff-overlay mode; the disputed carrier visually indicates disagreement
11. User clicks "show sources" on the detail panel; sees Narasimhan 2019 and Reich Ch.6,
    each weighted differently by AMT vs OOI per the source weight overrides

If a friend can sit down at the laptop, do this in under two minutes without
explanation, and understand that the system is showing them a contested historical claim
with the disagreement made visible — Phase 0 is done.

---

## 8. After Phase 0

Don't build any of this until the user explicitly asks, but for context:

- **Phase 1** (3-4 months): full Reich extraction, post-Reich revisions, paleoclimate
  basemap with derived coastlines, vector tile pipeline (Tippecanoe), proper auth.
- **Phase 2** (6-12 months): wiki edit UI, Perspective admission workflow, editorial
  board tooling, public deployment.
- **Phase 3**: continuous updates, AI-assisted source ingestion, dramatizations,
  governance scaling.

The data model and API are designed so that Phase 0 is a forward-compatible foundation.
Don't take shortcuts that block these later phases (e.g., don't bake "active perspective"
as a global singleton; users will need their own active sets).

---

## 9. When to stop and ask

Stop and ask the user before:

- Adding any dependency not in the tech-choices table (§4)
- Modifying the schema beyond cosmetic changes (column rename, comment additions)
- Modifying `ingest.py` substantively (small bug fixes are fine)
- Skipping any acceptance test
- Making any decision that affects the editorial-policy layer
- Implementing AI-generated content (dramatizations, synthesized text, etc.)

Don't ask before:

- Adding indexes, query optimization, refactoring
- Adding tests
- Renaming variables, restructuring files within the layout from §3
- Frontend styling decisions, color palettes, layout tweaks
- Choosing between equivalent libraries within the same role (e.g. zustand vs. jotai)

---

## 10. Files to produce, in build order

1. `db/001_schema.sql`
2. `db/002_indexes.sql`
3. `docker-compose.yml`
4. `ingest/` (copy in existing files, add `pyproject.toml` and `README.md`)
5. `backend/pyproject.toml`, `backend/src/db.py`, `backend/src/main.py`
6. `backend/src/models.py`, `backend/src/perspectives.py`
7. `backend/src/resolver.py` + `backend/tests/test_resolver.py`
8. `backend/src/routes/*.py`
9. `frontend/package.json`, `frontend/src/App.tsx`, basic chrome
10. `frontend/src/api.ts`, `frontend/src/state.ts`, `frontend/src/hooks/useWorldQuery.ts`
11. `frontend/src/components/Map.tsx`, `YearSlider.tsx`, `PerspectivePicker.tsx`
12. `frontend/src/components/DetailPanel.tsx`
13. `frontend/src/components/DiffOverlay.tsx`
14. `frontend/src/components/LineageGraph.tsx` (optional)
15. `README.md` at repo root (how to run, what's done, what's next)

---

## 11. Done is better than perfect

The single most valuable thing you can produce is a working end-to-end demo of the
Indo-Aryan example. Better to have a janky-looking but functional Phase 0 than a
beautifully designed but incomplete system. The novel contribution of this project is
the data model and the rendering of contested knowledge — not the visual polish. Polish
comes later. Get the contested-knowledge rendering working first.

If you find yourself spending more than half a day on a single Phase 0 task, stop and
flag it. The plan is meant to be doable in 2-3 weeks for a competent solo developer; if
something is taking dramatically longer, the plan is wrong, not you.
