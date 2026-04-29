# Harness

The harness is the small, stable entry point an AI agent (or a human) uses
to validate this codebase. It complements `pytest` / `tsc` by running
**end-to-end golden flows** against the live API and **drift detection**
against the live DB — the things unit tests don't cover but that
regularly break when seed data evolves.

## Subcommands

```
./harness/run.sh check         # everything below, in order; non-zero on failure
./harness/run.sh tests         # backend pytest + frontend tsc --noEmit
./harness/run.sh golden        # canonical end-to-end demo flows over the API
./harness/run.sh drift         # report stale / missing data (carriers without
                               # trait_mix, claims, Wikipedia mappings, etc.)
./harness/run.sh invariants    # architectural guardrails from CLAUDE.md
./harness/run.sh health        # /healthz only — quick sanity ping
```

`check` runs `health → tests → golden → invariants`. `drift` is run
*advisory* (it reports gaps but does not fail the build) — wire it into a
nightly job rather than a pre-commit hook.

## Golden flows

`harness/golden.sh` exercises the canonical demos described in `CLAUDE.md`:

- **Indo-Aryan disagreement**: AMT + OOI active at -1700 must surface
  `CARR_NW_SOUTH_ASIA_LATE_BRONZE` in `disagreed_carrier_ids`.
- **Multi-hop lineage to Neanderthal**: `CARR_RURAL_SOUTH_US_2025` ancestors
  must include `CARR_HOMININ_NEANDERTHAL` within 6 hops.
- **Future of First Americans is Native-American-only**: descendants of
  `CARR_PALEO_AMER_15K` must NOT include sibling populations like Saami /
  Yamnaya / Han.
- **No N-American temporal gap at 700 CE**: ≥3 carriers active.
- **Post-Columbian carriers present at 1700 CE**: African Americans,
  Colonial NA, Colonial Andean must all appear.
- **Roman provenance citation**: the `[AUTO-PROVENANCE]` claim for Romans
  cites `ANTONIO_2019`.

Add a flow whenever a regression bites — see `golden.sh` for the pattern.

## Drift report

`harness/drift.sh` queries the DB and prints:

- Carriers with no `carrier_trait_mix` rows.
- Carriers without any `claim` row.
- Carriers without a `carrier_threat` row that *probably should* have one
  (active for >500 years AND no [AUTO-THREAT] claim).
- Carriers without a `Wikipedia` mapping (frontend `lib/wikipedia.ts`)
  whose `display_name` doesn't match a sensible URL slug.
- Spec files in unexpected modified state.

Drift output is plain text intended for an LLM to read and triage. Counts
+ first 10 examples per category; full lists via the underlying SQL.

## Invariants

`harness/invariants.sh` enforces:

- No ORM imports in `backend/src/`.
- Spec files unchanged vs. main: `schema_v0.3.md`,
  `editorial_policy_v0.3.md`, `template_v0.3.xlsx`, `ingest/ingest.py`.
- All DB seed files (`db/0NN_seed_*.sql`) use idempotent DELETE-by-prefix
  patterns.
- `geo_region` referenced (not `geography`) in any new SQL.
- Migration / seed files never use `DROP TABLE`.

Each invariant is a small grep/git command — easy to skim and to extend.
