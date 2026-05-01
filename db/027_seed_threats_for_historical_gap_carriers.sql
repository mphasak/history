-- 027_seed_threats_for_historical_gap_carriers.sql
--
-- Threats for the prominent long-lived historical-era carriers that the
-- drift report flagged as having no `carrier_threat` rows. Without these,
-- the DetailPanel "Threats at {year}" section is empty for the most
-- recognizable populations on the map (Sumerians, Berbers, Holy Roman
-- Empire, Heian-Tokugawa Japan, Bell Beaker, Anatolian Farmers, etc.).
--
-- Date windows, severities, and short descriptions reflect broad
-- consensus historical record. Each threat is cited via an
-- [AUTO-THREAT-027] tagged Carrier-subject claim, which in turn cites
-- DEDUCED_PHASE_0.
--
-- Idempotent on the [AUTO-THREAT-027] tag.

BEGIN;

DELETE FROM carrier_threat
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-THREAT-027]%');
DELETE FROM claim_source
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-THREAT-027]%');
DELETE FROM claim WHERE statement LIKE '[AUTO-THREAT-027]%';

CREATE TEMP TABLE _threats_027 (
  carrier_id text,
  threat_type text,
  display_name text,
  description text,
  severity int,
  year_min int,
  year_max int
) ON COMMIT DROP;

INSERT INTO _threats_027 (carrier_id, threat_type, display_name, description, severity, year_min, year_max) VALUES
  -- Neolithic founder farmer populations
  ('CARR_ANATOLIAN_FARMER',  'climate',          '8.2 kiloyear event',
   'Abrupt cooling and aridification ~6200 BCE coincided with disruption / dispersal of central Anatolian farming villages, accelerating the Neolithic spread into Europe.', 3, -6300, -6100),
  ('CARR_ANATOLIAN_FARMER',  'displacement',     'Indo-European Steppe pressure',
   'Successive waves of Yamnaya / Corded Ware-derived gene flow from the Pontic-Caspian Steppe diluted the Anatolian-farmer ancestry across Europe and Anatolia from ~3000 BCE onward.', 3, -3000, -1500),
  ('CARR_IRAN_NEOLITHIC',    'climate',          '8.2 kiloyear event',
   'Same global cooling event stressed early Zagros agropastoral communities; some sites contracted while the broader IRN_N gene pool spread into S. Asia.', 3, -6300, -6100),
  ('CARR_IRAN_NEOLITHIC',    'displacement',     'Caucasus + Steppe admixture',
   'Late-Neolithic and Bronze-Age incoming gene flow (CHG, then Steppe_MLBA) reshaped Iran-plateau populations through the 4th and 3rd millennia BCE.', 2, -5000, -2000),

  -- Early Holocene China
  ('CARR_HIST_HOL_HEMUDU',   'climate',          'Mid-Holocene sea-level highstand',
   'Yangtze delta marine transgression ~5000-4000 BCE periodically inundated the lowland Hemudu sites, pushing settlement onto higher terraces.', 3, -5000, -3500),
  ('CARR_HIST_HOL_HONGSHAN', 'climate',          'Late-Neolithic cooling',
   'Aridification and cooling in NE China ~3000 BCE coincided with the abandonment of major Hongshan ceremonial centers (Niuheliang).', 3, -3300, -2800),

  -- Mesopotamia
  ('CARR_HIST_SUMERIAN',     'climate',          '4.2 kiloyear event',
   'Severe drought ~2200-2100 BCE collapsed the Akkadian Empire and depopulated southern Mesopotamian cities; written sources lament "people scattering".', 5, -2200, -2000),
  ('CARR_HIST_SUMERIAN',     'war',              'Akkadian + Amorite conquests',
   'Sargon of Akkad (~2334 BCE) absorbed the Sumerian city-states; later Amorite (Old Babylonian) dynasties replaced Sumerian dynasts and language by ~2000 BCE.', 5, -2334, -2000),
  ('CARR_HIST_SUMERIAN',     'assimilation_pressure', 'Akkadian linguistic replacement',
   'Sumerian persisted as a sacred / scribal language but was no longer a vernacular by ~1800 BCE; the Sumerian ethnos dissolved into Akkadian-speaking Babylonia.', 4, -2300, -1500),

  -- Bronze Age Europe
  ('CARR_BELL_BEAKER',       'displacement',     'Replacement by successor cultures',
   'Across western Europe Bell Beaker communities transitioned into Únětice, Wessex, Atlantic Bronze Age, and other regional successors during the 19th-17th c. BCE.', 2, -1900, -1700),
  ('CARR_BELL_BEAKER',       'climate',          '4.2 kiloyear cooling',
   'Cooling and aridification stressed early Beaker pastoral economies in Iberia and the British Isles in the late 3rd millennium BCE.', 2, -2200, -1900),

  -- North Africa & deep Sahara
  ('CARR_HIST_BERBER',       'colonization',     'Roman conquest of N Africa',
   'Punic Wars to Mauretanian annexation (264 BCE - 44 CE) brought Numidia, Mauretania, and the Atlas Berbers under Roman provincial rule with garrisons and tribute.', 4, -200, 400),
  ('CARR_HIST_BERBER',       'colonization',     'Arab conquests + Islamization',
   'Umayyad armies overran Egypt-to-Morocco between 642 and 711 CE; pastoralist resistance (Kahina, Kusayla) was suppressed and Arabic + Islam became dominant over centuries.', 5, 642, 1100),
  ('CARR_HIST_BERBER',       'colonization',     'French + Italian colonization',
   'France (Algeria 1830, Tunisia 1881, Morocco 1912) and Italy (Libya 1911) imposed settler colonialism, broke up tribal land tenure, and suppressed Berber language schooling.', 5, 1830, 1962),

  -- Pre-Inca / pre-Columbian South America
  ('CARR_HIST_BRIDGE_CUPISNIQUE', 'climate',     'Late formative reorganization',
   'Climatic shifts and inter-valley competition closed the Cupisnique horizon ~500 BCE; populations reorganized into Salinar / Gallinazo successors.', 3, -700, -400),
  ('CARR_HIST_BRIDGE_PARACAS',    'displacement','Absorption into Nazca',
   'The Paracas tradition transitioned into early Nazca by ~100 CE; the population continued but the Paracas cultural identity dissolved.', 2, -100, 200),
  ('CARR_HIST_BRIDGE_AMAZON_FORMATIVE','disease','European-disease pulse',
   'Pre- and post-contact epidemic disease (Spanish, Portuguese, Jesuit missions) collapsed Amazonian formative populations from ~1500 onwards; many archaeological complexes lack clear ethnographic successors.', 5, 1500, 1700),

  -- Sahara
  ('CARR_HIST_BRIDGE_GARAMANTES','climate',     'Aquifer exhaustion',
   'Foggara-irrigation farming depended on fossil aquifers; drawdown from ~400 CE forced abandonment of many oases and demographic decline.', 4, 400, 700),
  ('CARR_HIST_BRIDGE_GARAMANTES','colonization','Arab conquests',
   'Successor Berber polities were absorbed into the Umayyad / Abbasid orbit ~660-700 CE; the distinct Garamantian polity ceased to exist.', 4, 650, 750),

  -- Silk Road
  ('CARR_HIST_SOGDIAN',      'colonization',     'Arab conquest of Transoxiana',
   'Qutayba ibn Muslim''s campaigns 705-715 CE brought Sogdiana under Umayyad rule; subsequent revolts (Mukanna, 770s) were crushed and Sogdian language Islamized.', 5, 705, 800),
  ('CARR_HIST_SOGDIAN',      'assimilation_pressure', 'Persianization + Turkicization',
   'After conversion the Sogdian language and identity were progressively replaced by New Persian and incoming Turkic vernaculars; only Yaghnobi survives as a remnant.', 4, 800, 1100),

  -- Pre-contact southwestern N. America
  ('CARR_HIST_BRIDGE_ANASAZI', 'climate',         'Great Drought',
   'Tree-ring-documented megadrought ~1276-1299 CE forced abandonment of Mesa Verde, Chaco, and the Four Corners cliff dwellings.', 5, 1130, 1300),
  ('CARR_HIST_BRIDGE_HOHOKAM', 'climate',         'Salt River flooding + drought',
   'Extreme floods (1358, 1382) destroyed canal systems, followed by mid-15th-c. drought; Phoenix-basin population reorganized into smaller Pima / Tohono O''odham successors.', 4, 1350, 1500),
  ('CARR_HIST_BRIDGE_FREMONT', 'climate',         'Medieval Drought',
   'Persistent drying ~1100-1300 CE ended Fremont maize horticulture across the eastern Great Basin; populations dispersed into mobile foraging groups.', 4, 1100, 1300),

  -- East Asian dynastic chains
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA', 'war',  'Mongol invasions of Japan',
   'Yuan-dynasty invasion fleets in 1274 and 1281 destroyed coastal samurai forces before being scattered by typhoons ("kamikaze"); subsequent defense costs destabilized the Kamakura shogunate.', 4, 1274, 1281),
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA', 'war',  'Sengoku civil wars',
   'Century of inter-daimyō warfare 1467-1600 (Ōnin War to Sekigahara) caused widespread peasant displacement and famine before Tokugawa unification.', 4, 1467, 1615),
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA', 'colonization', 'Forced opening + Meiji rupture',
   'Perry expedition 1853 forced Japan open; Boshin War 1868 and Meiji Restoration ended the Tokugawa order and the warrior caste.', 3, 1853, 1868),

  ('CARR_HIST_BRIDGE_PC_GORYEO_JOSEON',  'war',  'Mongol invasions of Korea',
   'Six campaigns 1231-1259 devastated the peninsula; Goryeo became a Yuan vassal state until 1356.', 5, 1231, 1356),
  ('CARR_HIST_BRIDGE_PC_GORYEO_JOSEON',  'war',  'Imjin War (Hideyoshi invasions)',
   'Toyotomi Hideyoshi''s invasions 1592-1598 caused massive destruction; pottery industries crippled by mass abduction of artisans to Japan.', 5, 1592, 1598),
  ('CARR_HIST_BRIDGE_PC_GORYEO_JOSEON',  'colonization', 'Japanese annexation',
   'Korea annexed by Japan 1910-1945; cultural-suppression policies (forced Japanese names, language, Shinto worship) intensified during WWII.', 5, 1910, 1945),

  ('CARR_HIST_BRIDGE_PC_MING_QING',      'war',  'Manchu conquest',
   'Qing forces overthrew the Ming 1644; conquest of southern China and resistance suppression continued through the 1660s with millions killed.', 5, 1644, 1683),
  ('CARR_HIST_BRIDGE_PC_MING_QING',      'war',  'Taiping Rebellion',
   '1850-1864 civil war killed an estimated 20-30 million people, the largest 19th-c. conflict by death toll.', 5, 1850, 1864),
  ('CARR_HIST_BRIDGE_PC_MING_QING',      'colonization', 'Opium Wars + unequal treaties',
   'British / French interventions 1839-42 and 1856-60, plus subsequent foreign concessions, eroded Qing sovereignty and ended in Boxer-era 1900 occupation of Beijing.', 5, 1839, 1901),

  ('CARR_HIST_BRIDGE_PC_VIETNAM_DYNASTIES','war','Mongol invasions of Đại Việt',
   'Three Yuan-dynasty invasions (1258, 1285, 1287-88) all repulsed at heavy cost by the Trần dynasty.', 4, 1258, 1288),
  ('CARR_HIST_BRIDGE_PC_VIETNAM_DYNASTIES','colonization','French conquest of Indochina',
   'Cochinchina annexed 1862; protectorate over the rest of the country 1883; French rule until 1945.', 5, 1862, 1945),

  ('CARR_HIST_BRIDGE_PC_AYUTTHAYA_RATTANAKOSIN','war','Burmese sack of Ayutthaya',
   'Konbaung-dynasty Burmese forces destroyed the Ayutthaya capital in 1767 after a 14-month siege; the new Thonburi / Rattanakosin polity rebuilt from Bangkok.', 5, 1765, 1782),

  -- Europe long durée
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',     'disease', 'Black Death',
   'Plague pandemic 1347-1352 killed an estimated 30-50% of central European population; demographic recovery took a century.', 5, 1347, 1400),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',     'war',  'Thirty Years War',
   '1618-1648 religious-political war devastated the German lands; estimated 20-40% mortality in some regions, the worst pre-modern European demographic disaster.', 5, 1618, 1648),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',     'war',  'Napoleonic dissolution',
   'Defeats by Napoleonic France (Austerlitz 1805, etc.) led Francis II to abolish the Holy Roman Empire in 1806.', 4, 1792, 1815),

  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM', 'disease', 'Black Death',
   'Plague pandemic 1347-1352 killed an estimated 40-50% of the French population; recurrent outbreaks for two centuries afterwards.', 5, 1347, 1400),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM', 'war',  'Hundred Years War',
   '1337-1453 dynastic-and-territorial war with England devastated the countryside; combined with plague, France lost roughly half its population.', 5, 1337, 1453),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM', 'war',  'French Wars of Religion',
   'Eight civil wars 1562-1598 between Catholic and Huguenot factions; St. Bartholomew''s Day Massacre 1572 emblematic.', 4, 1562, 1598),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM', 'war',  'French Revolution + Reign of Terror',
   '1789 revolution overthrew the monarchy; Reign of Terror 1793-94 executed nobility, clergy, and political opponents en masse.', 5, 1789, 1799),

  -- Mediterranean
  ('CARR_HIST_MOORS_AL_ANDALUS', 'war',           'Reconquista',
   'Christian Iberian kingdoms reduced Al-Andalus over 781 years (711 → 1492 fall of Granada); 1492 also brought mass expulsion / forced conversion of Muslims and Jews.', 5, 1031, 1492),
  ('CARR_HIST_MOORS_AL_ANDALUS', 'genocide',     'Morisco expulsion',
   'Forced conversions, Inquisition trials, and the 1609-1614 expulsion removed an estimated 300,000 descendants of Andalusi Muslims from Iberia.', 5, 1492, 1614),

  -- Caliphate
  ('CARR_HIST_ABBASID',         'war',           'Mongol sack of Baghdad',
   'Hulagu Khan''s 1258 sack destroyed Baghdad and ended the Abbasid Caliphate as a temporal power; estimated 200,000-1,000,000 deaths and the destruction of the House of Wisdom library.', 5, 1257, 1260),

  -- Caribbean
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN', 'genocide','Atlantic slave trade',
   'Roughly 4-5 million enslaved Africans landed in the Caribbean 1500-1850; mortality on the Middle Passage and on plantations was catastrophic.', 5, 1500, 1850),
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN', 'natural_disaster','Recurrent hurricanes',
   'Caribbean basin sits in the Atlantic hurricane belt; major storms (1780 Great Hurricane, 1928 Okeechobee, recent Maria 2017, Dorian 2019) repeatedly devastate island societies.', 4, 1500, 2025);

-- Step 1: one claim per (carrier_id, threat display_name).
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', carrier_id,
       '[AUTO-THREAT-027] ' || carrier_id || ' :: ' || display_name,
       3
FROM _threats_027;

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim WHERE statement LIKE '[AUTO-THREAT-027]%';

-- Step 2: threats joining back to those claims by the encoded statement tag.
INSERT INTO carrier_threat (carrier_id, threat_type, display_name, description, severity, date_min_year, date_max_year, claim_id)
SELECT t.carrier_id, t.threat_type::threat_type, t.display_name, t.description,
       t.severity, t.year_min, t.year_max,
       c.id
FROM _threats_027 t
JOIN claim c
  ON c.subject_type = 'Carrier'
 AND c.subject_id = t.carrier_id
 AND c.statement = '[AUTO-THREAT-027] ' || t.carrier_id || ' :: ' || t.display_name;

COMMIT;
