# Human History Simulator

A scrubbable spatiotemporal map of human history. Pick a year, pan the world,
click on a place to see who lived there and what they carried — genes,
languages, religions, technologies — and how those things moved across time.

When the scholarly record disagrees, the map can show multiple curated
readings instead of forcing one answer (e.g. Indo-Aryan migration vs.
Out-of-India for the Steppe-genetics question).

> The data has been editorially seeded by curators; many entries cite
> a `DEDUCED_PHASE_0` editorial-best-effort source. The simulator is a
> tool for *visualization* and *comparing schools* — not a primary
> archaeological reference.

## Quick start

```bash
docker compose up
```

Wait ~30 seconds for the database to initialize and the seed services to
run, then open:

- **App**: http://localhost:5173
- **API + OpenAPI docs**: http://localhost:8000/docs

> **Ports**: Postgres is on host port `5433` (not 5432) to avoid clashing
> with a system Postgres. Inside Docker the containers still talk on 5432.
>
> **Apple Silicon**: PostGIS only ships an amd64 image, so it runs under
> Rosetta. Compose still works; first boot takes ~60s.

## What's there to do

- **Scrub**: drag the year slider (piecewise-log from -10 Mya through
  2026 with no year 0). The big "1700 CE" / "Iron Age" overlay at the
  top of the map shows you where you are.
- **Pan + click**: click a population dot for its inspector — Wikipedia
  thumbnail, ancestry mix, linguistic family, religious tradition,
  threats, claims, and a 1-2 paragraph plight narrative.
- **Search**: type `/` and start typing a population name (Mali, Han,
  Lapita, …). Click a match to jump to its time-window and select it.
- **Compare visualizations**:
  - **Fill** (default) — territory polygons.
  - **Pointwise** — archaeological-sample dots.
  - **Flow** — migration / propagation arrows.
- **Color by cluster**: each carrier is colored by its dominant ancestry
  trait, so the eye can group dozens of populations at a glance.
- **Lineage mode**: select a carrier, pick Past / Future / Both. The
  map locks to a multi-hop ancestry / descendant graph; press Play and
  the year scrubs forward, with pulse dots traveling along
  geographically-routed connectors (Bering, Khyber, Levant, Wallace).
  Trace e.g. modern South-US → European Bronze Age → Out-of-Africa →
  Neanderthal in five hops.
- **Compare scholarly readings**: open the Perspective picker, activate
  two perspectives, switch to Diff Overlay or Side-by-Side. Carriers
  whose related claims receive different stances under the two
  perspectives are highlighted.

## Indo-Aryan demo

The contested-knowledge feature is exercised by:

1. Open `?perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI` in the URL.
2. Slide the year to **-1700**.
3. Click the dot in NW South Asia.
4. The detail panel shows two columns with identical trait mixes (the
   disagreement isn't on the carrier itself). Below them, the
   **Claims about this population** section flags the Steppe-migration
   claim as contested: AMT *endorses* with Narasimhan 2019 + Reich
   Ch.6 cited; OOI *nuances* with the override statement *"Genetic
   Steppe signal acknowledged but interpreted as much earlier and/or
   bidirectional, not a 2000-1500 BCE Aryan migration."*
5. Toggle **Diff Overlay** mode — the disputed carrier renders in red.
   The diff is computed at the claim layer, not the carrier layer.

## Architecture at a glance

| Layer    | Technology                         |
| -------- | ---------------------------------- |
| DB       | Postgres 16 + PostGIS 3.4          |
| Backend  | FastAPI + psycopg3 + Pydantic      |
| Frontend | React + Vite + MapLibre GL JS      |
| State    | Zustand                            |
| Dev env  | Docker Compose                     |
| Validation | `./harness/run.sh check`         |

For everything else — invariants, gotchas, the design conventions —
see [CLAUDE.md](CLAUDE.md). Agents picking up a new task should read
[AGENTS.md](AGENTS.md) first.

## Data model in one paragraph

A *Carrier* is a population (or any cohesive group). It has a centroid,
a date range, an extent (sometimes per-year via `carrier_extent_snapshot`),
a *trait mix* (fractional composition across genetic / linguistic /
religious / technological / ideological / artistic / institutional /
material-culture / other domains), zero-or-more *threats* (climate, war,
disease, colonization, etc., with severity and year windows), and a
*plight* narrative. *Claims* are assertions about a Carrier (or about a
trait relation, propagation event, etc.) — and each Perspective endorses,
nuances, rejects, or asserts each claim independently. *Propagation
events* are migrations (Indo-European westward, Bantu southward,
Polynesian into the Pacific, …).

## Run without Docker

```bash
# Database (requires Postgres + PostGIS)
psql -U postgres -c "CREATE DATABASE history_sim;"
psql -U postgres -d history_sim -f db/001_schema.sql
psql -U postgres -d history_sim -f db/002_indexes.sql
for f in db/0[0-9][0-9]_seed_*.sql; do psql -U postgres -d history_sim -f "$f"; done

# Ingest
cd ingest && pip install -e . && \
  python ingest.py ../template_v0.3.xlsx --dsn 'postgresql://postgres:@localhost:5432/history_sim'

# Backend
cd ../backend && pip install -e . && \
  DATABASE_URL='postgresql://postgres:@localhost:5432/history_sim' uvicorn src.main:app --reload

# Frontend
cd ../frontend && npm install && \
  VITE_API_URL=http://localhost:8000 npm run dev
```

## Tests + harness

```bash
./harness/run.sh check   # full sanity: health, pytest, frontend tsc, golden flows, invariants
./harness/run.sh drift   # advisory DB drift report (carriers missing trait_mix / claims / etc.)
```

See [`harness/README.md`](harness/README.md) for what each subcommand
validates.

## Project layout

```
.
├── AGENTS.md / CLAUDE.md      # progressive disclosure for AI agents
├── db/                        # SQL schema + 25 idempotent seed files (db/003-027)
├── harness/                   # codebase harness (golden flows, invariants, drift)
├── ingest/                    # one-shot spreadsheet → Postgres
├── backend/                   # FastAPI + psycopg3
└── frontend/                  # React + MapLibre + Zustand
```

## What's deferred (Phase 1+)

User accounts, governance / Perspective-admission UI, vector tile pipeline,
public deployment, AI-generated dramatizations.
