-- 010_seed_holocene_carriers.sql
--
-- Fills the early-to-mid-Holocene coverage gap in the carrier set. Without
-- these, scrubbing the slider through ~-7000 to -2000 shows only Australian
-- Aboriginals + Papuans + Andamanese + Jomon + Hoabinhian — i.e. only
-- Asia / Oceania, leaving the rest of the world conspicuously empty.
--
-- New carriers cover:
--   * Mesopotamia / Levant — Hassuna, Halaf, Ubaid, Uruk-pre-state
--   * Egypt / N Africa — Predynastic, Saharan pastoralists, Capsian
--   * Europe — Cucuteni-Trypillia, Funnelbeaker (TRB), Cardial Mediterranean,
--     Vinča, Megalithic Atlantic
--   * Steppe / S Asia — Mehrgarh (pre-Harappan)
--   * E Asia — Yangshao, Hongshan, Liangzhu, Longshan
--   * Americas — Archaic North America, Norte Chico, Olmec, Pre-Classic Maya,
--     Adena/Hopewell, Chavín, Eastern Woodlands Archaic
--   * Sub-Saharan Africa — pan-LSA placeholder, Nok, C-Group Nubian
--
-- Idempotent: DELETE keyed on the CARR_HIST_* prefix shared with 005.
-- Specific IDs added here use a CARR_HIST_HOL_* sub-prefix so they're
-- visible at a glance in the table.

DELETE FROM carrier WHERE id LIKE 'CARR_HIST_HOL_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- ---- Mesopotamia / Levant ----
  ('CARR_HIST_HOL_HASSUNA', 'Hassuna culture', 'population',
   -7000, -6000, ST_GeogFromText('SRID=4326;POINT(43.0 35.5)'),
   'Hassuna', NULL,
   'Northern Mesopotamian early Neolithic; pottery + irrigation agriculture.'),
  ('CARR_HIST_HOL_HALAF', 'Halaf culture', 'population',
   -6100, -5100, ST_GeogFromText('SRID=4326;POINT(40.0 36.5)'),
   'Halaf', NULL,
   'Upper Mesopotamia / N Syria pottery Neolithic; distinctive painted ceramics, copper smelting.'),
  ('CARR_HIST_HOL_UBAID', 'Ubaid culture', 'population',
   -5500, -3700, ST_GeogFromText('SRID=4326;POINT(45.5 31.0)'),
   'Ubaid', NULL,
   'Southern Mesopotamian Chalcolithic; first temple platforms (Eridu) and proto-urban settlements; ancestor of Sumer.'),
  ('CARR_HIST_HOL_URUK_PRESTATE', 'Uruk-period (pre-Sumer)', 'population',
   -4000, -3100, ST_GeogFromText('SRID=4326;POINT(45.6 31.3)'),
   'Uruk', NULL,
   'Late Chalcolithic Mesopotamia; emergence of cities, proto-cuneiform writing, mass-produced beveled-rim bowls. Transitions into the Sumerian Early Dynastic.'),
  ('CARR_HIST_HOL_LEVANT_PN', 'Levantine Pottery Neolithic', 'population',
   -6400, -4500, ST_GeogFromText('SRID=4326;POINT(35.5 32.0)'),
   'Yarmukian / Lodian / Wadi Rabah', NULL,
   'Pottery Neolithic of the southern Levant; sedentary villages, herd animal husbandry, before the Chalcolithic.'),

  -- ---- Egypt / N Africa ----
  ('CARR_HIST_HOL_CAPSIAN', 'Capsian (Maghreb)', 'population',
   -10000, -6000, ST_GeogFromText('SRID=4326;POINT(8.5 35.0)'),
   'Capsian', NULL,
   'Maghrebi Mesolithic; microlithic foragers across Tunisia/Algeria/Libya, ancestor population of the Berber lineage.'),
  ('CARR_HIST_HOL_SAHARAN_PASTORAL', 'Green Sahara pastoralists', 'population',
   -7500, -3500, ST_GeogFromText('SRID=4326;POINT(10.0 22.0)'),
   'Saharan Neolithic', NULL,
   'African Humid Period pastoralists across the once-vegetated Sahara; cattle herding, rock art (Tassili n''Ajjer). Disperse south as the Sahara dries.'),
  ('CARR_HIST_HOL_PREDYNASTIC_EGYPT', 'Predynastic Egyptians', 'population',
   -5500, -3100, ST_GeogFromText('SRID=4326;POINT(31.5 27.0)'),
   'Badarian / Naqada I-III', NULL,
   'Pre-pharaonic Egyptian Nile Valley cultures (Badari, Naqada, Maadi); state formation culminating in unification ~-3100 under Narmer.'),
  ('CARR_HIST_HOL_C_GROUP_NUBIAN', 'C-Group Nubians', 'population',
   -2400, -1550, ST_GeogFromText('SRID=4326;POINT(31.0 22.0)'),
   'C-Group / Pan-Grave', NULL,
   'Lower Nubian pastoralist population between the Old Kingdom and New Kingdom Egypt periods; absorbed into Kerma and later Egyptian rule.'),
  ('CARR_HIST_HOL_NOK', 'Nok culture (W Africa)', 'population',
   -1500, 500, ST_GeogFromText('SRID=4326;POINT(8.0 9.5)'),
   'Nok', NULL,
   'Earliest known iron-working complex society in Sub-Saharan Africa (Nigeria); famous terracotta sculptures.'),
  ('CARR_HIST_HOL_KINTAMPO', 'Kintampo culture (Sahel)', 'population',
   -2000, -1400, ST_GeogFromText('SRID=4326;POINT(-1.0 8.0)'),
   'Kintampo', NULL,
   'West African Late Stone Age agropastoralists in modern Ghana; introduced cereal cultivation and iron south of the Sahara.'),

  -- ---- Europe ----
  ('CARR_HIST_HOL_CARDIAL', 'Cardial / Impressa (Mediterranean Neolithic)', 'population',
   -6400, -4500, ST_GeogFromText('SRID=4326;POINT(8.0 42.0)'),
   'Cardial Ware / Impressa', NULL,
   'Western Mediterranean early Neolithic; Anatolian-derived farmers spreading by sea-route along the N Mediterranean coast.'),
  ('CARR_HIST_HOL_VINCA', 'Vinča culture (Balkans)', 'population',
   -5700, -4500, ST_GeogFromText('SRID=4326;POINT(20.5 44.5)'),
   'Vinča', NULL,
   'Late Neolithic Balkans; large tell-villages, copper metallurgy, the Vinča symbols (sometimes claimed as proto-writing).'),
  ('CARR_HIST_HOL_CUCUTENI_TRYP', 'Cucuteni-Trypillia', 'population',
   -5500, -2750, ST_GeogFromText('SRID=4326;POINT(28.0 48.0)'),
   'Cucuteni-Trypillia', NULL,
   'Eastern European Chalcolithic; large planned megasites in modern Ukraine/Romania/Moldova, ritual house-burning, mass painted ceramics.'),
  ('CARR_HIST_HOL_FUNNELBEAKER', 'Funnelbeaker (TRB)', 'population',
   -4300, -2800, ST_GeogFromText('SRID=4326;POINT(11.0 54.0)'),
   'Funnelbeaker / TRB', NULL,
   'Northern European Neolithic; megalithic tombs, expansion of farming into the N European Plain.'),
  ('CARR_HIST_HOL_MEGALITHIC_ATL', 'Atlantic Megalithic builders', 'population',
   -4500, -2000, ST_GeogFromText('SRID=4326;POINT(-3.0 50.0)'),
   'Megalithic / Beaker antecedents', NULL,
   'Atlantic-facade Neolithic populations who built passage tombs and stone circles from Iberia to Britain (Carnac, Newgrange, Stonehenge).'),

  -- ---- South Asia ----
  ('CARR_HIST_HOL_MEHRGARH', 'Mehrgarh (pre-Harappan)', 'population',
   -7000, -2500, ST_GeogFromText('SRID=4326;POINT(67.0 29.4)'),
   'Mehrgarh', NULL,
   'Earliest known farming village in the Indian subcontinent (Balochistan); cattle/goat husbandry, dental drilling, ancestor population of the Indus Valley civilization.'),

  -- ---- East Asia ----
  ('CARR_HIST_HOL_YANGSHAO', 'Yangshao (Yellow River Neolithic)', 'population',
   -5000, -3000, ST_GeogFromText('SRID=4326;POINT(110.0 35.0)'),
   'Yangshao', NULL,
   'Middle Yellow River millet farmers; painted pottery, large villages (Banpo), nucleus of later northern East Asian agricultural expansion.'),
  ('CARR_HIST_HOL_HONGSHAN', 'Hongshan (NE China)', 'population',
   -4700, -2900, ST_GeogFromText('SRID=4326;POINT(120.0 42.0)'),
   'Hongshan', NULL,
   'Northeastern Chinese / Inner Mongolian Neolithic; jade carving, goddess temple at Niuheliang.'),
  ('CARR_HIST_HOL_LIANGZHU', 'Liangzhu (Yangtze rice culture)', 'population',
   -3300, -2300, ST_GeogFromText('SRID=4326;POINT(120.0 30.0)'),
   'Liangzhu', NULL,
   'Lower-Yangtze rice-farming culture; large urban hydraulic settlements, jade ritual objects.'),
  ('CARR_HIST_HOL_LONGSHAN', 'Longshan culture', 'population',
   -3000, -1900, ST_GeogFromText('SRID=4326;POINT(116.0 36.0)'),
   'Longshan', NULL,
   'Late Neolithic Yellow River; black eggshell pottery, walled towns, immediate antecedent of the Erlitou / Shang horizon.'),
  ('CARR_HIST_HOL_HEMUDU', 'Hemudu', 'population',
   -5000, -3300, ST_GeogFromText('SRID=4326;POINT(121.0 30.0)'),
   'Hemudu', NULL,
   'Lower-Yangtze early rice-farming culture; pile dwellings, lacquerwork, predates Liangzhu.'),

  -- ---- Americas ----
  ('CARR_HIST_HOL_ARCHAIC_NA', 'Archaic Period North Americans', 'population',
   -8000, -1000, ST_GeogFromText('SRID=4326;POINT(-95.0 39.0)'),
   'Archaic', NULL,
   'Holocene foragers and incipient horticulturalists across N America after the Paleo-Indian period; broad-spectrum subsistence, regional adaptations to oak forests, plains, deserts, coasts.'),
  ('CARR_HIST_HOL_EASTERN_WOODLAND_ARCH', 'Eastern Woodlands Late Archaic', 'population',
   -3500, -1000, ST_GeogFromText('SRID=4326;POINT(-87.0 36.0)'),
   'Late Archaic / Poverty Point', NULL,
   'Pre-Adena eastern North American populations; mound-building begins (Watson Brake, Poverty Point), early cultivation of indigenous starchy plants.'),
  ('CARR_HIST_HOL_NORTE_CHICO', 'Norte Chico / Caral', 'population',
   -3500, -1800, ST_GeogFromText('SRID=4326;POINT(-77.5 -10.5)'),
   'Norte Chico', NULL,
   'Coastal Peru pre-pottery civilization centered on Caral; monumental architecture, irrigated agriculture, contemporary with Old Kingdom Egypt.'),
  ('CARR_HIST_HOL_OLMEC', 'Olmec', 'population',
   -1500, -400, ST_GeogFromText('SRID=4326;POINT(-94.5 17.5)'),
   'Olmec', NULL,
   'Mesoamerican Gulf Coast civilization; colossal stone heads, San Lorenzo and La Venta centers, ancestor culture for Maya / Zapotec / Aztec ritual systems.'),
  ('CARR_HIST_HOL_PRECLASSIC_MAYA', 'Pre-Classic Maya', 'population',
   -2000, 250, ST_GeogFromText('SRID=4326;POINT(-90.0 17.0)'),
   'Pre-Classic Maya', NULL,
   'Maya region from initial sedentism through the rise of large centers (El Mirador, Nakbé) — bridges the gap between Olmec and Classic Maya.'),
  ('CARR_HIST_HOL_CHAVIN', 'Chavín', 'population',
   -900, -200, ST_GeogFromText('SRID=4326;POINT(-77.2 -9.6)'),
   'Chavín', NULL,
   'Andean Early Horizon civilization centered on Chavín de Huántar; widespread iconographic influence across pre-Inca Peru.'),
  ('CARR_HIST_HOL_ADENA', 'Adena', 'population',
   -1000, 200, ST_GeogFromText('SRID=4326;POINT(-82.0 39.5)'),
   'Adena', NULL,
   'Ohio Valley mound-building culture; conical burial mounds, earthworks; predates Hopewell.'),
  ('CARR_HIST_HOL_HOPEWELL', 'Hopewell', 'population',
   -200, 500, ST_GeogFromText('SRID=4326;POINT(-83.0 39.5)'),
   'Hopewell', NULL,
   'Eastern Woodlands ceremonial-and-trade network; geometric earthworks, copper / mica / obsidian goods exchanged across half the continent.'),

  -- ---- Sub-Saharan Africa Late Stone Age (broad placeholder) ----
  ('CARR_HIST_HOL_SS_AFR_LSA', 'Sub-Saharan Late Stone Age', 'population',
   -10000, -2000, ST_GeogFromText('SRID=4326;POINT(25.0 0.0)'),
   'Late Stone Age', NULL,
   'Pan-Sub-Saharan foragers and early herders prior to the Bantu expansion; microlithic toolkits, regional adaptations to forest / savanna / lake-shore environments.'),

  -- ---- Australia/Pacific Holocene continuation handled by AUS_ABORIGINAL/PAPUAN/ANDAMANESE ----
  -- (already span the Holocene)

  -- ---- Anatolian late Neolithic / Chalcolithic ----
  ('CARR_HIST_HOL_ANATOLIA_LATE_NEO', 'Anatolian Late Neolithic / Chalcolithic', 'population',
   -6000, -3500, ST_GeogFromText('SRID=4326;POINT(33.5 38.5)'),
   'Late Neolithic / Chalcolithic', NULL,
   'Anatolian populations between the Çatalhöyük heyday and the Hittite emergence; copper metallurgy, walled tells, Indo-European substrate uncertain.');
