#!/usr/bin/env bash
# Drift detection. Prints a plain-text report of stale / missing data so
# an LLM agent can triage what to enrich next. Advisory — exits 0 even
# when gaps exist; wire into a nightly job, not pre-commit.
set -euo pipefail

DSN="${DATABASE_URL:-postgresql://history_sim:dev@localhost:5433/history_sim}"
psqlq() { psql "$DSN" -tAF $'\t' -c "$1"; }

section() { echo; echo "── $1 ──"; }

section "Carriers without trait_mix"
n=$(psqlq "SELECT count(*) FROM carrier WHERE id NOT IN (SELECT DISTINCT carrier_id FROM carrier_trait_mix)")
echo "count: $n"
if [[ "$n" -gt 0 ]]; then
  echo "first 15:"
  psqlq "SELECT id, display_name FROM carrier
         WHERE id NOT IN (SELECT DISTINCT carrier_id FROM carrier_trait_mix)
         ORDER BY id LIMIT 15"
fi

section "Carriers without any claim"
n=$(psqlq "SELECT count(*) FROM carrier
           WHERE id NOT IN (SELECT subject_id FROM claim WHERE subject_type='Carrier')")
echo "count: $n"
if [[ "$n" -gt 0 ]]; then
  echo "first 15:"
  psqlq "SELECT id, display_name FROM carrier
         WHERE id NOT IN (SELECT subject_id FROM claim WHERE subject_type='Carrier')
         ORDER BY id LIMIT 15"
fi

section "Long-lived carriers (>500 yrs) without any threats"
n=$(psqlq "SELECT count(*) FROM carrier c
           WHERE c.date_max_year - c.date_min_year > 500
             AND NOT EXISTS (SELECT 1 FROM carrier_threat t WHERE t.carrier_id = c.id)")
echo "count: $n"
if [[ "$n" -gt 0 ]]; then
  echo "first 15:"
  psqlq "SELECT c.id, c.display_name, c.date_min_year || '..' || c.date_max_year AS range
         FROM carrier c
         WHERE c.date_max_year - c.date_min_year > 500
           AND NOT EXISTS (SELECT 1 FROM carrier_threat t WHERE t.carrier_id = c.id)
         ORDER BY c.date_min_year LIMIT 15"
fi

section "Carriers without an extent_snapshot (relying on buffered fallback)"
n=$(psqlq "SELECT count(*) FROM carrier c
           WHERE c.extent IS NULL
             AND NOT EXISTS (SELECT 1 FROM carrier_extent_snapshot s WHERE s.carrier_id=c.id)")
echo "count: $n  (these get the default 800km buffer; OK for small/regional carriers)"

section "Orphan admixture_event carrier refs"
# parent_carriers / result_carriers entries that don't match a real carrier id.
# These cause the AdmixtureAtlas curves and the lineage BFS to silently drop
# nodes — once happened with CARR_HIST_TANG vs CARR_HIST_TANG_CHINESE.
n=$(psqlq "
WITH refs AS (
  SELECT id, unnest(parent_carriers) AS cid FROM admixture_event
  UNION ALL
  SELECT id, unnest(result_carriers) AS cid FROM admixture_event
)
SELECT count(*) FROM refs WHERE cid NOT IN (SELECT id FROM carrier)")
echo "count: $n"
if [[ "$n" -gt 0 ]]; then
  echo "first 15:"
  psqlq "
  WITH refs AS (
    SELECT id, unnest(parent_carriers) AS cid FROM admixture_event
    UNION ALL
    SELECT id, unnest(result_carriers) AS cid FROM admixture_event
  )
  SELECT id AS event_id, cid AS missing_carrier_ref FROM refs
  WHERE cid NOT IN (SELECT id FROM carrier)
  ORDER BY id, cid LIMIT 15"
fi

section "Stale Wikipedia title overrides"
# Keys in frontend/src/lib/wikipedia.ts that don't match any current carrier
# id — those carriers fall through to the display_name fallback, often
# resolving to a less ideal page (or 404). Once happened with CARR_HIST_TANG
# being renamed to CARR_HIST_TANG_CHINESE.
WIKI_FILE="$(cd "$(dirname "$0")/.." && pwd)/frontend/src/lib/wikipedia.ts"
if [[ -f "$WIKI_FILE" ]]; then
  # Only treat lines that look like an object-literal entry: leading whitespace,
  # a CARR_* identifier, then ':'. This avoids false positives from comments.
  # BSD sed doesn't grok `\s`, so use the POSIX class.
  wiki_keys=$(grep -oE '^[[:space:]]*CARR_[A-Z_0-9]+:' "$WIKI_FILE" \
                | sed -E 's/^[[:space:]]+//; s/:$//' | sort -u)
  if [[ -n "$wiki_keys" ]]; then
    db_keys=$(psqlq "SELECT id FROM carrier ORDER BY id" | sort -u)
    stale=$(comm -23 <(echo "$wiki_keys") <(echo "$db_keys") || true)
    stale_count=$(echo "$stale" | grep -c . || true)
    echo "count: $stale_count"
    if [[ "$stale_count" -gt 0 ]]; then
      echo "first 15:"
      echo "$stale" | head -15
    fi
  else
    echo "count: 0  (no overrides in wikipedia.ts)"
  fi
else
  echo "count: 0  (wikipedia.ts not found at $WIKI_FILE)"
fi

section "Trait-domain enum coverage in trait_mix"
echo "domain breakdown:"
psqlq "SELECT domain, count(*) AS rows, count(DISTINCT carrier_id) AS carriers
       FROM carrier_trait_mix GROUP BY domain ORDER BY rows DESC"

section "Per-region carrier counts (rough)"
psqlq "
WITH r AS (
  SELECT id,
    CASE
      WHEN ST_Y(centroid::geometry) > 25 AND ST_X(centroid::geometry) BETWEEN -130 AND -50 THEN 'N_America'
      WHEN ST_Y(centroid::geometry) BETWEEN -10 AND 25 AND ST_X(centroid::geometry) BETWEEN -120 AND -60 THEN 'Mesoamerica'
      WHEN ST_Y(centroid::geometry) < -10 AND ST_X(centroid::geometry) BETWEEN -90 AND -30 THEN 'S_America'
      WHEN ST_Y(centroid::geometry) BETWEEN -35 AND 5 AND ST_X(centroid::geometry) BETWEEN 10 AND 45 THEN 'Sub_Saharan_Africa'
      WHEN ST_Y(centroid::geometry) BETWEEN 35 AND 75 AND ST_X(centroid::geometry) BETWEEN -10 AND 40 THEN 'Europe'
      WHEN ST_Y(centroid::geometry) BETWEEN 12 AND 45 AND ST_X(centroid::geometry) BETWEEN 25 AND 65 THEN 'Mideast'
      WHEN ST_Y(centroid::geometry) BETWEEN 5 AND 38 AND ST_X(centroid::geometry) BETWEEN 60 AND 95 THEN 'S_Asia'
      WHEN ST_Y(centroid::geometry) BETWEEN 15 AND 60 AND ST_X(centroid::geometry) BETWEEN 95 AND 150 THEN 'E_Asia'
      WHEN ST_Y(centroid::geometry) BETWEEN -55 AND 0 AND ST_X(centroid::geometry) BETWEEN 110 AND 180 THEN 'Oceania'
      WHEN ST_Y(centroid::geometry) > 50 AND ST_X(centroid::geometry) > 60 THEN 'Siberia'
      ELSE 'Other'
    END AS region
  FROM carrier WHERE centroid IS NOT NULL
)
SELECT region, count(*) FROM r GROUP BY region ORDER BY count DESC"

section "Total"
echo "carriers: $(psqlq "SELECT count(*) FROM carrier")"
echo "claims:   $(psqlq "SELECT count(*) FROM claim")"
echo "threats:  $(psqlq "SELECT count(*) FROM carrier_threat")"
echo "trait_mix:$(psqlq "SELECT count(*) FROM carrier_trait_mix")"
echo "extent_snapshots:$(psqlq "SELECT count(*) FROM carrier_extent_snapshot")"
