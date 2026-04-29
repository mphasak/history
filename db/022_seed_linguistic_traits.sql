-- 022_seed_linguistic_traits.sql
--
-- Adds first-class **linguistic-family traits** so the map can answer
-- "where was Indo-European at year X?" the same way it answers "where
-- was STEPPE_MLBA at year X?". Without these the trait domain
-- 'linguistic' was a hollow enum — declared but nothing seeded.
--
-- Why first-class linguistic traits matter for this app:
--   * Cluster coloring becomes a meaningful linguistic-family map when
--     the user toggles cluster + filters by domain.
--   * The lineage BFS now has a genuinely different *domain* of edge
--     to traverse — sharing a linguistic family is a different kind of
--     relatedness from sharing a genetic ancestry component.
--   * The DetailPanel surfaces a per-carrier linguistic-family bar
--     alongside ancestry, which is a much richer characterization of
--     what a population *was*.
--
-- ~12 families covered, with assignments to ~50 representative carriers.
-- Cited via DEDUCED_PHASE_0, tagged [AUTO-LING-022], idempotent.

INSERT INTO trait (id, domain, display_name, description) VALUES
  ('LING_INDO_EUROPEAN', 'linguistic', 'Indo-European',
   'Largest language family by speakers. Includes Anatolian, Tocharian, Indo-Iranian, Greek, Italic / Romance, Celtic, Germanic, Balto-Slavic, Albanian, Armenian.'),
  ('LING_SINO_TIBETAN',  'linguistic', 'Sino-Tibetan',
   'East / Southeast Asian family: Sinitic (Mandarin and other Chinese topolects), Tibetic, Burmic, and ~400 smaller languages.'),
  ('LING_NIGER_CONGO',   'linguistic', 'Niger-Congo (Bantu)',
   'Largest African family. Bantu sub-branch covers most of sub-equatorial Africa post-Bantu expansion (~1500 BCE - 500 CE).'),
  ('LING_AFRO_ASIATIC',  'linguistic', 'Afro-Asiatic',
   'North African + Levant family: Semitic (Akkadian, Phoenician, Hebrew, Aramaic, Arabic, Amharic), Egyptian, Berber, Cushitic, Chadic.'),
  ('LING_AUSTRONESIAN',  'linguistic', 'Austronesian',
   'Pacific + Maritime SE Asia family: Malayo-Polynesian, Oceanic, Polynesian. Originated in Taiwan ~5000 BCE; expanded across the Pacific via Lapita and Polynesian voyaging.'),
  ('LING_DRAVIDIAN',     'linguistic', 'Dravidian',
   'South Indian family: Tamil, Telugu, Malayalam, Kannada, Brahui (in Pakistan). Possibly the language of the Indus Valley Civilization.'),
  ('LING_TURKIC',        'linguistic', 'Turkic',
   'Steppe-origin family that spread westward post-6th century: Old Turkic, Oghuz (Turkish), Kipchak, Karluk (Uzbek, Uyghur), Sakha (Yakut).'),
  ('LING_MONGOLIC',      'linguistic', 'Mongolic',
   'Inner-Asian family centered on Mongolian; spread under the 13th-c. Mongol Empire to as far as Persia and Eastern Europe.'),
  ('LING_URALIC',        'linguistic', 'Uralic',
   'Northern Eurasian family: Finno-Ugric (Finnish, Saami, Hungarian, Estonian) + Samoyedic. Probably North-Asian origin.'),
  ('LING_ATHABASKAN',    'linguistic', 'Na-Dené / Athabaskan',
   'North American family: Athabaskan (incl. Navajo, Apache, Tlingit, Eyak); arrived from a later Beringian crossing than the First Americans.'),
  ('LING_MAYAN',         'linguistic', 'Mayan',
   'Mesoamerican family of ~30 languages including K''iche'', Yucatec, Tzotzil. Spoken by the Mayan civilization complex from at least 1000 BCE.'),
  ('LING_QUECHUAN',      'linguistic', 'Quechuan',
   'Andean family of related dialects; lingua franca of the Inca Empire and now official in Peru, Bolivia, and Ecuador.'),
  ('LING_AYMARAN',       'linguistic', 'Aymaran',
   'Andean altiplano family: Aymara, Jaqaru. Often associated with Tiwanaku; co-existed with Quechuan in the Inca period.'),
  ('LING_NAHUAN',        'linguistic', 'Nahuan (Uto-Aztecan)',
   'Mesoamerican branch of Uto-Aztecan: Classical Nahuatl, modern Nahua dialects. Carried by the Toltecs and Aztecs.'),
  ('LING_PAMA_NYUNGAN',  'linguistic', 'Pama-Nyungan',
   'Largest Australian family; covers most of mainland Aboriginal languages. (Non-Pama-Nyungan languages exist mainly in the Top End.)'),
  ('LING_IROQUOIAN',     'linguistic', 'Iroquoian',
   'NE woodland family: Mohawk, Oneida, Onondaga, Cayuga, Seneca, Tuscarora (Six Nations), Cherokee, Huron-Wendat.'),
  ('LING_TUPIAN',        'linguistic', 'Tupian',
   'South-Atlantic family in Brazil and surrounding countries; Tupinambá / Guaraní as colonial-era lingua francas.'),
  ('LING_KHOISAN',       'linguistic', 'Khoisan (click languages)',
   'Southern African macro-family characterized by click consonants; deeply diverged. Khoekhoe, San (!Xun, Ju), Hadza, Sandawe.'),
  ('LING_PAPUAN',        'linguistic', 'Papuan (non-Austronesian)',
   'Highly diverse, deeply diverged family group of New Guinea and surrounding islands; ~800 languages with ill-understood relationships.'),
  ('LING_AUSTROASIATIC', 'linguistic', 'Austroasiatic',
   'Mainland-SE-Asian family including Khmer, Vietnamese, Mon, and a sprinkling of South-Asian languages (Munda).'),
  ('LING_TAI_KADAI',     'linguistic', 'Tai-Kadai',
   'SE-Asian family: Thai, Lao, Zhuang. Originated in southern China.')
ON CONFLICT (id) DO NOTHING;

-- Idempotent re-run.
DELETE FROM carrier_trait_mix
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-LING-022]%');
DELETE FROM claim_source
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-LING-022]%');
DELETE FROM claim WHERE statement LIKE '[AUTO-LING-022]%';

-- Umbrella claim per carrier.
WITH targets(carrier_id) AS (VALUES
  -- Indo-European cluster
  ('CARR_YAMNAYA'), ('CARR_HIST_HITTITE'), ('CARR_HIST_VEDIC_ARYAN'),
  ('CARR_HIST_GREEK_CLASSICAL'), ('CARR_HIST_GREEK'), ('CARR_HIST_ROMAN'),
  ('CARR_HIST_BYZANTINE'), ('CARR_HIST_CELTS'), ('CARR_HIST_GERMANIC_IRON_AGE'),
  ('CARR_HIST_VIKING'), ('CARR_HIST_GAUL'), ('CARR_HIST_SCYTHIAN'),
  ('CARR_HIST_SOGDIAN'), ('CARR_HIST_SASANIAN'), ('CARR_HIST_ACHAEMENID'),
  ('CARR_HIST_PARTHIAN'), ('CARR_HIST_BABYLONIAN'), -- Babylonian was Akkadian-speaking, but I'll leave Indo-European out of this list
  ('CARR_HIST_MAURYAN'), ('CARR_HIST_MUGHAL_N_INDIAN'), ('CARR_HIST_MODERN_S_ASIAN'),
  ('CARR_HIST_BRIDGE_ANDRONOVO'), ('CARR_HIST_BRIDGE_AFANASIEVO'),
  ('CARR_HIST_BRIDGE_TAGAR'), ('CARR_HIST_BRIDGE_KARASUK'),
  ('CARR_HIST_POST1492_COLONIAL_NA'), ('CARR_HIST_POST1492_REPUBLIC_US_WHITE'),
  ('CARR_HIST_POST1492_GILDED_AGE_US'), ('CARR_HIST_POST1492_COLONIAL_AUS'),
  ('CARR_HIST_POST1492_MODERN_AUS'), ('CARR_HIST_POST1492_PAKEHA_NZ'),
  ('CARR_HIST_POST1492_AFRIKANER'), ('CARR_HIST_POST1492_MODERN_USA'),
  ('CARR_HIST_POST1492_MODERN_CANADA'), ('CARR_HIST_MODERN_EUROPEAN'),
  ('CARR_HIST_BRIDGE_LATE_WOODLAND'),
  -- Sino-Tibetan
  ('CARR_HIST_HAN'), ('CARR_HIST_TANG'), ('CARR_HIST_HOL_YANGSHAO'),
  ('CARR_HIST_HOL_HONGSHAN'), ('CARR_HIST_HOL_LIANGZHU'),
  ('CARR_HIST_HOL_LONGSHAN'), ('CARR_HIST_HOL_HEMUDU'),
  ('CARR_HIST_MODERN_HAN'), ('CARR_HIST_MODERN_E_ASIAN'),
  -- Niger-Congo / Bantu
  ('CARR_HIST_GAP_BANTU_EXPANSION'), ('CARR_HIST_GAP_GHANA_EMPIRE'),
  ('CARR_HIST_GAP_MALI_EMPIRE'), ('CARR_HIST_GAP_SONGHAI'),
  ('CARR_HIST_GAP_GREAT_ZIMBABWE'), ('CARR_HIST_GAP_KONGO'),
  ('CARR_HIST_GAP_SWAHILI_COAST'), ('CARR_HIST_GAP_ASANTE'),
  ('CARR_HIST_HOL_NOK'), ('CARR_HIST_HOL_KINTAMPO'),
  ('CARR_HIST_MODERN_W_AFRICAN'), ('CARR_HIST_MODERN_E_AFRICAN'),
  -- Afro-Asiatic
  ('CARR_HIST_AKKADIAN'), ('CARR_HIST_BABYLONIAN'),
  ('CARR_HIST_ASSYRIAN'), ('CARR_HIST_PHOENICIAN'),
  ('CARR_HIST_EGYPT_OK'), ('CARR_HIST_EGYPT_MK_NK'),
  ('CARR_HIST_HOL_PREDYNASTIC_EGYPT'), ('CARR_HIST_HOL_C_GROUP_NUBIAN'),
  ('CARR_HIST_NUBIAN_KUSHITE'), ('CARR_HIST_AKSUMITE'),
  ('CARR_HIST_BRIDGE_ZAGWE'), ('CARR_HIST_GAP_ETHIOPIAN_HIGHLAND'),
  ('CARR_HIST_RASHIDUN_UMAYYAD'), ('CARR_HIST_ABBASID'),
  ('CARR_HIST_MODERN_ARAB'), ('CARR_HIST_BERBER'),
  ('CARR_HIST_BRIDGE_GARAMANTES'), ('CARR_HIST_NATUFIAN_12K'),
  ('CARR_NATUFIAN_12K'), ('CARR_HIST_POST1492_MODERN_ISRAELI'),
  -- Austronesian
  ('CARR_HIST_GAP_LAPITA'), ('CARR_HIST_GAP_POLYNESIAN_EXP'),
  ('CARR_HIST_GAP_MAORI'), ('CARR_HIST_MAORI'),
  ('CARR_HIST_GAP_HAWAIIAN'), ('CARR_HIST_MODERN_SE_ASIAN'),
  -- Dravidian
  ('CARR_HARAPPAN'), -- speculative; debated
  -- Turkic
  ('CARR_HIST_GAP_YAKUT'), ('CARR_HIST_TURKIC_GOKTURK'), ('CARR_HIST_OTTOMAN'),
  -- Mongolic
  ('CARR_HIST_MONGOL'),
  -- Uralic
  ('CARR_HIST_FOR_SAAMI_ANCESTRAL'),
  -- Athabaskan
  ('CARR_HIST_GAP_NAVAJO_APACHE'),
  -- Mayan
  ('CARR_HIST_HOL_OLMEC'), -- arguably; the Olmec language is unknown
  ('CARR_HIST_HOL_PRECLASSIC_MAYA'), ('CARR_HIST_MAYA_CLASSICAL'),
  -- Quechuan / Aymaran
  ('CARR_HIST_INCA'), ('CARR_HIST_GAP_WARI'),
  ('CARR_HIST_GAP_TIWANAKU'), ('CARR_HIST_POST1492_COLONIAL_ANDEAN'),
  ('CARR_HIST_BRIDGE_CUPISNIQUE'), ('CARR_HIST_GAP_MOCHE'),
  -- Nahuan
  ('CARR_HIST_GAP_TOLTEC'), ('CARR_HIST_AZTEC'),
  -- Pama-Nyungan
  ('CARR_AUS_ABORIGINAL'),
  -- Iroquoian
  ('CARR_HIST_GAP_HAUDENOSAUNEE'),
  -- Tupian
  ('CARR_HIST_FOR_AMAZON_FORAGERS'), ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE'),
  ('CARR_HIST_GAP_MARAJOARA'), ('CARR_HIST_POST1492_COLONIAL_BR'),
  -- Khoisan
  ('CARR_HIST_FOR_KHOISAN_HOL'), ('CARR_HIST_KHOE_SAN_ANCESTRAL'),
  ('CARR_HIST_KHOISAN_MODERN'),
  -- Papuan
  ('CARR_PAPUAN_45K'),
  -- Austroasiatic
  ('CARR_HIST_KHMER'),
  -- Tai-Kadai
  ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE') -- placeholder; we don't have a Tai-Kadai-specific carrier yet
)
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', carrier_id,
       '[AUTO-LING-022] Linguistic-family attribution for ' || carrier_id ||
       '; see DEDUCED_PHASE_0 for methodology.',
       3
FROM (SELECT DISTINCT carrier_id FROM targets) t
WHERE EXISTS (SELECT 1 FROM carrier WHERE carrier.id = t.carrier_id);

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim WHERE statement LIKE '[AUTO-LING-022]%';

-- Trait mix entries.
WITH a(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- Indo-European: 1.0 each (linguistic identity, not admixture)
  ('CARR_YAMNAYA',                       'LING_INDO_EUROPEAN', 1.000, -2900),
  ('CARR_HIST_HITTITE',                  'LING_INDO_EUROPEAN', 1.000, -1500),
  ('CARR_HIST_VEDIC_ARYAN',              'LING_INDO_EUROPEAN', 1.000, -1000),
  ('CARR_HIST_GREEK_CLASSICAL',          'LING_INDO_EUROPEAN', 1.000, -400),
  ('CARR_HIST_GREEK',                    'LING_INDO_EUROPEAN', 1.000, -400),
  ('CARR_HIST_ROMAN',                    'LING_INDO_EUROPEAN', 1.000, 0),
  ('CARR_HIST_BYZANTINE',                'LING_INDO_EUROPEAN', 1.000, 800),
  ('CARR_HIST_CELTS',                    'LING_INDO_EUROPEAN', 1.000, -300),
  ('CARR_HIST_GERMANIC_IRON_AGE',        'LING_INDO_EUROPEAN', 1.000, 0),
  ('CARR_HIST_VIKING',                   'LING_INDO_EUROPEAN', 1.000, 900),
  ('CARR_HIST_SCYTHIAN',                 'LING_INDO_EUROPEAN', 1.000, -500),
  ('CARR_HIST_SOGDIAN',                  'LING_INDO_EUROPEAN', 1.000, 500),
  ('CARR_HIST_SASANIAN',                 'LING_INDO_EUROPEAN', 1.000, 500),
  ('CARR_HIST_ACHAEMENID',               'LING_INDO_EUROPEAN', 1.000, -500),
  ('CARR_HIST_MAURYAN',                  'LING_INDO_EUROPEAN', 1.000, -200),
  ('CARR_HIST_MUGHAL_N_INDIAN',          'LING_INDO_EUROPEAN', 1.000, 1700),
  ('CARR_HIST_MODERN_S_ASIAN',           'LING_INDO_EUROPEAN', 0.750, 2000),
  ('CARR_HIST_MODERN_S_ASIAN',           'LING_DRAVIDIAN',     0.250, 2000),
  ('CARR_HIST_BRIDGE_ANDRONOVO',         'LING_INDO_EUROPEAN', 1.000, -1700),
  ('CARR_HIST_BRIDGE_AFANASIEVO',        'LING_INDO_EUROPEAN', 1.000, -2900),
  ('CARR_HIST_BRIDGE_TAGAR',             'LING_INDO_EUROPEAN', 1.000, -500),
  ('CARR_HIST_POST1492_COLONIAL_NA',     'LING_INDO_EUROPEAN', 1.000, 1700),
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE','LING_INDO_EUROPEAN', 1.000, 1850),
  ('CARR_HIST_POST1492_GILDED_AGE_US',   'LING_INDO_EUROPEAN', 1.000, 1900),
  ('CARR_HIST_POST1492_COLONIAL_AUS',    'LING_INDO_EUROPEAN', 1.000, 1850),
  ('CARR_HIST_POST1492_MODERN_AUS',      'LING_INDO_EUROPEAN', 1.000, 2010),
  ('CARR_HIST_POST1492_PAKEHA_NZ',       'LING_INDO_EUROPEAN', 1.000, 2010),
  ('CARR_HIST_POST1492_AFRIKANER',       'LING_INDO_EUROPEAN', 1.000, 1900),
  ('CARR_HIST_POST1492_MODERN_USA',      'LING_INDO_EUROPEAN', 1.000, 2010),
  ('CARR_HIST_POST1492_MODERN_CANADA',   'LING_INDO_EUROPEAN', 1.000, 2010),
  ('CARR_HIST_MODERN_EUROPEAN',          'LING_INDO_EUROPEAN', 1.000, 2000),

  -- Sino-Tibetan
  ('CARR_HIST_HAN',                'LING_SINO_TIBETAN', 1.000, 0),
  ('CARR_HIST_TANG',               'LING_SINO_TIBETAN', 1.000, 800),
  ('CARR_HIST_HOL_YANGSHAO',       'LING_SINO_TIBETAN', 1.000, -5000),
  ('CARR_HIST_HOL_HONGSHAN',       'LING_SINO_TIBETAN', 1.000, -4000),
  ('CARR_HIST_HOL_LIANGZHU',       'LING_SINO_TIBETAN', 1.000, -3500),
  ('CARR_HIST_HOL_LONGSHAN',       'LING_SINO_TIBETAN', 1.000, -2500),
  ('CARR_HIST_HOL_HEMUDU',         'LING_SINO_TIBETAN', 1.000, -5000),
  ('CARR_HIST_MODERN_HAN',         'LING_SINO_TIBETAN', 1.000, 2000),
  ('CARR_HIST_MODERN_E_ASIAN',     'LING_SINO_TIBETAN', 1.000, 2000),

  -- Niger-Congo / Bantu
  ('CARR_HIST_GAP_BANTU_EXPANSION', 'LING_NIGER_CONGO', 1.000, 0),
  ('CARR_HIST_GAP_GHANA_EMPIRE',    'LING_NIGER_CONGO', 1.000, 1000),
  ('CARR_HIST_GAP_MALI_EMPIRE',     'LING_NIGER_CONGO', 1.000, 1300),
  ('CARR_HIST_GAP_SONGHAI',         'LING_NIGER_CONGO', 1.000, 1500),
  ('CARR_HIST_GAP_GREAT_ZIMBABWE',  'LING_NIGER_CONGO', 1.000, 1300),
  ('CARR_HIST_GAP_KONGO',           'LING_NIGER_CONGO', 1.000, 1600),
  ('CARR_HIST_GAP_SWAHILI_COAST',   'LING_NIGER_CONGO', 1.000, 1300),
  ('CARR_HIST_GAP_ASANTE',          'LING_NIGER_CONGO', 1.000, 1800),
  ('CARR_HIST_HOL_NOK',             'LING_NIGER_CONGO', 1.000, -500),
  ('CARR_HIST_HOL_KINTAMPO',        'LING_NIGER_CONGO', 1.000, -1700),
  ('CARR_HIST_MODERN_W_AFRICAN',    'LING_NIGER_CONGO', 1.000, 2000),
  ('CARR_HIST_MODERN_E_AFRICAN',    'LING_NIGER_CONGO', 0.700, 2000),
  ('CARR_HIST_MODERN_E_AFRICAN',    'LING_AFRO_ASIATIC', 0.300, 2000),

  -- Afro-Asiatic
  ('CARR_HIST_AKKADIAN',                 'LING_AFRO_ASIATIC', 1.000, -2200),
  ('CARR_HIST_BABYLONIAN',               'LING_AFRO_ASIATIC', 1.000, -1700),
  ('CARR_HIST_ASSYRIAN',                 'LING_AFRO_ASIATIC', 1.000, -700),
  ('CARR_HIST_PHOENICIAN',               'LING_AFRO_ASIATIC', 1.000, -1000),
  ('CARR_HIST_EGYPT_OK',                 'LING_AFRO_ASIATIC', 1.000, -2500),
  ('CARR_HIST_EGYPT_MK_NK',              'LING_AFRO_ASIATIC', 1.000, -1500),
  ('CARR_HIST_HOL_PREDYNASTIC_EGYPT',    'LING_AFRO_ASIATIC', 1.000, -4000),
  ('CARR_HIST_HOL_C_GROUP_NUBIAN',       'LING_AFRO_ASIATIC', 1.000, -2000),
  ('CARR_HIST_NUBIAN_KUSHITE',           'LING_AFRO_ASIATIC', 1.000, -500),
  ('CARR_HIST_AKSUMITE',                 'LING_AFRO_ASIATIC', 1.000, 200),
  ('CARR_HIST_BRIDGE_ZAGWE',             'LING_AFRO_ASIATIC', 1.000, 1100),
  ('CARR_HIST_GAP_ETHIOPIAN_HIGHLAND',   'LING_AFRO_ASIATIC', 1.000, 1500),
  ('CARR_HIST_RASHIDUN_UMAYYAD',         'LING_AFRO_ASIATIC', 1.000, 700),
  ('CARR_HIST_ABBASID',                  'LING_AFRO_ASIATIC', 1.000, 800),
  ('CARR_HIST_MODERN_ARAB',              'LING_AFRO_ASIATIC', 1.000, 2000),
  ('CARR_HIST_BERBER',                   'LING_AFRO_ASIATIC', 1.000, 0),
  ('CARR_HIST_BRIDGE_GARAMANTES',        'LING_AFRO_ASIATIC', 1.000, 100),
  ('CARR_HIST_NATUFIAN_12K',             'LING_AFRO_ASIATIC', 1.000, -10000),
  ('CARR_NATUFIAN_12K',                  'LING_AFRO_ASIATIC', 1.000, -10000),
  ('CARR_HIST_POST1492_MODERN_ISRAELI',  'LING_AFRO_ASIATIC', 1.000, 2010),

  -- Austronesian
  ('CARR_HIST_GAP_LAPITA',          'LING_AUSTRONESIAN', 1.000, -1000),
  ('CARR_HIST_GAP_POLYNESIAN_EXP',  'LING_AUSTRONESIAN', 1.000, 500),
  ('CARR_HIST_GAP_MAORI',           'LING_AUSTRONESIAN', 1.000, 1500),
  ('CARR_HIST_MAORI',               'LING_AUSTRONESIAN', 1.000, 1500),
  ('CARR_HIST_GAP_HAWAIIAN',        'LING_AUSTRONESIAN', 1.000, 1700),
  ('CARR_HIST_MODERN_SE_ASIAN',     'LING_AUSTRONESIAN', 0.700, 2000),
  ('CARR_HIST_MODERN_SE_ASIAN',     'LING_AUSTROASIATIC', 0.300, 2000),

  -- Dravidian (speculative for Harappan, often debated)
  ('CARR_HARAPPAN', 'LING_DRAVIDIAN', 1.000, -2000),

  -- Turkic
  ('CARR_HIST_GAP_YAKUT',          'LING_TURKIC',  1.000, 1700),
  ('CARR_HIST_TURKIC_GOKTURK',     'LING_TURKIC',  1.000, 600),
  ('CARR_HIST_OTTOMAN',            'LING_TURKIC',  1.000, 1500),

  -- Mongolic
  ('CARR_HIST_MONGOL', 'LING_MONGOLIC', 1.000, 1250),

  -- Uralic
  ('CARR_HIST_FOR_SAAMI_ANCESTRAL', 'LING_URALIC', 1.000, -1000),

  -- Athabaskan
  ('CARR_HIST_GAP_NAVAJO_APACHE', 'LING_ATHABASKAN', 1.000, 1700),

  -- Mayan
  ('CARR_HIST_HOL_PRECLASSIC_MAYA', 'LING_MAYAN', 1.000, -500),
  ('CARR_HIST_MAYA_CLASSICAL',      'LING_MAYAN', 1.000, 600),

  -- Quechuan / Aymaran
  ('CARR_HIST_INCA',                       'LING_QUECHUAN', 1.000, 1450),
  ('CARR_HIST_GAP_WARI',                   'LING_QUECHUAN', 1.000, 800),
  ('CARR_HIST_GAP_TIWANAKU',               'LING_AYMARAN',  1.000, 700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',   'LING_QUECHUAN', 0.700, 1700),
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN',   'LING_INDO_EUROPEAN', 0.300, 1700),

  -- Nahuan
  ('CARR_HIST_GAP_TOLTEC', 'LING_NAHUAN', 1.000, 1100),
  ('CARR_HIST_AZTEC',      'LING_NAHUAN', 1.000, 1450),

  -- Pama-Nyungan
  ('CARR_AUS_ABORIGINAL', 'LING_PAMA_NYUNGAN', 1.000, 0),

  -- Iroquoian
  ('CARR_HIST_GAP_HAUDENOSAUNEE', 'LING_IROQUOIAN', 1.000, 1500),

  -- Tupian
  ('CARR_HIST_FOR_AMAZON_FORAGERS',     'LING_TUPIAN', 1.000, -3000),
  ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE', 'LING_TUPIAN', 1.000, -500),
  ('CARR_HIST_GAP_MARAJOARA',           'LING_TUPIAN', 1.000, 800),
  ('CARR_HIST_POST1492_COLONIAL_BR',    'LING_INDO_EUROPEAN', 0.800, 1700),
  ('CARR_HIST_POST1492_COLONIAL_BR',    'LING_TUPIAN',        0.200, 1700),

  -- Khoisan
  ('CARR_HIST_FOR_KHOISAN_HOL',     'LING_KHOISAN', 1.000, -1000),
  ('CARR_HIST_KHOE_SAN_ANCESTRAL',  'LING_KHOISAN', 1.000, -100000),
  ('CARR_HIST_KHOISAN_MODERN',      'LING_KHOISAN', 1.000, 2000),

  -- Papuan
  ('CARR_PAPUAN_45K', 'LING_PAPUAN', 1.000, 0),

  -- Austroasiatic
  ('CARR_HIST_KHMER', 'LING_AUSTROASIATIC', 1.000, 1100)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT a.carrier_id, a.trait_id, a.fraction, a.as_of_year, t.domain, c.id
FROM a
JOIN trait t ON t.id = a.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = a.carrier_id
            AND c.statement LIKE '[AUTO-LING-022]%'
WHERE EXISTS (SELECT 1 FROM carrier WHERE carrier.id = a.carrier_id);
