-- 020_seed_hominin_archaic_traits.sql
--
-- Drift report flagged 12 carriers without any `carrier_trait_mix` rows
-- and 19 without any `claim` row — almost all of them archaic hominins
-- (Homo erectus, heidelbergensis, naledi, etc.) and the earliest
-- sapiens (Jebel Irhoud, Omo / Herto). For the lineage BFS to traverse
-- through them and for the cluster-coloring to render them at all, they
-- need trait_mix entries.
--
-- This seed:
--   1. Registers archaic-hominin trait_ids in the `trait` table
--      (HOMININ_HABILIS, HOMININ_ERECTUS, HOMININ_HEIDELBERGENSIS, etc.).
--      We already had NEANDERTHAL and DENISOVAN as canonical archaic-
--      admixture components from the spreadsheet seed.
--   2. Assigns each hominin carrier its own self-trait at fraction 1.0
--      (e.g. CARR_HOMININ_HEIDELBERGENSIS has trait HOMININ_HEIDELBERGENSIS
--      = 1.0). For sapiens precursors we use AFR_BASAL.
--   3. Adds [AUTO-PROVENANCE] claims for these carriers + the 8
--      spreadsheet-origin carriers that had trait_mix but no claim
--      (Anatolian Farmer, Iranian Neolithic, Yamnaya, Corded Ware, Bell
--      Beaker, Tianyuan, CHG, NW South Asia LBA), citing
--      DEDUCED_PHASE_0.
--
-- Idempotent on the [AUTO-TRAITMIX-020] / [AUTO-PROVENANCE-020] tags
-- and the new HOMININ_* trait_ids.

-- ---- 1. Archaic-hominin trait_ids ----
INSERT INTO trait (id, domain, display_name, description) VALUES
  ('HOMININ_HABILIS',         'genetic', 'Homo habilis lineage',
   'Earliest Homo, ~2.4-1.4 Mya; tool-using African hominin ancestral to erectus.'),
  ('HOMININ_ERECTUS',         'genetic', 'Homo erectus lineage',
   'Long-lived hominin ~1.9 Mya - ~100 kya; ergaster + Asian erectus radiations; first hominin out of Africa.'),
  ('HOMININ_ANTECESSOR',      'genetic', 'Homo antecessor lineage',
   'European Pleistocene hominin ~1.2-0.8 Mya, possibly ancestor to heidelbergensis.'),
  ('HOMININ_HEIDELBERGENSIS', 'genetic', 'Homo heidelbergensis lineage',
   'Middle-Pleistocene hominin ~700-200 kya; ancestor of Neanderthals and (in Africa) modern humans.'),
  ('HOMININ_NALEDI',          'genetic', 'Homo naledi lineage',
   'South African small-bodied hominin lineage, recently dated to ~335-236 kya.'),
  ('HOMININ_RHODESIENSIS',    'genetic', 'Homo rhodesiensis lineage',
   'African Middle-Pleistocene hominin (Kabwe), often grouped with heidelbergensis.'),
  ('HOMININ_FLORESIENSIS',    'genetic', 'Homo floresiensis lineage',
   'Insular dwarf hominin of Flores, Indonesia; ~100-50 kya.'),
  ('HOMININ_LUZONENSIS',      'genetic', 'Homo luzonensis lineage',
   'Insular Filipino hominin; small-bodied, ~67-50 kya, contemporary with sapiens arrival in SE Asia.')
ON CONFLICT (id) DO NOTHING;

-- ---- 2. Tear down prior 020-tagged entries (idempotent re-run) ----
DELETE FROM carrier_trait_mix
WHERE claim_id IN (
  SELECT id FROM claim WHERE statement LIKE '[AUTO-PROVENANCE-020]%'
);
DELETE FROM claim_source
WHERE claim_id IN (
  SELECT id FROM claim WHERE statement LIKE '[AUTO-PROVENANCE-020]%'
);
DELETE FROM claim WHERE statement LIKE '[AUTO-PROVENANCE-020]%';

-- ---- 3. Carriers we'll touch ----
WITH carriers_to_enrich(carrier_id) AS (VALUES
  ('CARR_HOMININ_HOMO_HABILIS'),
  ('CARR_HOMININ_AFRICAN_ERECTUS'),
  ('CARR_HOMININ_ASIAN_ERECTUS_JAVA'),
  ('CARR_HOMININ_ANTECESSOR'),
  ('CARR_HOMININ_ASIAN_ERECTUS_CHINA'),
  ('CARR_HOMININ_HEIDELBERGENSIS'),
  ('CARR_HOMININ_NALEDI'),
  ('CARR_HOMININ_RHODESIENSIS'),
  ('CARR_HOMININ_FLORESIENSIS'),
  ('CARR_HOMININ_LUZONENSIS'),
  ('CARR_HIST_JEBEL_IRHOUD'),
  ('CARR_HIST_OMO_HERTO'),
  -- Spreadsheet carriers missing a Carrier-level claim:
  ('CARR_ANATOLIAN_FARMER'),
  ('CARR_IRAN_NEOLITHIC'),
  ('CARR_YAMNAYA'),
  ('CARR_CORDED_WARE'),
  ('CARR_BELL_BEAKER'),
  ('CARR_CHG_MESO'),
  ('CARR_TIANYUAN_40K'),
  ('CARR_NW_SOUTH_ASIA_LATE_BRONZE')
)
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', carrier_id,
       '[AUTO-PROVENANCE-020] Editorial best-effort summary of the ' ||
       'genetic / archaeological identity of this carrier; see ' ||
       'DEDUCED_PHASE_0 for methodology.',
       3
FROM carriers_to_enrich;

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c WHERE c.statement LIKE '[AUTO-PROVENANCE-020]%';

-- ---- 4. Trait mixes for the 12 carriers without any ----
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- Each archaic hominin carries its own self-trait at 1.0.
  ('CARR_HOMININ_HOMO_HABILIS',        'HOMININ_HABILIS',         1.000, -1900000),
  ('CARR_HOMININ_AFRICAN_ERECTUS',     'HOMININ_ERECTUS',         1.000, -1200000),
  ('CARR_HOMININ_ASIAN_ERECTUS_JAVA',  'HOMININ_ERECTUS',         1.000, -800000),
  ('CARR_HOMININ_ASIAN_ERECTUS_CHINA', 'HOMININ_ERECTUS',         1.000, -600000),
  ('CARR_HOMININ_ANTECESSOR',          'HOMININ_ANTECESSOR',      1.000, -1000000),
  ('CARR_HOMININ_HEIDELBERGENSIS',     'HOMININ_HEIDELBERGENSIS', 1.000, -450000),
  ('CARR_HOMININ_NALEDI',              'HOMININ_NALEDI',          1.000, -285000),
  ('CARR_HOMININ_RHODESIENSIS',        'HOMININ_RHODESIENSIS',    1.000, -210000),
  ('CARR_HOMININ_FLORESIENSIS',        'HOMININ_FLORESIENSIS',    1.000, -75000),
  ('CARR_HOMININ_LUZONENSIS',          'HOMININ_LUZONENSIS',      1.000, -58000),
  -- Earliest sapiens carriers — predate the OOA differentiation, so they
  -- carry primarily AFR_BASAL with a small heidelbergensis substrate.
  ('CARR_HIST_JEBEL_IRHOUD', 'AFR_BASAL',              0.800, -280000),
  ('CARR_HIST_JEBEL_IRHOUD', 'HOMININ_HEIDELBERGENSIS', 0.200, -280000),
  ('CARR_HIST_OMO_HERTO',    'AFR_BASAL',              0.900, -180000),
  ('CARR_HIST_OMO_HERTO',    'HOMININ_HEIDELBERGENSIS', 0.100, -180000)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE-020]%';
