-- 019_seed_modern_continental_carriers.sql
--
-- The 1900-2025 strip had only narrow modern-US carriers (Rural South,
-- SF Bay Area) so scrubbing to 2025 painted the United States as two
-- regional dots while showing African Americans only in the SE and no
-- general European-derived "modern American" anywhere. This seed adds:
--
--   * CARR_HIST_POST1492_MODERN_USA — generic post-WWII US population,
--     continental coverage. Coexists with the African American carrier,
--     the regional Rural-South / SF-Bay-Area entries, and the modern
--     Native American carrier.
--   * CARR_HIST_POST1492_MODERN_CANADA — generic modern Canadian.
--   * CARR_HIST_POST1492_MODERN_MEXICO — generic modern Mexican.
--
-- Each comes with a continental extent polygon so the map shows broad
-- coverage rather than another point-circle.
--
-- All cited via DEDUCED_PHASE_0; idempotent on the carrier_id list.

DELETE FROM carrier_trait_mix WHERE carrier_id IN (
  'CARR_HIST_POST1492_MODERN_USA',
  'CARR_HIST_POST1492_MODERN_CANADA',
  'CARR_HIST_POST1492_MODERN_MEXICO'
);
DELETE FROM carrier_extent_snapshot WHERE carrier_id IN (
  'CARR_HIST_POST1492_MODERN_USA',
  'CARR_HIST_POST1492_MODERN_CANADA',
  'CARR_HIST_POST1492_MODERN_MEXICO'
);
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id IN (
    'CARR_HIST_POST1492_MODERN_USA',
    'CARR_HIST_POST1492_MODERN_CANADA',
    'CARR_HIST_POST1492_MODERN_MEXICO'
  )
);
DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id IN (
  'CARR_HIST_POST1492_MODERN_USA',
  'CARR_HIST_POST1492_MODERN_CANADA',
  'CARR_HIST_POST1492_MODERN_MEXICO'
);
DELETE FROM carrier WHERE id IN (
  'CARR_HIST_POST1492_MODERN_USA',
  'CARR_HIST_POST1492_MODERN_CANADA',
  'CARR_HIST_POST1492_MODERN_MEXICO'
);

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES
  ('CARR_HIST_POST1492_MODERN_USA', 'Modern United States population (broad)', 'population',
   1945, 2025, ST_GeogFromText('SRID=4326;POINT(-95.0 39.5)'),
   'Modern', 'English (US)',
   'Post-WWII trans-regional US population — predominantly European-derived but with substantial African American (~13%), Hispanic / Latino (~19%), Asian (~7%), and Native American components. Coexists on the map with the more specific Rural South, SF Bay Area, and African American carriers.'),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'Modern Canadian (broad)', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(-79.5 45.0)'),
   'Modern', 'English / French',
   'Modern Canadian population — British / French settler core with substantial post-war immigration from Europe, the Caribbean, South Asia, the Middle East, and East Asia. Excludes the First Nations / Inuit / Métis populations represented separately.'),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'Modern Mexican (broad)', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(-99.1 19.4)'),
   'Modern', 'Spanish',
   'Modern Mexican mestizo and indigenous synthesis: most of the population is mixed Spanish + indigenous Mesoamerican ancestry, with a substantial African American component (especially Veracruz / Costa Chica) and persistence of distinct indigenous nations.');

-- Provenance.
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is a continental modern carrier added so the post-WWII map ' ||
       'shows broad N-American coverage, not just regional dots; ' ||
       'see DEDUCED_PHASE_0.',
       3
FROM carrier WHERE id IN (
  'CARR_HIST_POST1492_MODERN_USA',
  'CARR_HIST_POST1492_MODERN_CANADA',
  'CARR_HIST_POST1492_MODERN_MEXICO'
);

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id IN (
    'CARR_HIST_POST1492_MODERN_USA',
    'CARR_HIST_POST1492_MODERN_CANADA',
    'CARR_HIST_POST1492_MODERN_MEXICO'
  );

-- Trait-mix entries reflecting the broad population profile.
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- Modern USA: ~57% non-Hispanic white, ~13% Black, ~19% Hispanic
  -- (mostly mestizo), ~7% Asian, ~3% other. The fractions below collapse
  -- those into the underlying ancestry components.
  ('CARR_HIST_POST1492_MODERN_USA', 'ANATOLIAN_FARMER', 0.250, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'STEPPE_MLBA',     0.200, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'WHG',             0.080, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'IRN_N',           0.080, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'AFR_WEST',        0.130, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'AMER_NA',         0.130, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'EAST_ASIAN',      0.080, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'ANI',             0.030, 2010),
  ('CARR_HIST_POST1492_MODERN_USA', 'NEANDERTHAL',     0.020, 2010),

  -- Modern Canada: similar but with smaller African American fraction.
  ('CARR_HIST_POST1492_MODERN_CANADA', 'ANATOLIAN_FARMER', 0.300, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'STEPPE_MLBA',     0.230, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'WHG',             0.110, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'IRN_N',           0.090, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'AFR_WEST',        0.040, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'AMER_NA',         0.080, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'EAST_ASIAN',      0.090, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'ANI',             0.040, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA', 'NEANDERTHAL',     0.020, 2010),

  -- Modern Mexico: dominant mestizo (Spanish + AMER_NA) with small AFR_WEST.
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'AMER_NA',          0.450, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'ANATOLIAN_FARMER', 0.230, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'STEPPE_MLBA',      0.150, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'WHG',              0.060, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'IRN_N',            0.040, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'AFR_WEST',         0.050, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 'NEANDERTHAL',      0.020, 2010)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE]%';

-- Continental extent polygons.
INSERT INTO carrier_extent_snapshot (carrier_id, as_of_year, geometry) VALUES
  ('CARR_HIST_POST1492_MODERN_USA', 2000,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-124 25, -97 25, -82 24, -75 25, -67 30, -67 45, -83 47, -95 49, -108 49, -124 49, -124 32, -124 25))')::geometry)::geography),
  ('CARR_HIST_POST1492_MODERN_CANADA', 2000,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-141 50, -109 50, -89 49, -83 47, -67 45, -56 47, -53 53, -65 60, -100 60, -130 60, -141 60, -141 50))')::geometry)::geography),
  ('CARR_HIST_POST1492_MODERN_MEXICO', 2000,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-117 32, -106 32, -97 26, -88 21, -88 16, -94 14, -103 16, -109 23, -115 27, -117 32))')::geometry)::geography);
