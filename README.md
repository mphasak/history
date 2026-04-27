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
4. The detail panel shows two columns — AMT and OOI — with different trait
   mixes and the OOI override statement contesting timing/directionality.
5. Toggle **Diff Overlay** mode. The disputed carrier renders in red, indicating
   that the active perspectives disagree about it.

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
- Ingestion of the seed dataset (18 traits, 5 carriers, 7 perspectives)
- Six read endpoints with Perspective resolution
- World map with year slider and Perspective picker
- Click-anywhere-on-map → carriers covering that spacetime point
- Pointwise / fill visualization toggle with a legend
- Paleo overlays (land bridges, ice sheets) driven by physical_feature_snapshot
- Side-by-side and diff-overlay perspective comparison modes
- Detail panel showing per-perspective trait mixes
- Indo-Aryan demo working end to end

## What's deferred

- User accounts / authentication
- Governance/wiki edit UI
- Perspective admission workflow
- Vector tile pipeline (Tippecanoe)
- AI-generated dramatizations
- Public deployment / CDN
