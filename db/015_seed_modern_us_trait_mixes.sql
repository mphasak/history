-- 015_seed_modern_us_trait_mixes.sql
--
-- Editorial best-effort ancestry for the two modern US demo carriers
-- (Rural South + SF Bay Area), so the multi-hop lineage can actually
-- trace from "redneck" → European Bronze Age → Mesolithic → Neanderthal,
-- and from "Bay Area" → East Asian / South Asian / European → archaic
-- admixture.
--
-- Numbers are approximate, follow rough census-genetics summaries
-- (e.g. Bryc et al. 2015 for African-American/European-American
-- admixture in the South), and pad small Neanderthal admixture so the
-- BFS terminates at CARR_HOMININ_NEANDERTHAL on a deep trace.
--
-- Idempotent: keyed on the [AUTO-TRAITMIX-015] claim statement prefix.

DELETE FROM carrier_trait_mix
WHERE claim_id IN (
  SELECT id FROM claim WHERE statement LIKE '[AUTO-TRAITMIX-015]%'
);
DELETE FROM claim_source
WHERE claim_id IN (
  SELECT id FROM claim WHERE statement LIKE '[AUTO-TRAITMIX-015]%'
);
DELETE FROM claim WHERE statement LIKE '[AUTO-TRAITMIX-015]%';

INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-TRAITMIX-015] Editorial best-effort modern-US ancestry composition for ' ||
       display_name || '; see DEDUCED_PHASE_0 for methodology.',
       3
FROM carrier
WHERE id IN ('CARR_RURAL_SOUTH_US_2025', 'CARR_SF_BAY_AREA_2025');

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim WHERE statement LIKE '[AUTO-TRAITMIX-015]%';

WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- Rural South US (~2000): predominantly NW-European-derived with sizable
  -- AFR_WEST and modest AMER_NA, plus universal small archaic admixture.
  ('CARR_RURAL_SOUTH_US_2025', 'ANATOLIAN_FARMER', 0.300, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'STEPPE_MLBA',     0.250, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'WHG',             0.100, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'IRN_N',           0.080, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'AFR_WEST',        0.180, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'AMER_NA',         0.050, 2000),
  ('CARR_RURAL_SOUTH_US_2025', 'NEANDERTHAL',     0.020, 2000),
  -- SF Bay Area (~2020): substantially more diverse, with East-Asian and
  -- South-Asian fractions reflecting recent immigration.
  ('CARR_SF_BAY_AREA_2025',   'ANATOLIAN_FARMER', 0.200, 2020),
  ('CARR_SF_BAY_AREA_2025',   'STEPPE_MLBA',     0.150, 2020),
  ('CARR_SF_BAY_AREA_2025',   'WHG',             0.050, 2020),
  ('CARR_SF_BAY_AREA_2025',   'EAST_ASIAN',      0.250, 2020),
  ('CARR_SF_BAY_AREA_2025',   'ANI',             0.080, 2020),
  ('CARR_SF_BAY_AREA_2025',   'ASI',             0.040, 2020),
  ('CARR_SF_BAY_AREA_2025',   'AFR_WEST',        0.080, 2020),
  ('CARR_SF_BAY_AREA_2025',   'AMER_NA',         0.130, 2020),
  ('CARR_SF_BAY_AREA_2025',   'NEANDERTHAL',     0.020, 2020)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-TRAITMIX-015]%';
