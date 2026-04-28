# Status

Phase 0 acceptance demo is fully wired end-to-end and tested. The
contested-knowledge story is now visible in the UI: both the diff
overlay and the DetailPanel render claim-level stance differences,
with citations.

## ✅ All acceptance tests pass

**21/21 automated tests pass** (`pytest backend/tests/`):

- Resolver (`test_resolver.py`):
  - 5 original perspective-resolution tests (Reich/AMT/OOI carriers,
    trait mixes, claim nuances, distinct per-perspective views)
  - `test_resolve_world_disagreed_carrier_ids_marks_indo_aryan` — the
    `_disagreed_carrier_ids` side-channel surfaces the contested
    NW South Asia carrier
  - `test_resolve_world_disagreed_empty_for_single_perspective` —
    no disagreement is reported when only one perspective is active
  - `test_resolve_carrier_claims_returns_steppe_migration` —
    `resolve_carrier_claims` returns the propagation-event claim
    with AMT endorses / OOI nuances
  - `test_resolve_carrier_claims_surfaces_provenance_for_romans` —
    the Roman provenance claim cites Antonio 2019
- Routes (`test_routes.py`):
  - 8 original integration tests (`/perspectives`, `/world`,
    `/carrier/{id}/timeline`, `/trait/{id}/lineage`, `/claim/{id}`,
    `/paleo-basemap`)
  - `test_world_disagreed_carrier_ids_indo_aryan`
  - `test_carrier_claims_endpoint_indo_aryan`
  - `test_carrier_claims_endpoint_roman_provenance`
  - `test_world_carrier_count_grows_with_historical_seed`

**End-to-end UI behaviors verified (Chrome browser automation):**

- Indo-Aryan demo: AMT+OOI at year -1700 → click NW South Asia →
  trait mixes match (55/30/15) → "Claims about this population"
  highlights Steppe migration as contested → AMT endorses with
  Narasimhan 2019 + Reich Ch.6 cited → OOI nuances with override
  statement → Diff Overlay marks the carrier red
- Year slider: full -10 Mya → 2025 range with no year 0; piecewise-log
  scaling; epoch jump labels (Holocene, sapiens, etc.) clickable
- Continental shelf: four pre-eroded depth bands (-25/-50/-90/-150 m)
  switch by sea-level proximity; legend reports the active band; no
  shelf at Eemian peak (-125k → +6 m)
- GPlates deep-time coastlines: activate at year < -3 Mya with the
  reconstruction time shown in the legend
- Side-by-side mode renders two synced map instances
- ClickPointPanel ranks carriers by distance with proper BCE/CE format
- Console clean — no MapLibre validation errors after the glyphs +
  data-driven-dasharray fixes

## How to run

```bash
# Full stack (Postgres + ingest + four idempotent seed services
# + backend + frontend)
docker compose up

# Tests
cd backend
DATABASE_URL='postgresql://history_sim:dev@localhost:5433/history_sim' \
API_URL='http://localhost:8000' \
pytest tests/ -v
```

## Phase 0 demo script

1. Open http://localhost:5173
2. Set Perspective picker to **PERSP_INDIAN_AMT** + **PERSP_INDIAN_OOI**
3. Slide year to **-1700**
4. Click the dot in NW South Asia (centroid ~72.5° E, 34.5° N)
5. The DetailPanel shows the trait mix and a Claims section with the
   AMT endorses / OOI nuances split, citations, and OOI's override
6. Toggle **Diff Overlay** → the carrier renders red

## Non-blocking notes

### Repository conventions

- The schema doc says `geography`, the actual table is `geo_region`
  (PostGIS owns the type name). Don't rename it back.
- Postgres on host port **5433** to avoid conflict with another local
  instance. Inside Docker, services connect to `postgres:5432`.
- PostGIS image (`postgis/postgis:16-3.4`) is amd64-only; on Apple
  Silicon it runs under Rosetta 2 with a slightly slower first boot.
- `claim` IDs are bigserial and shift on re-ingest. Tests discover
  the claim ID dynamically (see `test_claim_endpoint_nuanced`).

### Lineage graph (stretch goal §5.10) is data-limited

`LineageGraph.tsx` is implemented but the seed has no `trait_relation`
rows for `STEPPE_MLBA` or the ideological traits, so the graph has
nothing to render in the current dataset. Not a code issue.

### Side-by-side caps at two perspectives

`SideBySideMap` reads `perspIds[0]` and `perspIds[1]`. With 3+
perspectives active the third+ are silently dropped from the map view
(still in the URL). Phase 0 demo only requires two-perspective
comparison. Generalizing to N is a Phase 1 concern.

### Trait observations are sparse

The seed has 3 `trait_observation` rows. Pointwise mode therefore
looks empty for most years. This is content, not code — adding more
samples is a future seed-data task.
