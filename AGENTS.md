# AGENTS.md

A short, stable entry point for any AI agent working on this codebase. Read
this first, then drill down via the links below — `CLAUDE.md` has full
detail and is the canonical source when this file disagrees with it.

## What this is

Spatiotemporal map of human history. Pick a year, click a place, see who
lived there with their genetic / linguistic / technological / ideological
mix. See `plan.md` for scope, `schema_v0.3.md` for the data model.

## How to run

```bash
docker compose up                        # Postgres (port 5433) + ingest + backend (8000) + frontend (5173)
./harness/run.sh check                   # all sanity checks (tests, type, API health, golden flows)
./harness/run.sh golden                  # end-to-end demo flows only
./harness/run.sh drift                   # scan DB for stale / missing data
./harness/run.sh invariants              # architectural guardrails
```

`./harness/run.sh` exits non-zero on any failure and is the single command
agents and CI use. See `harness/README.md` for what each subcommand checks.

## Hard rules (do not violate)

These are repeated from CLAUDE.md because breaking any of them breaks the
project's invariants:

- **No ORM.** Write SQL directly. The schema is unusual enough that ORMs fight you.
- **No new top-level frameworks** without asking. Stack is locked: FastAPI,
  psycopg3, React, MapLibre GL JS, Zustand, Tailwind.
- **Don't touch the spec**: `schema_v0.3.md`, `editorial_policy_v0.3.md`,
  `template_v0.3.xlsx`, `ingest/ingest.py`. If code disagrees with these,
  flag it instead of editing them.
- **Resolver never merges Perspectives.** `resolve_world()` returns a dict
  keyed by perspective id; the frontend decides how to render.
- **DB seeds are idempotent** via stable ID prefixes (`CARR_HIST_*`,
  `CARR_HIST_GAP_*`, `CARR_HIST_BRIDGE_*`, `CARR_HIST_POST1492_*`) and
  statement tags (`[AUTO-PROVENANCE]`, `[AUTO-THREAT]`, `[AUTO-TRAITMIX-NNN]`).
  Re-running a seed must not duplicate rows.
- **Postgres is on port 5433.** Inside Docker the containers still use 5432.
- **No year 0**: BCE-negative, CE-positive, `-1` = 1 BCE.
- **The DB table is `geo_region`, not `geography`** (PostGIS owns the
  `geography` type name).

## Where to read further

- `CLAUDE.md` — full conventions, key files, gotchas, design invariants.
- `harness/README.md` — what the harness checks and why.
- `plan.md` — phase 0 scope and roadmap.
- `schema_v0.3.md` — the data model.
- `editorial_policy_v0.3.md` — governance for adding/contesting claims.

## Progressive disclosure for an agent picking up a new task

1. Read this file.
2. Run `./harness/run.sh check` to confirm baseline is green.
3. Read the relevant `CLAUDE.md` section for the area you're touching.
4. Read the file(s) you're about to change.
5. Make the change; re-run `./harness/run.sh check`.
6. Update CLAUDE.md / TODO.md / harness if the change affects an invariant
   or an architectural assumption.
