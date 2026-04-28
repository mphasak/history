-- 004_seed_population_genetics.sql
--
-- Reich-style population genetics: ancestry components and the population
-- groups that carry them, from Out-of-Africa (~-60 kya) through Iron Age.
--
-- Trait mixes are approximate; values are taken from the broader admixture
-- literature (Reich, Lazaridis, Mathieson, Narasimhan et al.) and rounded
-- for visualization. Within-domain fractions sum to ~1.0.
--
-- Idempotent: ON CONFLICT for traits/carriers, DELETE+INSERT for carrier_trait_mix
-- scoped to the IDs this file creates.

-- ---------------------------------------------------------------------------
-- New genetic ancestry components
-- ---------------------------------------------------------------------------

INSERT INTO trait (id, domain, display_name, description) VALUES
  ('AFR_BASAL',        'genetic', 'Deep African (Basal)',
   'Deeply-rooted Sub-Saharan African ancestry, ancestral to most modern African populations.'),
  ('AFR_WEST',         'genetic', 'West African',
   'West African ancestry, source population for the Bantu expansion (Yoruba/Mende-like).'),
  ('AFR_KHOISAN',      'genetic', 'Khoisan / San',
   'Southern African Khoisan-related ancestry; deeply diverged from other African lineages.'),
  ('IRN_N',            'genetic', 'Iranian Neolithic',
   'Iranian/Zagros Neolithic farmer ancestry (Ganj Dareh-like).'),
  ('ANATOLIAN_FARMER', 'genetic', 'Anatolian Neolithic Farmer',
   'Anatolian Neolithic ancestry (Boncuklu / Çatalhöyük-like); ancestral to EEF.'),
  ('NATUFIAN',         'genetic', 'Natufian',
   'Levantine Late Pleistocene / Early Holocene ancestry (pre-Neolithic Natufian).'),
  ('AUS_PNG',          'genetic', 'Australasian',
   'Combined Australian Aboriginal + Papuan / New Guinean ancestry component.'),
  ('AMER_NA',          'genetic', 'First Americans',
   'Native American ancestry derived from a Beringian source population.'),
  ('EAST_ASIAN',       'genetic', 'East Asian',
   'Generic East Asian ancestry component (post-Tianyuan radiation).'),
  ('JOMON',            'genetic', 'Jomon',
   'Jomon Japanese ancestry; basal East Asian-like with deep divergence.'),
  ('NEANDERTHAL',      'genetic', 'Neanderthal (archaic)',
   'Archaic Neanderthal admixture, present at 1–4% in non-African populations.'),
  ('DENISOVAN',        'genetic', 'Denisovan (archaic)',
   'Archaic Denisovan admixture, elevated in Australasians (3–6%) and present at trace levels in East Asians.')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- New carriers
-- ---------------------------------------------------------------------------

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES
  ('CARR_OOA_LEVANT_55K',     'Out-of-Africa Levantine source population',  'population',
   -60000, -45000, ST_GeogFromText('SRID=4326;POINT(35 31)'),
   NULL, NULL,
   'The Out-of-Africa source population in the Levant/Arabia, after the bottleneck and Neanderthal admixture event but before differentiation into West and East Eurasian lineages.'),

  ('CARR_AUS_ABORIGINAL',     'Australian Aboriginal populations',          'population',
   -45000, 2025, ST_GeogFromText('SRID=4326;POINT(134 -25)'),
   NULL, 'Pama-Nyungan (and others)',
   'Continuous Australian Aboriginal population since initial Sahul colonization ~45 kya. Carries elevated Denisovan admixture.'),

  ('CARR_PAPUAN_45K',         'Papuan / New Guinean populations',           'population',
   -45000, 2025, ST_GeogFromText('SRID=4326;POINT(143 -6)'),
   NULL, 'Papuan',
   'New Guinean population, sister branch of Australian Aboriginals after Sahul split. Carries the highest Denisovan ancestry observed.'),

  ('CARR_TIANYUAN_40K',       'Tianyuan / early East Asian',                'population',
   -42000, -36000, ST_GeogFromText('SRID=4326;POINT(116.5 39.7)'),
   'Initial Upper Paleolithic', NULL,
   'Tianyuan-cluster Upper Paleolithic population in northern China; basal-East-Asian-like, related to but predating modern East Asians.'),

  ('CARR_AURIGNACIAN_EU',     'Aurignacian / Goyet Q116-1 cluster',         'population',
   -42000, -28000, ST_GeogFromText('SRID=4326;POINT(2 47)'),
   'Aurignacian', NULL,
   'Western European Upper Paleolithic population (GoyetQ116-like), early modern human Europeans with elevated Basal Eurasian-related ancestry.'),

  ('CARR_GRAVETTIAN_EU',      'Gravettian / Vestonice cluster',             'population',
   -33000, -22000, ST_GeogFromText('SRID=4326;POINT(15 48)'),
   'Gravettian', NULL,
   'Central/Eastern European Gravettian population (Vestonice cluster), ancestral to later European hunter-gatherers (WHG-related).'),

  ('CARR_MALTA_24K',          'Mal''ta-Buret'' (Ancient North Eurasians)',   'population',
   -24000, -16000, ST_GeogFromText('SRID=4326;POINT(103 53)'),
   'Mal''ta-Buret''', NULL,
   'Mal''ta boy and related Siberian Upper Paleolithic populations; type specimen for the Ancient North Eurasian (ANE) ancestry component, contributor to both Native Americans and post-LGM Eurasians.'),

  ('CARR_PALEO_AMER_15K',     'First Americans (Paleo-Indians)',            'population',
   -16000, -10000, ST_GeogFromText('SRID=4326;POINT(-115 50)'),
   'Clovis (and pre-Clovis)', NULL,
   'Initial peopling of the Americas via Beringia; Anzick-1-like ancestry, ~65% First American + ~35% ANE admixture.'),

  ('CARR_NATUFIAN_12K',       'Natufian (Levant)',                          'population',
   -13000, -9500, ST_GeogFromText('SRID=4326;POINT(35.5 32.5)'),
   'Natufian', NULL,
   'Late Pleistocene / Epipaleolithic Levantine population; sedentary pre-agricultural foragers, ancestor of Levantine Neolithic populations.'),

  ('CARR_WHG_MESO',           'Western European Hunter-Gatherers (Mesolithic)', 'population',
   -12000, -7000, ST_GeogFromText('SRID=4326;POINT(5 49)'),
   'Mesolithic (Loschbour, La Braña, Cheddar)', NULL,
   'Mesolithic hunter-gatherers across western Europe, characterized by dark skin and blue eyes (per Loschbour and La Braña-1 ancient DNA).'),

  ('CARR_EHG_MESO',           'Eastern European Hunter-Gatherers (Mesolithic)', 'population',
   -12000, -5500, ST_GeogFromText('SRID=4326;POINT(40 60)'),
   'Mesolithic (Karelia, Samara)', NULL,
   'Mesolithic hunter-gatherers of the eastern European plain; intermediate between WHG and ANE.'),

  ('CARR_CHG_MESO',           'Caucasus Hunter-Gatherers',                  'population',
   -13000, -7000, ST_GeogFromText('SRID=4326;POINT(44 42)'),
   'Mesolithic (Satsurblia, Kotias)', NULL,
   'Late Pleistocene / Early Holocene Caucasus hunter-gatherers; type ancestry for half of the Yamnaya admixture.'),

  ('CARR_JOMON',              'Jomon Japanese',                             'population',
   -10000, -300, ST_GeogFromText('SRID=4326;POINT(140 38)'),
   'Jomon', NULL,
   'Hunter-gatherer / pottery-producing population of the Japanese archipelago; basal-East-Asian-like, partial ancestor of modern Ainu and Japanese.'),

  ('CARR_ANATOLIAN_FARMER',   'Anatolian Neolithic Farmers',                'population',
   -8500, -6500, ST_GeogFromText('SRID=4326;POINT(33 38)'),
   'Pre-Pottery Neolithic / Çatalhöyük', NULL,
   'Anatolian Neolithic farming population (Boncuklu, Çatalhöyük); source of Early European Farmer (EEF) ancestry.'),

  ('CARR_IRAN_NEOLITHIC',     'Iranian Neolithic Farmers',                  'population',
   -8000, -5500, ST_GeogFromText('SRID=4326;POINT(47 35)'),
   'Zagros Neolithic (Ganj Dareh)', NULL,
   'Iranian/Zagros Neolithic farmers; distinct from Anatolian Neolithic, source of major ancestry in later Indus Valley populations.'),

  ('CARR_YAMNAYA',            'Yamnaya Steppe Pastoralists',                'population',
   -3300, -2500, ST_GeogFromText('SRID=4326;POINT(40 47)'),
   'Yamnaya / Pit Grave', 'Late Proto-Indo-European',
   'Pontic-Caspian steppe pastoralists; classical ~50/50 EHG+CHG mix; vector of Steppe ancestry into Europe and South Asia.'),

  ('CARR_BELL_BEAKER',        'Bell Beaker complex (Western Europe)',       'population',
   -2800, -1800, ST_GeogFromText('SRID=4326;POINT(2 50)'),
   'Bell Beaker', NULL,
   'Western European Bronze Age population descended from Yamnaya admixed with local EEF/Neolithic; near-total replacement of pre-Beaker British populations.'),

  ('CARR_HARAPPAN',           'Harappan / Indus Valley Civilization',       'population',
   -2600, -1900, ST_GeogFromText('SRID=4326;POINT(71 27.5)'),
   'Indus Valley Civilization', 'Unknown (proto-Dravidian?)',
   'Mature urban civilization of the Indus Valley; ancestry approximately Iranian Neolithic-related + AASI (Ancestral South Indian).'),

  ('CARR_BANTU_EXPANSION',    'Bantu expansion source (West-Central Africa)','population',
   -3000, 1000, ST_GeogFromText('SRID=4326;POINT(13 7)'),
   NULL, 'Proto-Bantu',
   'West-Central African source population of the Bantu agricultural expansion that spread across sub-equatorial Africa.')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- carrier_trait_mix entries
-- ---------------------------------------------------------------------------

DELETE FROM carrier_trait_mix WHERE carrier_id IN (
  'CARR_OOA_LEVANT_55K','CARR_AUS_ABORIGINAL','CARR_PAPUAN_45K','CARR_TIANYUAN_40K',
  'CARR_AURIGNACIAN_EU','CARR_GRAVETTIAN_EU','CARR_MALTA_24K','CARR_PALEO_AMER_15K',
  'CARR_NATUFIAN_12K','CARR_WHG_MESO','CARR_EHG_MESO','CARR_CHG_MESO','CARR_JOMON',
  'CARR_ANATOLIAN_FARMER','CARR_IRAN_NEOLITHIC','CARR_YAMNAYA','CARR_BELL_BEAKER',
  'CARR_HARAPPAN','CARR_BANTU_EXPANSION'
);

INSERT INTO carrier_trait_mix (carrier_id, as_of_year, domain, trait_id, fraction) VALUES
  -- OOA Levantine source: deep African + recent Neanderthal admixture
  ('CARR_OOA_LEVANT_55K', -55000, 'genetic', 'AFR_BASAL', 0.97),
  ('CARR_OOA_LEVANT_55K', -55000, 'genetic', 'NEANDERTHAL', 0.03),

  -- Australian Aboriginals: Australasian + elevated archaics
  ('CARR_AUS_ABORIGINAL', -30000, 'genetic', 'AUS_PNG', 0.93),
  ('CARR_AUS_ABORIGINAL', -30000, 'genetic', 'NEANDERTHAL', 0.04),
  ('CARR_AUS_ABORIGINAL', -30000, 'genetic', 'DENISOVAN', 0.03),

  -- Papuans: Australasian + highest Denisovan
  ('CARR_PAPUAN_45K', -30000, 'genetic', 'AUS_PNG', 0.91),
  ('CARR_PAPUAN_45K', -30000, 'genetic', 'NEANDERTHAL', 0.04),
  ('CARR_PAPUAN_45K', -30000, 'genetic', 'DENISOVAN', 0.05),

  -- Tianyuan: early East Asian + Basal Eurasian
  ('CARR_TIANYUAN_40K', -40000, 'genetic', 'EAST_ASIAN', 0.78),
  ('CARR_TIANYUAN_40K', -40000, 'genetic', 'BASAL_EURASIAN', 0.18),
  ('CARR_TIANYUAN_40K', -40000, 'genetic', 'NEANDERTHAL', 0.04),

  -- Aurignacian Europe: WHG-precursor + elevated Basal Eurasian
  ('CARR_AURIGNACIAN_EU', -32000, 'genetic', 'WHG', 0.55),
  ('CARR_AURIGNACIAN_EU', -32000, 'genetic', 'BASAL_EURASIAN', 0.30),
  ('CARR_AURIGNACIAN_EU', -32000, 'genetic', 'ANE', 0.10),
  ('CARR_AURIGNACIAN_EU', -32000, 'genetic', 'NEANDERTHAL', 0.05),

  -- Gravettian: WHG-related + ANE
  ('CARR_GRAVETTIAN_EU', -28000, 'genetic', 'WHG', 0.83),
  ('CARR_GRAVETTIAN_EU', -28000, 'genetic', 'ANE', 0.13),
  ('CARR_GRAVETTIAN_EU', -28000, 'genetic', 'NEANDERTHAL', 0.04),

  -- Mal'ta: nearly pure ANE
  ('CARR_MALTA_24K', -24000, 'genetic', 'ANE', 0.95),
  ('CARR_MALTA_24K', -24000, 'genetic', 'NEANDERTHAL', 0.05),

  -- Paleo-Americans: First Americans + ANE (Mal'ta admixture)
  ('CARR_PALEO_AMER_15K', -14000, 'genetic', 'AMER_NA', 0.65),
  ('CARR_PALEO_AMER_15K', -14000, 'genetic', 'ANE', 0.32),
  ('CARR_PALEO_AMER_15K', -14000, 'genetic', 'NEANDERTHAL', 0.03),

  -- Natufians: Levantine + small African back-migration
  ('CARR_NATUFIAN_12K', -12000, 'genetic', 'NATUFIAN', 0.93),
  ('CARR_NATUFIAN_12K', -12000, 'genetic', 'AFR_BASAL', 0.05),
  ('CARR_NATUFIAN_12K', -12000, 'genetic', 'NEANDERTHAL', 0.02),

  ('CARR_WHG_MESO', -8000, 'genetic', 'WHG', 0.97),
  ('CARR_WHG_MESO', -8000, 'genetic', 'NEANDERTHAL', 0.03),

  ('CARR_EHG_MESO', -7000, 'genetic', 'EHG', 0.97),
  ('CARR_EHG_MESO', -7000, 'genetic', 'NEANDERTHAL', 0.03),

  ('CARR_CHG_MESO', -9000, 'genetic', 'CHG', 0.97),
  ('CARR_CHG_MESO', -9000, 'genetic', 'NEANDERTHAL', 0.03),

  ('CARR_JOMON', -5000, 'genetic', 'JOMON', 0.97),
  ('CARR_JOMON', -5000, 'genetic', 'NEANDERTHAL', 0.03),

  ('CARR_ANATOLIAN_FARMER', -7500, 'genetic', 'ANATOLIAN_FARMER', 0.97),
  ('CARR_ANATOLIAN_FARMER', -7500, 'genetic', 'NEANDERTHAL', 0.03),

  ('CARR_IRAN_NEOLITHIC', -7000, 'genetic', 'IRN_N', 0.97),
  ('CARR_IRAN_NEOLITHIC', -7000, 'genetic', 'NEANDERTHAL', 0.03),

  -- Yamnaya: classic ~50% EHG + ~50% CHG
  ('CARR_YAMNAYA', -3000, 'genetic', 'EHG', 0.50),
  ('CARR_YAMNAYA', -3000, 'genetic', 'CHG', 0.45),
  ('CARR_YAMNAYA', -3000, 'genetic', 'NEANDERTHAL', 0.05),

  -- Bell Beaker: ~50% Yamnaya + ~50% EEF
  ('CARR_BELL_BEAKER', -2300, 'genetic', 'YAMNAYA', 0.50),
  ('CARR_BELL_BEAKER', -2300, 'genetic', 'EEF', 0.45),
  ('CARR_BELL_BEAKER', -2300, 'genetic', 'WHG', 0.03),
  ('CARR_BELL_BEAKER', -2300, 'genetic', 'NEANDERTHAL', 0.02),

  -- Harappan: Iran_N + AASI (ASI), per Narasimhan 2019 reconstruction
  ('CARR_HARAPPAN', -2400, 'genetic', 'IRN_N', 0.55),
  ('CARR_HARAPPAN', -2400, 'genetic', 'ASI', 0.40),
  ('CARR_HARAPPAN', -2400, 'genetic', 'NEANDERTHAL', 0.05),

  -- Bantu source: West African + small basal/Khoisan
  ('CARR_BANTU_EXPANSION', -1500, 'genetic', 'AFR_WEST', 0.85),
  ('CARR_BANTU_EXPANSION', -1500, 'genetic', 'AFR_BASAL', 0.10),
  ('CARR_BANTU_EXPANSION', -1500, 'genetic', 'AFR_KHOISAN', 0.05);
