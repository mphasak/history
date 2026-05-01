-- 026_seed_postclassical_bridge_carriers.sql
--
-- The seed had a giant ~1000-year coverage gap in major regions: e.g.
-- at 1600 CE the map showed *nothing* in China (Tang ended 907,
-- Modern Han starts 1900) or in much of mainland Europe (Byzantine
-- ended 1453, Modern European starts 1900). This seed adds the
-- post-classical / early-modern bridges that should obviously be
-- there:
--
--   * China: Late Imperial (Ming + Qing, 1368-1912)
--   * Japan: Heian → Tokugawa (794-1868)
--   * Korea: Goryeo + Joseon (918-1910)
--   * India: Delhi Sultanate (1206-1526) — bridges Mauryan → Mughal
--   * Europe (broad): Renaissance → Enlightenment (1300-1800)
--   * Russia: Tsardom + Empire (1547-1917)
--   * Spain: Habsburg + early Bourbon (1516-1808)
--   * England: Tudor + Stuart (1485-1714)
--   * Italy: Renaissance city-states (1300-1800)
--   * Poland-Lithuania: Commonwealth (1569-1795)
--   * Iran: Safavid + Qajar (1501-1925)
--   * Vietnam: Lý / Trần / Lê / Nguyễn (1009-1945)
--   * Thailand: Ayutthaya + Rattanakosin (1351-1932)
--   * Indonesia: Majapahit + Mataram (1293-1755)
--
-- All cited via DEDUCED_PHASE_0; idempotent on the
-- CARR_HIST_BRIDGE_PC_* prefix. trait_mix entries follow the
-- region's broader genetic profile (Modern E Asian for the East
-- Asian dynasties, Modern European derivatives for European bridges,
-- etc.) — these aren't headline ancestry events, they're
-- demographic continuations.

DELETE FROM carrier_trait_mix WHERE carrier_id LIKE 'CARR_HIST_BRIDGE_PC_%';
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_BRIDGE_PC_%'
);
DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_BRIDGE_PC_%';
DELETE FROM carrier WHERE id LIKE 'CARR_HIST_BRIDGE_PC_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- Asia
  ('CARR_HIST_BRIDGE_PC_MING_QING', 'Late Imperial Chinese (Ming + Qing)', 'population',
   1368, 1912, ST_GeogFromText('SRID=4326;POINT(116.4 39.9)'),
   NULL, 'Sinitic',
   'Han Chinese demographic continuity from the founding of Ming through the fall of Qing — bridges Tang/Song to Modern Han. Population swelled from ~80 M (1500) to ~430 M (1850). Literati examination system, neo-Confucian orthodoxy, Manchu rule from 1644.'),
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA', 'Heian → Tokugawa Japan', 'population',
   794, 1868, ST_GeogFromText('SRID=4326;POINT(135.7 35.0)'),
   NULL, 'Japanese',
   'A millennium of Japanese feudal continuity: Heian aristocracy, Kamakura / Muromachi shogunates, Sengoku warring states, Tokugawa peace. Shintō + Buddhist religious synthesis; rigid Tokugawa social classes; sakoku isolation 1635-1854.'),
  ('CARR_HIST_BRIDGE_PC_GORYEO_JOSEON', 'Goryeo + Joseon Korea', 'population',
   918, 1910, ST_GeogFromText('SRID=4326;POINT(126.9 37.5)'),
   NULL, 'Korean',
   'Korean dynastic continuity from the founding of Goryeo through the Japanese annexation. Confucian state, hangul invented under Sejong (1443), Imjin War (1592-1598), tributary relations with Ming + Qing.'),
  ('CARR_HIST_BRIDGE_PC_DELHI_SULTANATE', 'Delhi Sultanate', 'population',
   1206, 1526, ST_GeogFromText('SRID=4326;POINT(77.2 28.6)'),
   NULL, 'Persian + Hindavi',
   'Five successive Muslim Turkic / Afghan dynasties ruling much of the north Indian subcontinent: Mamluk, Khalji, Tughlaq, Sayyid, Lodi. Bridges between the post-Gupta period and Mughal arrival; Persian as court language, Indo-Islamic architectural synthesis.'),
  ('CARR_HIST_BRIDGE_PC_SAFAVID_QAJAR', 'Safavid + Qajar Iran', 'population',
   1501, 1925, ST_GeogFromText('SRID=4326;POINT(51.4 35.7)'),
   NULL, 'Persian',
   'Twelver Shi''ism established as state religion under the Safavids; Persian high culture flourishes (Isfahan, miniature painting, poetry). Qajar dynasty rules from late 18th c. through constitutional revolution.'),
  ('CARR_HIST_BRIDGE_PC_VIETNAM_DYNASTIES', 'Vietnamese dynasties (Lý → Nguyễn)', 'population',
   1009, 1945, ST_GeogFromText('SRID=4326;POINT(105.8 21.0)'),
   NULL, 'Vietnamese',
   'Vietnamese dynastic continuity from independence under the Lý dynasty through Nguyễn. Sinitic literary culture, expansion southward (Nam Tiến) absorbing Cham + Khmer territories.'),
  ('CARR_HIST_BRIDGE_PC_AYUTTHAYA_RATTANAKOSIN', 'Ayutthaya + Rattanakosin (Thailand)', 'population',
   1351, 1932, ST_GeogFromText('SRID=4326;POINT(100.5 13.7)'),
   NULL, 'Thai',
   'Thai polity from Ayutthaya through the founding of Bangkok and the constitutional revolution of 1932. Theravada Buddhism, Indian-derived royal cosmology, only SE Asian state never colonized.'),
  ('CARR_HIST_BRIDGE_PC_MAJAPAHIT_MATARAM', 'Majapahit + Mataram (insular SE Asia)', 'population',
   1293, 1755, ST_GeogFromText('SRID=4326;POINT(110.4 -7.0)'),
   NULL, 'Javanese + Malay',
   'Javanese-led Hindu-Buddhist Majapahit thalassocracy succeeded by the Islamicized Mataram sultanate. Ends with Dutch VOC partition. Spice-trade entrepôt economy.'),

  -- Europe
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE', 'Renaissance / Reformation / Enlightenment Europe', 'population',
   1300, 1800, ST_GeogFromText('SRID=4326;POINT(7.0 47.0)'),
   NULL, 'multiple Indo-European',
   'Pan-European demographic continuity 1300-1800 covering everything from the Italian Renaissance and Northern Renaissance through the Reformation, Wars of Religion, Scientific Revolution, and Enlightenment. Population recovery after the 1347-1351 Black Death.'),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA', 'Tsardom + Russian Empire', 'population',
   1547, 1917, ST_GeogFromText('SRID=4326;POINT(37.6 55.8)'),
   NULL, 'Russian',
   'Muscovite Tsardom under Ivan IV through the Romanov empire to the 1917 revolutions. Eastward expansion across Siberia, Petrine modernization, serfdom (until 1861), Crimean / Russo-Japanese / WWI defeats.'),
  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART', 'Tudor + Stuart England', 'population',
   1485, 1714, ST_GeogFromText('SRID=4326;POINT(-0.1 51.5)'),
   NULL, 'English',
   'England from Henry VII through Anne. Anglican Reformation, English Civil War, Restoration, Glorious Revolution, foundation of the Bank of England, beginning of the Atlantic empire.'),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN', 'Habsburg + early-Bourbon Spain', 'population',
   1516, 1808, ST_GeogFromText('SRID=4326;POINT(-3.7 40.4)'),
   NULL, 'Spanish',
   'Habsburg Spain at its imperial height (Charles V, Philip II) through the early Bourbon period. American silver, Inquisition, golden-age literature (Cervantes, Velázquez), 18th-c. enlightened reforms.'),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'Italian city-states + Papal States', 'population',
   1300, 1800, ST_GeogFromText('SRID=4326;POINT(12.5 41.9)'),
   NULL, 'Italian',
   'Florence, Venice, Milan, Genoa, Naples, Rome — the polycentric Italian peninsula from Petrarch through Napoleonic invasion. Renaissance, Counter-Reformation, baroque, Grand Tour.'),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA', 'Polish-Lithuanian Commonwealth', 'population',
   1569, 1795, ST_GeogFromText('SRID=4326;POINT(21.0 52.2)'),
   NULL, 'Polish + Ruthenian + Lithuanian',
   'Elective-monarchy multi-ethnic commonwealth: szlachta noble democracy, religious tolerance, Hussar cavalry, partitioned out of existence by Russia / Prussia / Austria 1772-1795.'),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM', 'Capetian / Valois / Bourbon France', 'population',
   987, 1789, ST_GeogFromText('SRID=4326;POINT(2.3 48.9)'),
   NULL, 'French',
   'French royal continuity from Hugh Capet through Louis XVI. Plantagenet wars, Valois centralization, Wars of Religion, absolute monarchy under Louis XIV, philosophes, ending in the Revolution.'),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN', 'Holy Roman Empire / German lands', 'population',
   962, 1806, ST_GeogFromText('SRID=4326;POINT(11.0 50.0)'),
   NULL, 'High German + Low German',
   'The patchwork of duchies, free cities, and ecclesiastical principalities loosely under the Holy Roman Emperor — from Otto I through Napoleon''s dissolution. Hanseatic trade, Reformation flashpoint, Thirty Years'' War cataclysm.');

-- Provenance
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is a post-classical / early-modern bridge carrier added so the ' ||
       'map doesn''t look depopulated between the classical empires (~500 CE) ' ||
       'and the modern continental carriers (~1900 CE); see DEDUCED_PHASE_0.',
       3
FROM carrier WHERE id LIKE 'CARR_HIST_BRIDGE_PC_%';

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id LIKE 'CARR_HIST_BRIDGE_PC_%';

-- Trait mixes — broad regional ancestry profiles. Era-window is at the
-- midpoint of each carrier's range.
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- East Asian dynasties
  ('CARR_HIST_BRIDGE_PC_MING_QING',         'EAST_ASIAN', 1.000, 1700),
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA',    'EAST_ASIAN', 0.700, 1300),
  ('CARR_HIST_BRIDGE_PC_HEIAN_TOKUGAWA',    'JOMON',      0.300, 1300),
  ('CARR_HIST_BRIDGE_PC_GORYEO_JOSEON',     'EAST_ASIAN', 1.000, 1500),
  ('CARR_HIST_BRIDGE_PC_VIETNAM_DYNASTIES', 'EAST_ASIAN', 1.000, 1500),
  ('CARR_HIST_BRIDGE_PC_AYUTTHAYA_RATTANAKOSIN', 'EAST_ASIAN', 1.000, 1700),
  ('CARR_HIST_BRIDGE_PC_MAJAPAHIT_MATARAM', 'EAST_ASIAN', 0.700, 1500),
  ('CARR_HIST_BRIDGE_PC_MAJAPAHIT_MATARAM', 'AUS_PNG',    0.300, 1500),

  -- Indian / Persian
  ('CARR_HIST_BRIDGE_PC_DELHI_SULTANATE',   'ANI',         0.450, 1400),
  ('CARR_HIST_BRIDGE_PC_DELHI_SULTANATE',   'ASI',         0.300, 1400),
  ('CARR_HIST_BRIDGE_PC_DELHI_SULTANATE',   'STEPPE_MLBA', 0.150, 1400),
  ('CARR_HIST_BRIDGE_PC_DELHI_SULTANATE',   'IRN_N',       0.100, 1400),
  ('CARR_HIST_BRIDGE_PC_SAFAVID_QAJAR',     'IRN_N',       0.500, 1700),
  ('CARR_HIST_BRIDGE_PC_SAFAVID_QAJAR',     'NATUFIAN',    0.250, 1700),
  ('CARR_HIST_BRIDGE_PC_SAFAVID_QAJAR',     'STEPPE_MLBA', 0.150, 1700),
  ('CARR_HIST_BRIDGE_PC_SAFAVID_QAJAR',     'ANATOLIAN_FARMER', 0.100, 1700),

  -- European
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','ANATOLIAN_FARMER', 0.350, 1600),
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','STEPPE_MLBA',     0.300, 1600),
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','WHG',             0.150, 1600),
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','IRN_N',           0.100, 1600),
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','EHG',             0.080, 1600),
  ('CARR_HIST_BRIDGE_PC_RENAISSANCE_EUROPE','NEANDERTHAL',     0.020, 1600),

  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'STEPPE_MLBA',     0.350, 1750),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'EHG',             0.250, 1750),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'ANATOLIAN_FARMER',0.200, 1750),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'WHG',             0.080, 1750),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'EAST_ASIAN',      0.080, 1750),
  ('CARR_HIST_BRIDGE_PC_ROMANOV_RUSSIA',    'NEANDERTHAL',     0.020, 1750),

  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART',      'ANATOLIAN_FARMER',0.350, 1600),
  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART',      'STEPPE_MLBA',     0.300, 1600),
  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART',      'WHG',             0.180, 1600),
  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART',      'IRN_N',           0.100, 1600),
  ('CARR_HIST_BRIDGE_PC_TUDOR_STUART',      'NEANDERTHAL',     0.020, 1600),

  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'ANATOLIAN_FARMER',0.400, 1650),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'STEPPE_MLBA',     0.250, 1650),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'WHG',             0.140, 1650),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'IRN_N',           0.100, 1650),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'NATUFIAN',        0.080, 1650),
  ('CARR_HIST_BRIDGE_PC_HABSBURG_SPAIN',    'NEANDERTHAL',     0.020, 1650),

  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'ANATOLIAN_FARMER',0.450, 1500),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'STEPPE_MLBA',     0.250, 1500),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'WHG',             0.130, 1500),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'IRN_N',           0.100, 1500),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'NATUFIAN',        0.050, 1500),
  ('CARR_HIST_BRIDGE_PC_ITALY_RENAISSANCE', 'NEANDERTHAL',     0.020, 1500),

  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'STEPPE_MLBA',     0.380, 1700),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'ANATOLIAN_FARMER',0.300, 1700),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'EHG',             0.150, 1700),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'WHG',             0.100, 1700),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'IRN_N',           0.050, 1700),
  ('CARR_HIST_BRIDGE_PC_POLAND_LITHUANIA',  'NEANDERTHAL',     0.020, 1700),

  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM',    'ANATOLIAN_FARMER',0.380, 1500),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM',    'STEPPE_MLBA',     0.300, 1500),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM',    'WHG',             0.180, 1500),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM',    'IRN_N',           0.100, 1500),
  ('CARR_HIST_BRIDGE_PC_FRENCH_KINGDOM',    'NEANDERTHAL',     0.020, 1500),

  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'ANATOLIAN_FARMER',0.330, 1500),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'STEPPE_MLBA',     0.350, 1500),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'WHG',             0.180, 1500),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'IRN_N',           0.080, 1500),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'EHG',             0.060, 1500),
  ('CARR_HIST_BRIDGE_PC_HOLY_ROMAN',         'NEANDERTHAL',     0.020, 1500)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE]%';
