-- 017_seed_post_columbian_carriers.sql
--
-- The seed prior to this file represented post-1492 history almost
-- exclusively through indigenous-descendant carriers ("Modern Native
-- Americans", "Modern Latin American Mestizo") and a single Mexican
-- colonial bridge. The colonial-era and modern *settler-derived* and
-- *African-diasporic* populations that demographically dominate large
-- parts of the Americas, Australia, NZ, and southern Africa weren't
-- represented at all — so scrubbing through 1700, 1800, 1900 across
-- these regions made it look like Europeans never showed up and the
-- Atlantic slave trade never happened.
--
-- This seed adds the missing carriers (CARR_HIST_POST1492_*):
--
--   * North America: English/Dutch/French colonial period (1607-1776),
--     post-independence European-Americans (1776-1900), Gilded-Age
--     immigration era (1865-1945), and the African-American population
--     that formed under slavery (1700-2025).
--   * Caribbean: Afro-Caribbean post-Columbian populations (1500-2025).
--   * Brazil: Portuguese colonial (1500-1822), modern Brazilian (1900-2025).
--   * Andes: Spanish colonial Andean (1532-1810).
--   * Australia / NZ: British colonial Australia (1788-1901), modern
--     Australian (1900-2025), Pākehā New Zealand (1840-2025).
--   * Southern Africa: Afrikaner (1652-2025).
--   * Levant: Modern Israeli (1948-2025).
--
-- All cited via DEDUCED_PHASE_0; idempotent on the CARR_HIST_POST1492_
-- prefix.

DELETE FROM carrier_trait_mix WHERE carrier_id LIKE 'CARR_HIST_POST1492_%';
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_POST1492_%'
);
DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_POST1492_%';
DELETE FROM carrier WHERE id LIKE 'CARR_HIST_POST1492_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- ── North America ──
  ('CARR_HIST_POST1492_COLONIAL_NA',  'Colonial North America (English/Dutch/French)', 'population',
   1607, 1776, ST_GeogFromText('SRID=4326;POINT(-76.0 38.0)'),
   'Colonial', 'English / Dutch / French',
   'Atlantic-seaboard European settlers from Jamestown through independence; predominantly English / Scots-Irish / Dutch / French / German Protestant origin; coexists with declining indigenous nations and an enslaved African population that becomes its own carrier (CARR_HIST_POST1492_AFRICAN_AMERICAN).'),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE', 'European-American (Republic, 1776-1900)', 'population',
   1776, 1900, ST_GeogFromText('SRID=4326;POINT(-87.0 39.5)'),
   'Antebellum / Reconstruction', 'English (US dialects)',
   'Post-independence demographically European-derived US population, expanding westward; absorbs Irish (post-1845) and German waves but otherwise relatively closed; the demographic majority through the 19th century.'),
  ('CARR_HIST_POST1492_GILDED_AGE_US', 'Gilded-Age US (1865-1945)', 'population',
   1865, 1945, ST_GeogFromText('SRID=4326;POINT(-74.0 40.7)'),
   'Industrial America', 'English',
   'Mass-immigration-era US: Italian, Polish, Russian-Jewish, Greek, Hungarian, Slavic newcomers reshape the demographic profile of cities and industrial regions; ends with the Immigration Act of 1924 and WWII.'),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN', 'African Americans', 'population',
   1700, 2025, ST_GeogFromText('SRID=4326;POINT(-87.0 33.0)'),
   'Atlantic Diaspora', 'English (AAVE)',
   'Atlantic-slave-trade-derived population formed in the colonial Americas, primarily from West-Central African source populations with admixture from European-Americans and (regionally variable) Native Americans. Concentrated in the Southeast through the Civil War, then redistributed nationally during the Great Migration.'),

  -- ── Caribbean ──
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN', 'Afro-Caribbean', 'population',
   1500, 2025, ST_GeogFromText('SRID=4326;POINT(-72.0 18.5)'),
   'Atlantic Diaspora', 'English / French / Spanish creoles',
   'Post-Columbian Caribbean populations, mostly West-African-descended via the sugar plantation economy, with European, Taíno, and (in the 19th c.) South-Asian admixture in specific islands.'),

  -- ── Brazil ──
  ('CARR_HIST_POST1492_COLONIAL_BR', 'Colonial Brazilian', 'population',
   1500, 1822, ST_GeogFromText('SRID=4326;POINT(-43.2 -22.9)'),
   'Colonial Brazilian', 'Portuguese',
   'Portuguese-led colonial society with substantial enslaved-African and indigenous (Tupí) presence; sugar in the NE, cattle and gold in the interior, gold rush in Minas Gerais.'),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN', 'Modern Brazilians', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(-47.0 -15.0)'),
   'Modern Brazilian', 'Portuguese',
   'Trans-regional Brazilian demographic synthesis with substantial Iberian, West-African, indigenous, Italian, German, Lebanese, and Japanese components depending on the region.'),

  -- ── Andes ──
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN', 'Colonial Andean', 'population',
   1532, 1810, ST_GeogFromText('SRID=4326;POINT(-72.0 -13.5)'),
   'Colonial Spanish Andean', 'Spanish + Quechua + Aymara',
   'Post-Inca Spanish-Andean colonial society: mining-tribute-driven Cuzco/Potosí silver economy, mestizo formation, persistence of Quechua- and Aymara-speaking communities under encomienda.'),

  -- ── Australia / NZ ──
  ('CARR_HIST_POST1492_COLONIAL_AUS', 'Colonial Australia (British)', 'population',
   1788, 1901, ST_GeogFromText('SRID=4326;POINT(151.2 -33.9)'),
   'Colonial', 'English',
   'British convict and free-settler population from the First Fleet through Federation; coexists with — and demographically displaces — the Aboriginal population.'),
  ('CARR_HIST_POST1492_MODERN_AUS', 'Modern Australians', 'population',
   1901, 2025, ST_GeogFromText('SRID=4326;POINT(149.1 -35.3)'),
   'Modern', 'English (Australian)',
   'Federated Australian population: predominantly British / Irish-derived through WWII, then post-1970s Asian, Mediterranean European, and Middle-Eastern immigration reshape the urban demographic profile.'),
  ('CARR_HIST_POST1492_PAKEHA_NZ', 'Pākehā (New Zealand European)', 'population',
   1840, 2025, ST_GeogFromText('SRID=4326;POINT(174.8 -41.3)'),
   'Modern', 'English (NZ)',
   'European-derived New Zealanders since the 1840 Treaty of Waitangi; British / Irish core with Pacific-Islander and Asian admixture in recent decades.'),

  -- ── Southern Africa ──
  ('CARR_HIST_POST1492_AFRIKANER', 'Afrikaners', 'population',
   1652, 2025, ST_GeogFromText('SRID=4326;POINT(28.0 -25.7)'),
   'Modern', 'Afrikaans',
   'Dutch / Huguenot / German Cape-of-Good-Hope settler-descended population; small Khoisan and West-African admixture from early colonial intermixture.'),

  -- ── Levant modern ──
  ('CARR_HIST_POST1492_MODERN_ISRAELI', 'Modern Israelis', 'population',
   1948, 2025, ST_GeogFromText('SRID=4326;POINT(34.8 31.0)'),
   'Modern', 'Hebrew + Arabic',
   'Demographic synthesis of Ashkenazi, Sephardi, Mizrahi, Ethiopian, Arab Israeli, Soviet-Jewish-immigrant, and Druze communities since the 1948 founding.');

-- Provenance claims linking to DEDUCED_PHASE_0.
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is a post-1492 colonial / globalization-era carrier added so the ' ||
       'map reflects European colonization, the Atlantic slave trade, and ' ||
       'modern demographic synthesis; ancestry summary projected from ' ||
       'documented immigration history, see DEDUCED_PHASE_0.',
       3
FROM carrier WHERE id LIKE 'CARR_HIST_POST1492_%';

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id LIKE 'CARR_HIST_POST1492_%';

-- Trait-mix entries.
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- Colonial / Republic-era N. America: nearly-pure NW European mix.
  ('CARR_HIST_POST1492_COLONIAL_NA',         'ANATOLIAN_FARMER', 0.350, 1700),
  ('CARR_HIST_POST1492_COLONIAL_NA',         'STEPPE_MLBA',      0.300, 1700),
  ('CARR_HIST_POST1492_COLONIAL_NA',         'WHG',              0.150, 1700),
  ('CARR_HIST_POST1492_COLONIAL_NA',         'IRN_N',            0.100, 1700),
  ('CARR_HIST_POST1492_COLONIAL_NA',         'NEANDERTHAL',      0.020, 1700),

  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'ANATOLIAN_FARMER', 0.330, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'STEPPE_MLBA',      0.290, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'WHG',              0.150, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'IRN_N',            0.100, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'AMER_NA',          0.030, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'AFR_WEST',         0.030, 1850),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE',   'NEANDERTHAL',      0.020, 1850),

  -- Gilded-Age US adds Italian / Slavic / Eastern-European weight.
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'ANATOLIAN_FARMER', 0.340, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'STEPPE_MLBA',      0.250, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'WHG',              0.140, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'IRN_N',            0.150, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'AFR_WEST',         0.060, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'AMER_NA',          0.020, 1900),
  ('CARR_HIST_POST1492_GILDED_AGE_US',       'NEANDERTHAL',      0.020, 1900),

  -- African Americans: dominant West-African with European admixture.
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'AFR_WEST',         0.800, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'ANATOLIAN_FARMER', 0.080, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'STEPPE_MLBA',      0.060, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'WHG',              0.020, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'AMER_NA',          0.030, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',    'AFR_BASAL',        0.010, 1900),

  -- Afro-Caribbean: similar but slightly more African and less Native.
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN',      'AFR_WEST',         0.820, 1800),
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN',      'ANATOLIAN_FARMER', 0.080, 1800),
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN',      'STEPPE_MLBA',      0.050, 1800),
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN',      'AMER_NA',          0.030, 1800),
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN',      'AFR_BASAL',        0.020, 1800),

  -- Colonial Brazilian: Iberian + African + indigenous, mixed.
  ('CARR_HIST_POST1492_COLONIAL_BR',         'ANATOLIAN_FARMER', 0.370, 1700),
  ('CARR_HIST_POST1492_COLONIAL_BR',         'STEPPE_MLBA',      0.180, 1700),
  ('CARR_HIST_POST1492_COLONIAL_BR',         'AFR_WEST',         0.220, 1700),
  ('CARR_HIST_POST1492_COLONIAL_BR',         'AMER_NA',          0.130, 1700),
  ('CARR_HIST_POST1492_COLONIAL_BR',         'WHG',              0.080, 1700),

  -- Modern Brazilian: more uniform regional synthesis.
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'ANATOLIAN_FARMER', 0.330, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'STEPPE_MLBA',      0.180, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'AFR_WEST',         0.200, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'AMER_NA',          0.150, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'WHG',              0.060, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'EAST_ASIAN',       0.060, 1980),
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN',    'IRN_N',            0.020, 1980),

  -- Colonial Andean: dominant indigenous with Spanish minority.
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',     'AMER_NA',          0.700, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',     'ANATOLIAN_FARMER', 0.180, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',     'STEPPE_MLBA',      0.090, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',     'AFR_WEST',         0.020, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',     'WHG',              0.010, 1700),

  -- Colonial Australian: nearly-pure British-Irish.
  ('CARR_HIST_POST1492_COLONIAL_AUS',        'ANATOLIAN_FARMER', 0.350, 1850),
  ('CARR_HIST_POST1492_COLONIAL_AUS',        'STEPPE_MLBA',      0.300, 1850),
  ('CARR_HIST_POST1492_COLONIAL_AUS',        'WHG',              0.180, 1850),
  ('CARR_HIST_POST1492_COLONIAL_AUS',        'IRN_N',            0.100, 1850),
  ('CARR_HIST_POST1492_COLONIAL_AUS',        'NEANDERTHAL',      0.020, 1850),

  -- Modern Australian: post-WWII immigration adds EAST_ASIAN, AUS_PNG, AFR_WEST.
  ('CARR_HIST_POST1492_MODERN_AUS',          'ANATOLIAN_FARMER', 0.300, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'STEPPE_MLBA',      0.230, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'WHG',              0.110, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'IRN_N',            0.090, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'EAST_ASIAN',       0.130, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'AUS_PNG',          0.040, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'AFR_WEST',         0.030, 2010),
  ('CARR_HIST_POST1492_MODERN_AUS',          'ANI',              0.040, 2010),

  -- Pakeha NZ: similar to Australian but slightly more East-Asian / Pacific.
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'ANATOLIAN_FARMER', 0.310, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'STEPPE_MLBA',      0.260, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'WHG',              0.140, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'IRN_N',            0.100, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'EAST_ASIAN',       0.120, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'AUS_PNG',          0.050, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',           'NEANDERTHAL',      0.020, 2010),

  -- Afrikaner: mostly NW European with small Khoisan + W African.
  ('CARR_HIST_POST1492_AFRIKANER',           'ANATOLIAN_FARMER', 0.300, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'STEPPE_MLBA',      0.300, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'WHG',              0.180, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'IRN_N',            0.100, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'AFR_KHOISAN',      0.040, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'AFR_WEST',         0.040, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'AFR_BASAL',        0.020, 1900),
  ('CARR_HIST_POST1492_AFRIKANER',           'NEANDERTHAL',      0.020, 1900),

  -- Modern Israeli: multi-component Levant + diaspora.
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'NATUFIAN',         0.300, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'ANATOLIAN_FARMER', 0.220, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'STEPPE_MLBA',      0.150, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'IRN_N',            0.150, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'WHG',              0.060, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'AFR_BASAL',        0.080, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'AFR_WEST',         0.020, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',      'NEANDERTHAL',      0.020, 2010)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE]%';
