# Human History Simulator

A scrubbable spatiotemporal map of human history. Pick a year, pan the world,
click on a place to see who lived there and what they carried — genes,
languages, technologies, ideologies — and how those things moved across time.

Perspectives are one feature among several: when scholarly traditions disagree
about the same coordinates (e.g. Indo-Aryan migration vs. out-of-India), the
map can show both curated readings instead of forcing a single answer.

## Quick start

```bash
docker compose up
```

Wait ~30 seconds for Postgres to initialize and the ingest to run, then open:

```
http://localhost:5173
```

The backend API is at `http://localhost:8000` (OpenAPI docs at `/docs`).

> **Note on ports**: The compose file maps Postgres to host port **5433** (not 5432) to avoid
> conflicts with other Postgres instances. Services inside Docker still connect on 5432.
>
> **Apple Silicon Macs**: The PostGIS image (`postgis/postgis:16-3.4`) is amd64-only and runs
> under Rosetta 2 emulation. This works with Docker Desktop but startup is slower (~60s).

## Phase 0 demo

**Base flow** — exercises the core map:

1. Open the app. Two perspectives are active by default.
2. Scrub the year slider; pan the world map.
3. Click anywhere on land to see which carrier(s) occupied that point at the
   selected year, with trait mixes and supporting claims.
4. Toggle between **pointwise** (archaeological samples) and **fill**
   (carrier extents) viz modes via the legend.

**Perspectives demo** — Indo-Aryan migration vs. out-of-India:

1. Change the Perspective picker to **PERSP_INDIAN_AMT** and **PERSP_INDIAN_OOI**.
2. Scrub the year slider to **-1700** (1700 BCE).
3. Click the carrier dot in NW South Asia.
4. The detail panel shows two columns with the (identical) trait mixes
   plus a **Claims about this population** section. The Steppe-migration
   claim is highlighted as contested: AMT *endorses* it, citing
   Narasimhan 2019 and Reich Ch. 6 (with weight overrides shown);
   OOI *nuances* it with the override statement
   *"Genetic Steppe signal acknowledged but interpreted as much earlier
   and/or bidirectional, not a 2000-1500 BCE Aryan migration."*
5. Toggle **Diff Overlay** mode. The disputed carrier renders in red.
   The diff is computed from claim-level stance differences, so
   carriers can light up even when their trait mixes and per-carrier
   endorsements match — the disagreement lives on the propagation
   event, not the carrier row itself.

## Architecture

| Layer    | Technology                        |
| -------- | --------------------------------- |
| DB       | Postgres 16 + PostGIS 3.4         |
| Backend  | FastAPI + psycopg3 + Pydantic     |
| Frontend | React + Vite + MapLibre GL JS     |
| State    | Zustand                           |
| Dev env  | Docker Compose                    |

## Running without Docker

**Database** (requires a local Postgres+PostGIS instance):

```bash
psql -U postgres -c "CREATE DATABASE history_sim;"
psql -U postgres -d history_sim -f db/001_schema.sql
psql -U postgres -d history_sim -f db/002_indexes.sql
```

**Ingest**:

```bash
cd ingest
pip install -e .
python ingest.py ../template_v0.3.xlsx \
  --dsn 'postgresql://postgres:@localhost:5432/history_sim'
```

**Backend**:

```bash
cd backend
pip install -e .
DATABASE_URL='postgresql://postgres:@localhost:5432/history_sim' \
  uvicorn src.main:app --reload
```

**Frontend**:

```bash
cd frontend
npm install
VITE_API_URL=http://localhost:8000 npm run dev
```

## Running tests

```bash
cd backend
pip install -e ".[test]"
DATABASE_URL='postgresql://history_sim:dev@localhost:5432/history_sim' pytest
```

## Project structure

```
history-simulator/
├── db/                  # SQL schema + indexes
├── ingest/              # One-shot data ingestion from template_v0.3.xlsx
├── backend/             # FastAPI application
│   ├── src/
│   │   ├── resolver.py  # Core Perspective resolution logic
│   │   ├── routes/      # Six read endpoints
│   │   └── models.py    # Pydantic response models
│   └── tests/
└── frontend/            # React + MapLibre application
    └── src/
        ├── components/  # Map, YearSlider, PerspectivePicker, DetailPanel, DiffOverlay
        ├── hooks/       # useWorldQuery
        ├── api.ts       # Typed API client
        └── state.ts     # Zustand store
```

## What's in scope (Phase 0)

- Postgres + PostGIS schema (v0.3)
- Ingestion of the seed dataset (18 traits, 24 carriers, 7 perspectives)
  from `template_v0.3.xlsx`, plus four idempotent seed services applied
  by docker-compose:
    - `paleo-seed` (`db/003_seed_paleo_features.sql`) — ice-sheet
      polygons + paleoclimate keyframes
    - `genetics-seed` (`db/004_seed_population_genetics.sql`) — Reich-
      style ancestry components and Pleistocene/Holocene carriers
    - `carriers-seed` (`db/005_seed_historical_carriers.sql`) — 80
      additional carriers spanning non-sapiens hominins, early sapiens,
      additional UP/Mesolithic clusters, and Holocene/historical
      ethnolinguistic groups
    - `carriers-provenance-seed`
      (`db/006_seed_historical_carrier_ancestry.sql`) — ancestry
      breakdowns + cited claims for the carriers from 005
    - `carrier-threats-seed`
      (`db/007_carrier_threats.sql`) — `carrier_threat` table +
      `threat_type` enum, plus 94 seeded threats (climate, war,
      disease, colonization, megafauna loss, etc.) covering most of
      the carrier set with year windows and citations
    - `historical-places-seed`
      (`db/008_historical_places.sql`) — `historical_place` table
      seeded with 64 era-appropriate place labels (Constantinople,
      Tenochtitlan, Lutetia, etc.) with year windows that the map
      uses in "Historical" label mode
- Read endpoints with Perspective resolution: `/perspectives`,
  `/world` (with `disagreed_carrier_ids` side-channel), `/world/at`,
  `/carrier/{id}/timeline`, `/carrier/{id}/claims`,
  `/carrier/{id}/threats`, `/claim/{id}`,
  `/trait/{id}/lineage[-diff]`, `/paleo-basemap`, `/paleo-coastlines`
  (proxied GPlates Web Service for deep time), `/historical-places`
- World map with piecewise-log year slider (-10 Mya → 2025 with no
  year 0), epoch jump labels, and Perspective picker
- Three-source paleo basemap: modern OSM tiles + four pre-eroded
  continental-shelf depth bands (-25/-50/-90/-150 m) selected by
  current sea level + GPlates deep-time coastlines for year < -3 Mya
- Three-mode label control:
  - **Modern**: CartoDB Voyager labels with present-day place names
    and borders
  - **Historical**: hide modern labels and surface era-appropriate
    place names (Constantinople 330–1453, Tenochtitlan 1325–1521,
    Beringia / Doggerland / Sundaland / Sahul during their
    Pleistocene windows, etc.)
  - **None**: clean basemap with no labels — best for paleo scrubs
- Click-anywhere-on-map → carriers covering that spacetime point,
  ranked by distance, with proper BCE/CE formatting
- Pointwise / fill visualization toggle with a legend that swaps
  content based on viz mode and active paleo features
- Paleo overlays (land bridges, ice sheets) driven by
  physical_feature_snapshot
- Side-by-side and diff-overlay perspective comparison modes; diff
  overlay marks carriers contested at the *claim* layer (carrier
  itself, its trait mixes, or propagation events overlapping it)
- Detail panel showing per-perspective trait mixes plus
  a "Threats at {year}" section (climate, war, disease,
  colonization, etc., with severity 1–5 and citations) and
  a "Claims about this population" section with stance badges
  (endorses / nuances / rejects / asserts), override statements,
  and citation lists with weight-override annotations
- Indo-Aryan demo working end to end with the contested-knowledge
  rendering visible (claim text, stance split, citations)

## What's deferred

- User accounts / authentication
- Governance/wiki edit UI
- Perspective admission workflow
- Vector tile pipeline (Tippecanoe)
- AI-generated dramatizations
- Public deployment / CDN
