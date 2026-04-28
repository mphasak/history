-- 007_carrier_threats.sql
--
-- Carrier-threat model: for each population we record the major threats
-- they faced (climate, war, disease, etc.), with a year window and a
-- supporting claim that cites a source. Renders in the DetailPanel as
-- a "Threats faced" section under the trait mix.
--
-- Modeled as a sibling table rather than extending the carrier row so
-- multiple threats can coexist with their own time windows and severities.
-- Idempotent: DELETE keyed on carrier_id IN (CARR_HIST_*, CARR_HOMININ_*,
-- and the spreadsheet-seeded carriers we annotate below) plus claim_id
-- in the seeded set.

-- ---------------------------------------------------------------------------
-- Schema additions (additive; does not touch 001_schema.sql)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'threat_type') THEN
    CREATE TYPE threat_type AS ENUM (
      'climate',           -- glacial cooling, drought, monsoon failure, sea-level rise
      'disease',           -- epidemics, novel pathogens (smallpox, Black Death)
      'war',               -- inter-state warfare, conquest
      'raids',             -- raiding by neighbors, piracy
      'displacement',      -- migration, exile, ethnic cleansing
      'resource_scarcity', -- food / water / fuel limits
      'resource_competition', -- competition with another group for the same resources
      'megafauna_loss',    -- collapse of game animals (mammoth steppe, etc.)
      'natural_disaster',  -- volcanism, earthquake, flood
      'colonization',      -- external state takeover (e.g. European colonization)
      'genocide',          -- deliberate destruction of the group
      'assimilation_pressure', -- cultural / linguistic erasure short of genocide
      'other'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS carrier_threat (
  id              BIGSERIAL PRIMARY KEY,
  carrier_id      TEXT NOT NULL REFERENCES carrier(id) ON DELETE CASCADE,
  threat_type     threat_type NOT NULL,
  display_name    TEXT NOT NULL,
  description     TEXT,
  -- Severity 1-5: 1 = stressor, 5 = existential / extinction-level.
  severity        SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  date_min_year   INTEGER NOT NULL,
  date_max_year   INTEGER NOT NULL,
  -- Foreign key to a claim row (optional). When present, gives the
  -- DetailPanel a citation to attach.
  claim_id        BIGINT REFERENCES claim(id) ON DELETE SET NULL,
  CHECK (date_min_year <= date_max_year)
);

CREATE INDEX IF NOT EXISTS idx_carrier_threat_carrier_dates
  ON carrier_threat (carrier_id, date_min_year, date_max_year);

-- ---------------------------------------------------------------------------
-- Idempotency: clear seeded threats and the claims they cite, then re-insert.
-- ---------------------------------------------------------------------------

DELETE FROM carrier_threat
WHERE carrier_id LIKE 'CARR_HIST_%'
   OR carrier_id LIKE 'CARR_HOMININ_%'
   OR carrier_id LIKE 'CARR_OOA_%'
   OR carrier_id LIKE 'CARR_PAPUAN_%'
   OR carrier_id LIKE 'CARR_AUS_%'
   OR carrier_id LIKE 'CARR_HARAPPAN'
   OR carrier_id LIKE 'CARR_NW_SOUTH_ASIA%'
   OR carrier_id LIKE 'CARR_AURIGNACIAN_%'
   OR carrier_id LIKE 'CARR_GRAVETTIAN_%'
   OR carrier_id LIKE 'CARR_MALTA_%'
   OR carrier_id LIKE 'CARR_PALEO_AMER_%'
   OR carrier_id LIKE 'CARR_NATUFIAN_%'
   OR carrier_id LIKE 'CARR_WHG_%'
   OR carrier_id LIKE 'CARR_EHG_%'
   OR carrier_id LIKE 'CARR_CHG_%'
   OR carrier_id LIKE 'CARR_JOMON'
   OR carrier_id LIKE 'CARR_ANATOLIAN_%'
   OR carrier_id LIKE 'CARR_IRAN_NEOLITHIC'
   OR carrier_id LIKE 'CARR_LBK_%'
   OR carrier_id LIKE 'CARR_YAMNAYA'
   OR carrier_id LIKE 'CARR_BANTU_%'
   OR carrier_id LIKE 'CARR_CORDED_%'
   OR carrier_id LIKE 'CARR_BELL_%'
   OR carrier_id LIKE 'CARR_TIANYUAN_%'
   OR carrier_id LIKE 'CARR_SF_%'
   OR carrier_id LIKE 'CARR_RURAL_%';

DELETE FROM claim
WHERE statement LIKE '[AUTO-THREAT]%';

-- Helper that inserts one threat row + its supporting claim/sources atomically.
CREATE OR REPLACE FUNCTION _seed_threat(
  carrier_id TEXT,
  threat_type threat_type,
  display_name TEXT,
  description TEXT,
  severity SMALLINT,
  date_min_year INTEGER,
  date_max_year INTEGER,
  source_ids TEXT[]
) RETURNS BIGINT AS $$
DECLARE
  new_claim_id BIGINT;
  new_threat_id BIGINT;
  i INTEGER;
BEGIN
  INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
  VALUES ('Carrier', carrier_id, '[AUTO-THREAT] ' || display_name || ' — ' || description, 3)
  RETURNING id INTO new_claim_id;

  IF source_ids IS NOT NULL THEN
    FOR i IN 1..array_length(source_ids, 1) LOOP
      INSERT INTO claim_source (claim_id, source_id, stance)
      VALUES (new_claim_id, source_ids[i], 'supports');
    END LOOP;
  END IF;

  INSERT INTO carrier_threat
    (carrier_id, threat_type, display_name, description, severity,
     date_min_year, date_max_year, claim_id)
  VALUES
    (carrier_id, threat_type, display_name, description, severity,
     date_min_year, date_max_year, new_claim_id)
  RETURNING id INTO new_threat_id;

  RETURN new_threat_id;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Seeded threats — broad-stroke, illustrative, and citing literature where
-- a clean source exists. Severity is editorial.
-- ---------------------------------------------------------------------------

-- Pleistocene / Upper Paleolithic ------------------------------------------

SELECT _seed_threat('CARR_OOA_LEVANT_55K', 'climate', 'MIS-3 Levantine aridity',
  'Periodic drying and cooling cycles in the Levant compressing the OOA source population through population bottlenecks.',
  3::smallint, -60000, -45000, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_OOA_LEVANT_55K', 'megafauna_loss', 'Late Pleistocene fauna decline',
  'Gradual loss of large herbivores in the Levant restricting hunting returns.',
  2::smallint, -60000, -45000, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_AURIGNACIAN_EU', 'climate', 'Heinrich event cooling',
  'Repeated Heinrich-event cold spells across the early Upper Paleolithic.',
  4::smallint, -42000, -28000, ARRAY['CLARK_2009','DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_AURIGNACIAN_EU', 'resource_competition', 'Neanderthal contemporaries',
  'Coexistence and competition with Neanderthal populations until the latter''s ~-40 ka extinction.',
  3::smallint, -42000, -39000, ARRAY['REICH_CH2']::text[]);

SELECT _seed_threat('CARR_GRAVETTIAN_EU', 'climate', 'Approach of Last Glacial Maximum',
  'Progressive cooling toward the LGM compressing habitable European territory.',
  4::smallint, -33000, -22000, ARRAY['CLARK_2009']::text[]);

SELECT _seed_threat('CARR_MALTA_24K', 'climate', 'Last Glacial Maximum',
  'Peak glacial conditions on the Siberian steppe; severe cold and limited refugia.',
  5::smallint, -24000, -16000, ARRAY['CLARK_2009']::text[]);
SELECT _seed_threat('CARR_MALTA_24K', 'megafauna_loss', 'Mammoth steppe collapse',
  'Late Pleistocene decline of the mammoth-steppe ecosystem on which Mal''ta-Buret'' subsisted.',
  4::smallint, -16000, -12000, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_PALEO_AMER_15K', 'climate', 'Younger Dryas',
  'Abrupt return to glacial conditions ~12.9-11.7 kya disrupting recently-colonized American ecosystems.',
  4::smallint, -13000, -11700, ARRAY['CLARK_2009','DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_PALEO_AMER_15K', 'megafauna_loss', 'American megafauna extinction',
  'Late Pleistocene loss of mammoths, mastodons, ground sloths, and other megafauna in the Americas.',
  4::smallint, -14000, -10000, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_WHG_MESO', 'climate', 'Younger Dryas',
  'Cold reversal interrupting post-glacial recovery in western Europe.',
  3::smallint, -12900, -11700, ARRAY['CLARK_2009']::text[]);
SELECT _seed_threat('CARR_WHG_MESO', 'displacement', 'Anatolian farmer expansion',
  'Replacement / absorption by incoming Anatolian Neolithic farmers from ~-7000 onwards.',
  4::smallint, -7000, -5000, ARRAY['LAZARIDIS_2014','HAAK_2015']::text[]);

SELECT _seed_threat('CARR_EHG_MESO', 'displacement', 'Yamnaya / Steppe expansion',
  'Absorbed into the eastward Yamnaya horizon as the steppe pastoralist economy spread.',
  4::smallint, -3500, -2500, ARRAY['HAAK_2015','REICH_CH5']::text[]);

-- Holocene Neolithic / Bronze Age -------------------------------------------

SELECT _seed_threat('CARR_NATUFIAN_12K', 'climate', 'Younger Dryas drought',
  'Abrupt aridification triggering the transition to sedentism and pre-pottery agriculture.',
  4::smallint, -13000, -11700, ARRAY['CLARK_2009']::text[]);

SELECT _seed_threat('CARR_LBK_CENTRAL_EU', 'climate', '8.2 ka cooling event',
  'Centennial-scale cooling and aridification across Europe at ~-6200 disrupting early farming villages.',
  3::smallint, -6200, -6000, ARRAY['BOND_1997']::text[]);
SELECT _seed_threat('CARR_LBK_CENTRAL_EU', 'displacement', 'Steppe migration replacement',
  'Substantial replacement by Yamnaya-related populations from the Pontic-Caspian Steppe.',
  4::smallint, -3000, -2500, ARRAY['HAAK_2015']::text[]);

SELECT _seed_threat('CARR_HARAPPAN', 'climate', 'Late Holocene monsoon weakening',
  'Weakening of the Indian Summer Monsoon contributing to the Late Harappan urban decline.',
  4::smallint, -2200, -1900, ARRAY['DEMENOCAL_2000','DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HARAPPAN', 'displacement', 'Late-Bronze ruralization',
  'Urban depopulation and migration east into the Gangetic plain after ~-1900.',
  3::smallint, -1900, -1500, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Mesopotamia / Levant / Egypt ---------------------------------------------

SELECT _seed_threat('CARR_HIST_AKKADIAN', 'climate', '4.2 ka aridification event',
  'Abrupt aridification ~-2200 implicated in the Akkadian Empire''s collapse (Weiss 1993).',
  5::smallint, -2200, -2150, ARRAY['WEISS_1993']::text[]);

SELECT _seed_threat('CARR_HIST_BABYLONIAN', 'war', 'Hittite, Kassite, Assyrian conflicts',
  'Repeated invasion and conquest cycles through the second and first millennia BCE.',
  4::smallint, -1600, -540, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_ASSYRIAN', 'war', 'Inter-state warfare',
  'Persistent warfare with Mitanni, Elam, Babylon, Egypt; Assyrian collapse via Median + Babylonian alliance ~-612.',
  5::smallint, -1800, -609, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_HITTITE', 'war', 'Bronze Age Collapse',
  'Empire-level collapse at ~-1180 amid the broader Late Bronze Age systems collapse.',
  5::smallint, -1200, -1180, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_HITTITE', 'climate', 'Late Bronze Age megadrought',
  'Multi-decadal drought across the eastern Mediterranean contributing to the Bronze Age Collapse.',
  4::smallint, -1250, -1150, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_PHOENICIAN', 'war', 'Assyrian / Babylonian / Persian sieges',
  'Cycles of conquest by larger empires; Tyre famously besieged by Nebuchadnezzar II and later Alexander.',
  4::smallint, -700, -332, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_EGYPT_OK', 'climate', 'First Intermediate aridification',
  'Reduced Nile floods around -2200-2100 contributing to the Old Kingdom collapse.',
  5::smallint, -2200, -2050, ARRAY['DEMENOCAL_2000','WEISS_1993']::text[]);

SELECT _seed_threat('CARR_HIST_EGYPT_MK_NK', 'war', 'Hyksos invasion + Sea Peoples',
  'Hyksos occupation in the Second Intermediate (~-1650-1550) and Sea Peoples raids in the Bronze Age Collapse.',
  4::smallint, -1650, -1100, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_CARTHAGINIAN', 'war', 'Punic Wars',
  'Three wars with Rome culminating in Carthage''s destruction in -146.',
  5::smallint, -264, -146, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Mediterranean / Europe ----------------------------------------------------

SELECT _seed_threat('CARR_HIST_MYCENAEAN', 'war', 'Bronze Age Collapse',
  'Palace destruction layers at Pylos, Mycenae, Tiryns ~-1200-1100; possible Sea Peoples involvement.',
  5::smallint, -1200, -1100, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MYCENAEAN', 'climate', 'Late Bronze Age drought',
  'Multi-decadal eastern-Mediterranean drought reducing palace economy productivity.',
  3::smallint, -1250, -1150, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_GREEK_CLASSICAL', 'war', 'Persian + Peloponnesian + Macedonian',
  'Persian Wars (-499 to -449), Peloponnesian War (-431 to -404), Macedonian conquest under Philip and Alexander.',
  4::smallint, -500, -300, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_GREEK_CLASSICAL', 'disease', 'Plague of Athens',
  'Devastating epidemic during the Peloponnesian War (-430-426); killed ~25% of Athenians per Thucydides.',
  4::smallint, -430, -425, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_ROMAN', 'disease', 'Antonine + Cyprian plagues',
  'Antonine Plague (165-180 CE, likely smallpox) and Plague of Cyprian (249-262 CE).',
  4::smallint, 165, 270, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_ROMAN', 'war', 'Migration-Period invasions',
  'Goths, Vandals, Huns, Lombards over the 4th-6th centuries; sack of Rome in 410 and 455.',
  5::smallint, 250, 500, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_ROMAN', 'climate', 'Late-Antique Little Ice Age',
  'Cooling at ~536-660 CE attributed to volcanic forcing; agricultural stress in late Antiquity.',
  3::smallint, 535, 660, ARRAY['MANN_2009','DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_BYZANTINE', 'disease', 'Plague of Justinian',
  'First plague pandemic (Yersinia pestis) starting 541 CE; recurrent waves into the 8th century.',
  5::smallint, 541, 750, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_BYZANTINE', 'war', 'Arab + Turkic + Crusader conflicts',
  'Loss of Egypt, Syria to early Arab conquests; Battle of Manzikert (1071); Fourth Crusade sack of Constantinople (1204); final Ottoman conquest (1453).',
  5::smallint, 630, 1453, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_CELTS', 'colonization', 'Roman conquest',
  'Caesar''s Gallic Wars (-58 to -51) followed by Romanization across Gaul, Iberia, and Britain.',
  5::smallint, -58, 100, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_GERMANIC_IRON_AGE', 'war', 'Roman frontier wars',
  'Repeated cross-Rhine / cross-Danube conflicts with Rome; Teutoburg (9 CE), Marcomannic Wars.',
  3::smallint, -100, 400, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_NORSE', 'war', 'Christianization conflicts',
  'Internal raiding plus state-led Christianization conflicts (Stiklestad 1030).',
  3::smallint, 800, 1100, ARRAY['MARGARYAN_2020']::text[]);

SELECT _seed_threat('CARR_HIST_SLAVS_MEDIEVAL', 'war', 'Mongol invasion',
  'Mongol conquests of Rus principalities (1237-1240); centuries-long Tatar yoke.',
  5::smallint, 1237, 1480, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MEDIEVAL_W_EUROPEAN', 'disease', 'Black Death',
  'Second-pandemic plague (Yersinia pestis) 1346-1353 killing 30-60% of Europeans, with recurrent waves into the 17th c.',
  5::smallint, 1346, 1700, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MEDIEVAL_W_EUROPEAN', 'climate', 'Little Ice Age',
  'Cooling and crop failures from the 14th c. through the 19th c.',
  3::smallint, 1300, 1850, ARRAY['MANN_2009']::text[]);

-- South / East Asia --------------------------------------------------------

SELECT _seed_threat('CARR_HIST_VEDIC_ARYAN', 'displacement', 'Eastward Gangetic spread',
  'Gradual eastward migration into the Gangetic plain absorbing earlier ASI-related populations.',
  2::smallint, -1200, -500, ARRAY['NARASIMHAN_2019']::text[]);

SELECT _seed_threat('CARR_HIST_MAURYAN', 'war', 'Indo-Greek + Kushan invasions',
  'Post-Mauryan polities pressured by Indo-Greek (~-180) and Kushan (~30 CE) incursions.',
  3::smallint, -180, 200, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MUGHAL_N_INDIAN', 'war', 'Anglo-Mughal wars + decline',
  'Battle of Plassey (1757), Buxar (1764); progressive British East India Company control culminating in 1857.',
  5::smallint, 1750, 1857, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_SHANG', 'war', 'Zhou conquest',
  'Battle of Muye (~-1046) and the Zhou dynasty''s overthrow of Shang.',
  5::smallint, -1100, -1046, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_HAN_CHINESE_EMPIRE', 'climate', 'Yellow River shifts',
  'Catastrophic Yellow River course changes and floods in late Western Han contributing to dynastic crisis.',
  4::smallint, 0, 100, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_HAN_CHINESE_EMPIRE', 'war', 'Xiongnu raids + Yellow Turban Rebellion',
  'Centuries of steppe-frontier warfare with the Xiongnu plus the Yellow Turban Rebellion (184 CE) precipitating Han collapse.',
  4::smallint, -200, 220, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_TANG_CHINESE', 'war', 'An Lushan Rebellion',
  'An Lushan Rebellion (755-763) — one of the deadliest conflicts in pre-modern history; Tang never fully recovered.',
  5::smallint, 755, 763, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_KHMER_ANGKOR', 'climate', 'Mega-monsoon variability',
  'Multi-decadal drought / extreme flood cycles ~14th-15th c. straining Angkor''s hydraulic state.',
  4::smallint, 1300, 1431, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_KHMER_ANGKOR', 'war', 'Ayutthaya invasions',
  'Repeated Siamese (Ayutthaya) invasions culminating in the abandonment of Angkor (1431).',
  5::smallint, 1351, 1431, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MONGOL', 'climate', 'Pluvial + cold cycles',
  'Late-13th c. wet/grass productivity peak fueled the empire; subsequent cooling contributed to fragmentation.',
  3::smallint, 1200, 1400, ARRAY['MANN_2009','DEDUCED_PHASE_0']::text[]);

-- Pacific / Australia / Oceania ---------------------------------------------

SELECT _seed_threat('CARR_HIST_LAPITA', 'climate', 'ENSO variability',
  'Pacific climate oscillation affecting reef productivity and voyaging conditions.',
  2::smallint, -1200, -500, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_POLYNESIAN', 'natural_disaster', 'Cyclones / tsunamis',
  'Periodic cyclones, volcanic events, and tsunamis on small island populations.',
  3::smallint, -500, 1300, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_AUS_ABORIGINAL', 'colonization', 'British colonization',
  'British settlement from 1788 with massive demographic and cultural disruption; massacres and forced relocation.',
  5::smallint, 1788, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_AUS_ABORIGINAL', 'disease', 'Smallpox + introduced diseases',
  'Smallpox epidemics from 1789 onwards reducing Aboriginal populations dramatically.',
  5::smallint, 1789, 1900, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MAORI', 'colonization', 'British colonization',
  'Treaty of Waitangi (1840) and subsequent land confiscation, Musket Wars, and population decline through the 19th c.',
  4::smallint, 1820, 1900, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Americas ------------------------------------------------------------------

SELECT _seed_threat('CARR_HIST_MAYA_CLASSICAL', 'climate', 'Terminal Classic drought',
  'Multi-decadal drought in the southern lowlands ~800-900 implicated in the Classic Maya collapse.',
  5::smallint, 800, 900, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MAYA_CLASSICAL', 'war', 'Endemic inter-polity warfare',
  'Persistent warfare among lowland Maya city-states intensifying in the Late Classic.',
  4::smallint, 600, 900, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_AZTEC', 'colonization', 'Spanish conquest',
  'Cortés-led conquest 1519-1521; siege of Tenochtitlan and dismantling of the Triple Alliance.',
  5::smallint, 1519, 1521, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_AZTEC', 'disease', 'Smallpox + cocoliztli',
  'Smallpox epidemic during the conquest siege; cocoliztli outbreaks of 1545 and 1576 killing 70-80% of Indigenous Mexicans.',
  5::smallint, 1520, 1576, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_INCA', 'colonization', 'Spanish conquest',
  'Pizarro-led conquest 1532-1533 exploiting the post-smallpox civil war.',
  5::smallint, 1532, 1572, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_INCA', 'disease', 'Smallpox',
  'Smallpox arrived ahead of Pizarro killing the Inca Huayna Capac and triggering succession war.',
  5::smallint, 1525, 1535, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MISSISSIPPIAN', 'climate', 'Late Holocene drought',
  'Repeated megadroughts contributing to Cahokia''s decline ~1100-1300.',
  4::smallint, 1100, 1400, ARRAY['MANN_2009','DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MISSISSIPPIAN', 'disease', 'Pre-contact / contact-era disease',
  'European-introduced disease likely reached the interior Southeast via the Mississippi long before direct contact, contributing to the Mississippian collapse.',
  4::smallint, 1450, 1700, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_NATIVE_AMER', 'genocide', '19th-century displacement + violence',
  'Trail of Tears (1830s), Plains wars, boarding-school assimilation programs.',
  5::smallint, 1830, 1950, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Africa --------------------------------------------------------------------

SELECT _seed_threat('CARR_HIST_NUBIAN_KUSHITE', 'war', 'Egyptian + Roman + Aksumite conflicts',
  'New Kingdom Egyptian campaigns south, Roman engagements in 1st c. CE, eventual Aksumite defeat ~350 CE.',
  4::smallint, -1500, 350, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_AKSUMITE', 'climate', 'Late-1st-millennium drought',
  'Climate-driven agricultural decline contributing to Aksum''s 7th-c. collapse.',
  4::smallint, 600, 940, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_AKSUMITE', 'war', 'Arab maritime competition',
  'Loss of Red Sea trade after the Arab conquest of Egypt and Yemen.',
  3::smallint, 600, 940, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MALI_EMPIRE', 'war', 'Songhai + Moroccan conquests',
  'Mali eclipsed by Songhai mid-15th c.; Moroccan invasion of Songhai (1591) ended the West African Sahel imperial era.',
  4::smallint, 1450, 1670, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_KHOISAN_MODERN', 'displacement', 'Bantu expansion + colonization',
  'Bantu expansion absorbed/displaced southern Khoisan groups; later Dutch + British settler-colonial dispossession reduced ranges to small refuges.',
  5::smallint, 1, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_W_AFRICAN', 'colonization', 'Atlantic slave trade + colonization',
  'Atlantic slave trade (1500-1888) removed ~12 million people; subsequent European colonial partition (1880-1960).',
  5::smallint, 1500, 1960, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_E_AFRICAN', 'colonization', 'Slave trade + colonial era',
  'Indian Ocean slave trade and 19th-c. European partition of East Africa.',
  4::smallint, 1500, 1960, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Steppe / Central Asia / Iran ---------------------------------------------

SELECT _seed_threat('CARR_HIST_SCYTHIAN', 'war', 'Sarmatian replacement',
  'Pressure from Sarmatian groups and later Goths absorbing or displacing Scythian polities by ~300 CE.',
  4::smallint, -100, 300, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_ACHAEMENID', 'war', 'Greek + Macedonian conflicts',
  'Greco-Persian Wars (-499 to -449); Alexander''s conquest 334-330.',
  5::smallint, -499, -330, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_SASANIAN', 'war', 'Roman + Byzantine + Arab wars',
  'Byzantine-Sasanian wars 502-628 followed by the early Islamic conquest 633-651.',
  5::smallint, 200, 651, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_OTTOMAN', 'war', 'WWI + dissolution',
  'Catastrophic WWI defeat (1918), partition of Ottoman territories, and abolition of the sultanate (1922).',
  5::smallint, 1914, 1922, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Modern populations -------------------------------------------------------

SELECT _seed_threat('CARR_HIST_MODERN_EUROPEAN', 'war', 'World Wars',
  'WWI (1914-1918) and WWII (1939-1945) caused tens of millions of European deaths and demographic upheaval.',
  5::smallint, 1914, 1945, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MODERN_EUROPEAN', 'climate', 'Anthropogenic climate change',
  'Heat waves, drought, and infrastructure stress accelerating in the 21st c.',
  3::smallint, 1980, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_S_ASIAN', 'climate', 'Monsoon + heat extremes',
  'Increasing monsoon variability and lethal heat-humidity extremes in S Asia under anthropogenic warming.',
  4::smallint, 1980, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_HAN', 'climate', 'Coastal flooding + heat',
  'Sea-level rise threatening coastal megacities; lethal heat extremes in inland China.',
  3::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_LATIN_AMER_MESTIZO', 'war', 'Drug-cartel violence',
  'Late-20th and early-21st c. cartel-driven violence, particularly in Mexico, Central America, and Colombia.',
  3::smallint, 1980, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MODERN_LATIN_AMER_MESTIZO', 'climate', 'Drought + Amazon stress',
  'Increasing drought in central America and degradation of the Amazon basin affecting rural populations.',
  3::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_W_AFRICAN', 'climate', 'Sahel desertification',
  'Sahel southward shift, drought, and resource competition exacerbating displacement.',
  4::smallint, 1970, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_E_AFRICAN', 'climate', 'Horn-of-Africa drought',
  'Multi-year drought cycles 2010-2022 driving food insecurity and migration.',
  4::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_HIST_MODERN_ARAB', 'war', 'Civil wars + sectarian conflict',
  'Iraq (2003-), Syria (2011-), Yemen (2014-), Libya (2011-) — large-scale civil wars and proxy conflicts.',
  5::smallint, 2003, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_HIST_MODERN_ARAB', 'climate', 'Heat + water scarcity',
  'Lethal heat extremes (50°C+), drought, and aquifer depletion across the MENA.',
  4::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_SF_BAY_AREA_2025', 'climate', 'Wildfire + sea-level rise',
  'Worsening wildfire seasons and Bay sea-level rise threatening shoreline infrastructure.',
  3::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_SF_BAY_AREA_2025', 'resource_scarcity', 'Housing affordability crisis',
  'Severe housing supply / affordability crisis driving outmigration and homelessness.',
  3::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat('CARR_RURAL_SOUTH_US_2025', 'climate', 'Hurricanes + heat',
  'Increasing hurricane intensity along the Gulf coast and lethal heat in inland summers.',
  3::smallint, 2000, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);
SELECT _seed_threat('CARR_RURAL_SOUTH_US_2025', 'disease', 'Opioid epidemic',
  'Late-20th and 21st c. opioid epidemic disproportionately affecting rural southern US.',
  4::smallint, 1995, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Non-sapiens hominins -----------------------------------------------------

SELECT _seed_threat('CARR_HOMININ_NEANDERTHAL', 'climate', 'Late Pleistocene cooling cycles',
  'Repeated Heinrich-event cold spells reducing Neanderthal habitat.',
  4::smallint, -60000, -40000, ARRAY['CLARK_2009']::text[]);
SELECT _seed_threat('CARR_HOMININ_NEANDERTHAL', 'resource_competition', 'Modern human expansion',
  'Competition with incoming Homo sapiens populations after ~-50 ka.',
  5::smallint, -50000, -40000, ARRAY['REICH_CH2']::text[]);

SELECT _seed_threat('CARR_HOMININ_DENISOVAN', 'resource_competition', 'Modern human expansion',
  'Competition with sapiens following the Out-of-Africa expansion into Asia.',
  5::smallint, -55000, -50000, ARRAY['REICH_CH4']::text[]);

SELECT _seed_threat('CARR_HOMININ_FLORESIENSIS', 'natural_disaster', 'Toba supereruption + sapiens arrival',
  'Toba (~-74 ka) likely affected the Flores ecosystem; sapiens arrived ~-50 ka.',
  5::smallint, -74000, -50000, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Tear down the helper.
DROP FUNCTION _seed_threat(TEXT, threat_type, TEXT, TEXT, SMALLINT, INTEGER, INTEGER, TEXT[]);
