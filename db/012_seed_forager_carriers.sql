-- 012_seed_forager_carriers.sql
--
-- Fills regional Mesolithic / Pre-Pottery-Neolithic / Archaic-period gaps
-- in the carrier set. Without these, a screenshot at e.g. 11 kya across
-- Eurasia + Africa shows only ~6 dots — accurate for our seed but a poor
-- representation of where humans actually lived.
--
-- These are forager and aceramic-Neolithic populations that mostly didn't
-- leave the kind of state-level historical record we have for later periods,
-- but DID leave site clusters and ancient DNA evidence. Coverage:
--
--   Near East Pre-Pottery Neolithic
--     Levantine PPN-A, PPN-B; Anatolian Aceramic Neolithic; Zagros aceramic;
--     Cyprus Aceramic
--   European Mesolithic regional groups
--     Iberian, Italian, Sauveterrian, Maglemosian, Sami / Saami ancestral,
--     Karelian / Veretye
--   Asian foragers
--     Pre-Mehrgarh South Asian Mesolithic; Tibetan Plateau foragers;
--     Siberian Forest foragers; Pengtoushan early Yangtze; Korean Chulmun
--   American Archaic / pre-Maya / pre-Inca
--     Western Archaic, Eastern Archaic, Mesoamerican Archaic, Andean
--     Archaic, Chinchorro, Amazonian foragers, Pacific Northwest foragers,
--     Arctic Saqqaq / Pre-Dorset
--   Africa
--     East African Mesolithic foragers (separate from broad SS_AFR_LSA),
--     Khoisan continuity (closes the 50k-year gap between
--     KHOE_SAN_ANCESTRAL and KHOISAN_MODERN)
--
-- Idempotent: DELETE keyed on the CARR_HIST_FOR_* sub-prefix.

DELETE FROM carrier WHERE id LIKE 'CARR_HIST_FOR_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- ---- Near East Pre-Pottery Neolithic ----
  ('CARR_HIST_FOR_LEVANT_PPNA', 'Pre-Pottery Neolithic A (Levant)', 'population',
   -9700, -8500, ST_GeogFromText('SRID=4326;POINT(35.5 31.9)'),
   'PPN-A (Sultanian / Khiamian)', NULL,
   'Earliest Neolithic Levant — Jericho-tower phase, sedentary villages with proto-agriculture before the full domestication package.'),
  ('CARR_HIST_FOR_LEVANT_PPNB', 'Pre-Pottery Neolithic B (Levant)', 'population',
   -8500, -6900, ST_GeogFromText('SRID=4326;POINT(36.0 33.0)'),
   'PPN-B', NULL,
   'Domestication completes (cereals + sheep/goat/cattle); plastered skull cult, large villages (Ain Ghazal), expansion into the Anatolian and Zagros uplands.'),
  ('CARR_HIST_FOR_GOBEKLI', 'Göbekli Tepe / Upper Mesopotamian PPN', 'population',
   -9500, -8000, ST_GeogFromText('SRID=4326;POINT(38.9 37.2)'),
   'PPN (Göbekli horizon)', NULL,
   'Pre-agricultural ceremonial-architecture builders of SE Anatolia / N Mesopotamia; Göbekli Tepe T-pillars predate full domestication.'),
  ('CARR_HIST_FOR_ANATOLIAN_ACERAMIC', 'Anatolian Aceramic Neolithic', 'population',
   -9000, -7000, ST_GeogFromText('SRID=4326;POINT(33.0 38.0)'),
   'Aşıklı / Boncuklu / pre-Çatalhöyük', NULL,
   'Pre-pottery agropastoralists on the central Anatolian plateau, ancestor population of the Çatalhöyük / Anatolian Neolithic Farmer phase.'),
  ('CARR_HIST_FOR_ZAGROS_ACERAMIC', 'Zagros aceramic Neolithic', 'population',
   -9500, -7500, ST_GeogFromText('SRID=4326;POINT(46.5 35.0)'),
   'Ganj Dareh / Asiab', NULL,
   'Aceramic Neolithic Iran (Ganj Dareh, Asiab); goat-herding origin, ancestor of the Iranian Neolithic farmers.'),
  ('CARR_HIST_FOR_CYPRUS_ACERAMIC', 'Cyprus Aceramic Neolithic', 'population',
   -9000, -7000, ST_GeogFromText('SRID=4326;POINT(33.0 35.0)'),
   'Khirokitia / Aceramic', NULL,
   'Earliest seafaring colonists of Cyprus, bringing the Levantine PPN-B package across open water.'),

  -- ---- European Mesolithic regional groups ----
  ('CARR_HIST_FOR_IBERIA_MESO', 'Iberian Mesolithic foragers', 'population',
   -10000, -5500, ST_GeogFromText('SRID=4326;POINT(-4.0 39.0)'),
   'Asturian / Muge', NULL,
   'Iberian peninsula post-glacial foragers; coastal shell-midden sites at Muge, riverine settlements.'),
  ('CARR_HIST_FOR_ITALY_MESO', 'Italian Mesolithic foragers', 'population',
   -10000, -6000, ST_GeogFromText('SRID=4326;POINT(13.0 43.0)'),
   'Sauveterrian / Castelnovian', NULL,
   'Apennine and northern Italian Mesolithic; microlithic toolkits, Alpine-piedmont upland adaptations.'),
  ('CARR_HIST_FOR_MAGLEMOSE', 'Maglemosian (S Scandinavia / N Germany)', 'population',
   -9000, -6000, ST_GeogFromText('SRID=4326;POINT(11.0 56.0)'),
   'Maglemosian', NULL,
   'Earliest Mesolithic of southern Scandinavia and the North European plain; barbed bone points, microlithic flint, lakeshore camps.'),
  ('CARR_HIST_FOR_KARELIAN_MESO', 'Karelian / Veretye Mesolithic', 'population',
   -10000, -6000, ST_GeogFromText('SRID=4326;POINT(34.0 62.0)'),
   'Veretye / Butovo', NULL,
   'NW Russian forest-zone Mesolithic foragers; ancestor population for later EHG and the Sami lineage.'),
  ('CARR_HIST_FOR_SAAMI_ANCESTRAL', 'Sami / Saami ancestral lineage', 'population',
   -8000, 1500, ST_GeogFromText('SRID=4326;POINT(22.0 68.0)'),
   NULL, 'Pre-Saami / Saami',
   'Northern Fennoscandian forager-then-reindeer-pastoralist lineage; partial replacement / displacement by southern agriculturalists in the late Holocene.'),

  -- ---- Asian foragers ----
  ('CARR_HIST_FOR_S_ASIAN_MESO', 'South Asian Mesolithic foragers', 'population',
   -10000, -3000, ST_GeogFromText('SRID=4326;POINT(78.0 22.0)'),
   'Bhimbetka / Sarai Nahar Rai', NULL,
   'Indian-subcontinent Mesolithic foragers (Bhimbetka rock shelters, Vindhyan and Gangetic sites); deep ASI-related ancestry, ancestor population for later Indus-period substrates.'),
  ('CARR_HIST_FOR_TIBETAN_FORAGERS', 'Tibetan Plateau early foragers', 'population',
   -30000, -3000, ST_GeogFromText('SRID=4326;POINT(91.0 29.0)'),
   'Chusang / Tashitik', NULL,
   'High-altitude foragers of the Tibetan Plateau; deep East Asian ancestry plus Denisovan-derived high-altitude adaptation alleles (EPAS1).'),
  ('CARR_HIST_FOR_SIBERIAN_FOREST', 'Siberian forest-zone foragers', 'population',
   -15000, -3000, ST_GeogFromText('SRID=4326;POINT(95.0 60.0)'),
   NULL, NULL,
   'Post-glacial taiga foragers across central Siberia (Kitoi, Glazkovo cultural sequence at Lake Baikal); Ancient North Eurasian + East Asian ancestry mix.'),
  ('CARR_HIST_FOR_PENGTOUSHAN', 'Pengtoushan / early Yangtze rice', 'population',
   -7500, -6000, ST_GeogFromText('SRID=4326;POINT(112.0 30.0)'),
   'Pengtoushan', NULL,
   'Earliest rice-cultivating villages in the middle Yangtze; predates Hemudu and Liangzhu.'),
  ('CARR_HIST_FOR_KOREA_CHULMUN', 'Chulmun pottery period (Korea)', 'population',
   -8000, -1500, ST_GeogFromText('SRID=4326;POINT(127.0 37.0)'),
   'Chulmun', NULL,
   'Korean Neolithic pottery foragers / early agriculturalists; comb-pattern pottery, gradual incorporation of millet farming from the north.'),
  ('CARR_HIST_FOR_NE_ASIAN_FORAGERS', 'NE Asian Mesolithic foragers', 'population',
   -12000, -4000, ST_GeogFromText('SRID=4326;POINT(135.0 50.0)'),
   'Amur / Primorye Mesolithic', NULL,
   'Russian Far East / Amur basin foragers; ancestor populations for later Tungusic / Nivkh / NE Asian groups.'),

  -- ---- American Archaic + pre-state populations ----
  ('CARR_HIST_FOR_WESTERN_ARCHAIC', 'Western Archaic Americans', 'population',
   -8000, -1000, ST_GeogFromText('SRID=4326;POINT(-115.0 40.0)'),
   'Desert Archaic', NULL,
   'Holocene foragers of the Great Basin and intermontane West; pinyon / yucca / small-game economies, basketry traditions.'),
  ('CARR_HIST_FOR_PACIFIC_NW_FORAGERS', 'Pacific NW foragers', 'population',
   -8000, 1, ST_GeogFromText('SRID=4326;POINT(-125.0 50.0)'),
   NULL, NULL,
   'Coastal foragers of the Pacific Northwest; salmon-runs and cedar-based economies, ancestral to later Tlingit / Haida / Coast Salish.'),
  ('CARR_HIST_FOR_MESOAMER_ARCHAIC', 'Mesoamerican Archaic', 'population',
   -8000, -2000, ST_GeogFromText('SRID=4326;POINT(-98.0 18.0)'),
   'Coxcatlán / Tehuacán Archaic', NULL,
   'Pre-ceramic Mesoamerican foragers experimenting with maize, beans, squash domestication (Tehuacán Valley); ancestor of the Olmec / Maya horizon.'),
  ('CARR_HIST_FOR_ANDEAN_ARCHAIC', 'Andean Archaic foragers', 'population',
   -10000, -3500, ST_GeogFromText('SRID=4326;POINT(-72.0 -13.0)'),
   'Lauricocha / Asana', NULL,
   'High-altitude Andean foragers experimenting with quinoa / camelid domestication; predates the Norte Chico monumental phase.'),
  ('CARR_HIST_FOR_CHINCHORRO', 'Chinchorro (Atacama coast)', 'population',
   -7000, -1500, ST_GeogFromText('SRID=4326;POINT(-70.3 -18.5)'),
   'Chinchorro', NULL,
   'Coastal Atacama-desert foragers; produced the world''s oldest deliberately mummified human remains.'),
  ('CARR_HIST_FOR_AMAZON_FORAGERS', 'Amazonian foragers / early horticulturalists', 'population',
   -10000, 500, ST_GeogFromText('SRID=4326;POINT(-60.0 -5.0)'),
   NULL, NULL,
   'Pan-Amazonian forager-horticulturalist populations; ancestral to later mound-builders and the Marajoara / Tapajós complexes.'),
  ('CARR_HIST_FOR_SAQQAQ', 'Saqqaq / Pre-Dorset (Arctic)', 'population',
   -2500, -1, ST_GeogFromText('SRID=4326;POINT(-50.0 70.0)'),
   'Saqqaq / Pre-Dorset', NULL,
   'Earliest known Greenland / Eastern-Arctic population; Paleo-Eskimo lineage, distinct from later Thule / Inuit ancestors.'),

  -- ---- Africa Mesolithic / Late Stone Age detail ----
  ('CARR_HIST_FOR_E_AFR_MESO', 'East African Late Stone Age foragers', 'population',
   -15000, -3000, ST_GeogFromText('SRID=4326;POINT(36.0 0.0)'),
   'Eburran / Kansyore', NULL,
   'East African Rift Late Stone Age foragers — separate from the broad pan-Sub-Saharan LSA carrier; Kansyore pottery, Eburran microlithic toolkits.'),
  ('CARR_HIST_FOR_KHOISAN_HOL', 'Khoisan continuity (Holocene)', 'population',
   -50000, 1900, ST_GeogFromText('SRID=4326;POINT(22.0 -28.0)'),
   NULL, 'Khoe / San (Tuu / Kx''a)',
   'Continuous Khoisan-speaking forager-and-pastoralist lineage in southern Africa, bridging the gap between the early-divergence ancestral Khoe-San lineage and the modern Khoisan carrier.'),
  ('CARR_HIST_FOR_HORN_AFR_PASTORAL', 'Horn-of-Africa pastoralists', 'population',
   -3000, 500, ST_GeogFromText('SRID=4326;POINT(40.0 7.0)'),
   'Pastoral Neolithic', NULL,
   'Cushitic-speaking pastoralists spreading south through the Horn of Africa and into east Africa with cattle, sheep, goats; ancestor populations for modern Cushitic groups.'),

  -- ---- Steppe + Northern + Caucasian additional ----
  ('CARR_HIST_FOR_LEPENSKI_VIR', 'Lepenski Vir (Iron Gates Mesolithic)', 'population',
   -9500, -5500, ST_GeogFromText('SRID=4326;POINT(22.3 44.6)'),
   'Iron Gates Mesolithic', NULL,
   'Riverine Mesolithic foragers of the Iron Gates gorge; iconic stone-head sculptures, salmon-and-beluga riverine economy.'),
  ('CARR_HIST_FOR_KEBARAN', 'Kebaran (Levant Late Pleistocene)', 'population',
   -23000, -16500, ST_GeogFromText('SRID=4326;POINT(35.0 32.0)'),
   'Kebaran', NULL,
   'Late-Pleistocene Levantine microlithic foragers; immediate ancestor of the Natufian.'),
  ('CARR_HIST_FOR_OASIS_GREATER_CASPIAN', 'Caspian / Hyrcanian Mesolithic', 'population',
   -10000, -6000, ST_GeogFromText('SRID=4326;POINT(53.0 37.0)'),
   'Hotu / Belt Cave', NULL,
   'Caspian-shore foragers (Hotu / Belt cave sequence in N Iran); ancestor populations for the Iranian Neolithic / CHG-related branch.');
