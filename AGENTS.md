# AGENTS.md

The short, stable entry point for any AI agent working on this codebase.

## In one sentence

Spatiotemporal map of human history; FastAPI + psycopg3 + React + MapLibre;
Postgres on port 5433; data seeded by curated SQL files (`db/0NN_seed_*.sql`),
not by an admin UI.

## What to read

| If you want…                              | Read                                                    |
| ----------------------------------------- | ------------------------------------------------------- |
| The user-facing pitch + how to run it     | [README.md](README.md)                                  |
| Hard rules + invariants + gotchas         | [CLAUDE.md](CLAUDE.md) (deep reference; **read this**)  |
| Data model                                | `schema_v0.3.md` (canonical, **do not modify**)         |
| Governance for claims / perspectives      | `editorial_policy_v0.3.md` (canonical, do not modify)   |
| Phase 0 scope                             | `plan.md`                                               |

## What to run

```bash
docker compose up                  # bring up the stack
./harness/run.sh check             # validate end-to-end (health, tests, golden, invariants)
./harness/run.sh drift             # advisory DB report (carriers missing trait_mix / claims / etc.)
```

`./harness/run.sh check` is what you re-run after any change. Fast and
deterministic; non-zero on failure.

## The five hard rules

These each have detail in CLAUDE.md, but they are load-bearing:

1. **No ORM.** Write SQL directly with `psycopg3`.
2. **No new top-level frameworks** without asking — stack is locked.
3. **Don't modify the spec**: `schema_v0.3.md`, `editorial_policy_v0.3.md`,
   `template_v0.3.xlsx`, `ingest/ingest.py`. If code disagrees, flag it.
4. **Resolver never merges Perspectives.** `resolve_world()` returns a
   dict keyed by perspective id.
5. **Seeds are idempotent** — DELETE-by-ID-prefix or by `[AUTO-FOO-NNN]`
   statement tag, then re-INSERT. Never `DROP TABLE` a persistent table.

`./harness/run.sh invariants` mechanically enforces these.

## Workflow

1. Read this file.
2. Run `./harness/run.sh check` to confirm baseline is green.
3. Read the relevant CLAUDE.md section for the area you're touching.
4. Read the file(s) you're about to change.
5. Make the change; re-run `./harness/run.sh check`.
6. Update CLAUDE.md / TODO.md / harness if the change affects an
   invariant, a key file, or a documented architectural assumption.
