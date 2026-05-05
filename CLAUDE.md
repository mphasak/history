# CLAUDE.md — Human History Simulator (deep reference for AI agents)

> The user-facing overview lives in [README.md](README.md); the short
> progressive-disclosure entry point for AI agents is [AGENTS.md](AGENTS.md).
> This file is the deep reference: invariants, gotchas, key files, and
> design conventions you need to read *before* changing anything load-bearing.

`plan.md` defines Phase 0 scope; `schema_v0.3.md` is the canonical data
model; `editorial_policy_v0.3.md` is the governance for adding /
contesting claims. **None of those three files may be modified.**

---

## The harness

A small, stable entry point for agents and CI lives at `harness/`. The
single command an agent runs to validate this codebase is:

```bash
./harness/run.sh check     # health → tests → golden flows → invariants
./harness/run.sh drift     # advisory: report stale / missing data
```

`AGENTS.md` (top of the repo) is the short progressive-disclosure entry
point; this `CLAUDE.md` is the deep reference. See `harness/README.md`
for what each subcommand validates.

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

### Paleo coastlines use a three-source hybrid

The map's "where was land at this year?" rendering pulls from three sources:

1. **Modern OSM tiles** — always shown as the base layer.
2. **Continental-shelf depth bands** (`frontend/public/paleo/shelf_-{25,50,90,150}m.geojson`)
   — pre-eroded variants of the Natural Earth `L_0 - K_200` continental-shelf
   polygon, generated by progressive negative buffering with shapely (see
   `/tmp/build_depth_shelves.py` for the original build script). The
   `useContinentalShelf` hook picks the band whose depth is closest to the
   current `paleoclimate_state.sea_level_meters` and renders it; the legend
   reports the active band. Sea-level interpolation is linear between the
   bracketing keyframes (see `_resolve_climate` in `backend/src/routes/basemap.py`)
   so the band selection is smooth across the slider.
3. **GPlates Web Service** (`https://gws.gplates.org`, model `MULLER2019`) — proxied
   by `backend/src/routes/gplates.py` for `year < -3 Mya`. In-memory cache keyed by
   (rounded-time-Ma, model). Frontend hook `usePaleoCoastlines` only fires for deep
   time. Upstream is rate-limited and slow on cache miss (~5–10 s for first request
   per timestep); subsequent ones are instant. GPlates fills are rendered in an
   earthy brown (`#8b5e34`) so they're visually distinct from the shelf overlay,
   and the legend includes the reconstruction time.

Hand-authored polygons (`physical_feature_snapshot.geometry`) are still used for
ice sheets, where sea-level + bathymetry doesn't apply. A snapshot with
`geometry IS NULL` at year Y means "this feature is gone as of Y" — the
`/paleo-basemap` endpoint uses `DISTINCT ON (feature_id) ... ORDER BY feature_id,
as_of_year DESC` so the NULL row wins for years past disappearance.

### Lineage edges use dominant-trait alignment, not "any shared trait"

The BFS for `/carrier/{id}/lineage` requires real ancestry contribution
between consecutive nodes — sharing an upstream component is **not**
enough, because that pulls in sibling populations that descend from a
common ancestor as if they were each other's ancestors/descendants.

Concretely:
- **Past hop** (find ancestors of source `S`): candidate `A`'s
  *dominant* trait must be one of `S`'s *substantial* traits (fraction
  ≥ 0.02). So Bronze NW South Asia (ANI 0.55, ASI 0.30, STEPPE_MLBA
  0.15) finds ancestors whose dominant ancestry is ANI / ASI /
  STEPPE_MLBA — Iranian Neolithic, S Asian Mesolithic, Yamnaya.
- **Future hop** (find descendants of source `S`): candidate `D` must
  carry `S`'s *dominant* trait at fraction ≥ 0.02. So First Americans
  (dominant=AMER_NA) finds Inca / Maya / Modern S. Asian Mestizo / SF
  Bay Area, but **not** Saami / Yamnaya / Han, who don't carry AMER_NA
  at all even though they share ANE upstream.

The 0.02 threshold is low enough to admit archaic admixture
(NEANDERTHAL / DENISOVAN typically 1–4%), so deep traces from any
non-African modern population back to Neanderthal still work. Spatial
fallback (~3000 km radius) only kicks in when the source has no
trait_mix data at all (Homo erectus and other deep-paleolithic
hominins).

### Lineage mode is a map-wide mode, not just an overlay

When `lineageMode !== 'off'` and a carrier is selected, lineage mode
*locks*: the regular `carriers` and `carrier-extents` layers hide so the
multi-hop subgraph owns the map, and clicks on lineage nodes set
`lineagePreviewCarrierId` instead of `selectedCarrierId`. The focal
carrier only changes when the user exits lineage mode (Lineage → Off).

The `/carrier/{id}/lineage` endpoint returns a multi-hop BFS:
`nodes[]` (every reachable carrier with `depth` + `side`) and `edges[]`
(parent→child hops, oriented older → newer temporally). The frontend
draws every edge as a halo+core line with a per-edge pulse dot that
slides along the edge based on the slider year — so scrubbing the year
visibly shows ancestors flowing into intermediates flowing into the
focal, and onward into descendants. Default depth is 5, default
per-hop fan-out 5 — enough to trace e.g. Rural-South-US → European
Bronze Age → Mesolithic → OOA → Neanderthal in one graph.

### Defaults

The app loads with a single default state:
- **Perspective**: `PERSP_POSTREICH_2025` only (academic mainstream).
- **Viz mode**: `fill`.
- **Label mode**: `none`.

The Perspective picker is **collapsed** by default — it shows a small
"Perspective" pill in the top-left, expandable into the full multi-select
when the user wants to compare scholarly schools (e.g. AMT vs OOI for the
Indo-Aryan demo). The DB column `perspective.default_active` is preserved
so URL-driven demos like
`/?perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI` still work; the seed
just doesn't auto-activate all default-actives any more.

### Year range and slider

The slider (`frontend/src/components/YearSlider.tsx`) is piecewise-log:
**slider position [0, 200] → year [-10 Mya, -300 kya]** (deep time, 20% of bar) and
**[200, 1000] → year [-300 kya, 2026]** (sapiens, 80% of bar). Both regions are
log-scaled in years-before-present so recent history gets proportionally more
positions. The amber tick at 20% marks the deep-time/sapiens boundary, and there
are click-to-jump epoch labels along the bottom.

Schema-side, `integer` year columns trivially handle negative millions of years.
The resolver's date-window queries (`date_min_year <= y AND date_max_year >= y`)
work unchanged — there's just no carrier seed data older than the spreadsheet's
oldest entry, so deep-time scrubs show only paleo coastlines and ice sheets.

### Carrier extent has a three-tier resolution priority

Fill-mode polygons resolve in this order, most → least specific:

1. **`carrier_extent_snapshot`** (the new 009 seed). The resolver picks the
   latest snapshot whose `as_of_year <= query_year` for each carrier, via a
   `LATERAL` join. This is what makes the Roman Empire actually grow and
   shrink as the slider moves through Republic → Augustan → Trajanic peak
   → post-split contraction.
2. **`carrier.extent`** (a fixed authored polygon — used only for the NW
   South Asia carrier in the spreadsheet seed; null for everyone else).
3. **`ST_Buffer(centroid, RADIUS)`** with RADIUS keyed by `carrier.type`
   via `_CARRIER_DEFAULT_RADIUS_M`. The fallback for carriers without a
   snapshot or fixed extent.

`extent_is_real` is true for (1) and (2) and false for (3). The UI uses
that flag to draw solid outlines for authored extents and dashed outlines
for buffered fallbacks (rendered via two layers since MapLibre rejects
data-driven `line-dasharray`).

### `paleo-seed` compose service runs every `docker compose up`

`db/003_seed_paleo_features.sql` is applied by a dedicated `paleo-seed` service
that runs after `ingest`. It is idempotent (DELETE+INSERT keyed on
`PF_PALEO_*` IDs) so existing pgdata volumes pick up edits without requiring
`docker compose down -v`. New paleo features should follow the same ID prefix
convention.

### Idempotent seed services chain after ingest

`db/0NN_seed_*.sql` files are each applied by a dedicated compose
service that runs after `ingest`. The chain has grown over time —
there are now ~24 seed services covering the full set (`db/003`
through `db/026`). The originating four are:

1. **`paleo-seed`** (`003_seed_paleo_features.sql`) — ice-sheet polygons +
   paleoclimate keyframes (`PF_PALEO_*`, `PCS_PALEO_*`).
2. **`genetics-seed`** (`004_seed_population_genetics.sql`) — Reich-style
   ancestry components and Pleistocene/Holocene carriers (`AFR_BASAL`,
   `STEPPE_MLBA`, `CARR_OOA_LEVANT_55K`, etc.).
3. **`carriers-seed`** (`005_seed_historical_carriers.sql`) — 80 carriers
   covering non-sapiens hominins, early sapiens, additional UP/Mesolithic
   clusters, and Holocene/historical ethnolinguistic groups
   (`CARR_HOMININ_*`, `CARR_HIST_*`).
4. **`carriers-provenance-seed`** (`006_seed_historical_carrier_ancestry.sql`)
   — `carrier_trait_mix` ancestry breakdowns + cited claims for the carriers
   from 005. Each ancestry assertion is recorded as a Claim
   (`subject_type=Carrier`) tagged `[AUTO-PROVENANCE]` (the DetailPanel
   strips this before displaying), with `claim_source` rows linking to the
   primary literature (Reich, Lazaridis, Narasimhan, Antonio, etc.) or to
   the new `DEDUCED_PHASE_0` source for editorial best-effort summaries.
5. **`carrier-threats-seed`** (`007_carrier_threats.sql`) — additively
   defines the `carrier_threat` table + `threat_type` enum
   (climate / disease / war / raids / displacement / resource_scarcity /
   resource_competition / megafauna_loss / natural_disaster /
   colonization / genocide / assimilation_pressure / other). Seeds 94
   threats across the carrier set with year windows, severities (1–5),
   and a Claim (`subject_type=Carrier`) tagged `[AUTO-THREAT]` linking
   to citations. The DetailPanel filters threats whose
   `[date_min_year, date_max_year]` window covers the current slider
   year so the section auto-updates as the user scrubs.

The remaining ~19 services (008-026) extend coverage:
historical-place labels, per-year territory snapshots, Holocene /
forager / regional / temporal-bridge / post-Columbian / modern-
continental / post-classical-bridge gap-filler carriers, missing
trait_mix backfills, hominin-archaic enrichment, threats for gap
carriers, linguistic + religion traits, plight narratives, and the
admixture-event drama feature (the headline UI on the timeline).
See `docker-compose.yml` for the current dependency graph and
`db/0NN_seed_*.sql` for the file-by-file content.

Each seed is idempotent (DELETE+INSERT keyed on stable ID prefixes
or on a tagged statement prefix like `[AUTO-PROVENANCE]` /
`[AUTO-THREAT]` / `[AUTO-LING-022]` / etc.) so existing pgdata
volumes pick up edits without requiring `docker compose down -v`.
The backend service waits on every seed via
`service_completed_successfully`.

### Disagreement detection happens at the *claim* layer

The Indo-Aryan demo's disagreement is on Claim 22 (the Steppe migration
propagation event), not on the carrier itself. Two pieces honor that:

- `resolver.resolve_carrier_claims` returns claims about the carrier,
  its `carrier_trait_mix` rows, and propagation events whose destination
  intersects the carrier's extent / lies within ~1500 km of its centroid /
  shares any trait with its mix. Each claim is annotated with
  `has_disagreement` whenever stances differ across the active perspectives.
  The DetailPanel's "Claims about this population" section renders these
  with stance badges, override quotes, and citations.
- `resolver.resolve_world` precomputes `_disagreed_carrier_ids` (a list of
  carrier IDs whose related claims are contested) using a single batch SQL
  over the same relevance rules. The route surfaces this as
  `disagreed_carrier_ids` on `WorldResponse`; `DiffOverlay.computeDiff`
  treats it as authoritative *in addition to* direct carrier-endorsement
  differences. Without this side-channel the diff overlay would never
  mark the Indo-Aryan carrier (its trait mix is identical across AMT/OOI
  by design — the disagreement lives elsewhere).

### MapLibre layer gotchas

`Map.tsx` has hit two MapLibre validation errors that fail silently —
the layer is rejected but no UI feedback. Keep these in mind when adding
new layers:

- **No data-driven `line-dasharray`.** MapLibre rejects it; the
  `carrier-extents-outline` layer is split into `-solid` and `-dashed`
  variants filtered by `extent_is_real`.
- **`text-field` requires a `glyphs` URL on the style.** OSM raster
  styles don't include one by default; we add the MapLibre demotiles
  glyph endpoint and `text-font: ['Noto Sans Regular']`.

### Source-data effects gate on source existence, not `isStyleLoaded()`

Each per-source data-update effect in `Map.tsx` follows the pattern
`if (map.getSource('foo')) apply(); else map.once('load', apply)`.
The previous gate (`map.isStyleLoaded()`) flickers back to `false`
during raster tile fetches; falling into the `once('load', apply)`
fallback registered a one-time listener for an event that had already
fired, silently dropping shelf / GPlates / carrier / observation
updates. Sources, once added by init's `'load'` callback, persist for
the lifetime of the map, so source existence is the right gate.

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
| `backend/src/resolver.py` | Core Perspective resolution logic — `resolve_world`, `resolve_world_at_point`, `resolve_claim`, `resolve_carrier_timeline`, `resolve_carrier_claims`, `resolve_carrier_lineage`, `_compute_disagreed_carrier_ids` |
| `backend/src/perspectives.py` | `GET /perspectives` endpoint |
| `backend/src/routes/world.py` | `GET /world` (with `disagreed_carrier_ids`) + `GET /world/at` |
| `backend/src/routes/basemap.py` | `GET /paleo-basemap` — paleo feature polygons + interpolated sea level / temp anomaly |
| `backend/src/routes/carrier.py` | `GET /carrier/{id}/timeline`, `/claims`, `/threats`, and `/lineage` (multi-hop BFS DAG of past/future feeders, with `max_depth` + `max_per_hop` knobs) |
| `backend/src/routes/claim.py` | `GET /claim/:id` — per-Perspective claim stances |
| `backend/src/routes/gplates.py` | `GET /paleo-coastlines` — proxied GPlates for deep time |
| `db/001_schema.sql` | Full DDL (generated from schema_v0.3.md) |
| `db/003_seed_paleo_features.sql` | Ice-sheet polygons + paleoclimate keyframes |
| `db/004_seed_population_genetics.sql` | Reich-style ancestry components and Pleistocene/Holocene carriers |
| `db/005_seed_historical_carriers.sql` | 80 historical / hominin carriers (`CARR_HIST_*`, `CARR_HOMININ_*`) |
| `db/006_seed_historical_carrier_ancestry.sql` | Ancestry mixes + cited claims (`[AUTO-PROVENANCE]`) for the carriers from 005 |
| `db/007_carrier_threats.sql` | `carrier_threat` table + `threat_type` enum + 94 seeded threats with year windows and cited claims (`[AUTO-THREAT]`) |
| `db/008_historical_places.sql` | `historical_place` table + 64 era-appropriate city/region labels keyed by `[date_min_year, date_max_year]` |
| `db/009_carrier_territory_snapshots.sql` | `carrier_extent_snapshot` table + ~36 territorial polygons that the resolver picks per-year via `LATERAL` lookup |
| `db/010_seed_holocene_carriers.sql` | 32 early-to-mid Holocene carriers filling regional gaps for ~-7000 to -1500 (`CARR_HIST_HOL_*` prefix) |
| `db/011_holocene_carrier_threats.sql` | Threats for Holocene gap-filler + older forager/Mesolithic carriers (Cucuteni-Trypillia / Predynastic Egyptian / Yangshao / etc.); shares the `[AUTO-THREAT]` idempotency tag |
| `db/012_seed_forager_carriers.sql` | Forager / aceramic-Neolithic regional coverage so a screenshot at ~11 kya shows ~30 dots globally instead of ~10 (`CARR_HIST_FOR_*` prefix) |
| `db/013_seed_regional_gap_carriers.sql` | 31 region/era gap-fillers (`CARR_HIST_GAP_*` prefix): Andean / Mesoamerican / Caribbean / sub-Saharan / Pacific / Arctic / additional N. American carriers, all cited via DEDUCED_PHASE_0 |
| `db/014_seed_missing_trait_mixes.sql` | Editorial best-effort ancestry compositions for the 93 carriers from 010/012/013 that lacked trait_mix; tagged `[AUTO-TRAITMIX-014]`, cited via DEDUCED_PHASE_0 |
| `db/015_seed_modern_us_trait_mixes.sql` | Modern-US trait_mix for `CARR_RURAL_SOUTH_US_2025` + `CARR_SF_BAY_AREA_2025` so the multi-hop lineage BFS can trace back through European Bronze Age / OOA to Neanderthal; tagged `[AUTO-TRAITMIX-015]` |
| `db/016_seed_temporal_bridge_carriers.sql` | Temporal-bridge carriers (`CARR_HIST_BRIDGE_*`) filling regional date-range gaps so populations don't appear extinct as the slider scrubs across centuries: Late Woodland / Anasazi / Hohokam / Fremont (N America), Cupisnique / Paracas (Andean), Afanasievo / Andronovo / Botai / Okunev / Karasuk / Tagar (Siberia), Colonial Mesoamerica, Garamantes, Zagwe Ethiopia |
| `db/017_seed_post_columbian_carriers.sql` | Post-1492 colonial / slave-trade / globalization-era carriers (`CARR_HIST_POST1492_*`): Colonial NA / Republic-era US / Gilded-Age US / African Americans / Afro-Caribbean / Colonial Brazilian / Modern Brazilian / Colonial Andean / Colonial Australia / Modern Australia / Pākehā NZ / Afrikaner / Modern Israeli |
| `db/018_seed_post_columbian_extents.sql` | Authored MultiPolygon extents for the post-Columbian carriers (Republic-era US east-of-Rockies + Pacific strip; African American multi-region; Modern Australia continent; etc.) |
| `db/019_seed_modern_continental_carriers.sql` | Modern continental carriers (Modern USA / Canada / Mexico, 1900-2025) so post-WWII N America isn't a couple of regional dots |
| `db/020_seed_hominin_archaic_traits.sql` | Archaic-hominin trait_ids (HOMININ_HABILIS / _ERECTUS / _HEIDELBERGENSIS / etc.) + self-trait mixes for the Homo-* carriers; Carrier-level claims for the spreadsheet-origin carriers that previously had none |
| `db/021_seed_threats_for_gap_carriers.sql` | 37 threats across 24 long-lived gap-filler / bridge / post-Columbian carriers (drought, war, disease, colonization, genocide); tagged `[AUTO-THREAT-021]` |
| `db/022_seed_linguistic_traits.sql` | First-class linguistic-family traits (Indo-European / Sino-Tibetan / Niger-Congo / Afro-Asiatic / Austronesian / Dravidian / Turkic / Mongolic / Uralic / Athabaskan / Mayan / Quechuan / Aymaran / Nahuan / Pama-Nyungan / Iroquoian / Tupian / Khoisan / Papuan / Austroasiatic) + 102 carrier assignments; tagged `[AUTO-LING-022]` |
| `db/023_seed_religion_traits.sql` | First-class religion / ideological-tradition traits (Christianity / Islam / Buddhism / Hinduism / Judaism / Confucianism / Zoroastrianism / etc.) + 89 era-windowed assignments capturing conversion (Roman → Christianity ~400; Vikings → Christianity ~1100; Mali → Islam ~1300); tagged `[AUTO-RELIGION-023]` |
| `db/024_seed_plight_narratives.sql` | `carrier_plight` table + 25 editorial 1-2-paragraph narratives (everyday life, origin, ending) per carrier — pairs with the itemized Threats list |
| `db/025_seed_admixture_events.sql` | `admixture_event` table + 16 fusion moments (OOA × Neanderthal, Bering, Yamnaya into Europe, Steppe into S Asia, Bantu, Lapita, Han southward, Arab conquests, Mongol expansion, European colonization, Atlantic slave trade, etc.); each tagged with severity 1-5 and `rupture_kind` (gradual_blend / elite_dominance / demographic_swamp / violent_replacement / forced_diaspora / island_settlement). The headline "drama" feature — surfaced via the AdmixtureTimeline above the year slider and the on-map glow when the slider intersects an event window. |
| `db/026_seed_postclassical_bridge_carriers.sql` | 16 bridge carriers covering the 1500-1900 demographic gap between classical empires and modern carriers — Ming/Qing China, Edo Japan, Joseon Korea, Delhi Sultanate, Safavid/Qajar Iran, Vietnam dynasties, Ayutthaya, Majapahit/Mataram, Renaissance Europe, Romanov Russia, Tudor/Stuart England, Habsburg Spain, Italian city-states, Polish-Lithuanian Commonwealth, French Kingdom, Holy Roman Empire (`CARR_HIST_BRIDGE_PC_*` prefix) |
| `db/027_seed_threats_for_historical_gap_carriers.sql` | Threats for 20+ prominent long-lived historical carriers that previously had none (Sumerian, Bell Beaker, Anatolian Farmers, Iran Neolithic, Norse, Berber, several Bridge_PC empires, Sogdians, Hongshan/Hemudu, Anasazi/Hohokam/Fremont); tagged `[AUTO-THREAT-027]` |
| `db/028_seed_audit_gap_fillers.sql` | 14 carriers closing the highest-impact (region, year) gaps surfaced by `harness/audit_gaps.py` — fixes the "no Chinese at 472 BCE" complaint via Zhou / Three-Kingdoms-Jin / Song-Liao bridges, plus pre-Goryeo Korea, pre-Han Yangtze, Đông Sơn / Funan-Pre-Angkor / Champa, Xiongnu / Saka / Kushan steppe, Numidian / Kanem-Bornu, proto-Mississippian. Inline trait_mix + 19 threats; tagged `[AUTO-PROVENANCE]` / `[AUTO-THREAT-028]` |
| `harness/audit_gaps.py` | Timespace gap audit: crawls a 15°×10° lat/lon grid and reports stretches with no covering carrier, classified EXTEND (continuity — pred/succ genetic overlap ≥0.7) / BRIDGE (different populations — overlap <0.3) / BLEND / BOOKEND / UNCLEAR. Run via `./harness/run.sh gaps`. |
| `ingest/ingest.py` | Spreadsheet → Postgres; idempotent |
| `frontend/src/state.ts` | Zustand store: year, bbox, activePerspectives, renderMode, vizMode, lineageMode, lineageAnimating, lineagePreviewCarrierId, carrierColorMode, selectedAdmixtureEventId, admixtureAtlasOpen, clickPoint |
| `frontend/src/components/Map.tsx` | MapLibre wrapper; export is `WorldMap` (not `Map`); also exports `DOMAIN_COLORS` used by `Legend` |
| `frontend/src/lib/clusters.ts` | Per-carrier color resolution for the Color: Cluster mode — palette keyed on the dominant ancestry trait (Steppe_MLBA blue, ANI violet, ANATOLIAN_FARMER lime, etc.); fallback hash-palette for unknown trait_ids |
| `frontend/src/lib/migrationRoutes.ts` | Hand-curated routing for lineage connector lines — bends edges through known migration choke points (Bering, Khyber, Levant, Wallacea, SE-Asia coastal route) when endpoints straddle one. Pulse dots interpolate along the resulting polyline. |
| `frontend/src/lib/timeScale.ts` | Shared piecewise-log time-scale helpers (`sliderToYear`, `yearToFraction`, `formatYear`, `PRESENT_YEAR=2026`). Owned by `YearSlider` but imported wherever else the same scale is needed (notably `AdmixtureTimeline`). |
| `frontend/src/components/YearSlider.tsx` / `YearHeader.tsx` | Year slider (piecewise-log, owns the scale constants) and the giant "1700 CE / Iron Age" header overlay above the map |
| `frontend/src/components/AdmixtureTimeline.tsx` | Headline "drama" lane above the year slider — every admixture event from `db/025` rendered as a glowing marker, scaled by severity, colored by rupture_kind. Click jumps the slider + opens the AdmixtureCard |
| `frontend/src/components/AdmixtureCard.tsx` | Right-side panel for a selected admixture event: parents, results, year window, narrative, severity, rupture_kind |
| `frontend/src/components/AdmixtureAtlas.tsx` | Expanded multi-row phylogeny — each carrier on its own row, parent→result curves spanning the time axis. Opened from the Expand button next to the AdmixtureTimeline |
| `frontend/src/components/SearchBox.tsx` | "/ to focus" name search across carriers — debounced; pick a result to snap year + select carrier |
| `frontend/src/components/LineagePreviewPanel.tsx` | Non-destructive preview panel shown when, in lineage mode, the user clicks a non-focal node (focal carrier stays selected) |
| `frontend/src/components/Legend.tsx` | Bottom-left legend; swaps content based on vizMode and active paleo features |
| `frontend/src/components/DetailPanel.tsx` | Right-side carrier panel; renders trait mix + per-perspective claims with stance badges; Wikipedia thumbnail + extract at top via `lib/wikipedia.ts` |
| `frontend/src/lib/wikipedia.ts` | Client-side Wikipedia REST `page/summary` lookup keyed by carrier_id → article title (with display_name fallback). Cached per session. CORS-allowed, no API key required. |
| `frontend/src/components/DiffOverlay.tsx` | `computeDiff` honors `worldData.disagreed_carrier_ids` for claim-level disagreement |
| `frontend/src/components/ClickPointPanel.tsx` | Right-side picker shown when an empty map point is clicked |
| `frontend/src/components/ParticleOverlay.ts` | Particle viz mode (`vizMode='particles'`). Canvas 2-D overlay sibling to the MapLibre canvas, synced via `map.project()` each frame. Per carrier: rejection-samples N home points inside `extent_geojson` (Polygon / MultiPolygon), then per-frame: damped Brownian noise + soft spring back to home in lng/lat space, with point-in-polygon containment (bbox quick-reject) so particles stay inside the territory. Particle count scales with `sqrt(bbox_area)` clamped to [8, 80]. Migration streams continually emit particles at the origin and advance them along a routed polyline; in lineage mode the per-frame fade is gentler so streams leave a smear-trail. Three migration sources are toggleable: `extents` (perspective propagation_events), `admixture` (avg parent_carriers → avg result_carriers, colored by rupture_kind), `lineage` (focal carrier's lineage edges). The Map effect feeds carriers/migrations from the same data the rest of the map uses; visibility and trail-mode are wired to `vizMode` + `lineageActive`. Carriers without `extent_geojson` get a small ring fallback around the centroid. |

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
4. Detail panel: both columns show 55% ANI / 30% ASI / 15% Steppe_MLBA
   (the trait mix is identical by design — this isn't where the
   disagreement lives). Below the trait mixes, the **Claims about this
   population** section flags the Steppe-migration claim as contested:
   AMT *endorses* with Narasimhan 2019 + Reich Ch.6 cited (with weight
   overrides), OOI *nuances* with the override statement *"Genetic
   Steppe signal acknowledged but interpreted as much earlier and/or
   bidirectional, not a 2000-1500 BCE Aryan migration."*
5. Toggle **Diff Overlay** — the disputed carrier renders in red.
   This is driven by `WorldResponse.disagreed_carrier_ids`, not by the
   carrier's own endorsement field (which is null), so the marker
   reflects real claim-level disagreement.
