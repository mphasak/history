-- 023_seed_religion_traits.sql
--
-- Adds first-class **religion / ideological-tradition traits**. The
-- 'religious' trait domain was declared in the schema but unseeded —
-- so the map couldn't show "where was Christianity at year X?" or
-- "where was Buddhism at year X?" the same way it shows ancestry or
-- linguistic family.
--
-- Religion is era-dependent in a way ancestry isn't: a population is
-- ANATOLIAN_FARMER from cradle to grave, but the Roman Empire shifts
-- from Roman polytheism to Christianity around 380 CE. We use
-- carrier_trait_mix's existing `as_of_year` field to capture this:
-- multiple snapshots per carrier when their dominant tradition
-- changed.
--
-- ~10 traditions covered with assignments to ~50 carriers across
-- their relevant eras. Tagged [AUTO-RELIGION-023], idempotent, cited
-- via DEDUCED_PHASE_0.

INSERT INTO trait (id, domain, display_name, description) VALUES
  ('REL_INDIGENOUS', 'religious', 'Indigenous / animist tradition',
   'Place-specific oral religious traditions — ancestor veneration, totemic systems, animism, shamanism. Default state for prehistoric and many historic populations before adoption of a literate world religion.'),
  ('REL_CLASSICAL_POLYTHEISM', 'religious', 'Classical Mediterranean polytheism',
   'Greek / Roman / Etruscan polytheist tradition; expanded through Hellenistic and Roman empires. Displaced by Christianity from the 4th c.'),
  ('REL_AKKADIAN_BABYLONIAN', 'religious', 'Mesopotamian polytheism',
   'Sumerian → Akkadian → Babylonian → Assyrian polytheism (Marduk, Ishtar, Enlil, Ashur). Persisted into the Hellenistic period.'),
  ('REL_EGYPTIAN', 'religious', 'Ancient Egyptian religion',
   'Multi-millennial Egyptian state cult: Ra, Osiris, Isis, Amun. Suppressed under Christianization 4-6th c. CE.'),
  ('REL_ZOROASTRIAN', 'religious', 'Zoroastrianism',
   'Iranian religion founded by Zarathustra ~1500-1000 BCE; state religion of Achaemenid, Parthian, and Sasanian empires; declined post-Islamic conquest.'),
  ('REL_JUDAISM', 'religious', 'Judaism',
   'Monotheistic tradition centered on Israel/Judah; Second-Temple Judaism (~516 BCE - 70 CE), Rabbinic Judaism since.'),
  ('REL_CHRISTIANITY', 'religious', 'Christianity',
   'Originated in 1st-c. Roman Judea; state religion of Rome 380 CE; spread through medieval Europe, Slavic lands, Ethiopia, and (via colonization) the Americas, sub-Saharan Africa, the Pacific.'),
  ('REL_ISLAM', 'religious', 'Islam',
   'Founded in 7th-c. Arabia; rapid expansion through the Caliphates across MENA, Iran, Central Asia, North/West Africa, Spain, and (later) South + Southeast Asia.'),
  ('REL_HINDUISM', 'religious', 'Hindu / Vedic tradition',
   'Vedic religion of the Indo-Aryan-period north India; codified into classical Hinduism through the medieval period; dominant religion of South Asia.'),
  ('REL_BUDDHISM', 'religious', 'Buddhism',
   'Founded by Siddhartha Gautama 5th c. BCE; spread under the Mauryan Empire to Central, East, and Southeast Asia; declined in India by the medieval period.'),
  ('REL_JAINISM', 'religious', 'Jainism',
   'Indian heterodox tradition contemporaneous with early Buddhism; persistent minority in South Asia.'),
  ('REL_CONFUCIANISM', 'religious', 'Confucianism / Daoism',
   'Chinese ethical-religious complex of Confucian, Daoist, and Mohist schools, plus folk religion. Dominant Chinese tradition through the imperial period.'),
  ('REL_SHINTO', 'religious', 'Shintō',
   'Japanese animist / kami tradition; coexists with Buddhism in Japan from the 6th c. CE.'),
  ('REL_BONPO_TIBETAN_BUDDHIST', 'religious', 'Tibetan Buddhism / Bön',
   'Tibetan Buddhism (Vajrayāna) since the 7th c. CE, often coexisting with the indigenous Bön tradition.')
ON CONFLICT (id) DO NOTHING;

-- Idempotent re-run.
DELETE FROM carrier_trait_mix
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-RELIGION-023]%');
DELETE FROM claim_source
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-RELIGION-023]%');
DELETE FROM claim WHERE statement LIKE '[AUTO-RELIGION-023]%';

-- Trait-mix entries — `as_of_year` differentiates pre/post conversion
-- snapshots for carriers whose dominant tradition changed.
CREATE TEMP TABLE _rel_023 (
  carrier_id text,
  trait_id text,
  fraction numeric,
  as_of_year int
);
INSERT INTO _rel_023 (carrier_id, trait_id, fraction, as_of_year) VALUES
  -- Mesopotamian polytheism
  ('CARR_HIST_SUMERIAN',         'REL_AKKADIAN_BABYLONIAN', 1.000, -2500),
  ('CARR_HIST_AKKADIAN',         'REL_AKKADIAN_BABYLONIAN', 1.000, -2200),
  ('CARR_HIST_BABYLONIAN',       'REL_AKKADIAN_BABYLONIAN', 1.000, -1700),
  ('CARR_HIST_ASSYRIAN',         'REL_AKKADIAN_BABYLONIAN', 1.000, -700),
  -- Egyptian
  ('CARR_HIST_EGYPT_OK',          'REL_EGYPTIAN', 1.000, -2500),
  ('CARR_HIST_EGYPT_MK_NK',       'REL_EGYPTIAN', 1.000, -1500),
  ('CARR_HIST_HOL_PREDYNASTIC_EGYPT', 'REL_EGYPTIAN', 1.000, -4000),
  -- Zoroastrian
  ('CARR_HIST_ACHAEMENID', 'REL_ZOROASTRIAN', 1.000, -500),
  ('CARR_HIST_PARTHIAN',   'REL_ZOROASTRIAN', 1.000, 100),
  ('CARR_HIST_SASANIAN',   'REL_ZOROASTRIAN', 1.000, 500),
  ('CARR_HIST_SOGDIAN',    'REL_ZOROASTRIAN', 0.700, 500),
  ('CARR_HIST_SOGDIAN',    'REL_BUDDHISM',    0.300, 500),
  -- Classical Mediterranean polytheism
  ('CARR_HIST_GREEK',           'REL_CLASSICAL_POLYTHEISM', 1.000, -400),
  ('CARR_HIST_GREEK_CLASSICAL', 'REL_CLASSICAL_POLYTHEISM', 1.000, -400),
  ('CARR_HIST_ROMAN',           'REL_CLASSICAL_POLYTHEISM', 1.000, 0),
  ('CARR_HIST_ROMAN',           'REL_CHRISTIANITY',         1.000, 400), -- post-Constantine
  ('CARR_HIST_PHOENICIAN',      'REL_CLASSICAL_POLYTHEISM', 1.000, -1000), -- approx; Phoenician polytheism is its own tradition but we lump
  -- Christianity (medieval and early-modern Europe)
  ('CARR_HIST_BYZANTINE',                'REL_CHRISTIANITY', 1.000, 800),
  ('CARR_HIST_VIKING',                   'REL_INDIGENOUS',   1.000, 900),
  ('CARR_HIST_VIKING',                   'REL_CHRISTIANITY', 1.000, 1100), -- post-conversion
  ('CARR_HIST_GERMANIC_IRON_AGE',        'REL_INDIGENOUS',   1.000, 0),
  ('CARR_HIST_CELTS',                    'REL_INDIGENOUS',   1.000, -300),
  ('CARR_HIST_AKSUMITE',                 'REL_INDIGENOUS',   1.000, 100),
  ('CARR_HIST_AKSUMITE',                 'REL_CHRISTIANITY', 1.000, 400),
  ('CARR_HIST_BRIDGE_ZAGWE',             'REL_CHRISTIANITY', 1.000, 1100),
  ('CARR_HIST_GAP_ETHIOPIAN_HIGHLAND',   'REL_CHRISTIANITY', 1.000, 1500),
  ('CARR_HIST_POST1492_COLONIAL_NA',     'REL_CHRISTIANITY', 1.000, 1700),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE','REL_CHRISTIANITY', 1.000, 1850),
  ('CARR_HIST_POST1492_GILDED_AGE_US',   'REL_CHRISTIANITY', 1.000, 1900),
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN','REL_CHRISTIANITY', 1.000, 1900),
  ('CARR_HIST_POST1492_COLONIAL_AUS',    'REL_CHRISTIANITY', 1.000, 1850),
  ('CARR_HIST_POST1492_MODERN_AUS',      'REL_CHRISTIANITY', 1.000, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',       'REL_CHRISTIANITY', 1.000, 2010),
  ('CARR_HIST_POST1492_AFRIKANER',       'REL_CHRISTIANITY', 1.000, 1900),
  ('CARR_HIST_POST1492_COLONIAL_BR',     'REL_CHRISTIANITY', 1.000, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN', 'REL_CHRISTIANITY', 0.700, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN', 'REL_INDIGENOUS',   0.300, 1700),
  ('CARR_HIST_POST1492_COLONIAL_MESO',   'REL_CHRISTIANITY', 0.700, 1700),
  ('CARR_HIST_BRIDGE_COLONIAL_MESO',     'REL_CHRISTIANITY', 0.700, 1700),
  ('CARR_HIST_POST1492_MODERN_USA',      'REL_CHRISTIANITY', 0.700, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA',   'REL_CHRISTIANITY', 0.700, 2010),
  ('CARR_HIST_POST1492_MODERN_MEXICO',   'REL_CHRISTIANITY', 0.900, 2010),
  ('CARR_HIST_MODERN_EUROPEAN',          'REL_CHRISTIANITY', 0.700, 2000),
  -- Islam
  ('CARR_HIST_RASHIDUN_UMAYYAD',  'REL_ISLAM', 1.000, 700),
  ('CARR_HIST_ABBASID',           'REL_ISLAM', 1.000, 800),
  ('CARR_HIST_OTTOMAN',           'REL_ISLAM', 1.000, 1500),
  ('CARR_HIST_MODERN_ARAB',       'REL_ISLAM', 1.000, 2000),
  ('CARR_HIST_BERBER',            'REL_INDIGENOUS', 1.000, 0),
  ('CARR_HIST_BERBER',            'REL_ISLAM',      1.000, 800),
  ('CARR_HIST_GAP_GHANA_EMPIRE',  'REL_INDIGENOUS', 1.000, 800),
  ('CARR_HIST_GAP_GHANA_EMPIRE',  'REL_ISLAM',      1.000, 1100),
  ('CARR_HIST_GAP_MALI_EMPIRE',   'REL_ISLAM',      1.000, 1300),
  ('CARR_HIST_GAP_SONGHAI',       'REL_ISLAM',      1.000, 1500),
  ('CARR_HIST_GAP_SWAHILI_COAST', 'REL_ISLAM',      1.000, 1300),
  ('CARR_HIST_MUGHAL_N_INDIAN',   'REL_ISLAM',      0.700, 1700),
  ('CARR_HIST_MUGHAL_N_INDIAN',   'REL_HINDUISM',   0.300, 1700),
  ('CARR_HIST_BRIDGE_GARAMANTES', 'REL_INDIGENOUS', 1.000, 100),
  -- Hinduism
  ('CARR_HIST_VEDIC_ARYAN',     'REL_HINDUISM', 1.000, -1000),
  ('CARR_NW_SOUTH_ASIA_LATE_BRONZE', 'REL_HINDUISM', 1.000, -1700),
  ('CARR_HIST_MAURYAN',         'REL_HINDUISM', 0.500, -300),
  ('CARR_HIST_MAURYAN',         'REL_BUDDHISM', 0.500, -200), -- post-Ashoka
  ('CARR_HIST_MODERN_S_ASIAN',  'REL_HINDUISM', 0.700, 2000),
  ('CARR_HIST_MODERN_S_ASIAN',  'REL_ISLAM',    0.250, 2000),
  ('CARR_HIST_MODERN_S_ASIAN',  'REL_BUDDHISM', 0.030, 2000),
  ('CARR_HIST_MODERN_S_ASIAN',  'REL_JAINISM',  0.020, 2000),
  -- Buddhism
  ('CARR_HIST_HAN',         'REL_CONFUCIANISM', 1.000, 0),
  ('CARR_HIST_TANG',        'REL_CONFUCIANISM', 0.600, 800),
  ('CARR_HIST_TANG',        'REL_BUDDHISM',     0.400, 800),
  ('CARR_HIST_KHMER',       'REL_HINDUISM',     0.500, 1100),
  ('CARR_HIST_KHMER',       'REL_BUDDHISM',     0.500, 1100),
  ('CARR_HIST_MODERN_E_ASIAN','REL_CONFUCIANISM', 0.500, 2000),
  ('CARR_HIST_MODERN_E_ASIAN','REL_BUDDHISM',   0.300, 2000),
  ('CARR_HIST_MODERN_E_ASIAN','REL_INDIGENOUS', 0.200, 2000),
  ('CARR_HIST_MODERN_HAN',  'REL_CONFUCIANISM', 0.700, 2000),
  ('CARR_HIST_MODERN_HAN',  'REL_BUDDHISM',     0.300, 2000),
  -- Judaism
  ('CARR_HIST_POST1492_MODERN_ISRAELI', 'REL_JUDAISM', 0.750, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI', 'REL_ISLAM',   0.200, 2010),
  ('CARR_HIST_POST1492_MODERN_ISRAELI', 'REL_CHRISTIANITY', 0.050, 2010),
  -- Indigenous defaults for paleo / classical-American populations
  ('CARR_HIST_HOL_OLMEC',           'REL_INDIGENOUS', 1.000, -1000),
  ('CARR_HIST_HOL_PRECLASSIC_MAYA', 'REL_INDIGENOUS', 1.000, -500),
  ('CARR_HIST_MAYA_CLASSICAL',      'REL_INDIGENOUS', 1.000, 600),
  ('CARR_HIST_AZTEC',               'REL_INDIGENOUS', 1.000, 1450),
  ('CARR_HIST_INCA',                'REL_INDIGENOUS', 1.000, 1450),
  ('CARR_HIST_GAP_TEOTIHUACAN',     'REL_INDIGENOUS', 1.000, 200),
  ('CARR_HIST_GAP_MOCHE',           'REL_INDIGENOUS', 1.000, 400),
  ('CARR_HIST_GAP_NAZCA',           'REL_INDIGENOUS', 1.000, 300),
  ('CARR_HIST_GAP_WARI',            'REL_INDIGENOUS', 1.000, 800),
  ('CARR_HIST_GAP_TIWANAKU',        'REL_INDIGENOUS', 1.000, 700),
  ('CARR_HIST_GAP_MARAJOARA',       'REL_INDIGENOUS', 1.000, 800),
  ('CARR_HIST_GAP_MAPUCHE',         'REL_INDIGENOUS', 1.000, 1500),
  ('CARR_HIST_GAP_LAPITA',          'REL_INDIGENOUS', 1.000, -1000),
  ('CARR_HIST_GAP_POLYNESIAN_EXP',  'REL_INDIGENOUS', 1.000, 500),
  ('CARR_HIST_GAP_HAWAIIAN',        'REL_INDIGENOUS', 1.000, 1700),
  ('CARR_HIST_GAP_MAORI',           'REL_INDIGENOUS', 1.000, 1500),
  ('CARR_AUS_ABORIGINAL',           'REL_INDIGENOUS', 1.000, 0),
  ('CARR_PAPUAN_45K',               'REL_INDIGENOUS', 1.000, 0),
  ('CARR_HIST_GAP_NAVAJO_APACHE',   'REL_INDIGENOUS', 1.000, 1700),
  ('CARR_HIST_GAP_HAUDENOSAUNEE',   'REL_INDIGENOUS', 1.000, 1500),
  ('CARR_HIST_GAP_MISSISSIPPIAN',   'REL_INDIGENOUS', 1.000, 1200);

-- Build claims (one per row).
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', carrier_id,
       '[AUTO-RELIGION-023] ' || carrier_id || ' :: ' || trait_id || ' @ ' || as_of_year,
       3
FROM _rel_023
WHERE EXISTS (SELECT 1 FROM carrier WHERE carrier.id = _rel_023.carrier_id)
  AND EXISTS (SELECT 1 FROM trait WHERE trait.id = _rel_023.trait_id);

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim WHERE statement LIKE '[AUTO-RELIGION-023]%';

-- Insert trait-mix rows joining back to those claims by the encoded statement.
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT r.carrier_id, r.trait_id, r.fraction, r.as_of_year, t.domain, c.id
FROM _rel_023 r
JOIN trait t ON t.id = r.trait_id
JOIN claim c
  ON c.subject_type = 'Carrier'
 AND c.subject_id = r.carrier_id
 AND c.statement = '[AUTO-RELIGION-023] ' || r.carrier_id || ' :: ' || r.trait_id || ' @ ' || r.as_of_year
WHERE EXISTS (SELECT 1 FROM carrier WHERE carrier.id = r.carrier_id);

-- _rel_023 is a TEMP TABLE; PostgreSQL auto-cleans it on session end so
-- we don't need an explicit teardown.
