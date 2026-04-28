-- 005_seed_historical_carriers.sql
--
-- Fills the population coverage gaps left by 004_seed_population_genetics.sql:
--
--   * Non-sapiens hominins (Homo erectus, Neanderthals, Denisovans, etc.)
--     so deep-time and Pleistocene scrubs aren't empty.
--   * Early African sapiens / pre-OOA source populations.
--   * Additional regional Upper Paleolithic clusters (Ust'-Ishim, Hofmeyr,
--     Iberomaurusian, Hoabinhian, Andamanese).
--   * Holocene/historical ethnolinguistic carriers covering 0 CE – 1900 CE,
--     which previously had only Bantu/Papuan/Aboriginal.
--   * Modern (1900–2025) regional populations.
--
-- All coordinates are coarse centroids; date ranges follow broad-consensus
-- chronologies. No trait_mix entries are added here — these carriers exist
-- so users can see population dots across the slider; ancestry breakdowns
-- can be layered in later via separate seed files.
--
-- Idempotent: DELETE + INSERT scoped to the CARR_HIST_* and CARR_HOMININ_*
-- ID prefixes this file owns. Re-running picks up edits without requiring
-- `docker compose down -v`.

-- ---------------------------------------------------------------------------
-- Clean up rows owned by this file (so re-runs pick up edits)
-- ---------------------------------------------------------------------------

DELETE FROM carrier WHERE id LIKE 'CARR_HIST_%' OR id LIKE 'CARR_HOMININ_%';

-- ---------------------------------------------------------------------------
-- Non-sapiens hominins
-- ---------------------------------------------------------------------------

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HOMININ_HOMO_HABILIS', 'Homo habilis', 'population',
   -2400000, -1400000, ST_GeogFromText('SRID=4326;POINT(36 -3)'),
   'Oldowan', NULL,
   'Early Homo, East African Rift; small-bodied with large brain relative to australopithecines, associated with the earliest stone tool industries.'),

  ('CARR_HOMININ_AFRICAN_ERECTUS', 'Homo erectus / ergaster (Africa)', 'population',
   -1900000, -500000, ST_GeogFromText('SRID=4326;POINT(36 0)'),
   'Acheulean', NULL,
   'African Homo erectus / Homo ergaster. First hominin to leave Africa; associated with Acheulean handaxes after ~-1.7 Mya.'),

  ('CARR_HOMININ_ANTECESSOR', 'Homo antecessor', 'population',
   -1200000, -800000, ST_GeogFromText('SRID=4326;POINT(-3.5 42.4)'),
   NULL, NULL,
   'Atapuerca (Spain) hominin; possible common ancestor of Neanderthals and modern humans, or a side branch of the European erectus radiation.'),

  ('CARR_HOMININ_ASIAN_ERECTUS_JAVA', 'Java Homo erectus', 'population',
   -1600000, -100000, ST_GeogFromText('SRID=4326;POINT(112 -7)'),
   NULL, NULL,
   'Trinil / Sangiran / Solo Homo erectus on Java; one of the longest-lived hominin populations, possibly persisting until ~-100 kya.'),

  ('CARR_HOMININ_ASIAN_ERECTUS_CHINA', 'Chinese Homo erectus (Peking Man)', 'population',
   -770000, -400000, ST_GeogFromText('SRID=4326;POINT(115.9 39.7)'),
   NULL, NULL,
   'Zhoukoudian / Peking Man Homo erectus; northern China population using fire and simple stone tools.'),

  ('CARR_HOMININ_HEIDELBERGENSIS', 'Homo heidelbergensis', 'population',
   -700000, -200000, ST_GeogFromText('SRID=4326;POINT(10 35)'),
   'Late Acheulean', NULL,
   'Broad Afro-European Middle Pleistocene hominin; likely common ancestor of Neanderthals (in Europe) and modern humans (in Africa).'),

  ('CARR_HOMININ_RHODESIENSIS', 'Homo rhodesiensis (Kabwe)', 'population',
   -300000, -125000, ST_GeogFromText('SRID=4326;POINT(28 -15)'),
   NULL, NULL,
   'Kabwe / Broken Hill Middle Pleistocene African hominin; sometimes lumped with Homo heidelbergensis, sometimes split as a distinct African lineage.'),

  ('CARR_HOMININ_NALEDI', 'Homo naledi', 'population',
   -335000, -236000, ST_GeogFromText('SRID=4326;POINT(27.7 -26)'),
   NULL, NULL,
   'Rising Star Cave (South Africa) hominin; small-brained but contemporary with early Homo sapiens, suggesting late-surviving archaic morphology in Africa.'),

  ('CARR_HOMININ_NEANDERTHAL', 'Neanderthals', 'population',
   -400000, -40000, ST_GeogFromText('SRID=4326;POINT(15 47)'),
   'Mousterian', NULL,
   'Eurasian archaic humans, range from Iberia to Central Asia. Cold-adapted, robust skeletons; admixed with modern humans ~-55 kya, contributing 1–4% ancestry to all non-Africans.'),

  ('CARR_HOMININ_DENISOVAN', 'Denisovans', 'population',
   -300000, -50000, ST_GeogFromText('SRID=4326;POINT(85 51)'),
   NULL, NULL,
   'Sister archaic lineage to Neanderthals, known mainly from Siberian and Tibetan remains plus genomic traces in living people. Contributed 3–6% ancestry to modern Australasians and trace amounts to East Asians.'),

  ('CARR_HOMININ_FLORESIENSIS', 'Homo floresiensis', 'population',
   -100000, -50000, ST_GeogFromText('SRID=4326;POINT(121 -8.5)'),
   NULL, NULL,
   'Insular dwarf hominin on the Indonesian island of Flores; ~1 m tall, possibly descended from an early erectus dispersal.'),

  ('CARR_HOMININ_LUZONENSIS', 'Homo luzonensis', 'population',
   -67000, -50000, ST_GeogFromText('SRID=4326;POINT(120.6 18.1)'),
   NULL, NULL,
   'Late Pleistocene small-bodied hominin from Callao Cave on Luzon (Philippines); possibly a parallel insular lineage to floresiensis.');

-- ---------------------------------------------------------------------------
-- Early sapiens / pre-OOA source populations
-- ---------------------------------------------------------------------------

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_JEBEL_IRHOUD', 'Early Homo sapiens (Jebel Irhoud)', 'population',
   -315000, -250000, ST_GeogFromText('SRID=4326;POINT(-8.9 31.8)'),
   'Middle Stone Age', NULL,
   'Earliest known Homo sapiens fossils, from Jebel Irhoud (Morocco). Mosaic anatomy with elongated braincase but archaic facial features.'),

  ('CARR_HIST_OMO_HERTO', 'Early African sapiens (Omo / Herto)', 'population',
   -200000, -150000, ST_GeogFromText('SRID=4326;POINT(36 5.5)'),
   'Middle Stone Age', NULL,
   'East African anatomically modern humans (Omo Kibish, Herto Bouri), broadly considered the source population for later Homo sapiens diversity.'),

  ('CARR_HIST_KHOE_SAN_ANCESTRAL', 'Khoe-San ancestral lineage', 'population',
   -200000, -50000, ST_GeogFromText('SRID=4326;POINT(22 -28)'),
   NULL, NULL,
   'Southern African ancestral lineage that diverged from other modern human populations very early (~-200 to -300 kya by genetic estimates), source of modern Khoisan ancestry.'),

  ('CARR_HIST_AFR_EARLY_OOA_SOURCE', 'Pre-OOA Northeast African source', 'population',
   -100000, -65000, ST_GeogFromText('SRID=4326;POINT(35 18)'),
   'Middle Stone Age', NULL,
   'Northeast African / Horn of Africa population just before the Out-of-Africa bottleneck; ancestral to all non-African modern human populations.');

-- ---------------------------------------------------------------------------
-- Additional regional Upper Paleolithic / Mesolithic clusters
-- ---------------------------------------------------------------------------

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_UST_ISHIM', 'Ust''-Ishim individual / NE Eurasian UP', 'population',
   -46000, -42000, ST_GeogFromText('SRID=4326;POINT(71.2 57.7)'),
   'Initial Upper Paleolithic', NULL,
   'Western Siberian early modern human (Ust''-Ishim); represents an early Eurasian population shortly after the OOA dispersal, before East/West Eurasian split.'),

  ('CARR_HIST_KOSTENKI_SUNGIR', 'Kostenki / Sungir cluster', 'population',
   -37000, -22000, ST_GeogFromText('SRID=4326;POINT(39.5 51.4)'),
   'Streletskian / Sungirian', NULL,
   'Russian Plain Upper Paleolithic populations (Kostenki-14, Sungir); early West Eurasians with Aurignacian-related affinities and early ANE-like signal.'),

  ('CARR_HIST_HOFMEYR', 'Hofmeyr (Late Pleistocene S Africa)', 'population',
   -37000, -35000, ST_GeogFromText('SRID=4326;POINT(25.8 -31.6)'),
   'Late Stone Age', NULL,
   'Late Pleistocene South African individual showing affinities with Eurasian Upper Paleolithic populations rather than modern Khoisan.'),

  ('CARR_HIST_HOABINHIAN', 'Hoabinhian (SE Asia)', 'population',
   -44000, -4000, ST_GeogFromText('SRID=4326;POINT(105 18)'),
   'Hoabinhian', NULL,
   'Mainland Southeast Asian Late Pleistocene / Early Holocene hunter-gatherers; precursor population to modern East/Southeast Asians, with deep "basal East Asian" affinities.'),

  ('CARR_HIST_IBEROMAURUSIAN', 'Iberomaurusian / Taforalt (N Africa)', 'population',
   -23000, -11000, ST_GeogFromText('SRID=4326;POINT(-2.1 34.8)'),
   'Iberomaurusian', NULL,
   'Late Pleistocene North African foragers (Taforalt, Morocco); approx. two-thirds Natufian-like ancestry plus one-third Sub-Saharan African.'),

  ('CARR_HIST_ANDAMANESE', 'Andamanese (Onge / Jarawa)', 'population',
   -30000, 2025, ST_GeogFromText('SRID=4326;POINT(92.9 12.5)'),
   NULL, 'Great Andamanese / Ongan',
   'Andaman Islands foragers carrying a deep South Asian lineage ("Ancient Ancestral South Indian" / Onge-related), branching off from other Eurasians soon after OOA.');

-- ---------------------------------------------------------------------------
-- Holocene / historical ethnolinguistic carriers
-- ---------------------------------------------------------------------------

-- Mesopotamia / Levant
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_SUMERIAN', 'Sumerians', 'population',
   -3500, -2000, ST_GeogFromText('SRID=4326;POINT(45.7 30.9)'),
   'Uruk / Early Dynastic Sumer', 'Sumerian',
   'Southern Mesopotamian civilization; cuneiform writing, city-states (Ur, Uruk, Eridu), bronze metallurgy, irrigation agriculture.'),

  ('CARR_HIST_AKKADIAN', 'Akkadians', 'population',
   -2350, -2150, ST_GeogFromText('SRID=4326;POINT(44.4 33.1)'),
   'Akkadian Empire', 'Akkadian (Semitic)',
   'Semitic-speaking Mesopotamian empire under Sargon and Naram-Sin; first major political unification of Mesopotamia.'),

  ('CARR_HIST_BABYLONIAN', 'Babylonians', 'population',
   -1900, -540, ST_GeogFromText('SRID=4326;POINT(44.4 32.5)'),
   'Old / Neo-Babylonian', 'Akkadian (Babylonian dialect)',
   'Mesopotamian successor to Sumer/Akkad; Hammurabi''s Old Babylonian period and the Neo-Babylonian Empire under Nebuchadnezzar II.'),

  ('CARR_HIST_ASSYRIAN', 'Assyrians', 'population',
   -2000, -609, ST_GeogFromText('SRID=4326;POINT(43.1 36.4)'),
   'Old / Middle / Neo-Assyrian', 'Akkadian (Assyrian dialect)',
   'Northern Mesopotamian power centered on Ashur and Nineveh; Neo-Assyrian Empire was the dominant Near Eastern state from ~-900 to -609.'),

  ('CARR_HIST_HITTITE', 'Hittites', 'population',
   -1700, -1180, ST_GeogFromText('SRID=4326;POINT(34.6 40)'),
   'Hittite Empire', 'Hittite (Indo-European)',
   'Anatolian Indo-European-speaking state centered on Hattusa; major Late Bronze Age power, contemporary with New Kingdom Egypt.'),

  ('CARR_HIST_PHOENICIAN', 'Phoenicians', 'population',
   -1500, -300, ST_GeogFromText('SRID=4326;POINT(35.5 34.1)'),
   NULL, 'Phoenician (Semitic)',
   'Levantine maritime city-states (Tyre, Sidon, Byblos); spread the alphabet and founded colonies across the Mediterranean including Carthage.');

-- Egypt / North Africa
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_EGYPT_OK', 'Old Kingdom Egyptians', 'population',
   -2700, -2200, ST_GeogFromText('SRID=4326;POINT(31.1 29.9)'),
   'Old Kingdom Egypt', 'Old Egyptian',
   'Pyramid-builder period; centralized state along the Nile, hieroglyphic writing, administrative bureaucracy.'),

  ('CARR_HIST_EGYPT_MK_NK', 'Middle / New Kingdom Egyptians', 'population',
   -2050, -1070, ST_GeogFromText('SRID=4326;POINT(32.6 25.7)'),
   'Middle / New Kingdom Egypt', 'Middle / Late Egyptian',
   'Theban-centered Egypt during the Middle and New Kingdoms; imperial expansion into Nubia and the Levant under the 18th–20th Dynasties.'),

  ('CARR_HIST_CARTHAGINIAN', 'Carthaginians', 'population',
   -800, -146, ST_GeogFromText('SRID=4326;POINT(10.3 36.9)'),
   'Carthage / Punic', 'Punic (Phoenician dialect)',
   'Phoenician colonial power in North Africa; maritime empire across the western Mediterranean, defeated by Rome in the Punic Wars.'),

  ('CARR_HIST_BERBER', 'Berber / Amazigh peoples', 'population',
   -2000, 2025, ST_GeogFromText('SRID=4326;POINT(0 31)'),
   NULL, 'Berber (Afro-Asiatic)',
   'Indigenous North African pastoralist and agricultural populations from the Maghreb to the Siwa Oasis and the Sahara.');

-- Mediterranean / Europe
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_MYCENAEAN', 'Mycenaean Greeks', 'population',
   -1600, -1100, ST_GeogFromText('SRID=4326;POINT(22.7 37.7)'),
   'Mycenaean', 'Mycenaean Greek (Linear B)',
   'Late Bronze Age Aegean palace civilization; Linear B writing, citadels at Mycenae / Tiryns / Pylos, collapse ~-1100 in the Bronze Age Collapse.'),

  ('CARR_HIST_GREEK_CLASSICAL', 'Classical Greeks', 'population',
   -800, -300, ST_GeogFromText('SRID=4326;POINT(23.7 38)'),
   'Classical Greece', 'Ancient Greek',
   'Iron Age and Classical Greek city-states; Athenian democracy, Hellenic colonies across the Mediterranean and Black Sea, philosophy and science.'),

  ('CARR_HIST_ROMAN', 'Roman population (Italy)', 'population',
   -500, 500, ST_GeogFromText('SRID=4326;POINT(12.5 41.9)'),
   'Roman Republic / Empire', 'Latin',
   'Italian-peninsula Roman population from the Republic through the Western Empire; gradual admixture of Italic, Greek, North African, and eastern Mediterranean ancestry.'),

  ('CARR_HIST_BYZANTINE', 'Byzantines (East Roman)', 'population',
   330, 1453, ST_GeogFromText('SRID=4326;POINT(28.9 41)'),
   'Byzantine Empire', 'Medieval Greek',
   'Eastern Roman / Byzantine Empire centered on Constantinople; Greek-speaking, Orthodox Christian, surviving the West''s collapse by a millennium.'),

  ('CARR_HIST_CELTS', 'Celts / Gauls', 'population',
   -700, 100, ST_GeogFromText('SRID=4326;POINT(2.3 47)'),
   'La Tène / Hallstatt', 'Continental Celtic',
   'Iron Age Celtic-speaking peoples across central / western Europe and the British Isles; gradually incorporated into Rome or pushed to the Atlantic fringe.'),

  ('CARR_HIST_GERMANIC_IRON_AGE', 'Iron Age Germanic peoples', 'population',
   -500, 500, ST_GeogFromText('SRID=4326;POINT(10 53)'),
   'Jastorf / Roman-era Germanic', 'Proto-Germanic / Old Germanic',
   'Pre-migration-era Germanic-speaking peoples north of the Roman frontier; later expanded into the Western Empire during the Migration Period.'),

  ('CARR_HIST_NORSE', 'Norse / Vikings', 'population',
   700, 1100, ST_GeogFromText('SRID=4326;POINT(10 60)'),
   'Viking Age Scandinavia', 'Old Norse',
   'Scandinavian Viking-Age population; raiding and trading network from Vinland to Constantinople, founded settlements in Iceland, Greenland, the Danelaw, and the Kievan Rus.'),

  ('CARR_HIST_SLAVS_MEDIEVAL', 'Medieval Slavs', 'population',
   500, 1500, ST_GeogFromText('SRID=4326;POINT(28 50)'),
   NULL, 'Common Slavic / Old Church Slavonic',
   'Slavic-speaking peoples expanding across central / eastern Europe from the 6th c. onward; ancestral to modern Polish, Russian, Ukrainian, South Slavic populations.'),

  ('CARR_HIST_MEDIEVAL_W_EUROPEAN', 'Medieval Western European', 'population',
   800, 1500, ST_GeogFromText('SRID=4326;POINT(5 48)'),
   NULL, 'Old / Middle French / German / English',
   'Post-Carolingian Western European Christendom; feudal society, cathedrals, monasteries, gradual urbanization, the Black Death, late-medieval state formation.');

-- South / East Asia
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_VEDIC_ARYAN', 'Vedic Aryans / early Indo-Aryans', 'population',
   -1500, -500, ST_GeogFromText('SRID=4326;POINT(76 30)'),
   'Painted Grey Ware', 'Vedic Sanskrit',
   'Indo-Aryan-speaking population in the northwestern subcontinent during and after the Steppe migration; Rigveda composition, gradual eastward spread into the Gangetic plain.'),

  ('CARR_HIST_MAURYAN', 'Mauryan / classical-era Indians', 'population',
   -300, 200, ST_GeogFromText('SRID=4326;POINT(85.1 25.6)'),
   'Mauryan Empire', 'Prakrit / Classical Sanskrit',
   'Mauryan Empire (Chandragupta, Ashoka) and successor states; first major political unification of South Asia, spread of Buddhism, Indo-Greek and Kushan interactions.'),

  ('CARR_HIST_MUGHAL_N_INDIAN', 'Mughal-era North Indians', 'population',
   1500, 1857, ST_GeogFromText('SRID=4326;POINT(77.2 28.6)'),
   'Mughal Empire', 'Persian / Hindustani',
   'North Indian population under the Mughal Empire; Persianate court culture, Indo-Islamic architecture (Taj Mahal, Red Fort), gradual British encroachment after 1757.'),

  ('CARR_HIST_MODERN_S_ASIAN', 'Modern South Asians', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(78.9 21.7)'),
   NULL, 'Indo-Aryan / Dravidian',
   'Modern Indian, Pakistani, Bangladeshi, Sri Lankan, Nepali populations; broad ANI–ASI cline plus regional Tibeto-Burman and Austroasiatic admixture.'),

  ('CARR_HIST_SHANG', 'Shang Chinese', 'population',
   -1600, -1046, ST_GeogFromText('SRID=4326;POINT(114.4 36.1)'),
   'Shang Dynasty', 'Old Chinese',
   'Bronze Age Chinese state in the Yellow River valley; oracle bone script, ritual bronze vessels, chariot warfare. Earliest historically attested Chinese dynasty.'),

  ('CARR_HIST_HAN_CHINESE_EMPIRE', 'Han-dynasty Chinese', 'population',
   -200, 220, ST_GeogFromText('SRID=4326;POINT(108.9 34.3)'),
   'Han Dynasty', 'Eastern Han Chinese',
   'Han Empire; Confucian state ideology, expansion into Central Asia (Silk Road), Korea, Vietnam. The cultural template for later "Han" identity.'),

  ('CARR_HIST_TANG_CHINESE', 'Tang-era Chinese', 'population',
   600, 900, ST_GeogFromText('SRID=4326;POINT(108.9 34.3)'),
   'Tang Dynasty', 'Middle Chinese',
   'Tang Empire centered on Chang''an; cosmopolitan capital, Buddhist flowering, woodblock printing, Silk Road peak.'),

  ('CARR_HIST_MODERN_HAN', 'Modern Han Chinese', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(110 35)'),
   NULL, 'Mandarin / Wu / Yue / Min / Hakka',
   'Modern Han Chinese, the world''s largest ethnic group; substantial regional substructure across northern, central, and southern China.'),

  ('CARR_HIST_KHMER_ANGKOR', 'Khmer (Angkor)', 'population',
   800, 1431, ST_GeogFromText('SRID=4326;POINT(103.9 13.4)'),
   'Angkor / Khmer Empire', 'Old Khmer',
   'Khmer Empire centered on Angkor; massive temple complexes (Angkor Wat, Bayon), Indianized state with Hindu and Mahayana / Theravada Buddhist phases.'),

  ('CARR_HIST_MONGOL', 'Mongols (Steppe Empire)', 'population',
   1100, 1400, ST_GeogFromText('SRID=4326;POINT(106 47)'),
   'Mongol Empire', 'Middle Mongolic',
   'Mongol unification under Chinggis Khan and successors; the largest contiguous land empire in history, reshaping Eurasia from Korea to Hungary.');

-- Pacific / Australia
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_LAPITA', 'Lapita seafarers', 'population',
   -1500, -500, ST_GeogFromText('SRID=4326;POINT(166 -15)'),
   'Lapita', 'Proto-Oceanic',
   'Austronesian seafaring population spreading across Near and Remote Oceania; ancestral to Polynesians, characterized by distinctive dentate-stamped pottery.'),

  ('CARR_HIST_POLYNESIAN', 'Polynesian voyagers', 'population',
   -500, 1300, ST_GeogFromText('SRID=4326;POINT(-150 -17)'),
   NULL, 'Proto-Polynesian / Polynesian',
   'Austronesian descendants of the Lapita expansion; settled Tonga, Samoa, the Marquesas, Hawaii, Aotearoa (NZ), and Rapa Nui via long-distance ocean voyaging.'),

  ('CARR_HIST_MAORI', 'Maori', 'population',
   1300, 2025, ST_GeogFromText('SRID=4326;POINT(174 -41)'),
   NULL, 'Maori (Polynesian)',
   'Polynesian settlers of Aotearoa (New Zealand) from ~1300 CE; iwi-based society, distinct material culture, displaced and reconstituted under European colonization.');

-- Americas
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_MAYA_CLASSICAL', 'Classic Maya', 'population',
   250, 900, ST_GeogFromText('SRID=4326;POINT(-89.6 17.2)'),
   'Classic Maya', 'Mayan languages',
   'Lowland Maya city-states (Tikal, Calakmul, Palenque, Copán); hieroglyphic writing, Long Count calendar, monumental temple-pyramids, "Classic Collapse" by ~900 CE.'),

  ('CARR_HIST_AZTEC', 'Aztec / Mexica', 'population',
   1300, 1521, ST_GeogFromText('SRID=4326;POINT(-99.1 19.4)'),
   'Aztec / Mexica', 'Classical Nahuatl',
   'Triple Alliance (Tenochtitlan, Texcoco, Tlacopan) dominating central Mexico; conquered by Cortés and Tlaxcalan allies in 1519–1521.'),

  ('CARR_HIST_INCA', 'Inca / Tawantinsuyu', 'population',
   1400, 1533, ST_GeogFromText('SRID=4326;POINT(-71.9 -13.5)'),
   'Inca Empire', 'Quechua / Aymara',
   'Andean empire stretching from modern Colombia to Chile; quipu record-keeping, terraced agriculture, road network, conquered by Pizarro 1532–1533.'),

  ('CARR_HIST_MISSISSIPPIAN', 'Mississippian (Cahokia and successors)', 'population',
   800, 1400, ST_GeogFromText('SRID=4326;POINT(-90.1 38.7)'),
   'Mississippian', 'various (Siouan / Caddoan / Muskogean)',
   'North American mound-building societies of the Mississippi and Ohio river valleys; Cahokia was the largest pre-Columbian city north of Mexico.'),

  ('CARR_HIST_MODERN_LATIN_AMER_MESTIZO', 'Modern Latin American (Mestizo)', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(-65 -10)'),
   NULL, 'Spanish / Portuguese',
   'Modern Latin American populations of mixed Indigenous American, European, and African ancestry, varying widely by country and region.'),

  ('CARR_HIST_MODERN_NATIVE_AMER', 'Modern Native Americans', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(-105 45)'),
   NULL, 'various (Algonquian / Siouan / Athabaskan / etc.)',
   'Indigenous peoples of the Americas in the modern era; reduced to a fraction of pre-contact populations by epidemics and colonization, with major cultural and linguistic continuities preserved.');

-- Africa (Holocene / historical)
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_NUBIAN_KUSHITE', 'Nubians / Kushites', 'population',
   -2500, 350, ST_GeogFromText('SRID=4326;POINT(31 19)'),
   'Kerma / Napatan / Meroitic', 'Nubian / Meroitic',
   'Nile Valley civilizations south of Egypt (Kerma, Kush, Meroe); periodically rivals to and overlords of Egypt (25th "Black Pharaoh" Dynasty).'),

  ('CARR_HIST_AKSUMITE', 'Aksumite (Ethiopian)', 'population',
   -100, 940, ST_GeogFromText('SRID=4326;POINT(38.7 14.1)'),
   'Aksum', 'Ge''ez',
   'Aksumite Kingdom of the Ethiopian highlands; major trading state on the Red Sea, early adopter of Christianity (4th c.), minted coinage.'),

  ('CARR_HIST_MALI_EMPIRE', 'Mali Empire', 'population',
   1230, 1670, ST_GeogFromText('SRID=4326;POINT(-7 14)'),
   'Mali Empire', 'Mande / Manding',
   'West African Sahel empire (Mansa Musa''s Mali); gold-and-salt trade across the Sahara, Timbuktu as a Muslim scholarly center.'),

  ('CARR_HIST_KHOISAN_MODERN', 'Modern Khoisan', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(20 -25)'),
   NULL, 'Khoe / San (Tuu / Kx''a)',
   'Modern Khoisan-speaking populations of southern Africa (Ju|''hoansi, Hai||om, Khwe, etc.); deepest-diverged modern human lineage.'),

  ('CARR_HIST_MODERN_W_AFRICAN', 'Modern West Africans', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(2 8)'),
   NULL, 'Niger-Congo (various)',
   'Modern West African populations (Yoruba, Igbo, Akan, Mande, etc.); descendants of the Bantu-source region but distinct linguistically and culturally.'),

  ('CARR_HIST_MODERN_E_AFRICAN', 'Modern East Africans', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(35 0)'),
   NULL, 'Bantu / Cushitic / Nilotic',
   'Modern East African populations (Bantu-speakers like Kikuyu / Luhya, Cushitic-speakers like Somali / Oromo, Nilotic-speakers like Maasai / Dinka).');

-- Steppe / Central Asia / Iran
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_SCYTHIAN', 'Scythians', 'population',
   -700, 300, ST_GeogFromText('SRID=4326;POINT(45 47)'),
   'Scythian / Saka', 'Scythian (Eastern Iranian)',
   'Iron Age Eurasian steppe pastoralist confederations from the Pontic-Caspian to the Altai; mounted archers, animal-style art, kurgans.'),

  ('CARR_HIST_HUNS', 'Huns (Eurasian steppe)', 'population',
   100, 500, ST_GeogFromText('SRID=4326;POINT(50 50)'),
   NULL, NULL,
   'Steppe confederation invading Europe under Attila in the 5th century; trigger of the Migration Period and contributor to the Western Roman collapse.'),

  ('CARR_HIST_TURKIC_GOKTURK', 'Gökturks (Turkic Khaganate)', 'population',
   550, 750, ST_GeogFromText('SRID=4326;POINT(95 47)'),
   'Turkic Khaganate', 'Old Turkic',
   'First Turkic Khaganate; Orkhon inscriptions, source population for the later spread of Turkic languages from Anatolia to Central Asia.'),

  ('CARR_HIST_OTTOMAN', 'Ottomans', 'population',
   1300, 1922, ST_GeogFromText('SRID=4326;POINT(28.9 41)'),
   'Ottoman Empire', 'Ottoman Turkish',
   'Ottoman Empire from the Anatolian beylik to the post-WWI dissolution; ruled the Balkans, Anatolia, Levant, Egypt, and parts of North Africa for ~6 centuries.'),

  ('CARR_HIST_SOGDIAN', 'Sogdians', 'population',
   -100, 1000, ST_GeogFromText('SRID=4326;POINT(67 39)'),
   'Sogdian / Samarkand', 'Sogdian (Eastern Iranian)',
   'Central Asian Iranian-speaking trader population along the Silk Road (Samarkand, Bukhara); cultural broker between China, Iran, and Byzantium.'),

  ('CARR_HIST_ACHAEMENID', 'Achaemenid Persians', 'population',
   -550, -330, ST_GeogFromText('SRID=4326;POINT(53 32)'),
   'Achaemenid Persia', 'Old Persian',
   'First Persian Empire under Cyrus, Darius, Xerxes; spanned the Indus to Macedonia, ended by Alexander.'),

  ('CARR_HIST_SASANIAN', 'Sasanian Persians', 'population',
   224, 651, ST_GeogFromText('SRID=4326;POINT(48.4 32.5)'),
   'Sasanian Empire', 'Middle Persian',
   'Sasanian (late Persian) Empire; Zoroastrian state religion, Roman/Byzantine rival, conquered by the early Islamic caliphates.');

-- Arab / Islamic world
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_RASHIDUN_UMAYYAD', 'Rashidun / Umayyad Arabs', 'population',
   632, 750, ST_GeogFromText('SRID=4326;POINT(36.3 33.5)'),
   'Early Caliphates', 'Classical Arabic',
   'Early Islamic conquests under the Rashidun and Umayyad Caliphates; from the Arabian peninsula to Iberia and the Indus within a century.'),

  ('CARR_HIST_ABBASID', 'Abbasid Caliphate', 'population',
   750, 1258, ST_GeogFromText('SRID=4326;POINT(44.4 33.3)'),
   'Abbasid Caliphate', 'Classical Arabic',
   'Abbasid Caliphate centered on Baghdad; "Islamic Golden Age" of mathematics, medicine, astronomy, philosophy, and translation.'),

  ('CARR_HIST_MOORS_AL_ANDALUS', 'Moors / Al-Andalus', 'population',
   711, 1492, ST_GeogFromText('SRID=4326;POINT(-3.7 37.2)'),
   'Al-Andalus', 'Andalusi Arabic / Mozarabic',
   'Muslim Iberia from the Umayyad conquest to the fall of Granada; Córdoba caliphate, Toledo translation school, distinctive Andalusi culture.');

-- Modern (additional regional)
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  ('CARR_HIST_MODERN_E_ASIAN', 'Modern East Asians (broad)', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(125 38)'),
   NULL, 'Sinitic / Japonic / Koreanic',
   'Modern Han Chinese, Japanese, Korean, plus regional minorities; broadly East Asian ancestry with Jomon (Japan) and Tibeto-Burman (W China) substructure.'),

  ('CARR_HIST_MODERN_EUROPEAN', 'Modern Europeans', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(15 50)'),
   NULL, 'Indo-European (mostly)',
   'Modern European populations; broadly mixed Steppe + EEF + WHG + later admixture, with regional clines (more EEF in S Europe, more Steppe in N/E Europe).'),

  ('CARR_HIST_MODERN_SE_ASIAN', 'Modern Southeast Asians', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(108 12)'),
   NULL, 'Austronesian / Austroasiatic / Tai-Kadai',
   'Modern Southeast Asian populations (Vietnamese, Thai, Burmese, Filipino, Indonesian, Malay, etc.); mix of Hoabinhian-related, East Asian agriculturalist, and Austronesian ancestry.'),

  ('CARR_HIST_MODERN_ARAB', 'Modern Arabs', 'population',
   1900, 2025, ST_GeogFromText('SRID=4326;POINT(45 25)'),
   NULL, 'Modern Standard Arabic / regional dialects',
   'Modern Arabic-speaking populations from the Maghreb to the Levant and Arabian peninsula; regional substructure with Berber, Levantine, and Iranian influence.');
