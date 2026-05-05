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
./harness/run.sh gaps [args]   # timespace gap audit — find (region, year) pairs
                               # with no covering carrier. Args forwarded to
                               # audit_gaps.py (e.g. --top 30, --cell 105,30,120,40,
                               # --from-year -3000000). Advisory.
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
  (active for >500 years AND no `[AUTO-THREAT]` claim).
- Carriers without a `carrier_extent_snapshot` (relying on the buffered
  fallback — fine for small/regional carriers, worth surfacing for empires).
- Trait-domain coverage breakdown of `carrier_trait_mix` (genetic /
  linguistic / religious row counts).
- Per-region carrier counts via a coarse centroid bucketing.
- **Orphan admixture_event refs** — `parent_carriers` /
  `result_carriers` entries that don't match a real carrier id
  (silent today; once happened with `CARR_HIST_TANG` vs.
  `CARR_HIST_TANG_CHINESE`).
- **Stale Wikipedia title overrides** — keys in
  `frontend/src/lib/wikipedia.ts` whose carrier id no longer exists,
  meaning the inspector falls through to the `display_name` fallback.

Drift output is plain text intended for an LLM to read and triage. Counts
+ first 10 examples per category; full lists via the underlying SQL.

## Gap audit

`harness/audit_gaps.py` (run via `./harness/run.sh gaps`) crawls a coarse
lat/lon grid and, for each cell that's inhabited at *some* point, reports
year stretches with zero covering carriers — flanked by a predecessor
(latest carrier ending before) and a successor (earliest starting after).
These are the "the map shows nothing here right now" gaps.

It mirrors the resolver's coverage logic (extent_snapshot → extent →
ST_Buffer(centroid, type-keyed radius)) and is permissive: a carrier counts
as covering a cell across its full date range if any of those geometries
intersects the cell at all. False negatives (real gaps missed) matter more
than false positives.

Default `--from-year -15000` keeps output focused on the post-LGM /
Holocene / historical range where the user actually scrubs. Pass
`--from-year -3000000` to include the deep paleolithic.

Each gap is classified by comparing the predecessor's and successor's
genetic trait_mix overlap (sum of min(p_frac, s_frac) per genetic trait,
0 = disjoint, 1 = identical) plus linguistic_affiliation / archaeological
_culture word-token match:

- **EXTEND** — high genetic overlap (≥0.7, or ≥0.5 with a name match).
  Populations are continuous; the right fix is to widen one carrier's
  date range or seed a near-identical successor with the same trait_mix.
  e.g. Shang → Han (gen 1.00, ling✓): same East Asian profile, shared
  "Chinese" linguistic affiliation. Adding a Zhou/Warring-States bridge
  with the same trait_mix counts as an EXTEND fix.
- **BRIDGE** — low overlap (<0.3) AND no name match. Genuinely different
  populations; needs a new carrier with its own trait_mix and citations.
  e.g. Eastern N America 999 BCE → 1700 CE: Archaic NA → African Americans
  (gen 0.03) — Mississippian / Iroquois / Algonquian carriers are missing.
- **BLEND** — partial overlap (0.3–0.7 without strong name match). Could
  go either way; case-by-case judgment.
- **BOOKEND** — predecessor or successor is missing. The cell has only
  carriers on one side of the gap.
- **UNCLEAR** — neither side has trait_mix and no name overlap. Most
  hominin / pre-trait-mix carriers fall here.

Examples:

```
./harness/run.sh gaps                              # post-LGM, top of the list
./harness/run.sh gaps --top 30                     # 30 longest
./harness/run.sh gaps --kind BRIDGE --top 20       # only the ones that need new carriers
./harness/run.sh gaps --kind EXTEND --top 20       # only the ones a date-range tweak fixes
./harness/run.sh gaps --cell 105,30,120,40         # one cell, full timeline
./harness/run.sh gaps --json                       # machine-readable
```

The script surfaces things like the Yellow River 845-yr Shang→Han gap
(why "no Chinese at 472 BCE" — classified EXTEND), the Three-Kingdoms /
Jin / N-S-Dynasties 379-yr post-Han gap (EXTEND), the Eastern N America
2699-yr Archaic-NA → African-American hole (BRIDGE), and the Andronovo→
Mongol 2299-yr Central Asia hole (BRIDGE). Output is a triage list —
each entry tells you which two carriers flank the gap and whether the
fix is a date-range extension or a new bridge carrier.

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
