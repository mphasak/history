-- 016_seed_temporal_bridge_carriers.sql
--
-- Fills temporal gaps that made populations look extinct as the user
-- scrubbed the year slider. The pattern was: a carrier ends at year Y,
-- its successor in the same region starts at year Y+N for some N, and
-- the intervening N years show NO carrier in that region — leaving a
-- visually empty map at e.g. 600 CE in North America (between Hopewell
-- ending ~500 CE and Mississippian starting ~800 CE).
--
-- Coverage added (carrier_id prefix CARR_HIST_BRIDGE_):
--
--   * North America 300-1100 CE — Late Woodland, Anasazi (Ancestral
--     Puebloan), Hohokam, Fremont. Bridges Hopewell → Mississippian /
--     Pueblo.
--   * S America bronze-age 1500 BCE - 100 BCE — Cupisnique (Andean coast
--     precursor of Chavín) and Amazonian horticulturalists. Bridges
--     Norte-Chico → Chavín → Moche.
--   * Siberia 2500 BCE - 1000 BCE — Afanasievo, Andronovo, Botai,
--     Okunev. Bridges between deep-paleolithic Mal'ta and historical
--     Türkic / Yakut entries.
--   * Mesoamerica 1521-1900 CE — Colonial Latin American (criollo +
--     mestizo formation). Bridges Aztec → Modern Mestizo.
--   * Sub-Saharan Africa transitions — Garamantes (Sahara, 500 BCE -
--     700 CE), Aksumite/Solomonic transition (Zagwe, 900-1270).
--
-- All cited via DEDUCED_PHASE_0. Idempotent on the CARR_HIST_BRIDGE_ prefix.

DELETE FROM carrier_trait_mix WHERE carrier_id LIKE 'CARR_HIST_BRIDGE_%';
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_BRIDGE_%'
);
DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_BRIDGE_%';
DELETE FROM carrier WHERE id LIKE 'CARR_HIST_BRIDGE_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- ── North America 300-1100 CE bridge ──
  ('CARR_HIST_BRIDGE_LATE_WOODLAND', 'Late Woodland (Eastern N America)', 'population',
   500, 1100, ST_GeogFromText('SRID=4326;POINT(-83.0 38.0)'),
   'Late Woodland', NULL,
   'Eastern Woodlands populations between the Hopewell decline and Mississippian rise; bow-and-arrow adoption, intensifying maize agriculture, smaller more dispersed settlements than Hopewell.'),
  ('CARR_HIST_BRIDGE_ANASAZI', 'Ancestral Puebloan (Anasazi)', 'population',
   100, 1300, ST_GeogFromText('SRID=4326;POINT(-108.0 36.5)'),
   'Ancestral Puebloan', NULL,
   'Four Corners region cliff-dwelling and pueblo-building society; Mesa Verde, Chaco Canyon. Drought-driven southward dispersal in the late 13th century into the historic Pueblo peoples.'),
  ('CARR_HIST_BRIDGE_HOHOKAM', 'Hohokam', 'population',
   300, 1500, ST_GeogFromText('SRID=4326;POINT(-112.0 33.5)'),
   'Hohokam', NULL,
   'Sonoran Desert (S Arizona) irrigation-canal society, ancestral to the modern Akimel O''odham (Pima) and Tohono O''odham.'),
  ('CARR_HIST_BRIDGE_FREMONT', 'Fremont', 'population',
   400, 1300, ST_GeogFromText('SRID=4326;POINT(-112.5 39.5)'),
   'Fremont', NULL,
   'Great Basin / Utah maize-and-foraging culture, contemporaneous with Anasazi but with distinct material culture; absorbed or displaced by Numic-speaker arrival.'),

  -- ── S America bronze-age & late-classical bridges ──
  ('CARR_HIST_BRIDGE_CUPISNIQUE', 'Cupisnique', 'population',
   -1500, -500, ST_GeogFromText('SRID=4326;POINT(-79.0 -7.5)'),
   'Cupisnique', NULL,
   'Northern Peruvian coastal culture predating Chavín; ceramic stirrup-spout vessels, ceremonial centers (Kuntur Wasi, Caballo Muerto). Ancestral to the Chavín tradition.'),
  ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE', 'Amazonian formative horticulturalists', 'population',
   -2000, 500, ST_GeogFromText('SRID=4326;POINT(-65.0 -5.0)'),
   'Amazonian Formative', NULL,
   'Pre-Marajoara Amazonian populations transitioning from foraging to manioc / maize horticulture; terra preta soil engineering, riverine settlements.'),
  ('CARR_HIST_BRIDGE_PARACAS', 'Paracas', 'population',
   -800, 100, ST_GeogFromText('SRID=4326;POINT(-76.0 -14.0)'),
   'Paracas', NULL,
   'South-coastal Peruvian society famous for elaborate textile mantles and cranial modification; precedes and partly overlaps Nazca.'),

  -- ── Siberia / Steppe bronze-age bridges ──
  ('CARR_HIST_BRIDGE_AFANASIEVO', 'Afanasievo', 'population',
   -3300, -2500, ST_GeogFromText('SRID=4326;POINT(88.0 53.0)'),
   'Afanasievo', NULL,
   'South-Siberian (Altai/Yenisei) bronze-age culture, Yamnaya-derived; the easternmost prehistoric Indo-European-related expansion, ancestor of Tocharian-speakers.'),
  ('CARR_HIST_BRIDGE_OKUNEV', 'Okunev', 'population',
   -2500, -1800, ST_GeogFromText('SRID=4326;POINT(91.0 54.0)'),
   'Okunev', NULL,
   'Minusinsk-basin successor to Afanasievo with substantial Siberian admixture; distinctive carved-stone stelae.'),
  ('CARR_HIST_BRIDGE_BOTAI', 'Botai', 'population',
   -3700, -3100, ST_GeogFromText('SRID=4326;POINT(67.5 53.5)'),
   'Botai', NULL,
   'Northern-Kazakh culture associated with the earliest evidence of horse domestication and milking; contributed ancestry to later Central-Asian populations.'),
  ('CARR_HIST_BRIDGE_ANDRONOVO', 'Andronovo', 'population',
   -2000, -1200, ST_GeogFromText('SRID=4326;POINT(70.0 52.0)'),
   'Andronovo', NULL,
   'Bronze-age horizon across the Eurasian steppe; descended from Sintashta, ancestor of Indo-Iranian-speakers; chariot-and-horse warfare, mass copper/tin metallurgy.'),
  ('CARR_HIST_BRIDGE_KARASUK', 'Karasuk', 'population',
   -1500, -800, ST_GeogFromText('SRID=4326;POINT(91.0 53.5)'),
   'Karasuk', NULL,
   'Late-bronze-age south-Siberian successor to Andronovo; intensive bronze-casting, transitional to early-iron-age Tagar.'),
  ('CARR_HIST_BRIDGE_TAGAR', 'Tagar', 'population',
   -800, -200, ST_GeogFromText('SRID=4326;POINT(91.5 54.0)'),
   'Tagar', NULL,
   'Iron-age south-Siberian Scythian-related culture; massive bronze-and-gold animal-style art, kurgan burials.'),

  -- ── Mesoamerica 1521-1900 CE bridge ──
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'Colonial Mesoamerican (criollo / mestizo formation)', 'population',
   1521, 1900, ST_GeogFromText('SRID=4326;POINT(-99.1 19.4)'),
   'Colonial', 'Spanish + Nahuatl + Maya + …',
   'New-Spain populations during the colonial period: Spanish creoles, mestizos forming from Spanish-Mesoamerican intermixture, surviving indigenous nations, and the African-descended population brought via the Atlantic slave trade. Precursor to the modern Mexican mestizo population.'),

  -- ── Sub-Saharan / Saharan transitions ──
  ('CARR_HIST_BRIDGE_GARAMANTES', 'Garamantes', 'population',
   -500, 700, ST_GeogFromText('SRID=4326;POINT(13.5 26.5)'),
   'Garamantian', 'Berber-related',
   'Saharan kingdom in the Fezzan (modern SW Libya); foggara irrigation, trans-Saharan caravan trade, urban centers like Garama.'),
  ('CARR_HIST_BRIDGE_ZAGWE', 'Zagwe Ethiopia', 'population',
   900, 1270, ST_GeogFromText('SRID=4326;POINT(38.5 12.0)'),
   'Zagwe', 'Agaw / Geez',
   'Ethiopian highland Christian dynasty between Aksum''s decline and the Solomonic restoration; rock-hewn churches at Lalibela.');

-- Provenance claims linking to DEDUCED_PHASE_0.
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is a temporal-bridge carrier filling a gap that previously left ' ||
       'this region empty as the slider scrubbed across; ancestry summary ' ||
       'projected from contemporary neighbors, see DEDUCED_PHASE_0.',
       3
FROM carrier WHERE id LIKE 'CARR_HIST_BRIDGE_%';

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id LIKE 'CARR_HIST_BRIDGE_%';

-- Trait-mix entries (so cluster coloring + lineage BFS pick up these
-- carriers cleanly).
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- N America bridges: AMER_NA dominant.
  ('CARR_HIST_BRIDGE_LATE_WOODLAND', 'AMER_NA', 1.000, 800),
  ('CARR_HIST_BRIDGE_ANASAZI',       'AMER_NA', 1.000, 700),
  ('CARR_HIST_BRIDGE_HOHOKAM',       'AMER_NA', 1.000, 800),
  ('CARR_HIST_BRIDGE_FREMONT',       'AMER_NA', 1.000, 800),

  -- S America formative: AMER_NA dominant.
  ('CARR_HIST_BRIDGE_CUPISNIQUE',         'AMER_NA', 1.000, -1000),
  ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE',   'AMER_NA', 1.000, -500),
  ('CARR_HIST_BRIDGE_PARACAS',            'AMER_NA', 1.000, -300),

  -- Siberian steppe bronze-age: heavy ANE + EHG, Andronovo carries
  -- STEPPE_MLBA dominant (it's the type carrier for that ancestry).
  ('CARR_HIST_BRIDGE_AFANASIEVO',  'YAMNAYA',     0.700, -2900),
  ('CARR_HIST_BRIDGE_AFANASIEVO',  'EAST_ASIAN',  0.300, -2900),
  ('CARR_HIST_BRIDGE_OKUNEV',      'ANE',         0.500, -2200),
  ('CARR_HIST_BRIDGE_OKUNEV',      'EAST_ASIAN',  0.500, -2200),
  ('CARR_HIST_BRIDGE_BOTAI',       'ANE',         0.700, -3400),
  ('CARR_HIST_BRIDGE_BOTAI',       'EAST_ASIAN',  0.300, -3400),
  ('CARR_HIST_BRIDGE_ANDRONOVO',   'STEPPE_MLBA', 0.900, -1700),
  ('CARR_HIST_BRIDGE_ANDRONOVO',   'EAST_ASIAN',  0.100, -1700),
  ('CARR_HIST_BRIDGE_KARASUK',     'STEPPE_MLBA', 0.500, -1100),
  ('CARR_HIST_BRIDGE_KARASUK',     'EAST_ASIAN',  0.500, -1100),
  ('CARR_HIST_BRIDGE_TAGAR',       'STEPPE_MLBA', 0.500, -500),
  ('CARR_HIST_BRIDGE_TAGAR',       'EAST_ASIAN',  0.500, -500),

  -- Colonial Mesoamerica: mixed Spanish (ANATOLIAN_FARMER + STEPPE_MLBA)
  -- + Nahua (AMER_NA) + small AFR_WEST.
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'AMER_NA',          0.450, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'ANATOLIAN_FARMER', 0.250, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'STEPPE_MLBA',      0.150, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'AFR_WEST',         0.100, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'WHG',              0.030, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO', 'NEANDERTHAL',      0.020, 1700),

  -- Garamantes: Saharan Berber descendants — NATUFIAN + AFR_BASAL.
  ('CARR_HIST_BRIDGE_GARAMANTES',  'NATUFIAN',  0.500, 100),
  ('CARR_HIST_BRIDGE_GARAMANTES',  'AFR_BASAL', 0.500, 100),

  -- Zagwe Ethiopia: AFR_BASAL + NATUFIAN like the broader Ethiopian
  -- highland population.
  ('CARR_HIST_BRIDGE_ZAGWE',       'AFR_BASAL', 0.600, 1100),
  ('CARR_HIST_BRIDGE_ZAGWE',       'NATUFIAN',  0.400, 1100)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE]%';
