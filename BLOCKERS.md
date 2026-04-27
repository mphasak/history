# Status after unattended build session

Everything from Phase 0 is complete and tested. No blockers remaining from this
session. Notes below are for your information, not action items.

---

## ✅ All acceptance tests pass

**13/13 automated tests pass** (`pytest backend/tests/`):
- 5 resolver tests (including the core Indo-Aryan demo)
- 8 route integration tests (hitting the live server)

**End-to-end on clean `docker compose up`:**
- Postgres initializes, schema + indexes applied via SQL files
- Ingest container seeds 18 traits, 7 perspectives, 8 endorsements
- Backend starts and passes all route tests
- Frontend builds and serves at localhost:5173
- Indo-Aryan demo: claim 2 returns `endorses` for AMT and `nuances` for OOI
  with the timing/directionality override

---

## Non-blocking notes (same as before, kept for reference)

### 1. `geography` table renamed `geo_region`

The schema_v0.3.md says `geography`. The actual table is `geo_region` (PostGIS
owns the `geography` type name in PostgreSQL). You should update schema_v0.3.md
if you want the spec and implementation to match.

### 2. Postgres on port 5433

Port 5432 was occupied by `onecli-postgres-1`. The compose file uses host port
5433. To run pytest outside Docker: `DATABASE_URL='postgresql://history_sim:dev@localhost:5433/history_sim'`.

### 3. PostGIS image is amd64-only on Apple Silicon

`postgis/postgis:16-3.4` has no ARM64 build. The compose file has
`platform: linux/amd64`; Rosetta 2 handles it. First boot ~60s.

### 4. Lineage graph (stretch goal, §5.10) is data-limited

`LineageGraph.tsx` is implemented but `STEPPE_MLBA` has 0 lineage nodes in the
seed data (no `trait_relation` rows for it). The ideological traits
(`IDEO_TRUMPISM` etc.) have `asserts`-type endorsements but no actual
`trait_relation` rows either. The graph component works; it needs richer seed data
to show anything meaningful. Not a code issue.

### 5. Claim IDs are bigserial and shift on re-ingest

The `claim` table uses `bigserial` (auto-increment). Each `DELETE + INSERT` cycle
advances the sequence. After the idempotency test during development, claim IDs
were at 6–10. After the full compose run (first fresh boot), they're at 1–5. The
test suite discovers the correct claim ID dynamically via a DB query, so this is
not a problem.

---

## How to run

```bash
# Full stack
docker compose up

# Tests (requires full stack running)
cd backend
DATABASE_URL='postgresql://history_sim:dev@localhost:5433/history_sim' \
API_URL='http://localhost:8000' \
pytest tests/ -v

# Demo
# 1. Open http://localhost:5173
# 2. Set perspectives to PERSP_INDIAN_AMT + PERSP_INDIAN_OOI
# 3. Slide year to -1700
# 4. Click the NW South Asia carrier
# 5. Detail panel shows AMT endorsing / OOI nuancing the Steppe migration claim
# 6. Toggle Diff Overlay → disputed carrier shows in red
```
