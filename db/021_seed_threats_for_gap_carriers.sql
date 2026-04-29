-- 021_seed_threats_for_gap_carriers.sql
--
-- Threats for the 24 CARR_HIST_GAP_* / CARR_HIST_BRIDGE_* /
-- CARR_HIST_POST1492_* carriers that the drift report flagged as having
-- no entries in `carrier_threat`. The DetailPanel surfaces threats per
-- year, so without these the bottom half of the inspector is empty for
-- a third of the post-005 carriers.
--
-- Each threat is editorially seeded — date windows, severities, and
-- short descriptions reflect the broad consensus historical record.
-- Cited via the [AUTO-THREAT-021] tagged Carrier-subject claim, which
-- in turn cites DEDUCED_PHASE_0.
--
-- Idempotent on the [AUTO-THREAT-021] tag.

BEGIN;

DELETE FROM carrier_threat
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-THREAT-021]%');
DELETE FROM claim_source
WHERE claim_id IN (SELECT id FROM claim WHERE statement LIKE '[AUTO-THREAT-021]%');
DELETE FROM claim WHERE statement LIKE '[AUTO-THREAT-021]%';

-- One claim per (carrier_id, threat display_name) row, then threats join
-- back to those claims by matching the statement tag. PostgreSQL doesn't
-- allow data-modifying CTEs inside LATERAL, so we pass it in two steps.
CREATE TEMP TABLE _threats_021 (
  carrier_id text,
  threat_type text,
  display_name text,
  description text,
  severity int,
  year_min int,
  year_max int
) ON COMMIT DROP;

INSERT INTO _threats_021 (carrier_id, threat_type, display_name, description, severity, year_min, year_max) VALUES
  -- South America
  ('CARR_HIST_GAP_MOCHE',     'climate',          'El Niño megadroughts',
   'Severe ENSO-related droughts and floods in the late-Moche period contributed to the abandonment of major centers (~600-800 CE).', 4, 500, 800),
  ('CARR_HIST_GAP_NAZCA',     'climate',          'Late-Holocene aridification',
   'Increasing desertification and over-tapping of subterranean aquifers (puquios); contributed to settlement decline.', 3, 400, 800),
  ('CARR_HIST_GAP_WARI',      'climate',          'Medieval Drought',
   'Prolonged drought in the Andes ~900-1100 CE undermined Wari''s irrigation-fed agriculture and accelerated state collapse.', 4, 900, 1100),
  ('CARR_HIST_GAP_TIWANAKU',  'climate',          'Medieval Drought',
   'Same Medieval Drought event terminated raised-field agriculture around Lake Titicaca.', 4, 900, 1100),
  ('CARR_HIST_GAP_MARAJOARA', 'displacement',     'European arrival',
   'Cultural collapse and demographic displacement during the late-pre-contact and early-contact periods.', 4, 1400, 1600),
  ('CARR_HIST_GAP_MAPUCHE',   'colonization',     'Spanish + Chilean conquest',
   'Centuries of Spanish and later Chilean military pressure (Arauco War 1536-1818, Pacification 1861-1883); maintained partial autonomy until late 19th c.', 5, 1536, 1900),

  -- Mesoamerica
  ('CARR_HIST_GAP_TEOTIHUACAN', 'war',         'Sack of the city',
   'Internal uprising and burning of the ceremonial center ~550 CE marks the political collapse of the metropolis.', 5, 540, 600),
  ('CARR_HIST_GAP_TEOTIHUACAN', 'climate',     'Mid-6th-century cooling',
   'Volcanic-aerosol cooling and crop failure compounded the city''s decline.', 3, 535, 600),
  ('CARR_HIST_GAP_ZAPOTEC',   'war',          'Aztec tributary status',
   'Reduced to tributary status after Aztec conquests in the late 15th c.; substantial autonomy retained but cultural pressure increased.', 3, 1450, 1521),
  ('CARR_HIST_GAP_ZAPOTEC',   'colonization', 'Spanish conquest',
   'Forced labor, Catholic conversion, demographic collapse from European disease epidemics post-1521.', 5, 1521, 1600),
  ('CARR_HIST_GAP_MIXTEC',    'colonization', 'Spanish conquest',
   'Same post-1521 colonization shock as Zapotec; surviving Mixtec codices document the pre-contact royal genealogies.', 5, 1521, 1600),
  ('CARR_HIST_GAP_TOLTEC',    'war',          'Internal collapse of Tula',
   'Tula abandoned in the early 12th c. amid drought and warfare; remnants absorbed into successor polities.', 4, 1100, 1200),
  ('CARR_HIST_GAP_PUREPECHA', 'colonization', 'Spanish conquest',
   'Submission to Cortés in 1525, killing of king Tangaxuan II, dismantling of the Tarascan state.', 5, 1521, 1600),
  ('CARR_HIST_GAP_TAINO',     'disease',      'Old-world epidemics',
   'Smallpox, measles, and influenza killed an estimated 80-95% of the Hispaniola population within decades of contact.', 5, 1492, 1550),
  ('CARR_HIST_GAP_TAINO',     'genocide',     'Encomienda system',
   'Forced labor, mass killing, and family breakup under Spanish encomienda; recognized today as a genocide.', 5, 1500, 1600),

  -- Sub-Saharan Africa
  ('CARR_HIST_GAP_BANTU_EXPANSION', 'displacement',  'Pygmy / Khoisan displacement',
   'Bantu agricultural expansion displaced or absorbed earlier forager populations across central and southern Africa.', 3, -1000, 500),
  ('CARR_HIST_GAP_GHANA_EMPIRE',    'war',           'Almoravid invasion',
   'Almoravid attacks and conversion pressure on the western Sahel ~1076 CE accelerated the empire''s decline.', 4, 1076, 1240),
  ('CARR_HIST_GAP_MALI_EMPIRE',     'war',           'Songhai supersession',
   'Internal succession crises and Songhai expansion stripped territory and prestige through the 15th c.', 4, 1400, 1600),
  ('CARR_HIST_GAP_SONGHAI',         'war',           'Battle of Tondibi',
   'Moroccan firearm-equipped force under Judar Pasha shattered the empire''s field army at Tondibi in 1591.', 5, 1590, 1610),
  ('CARR_HIST_GAP_GREAT_ZIMBABWE',  'climate',       'Late-medieval drought',
   'Drying of the central plateau ~1450; soil exhaustion and trade-route shifts forced abandonment of the capital.', 4, 1400, 1500),
  ('CARR_HIST_GAP_KONGO',           'colonization',  'Atlantic slave trade',
   'Centuries of Portuguese-driven slave trade, civil war (Battle of Mbwila, 1665), and partition between Portugal and Belgium.', 5, 1500, 1914),
  ('CARR_HIST_GAP_SWAHILI_COAST',   'colonization',  'Portuguese conquest',
   'Vasco da Gama and successors looted Kilwa, Mombasa, and Mozambique 1500s; trade re-routed under Portuguese forts.', 5, 1500, 1700),
  ('CARR_HIST_GAP_ASANTE',          'war',           'Anglo-Ashanti wars',
   'Five wars with Britain 1823-1900; final annexation as part of Gold Coast colony.', 5, 1823, 1902),
  ('CARR_HIST_GAP_ETHIOPIAN_HIGHLAND','war',         'Mahdist + Italian invasions',
   'Late-19th-c. Mahdist incursions and the 1895-96 Italian invasion (defeated at Adwa); 1935-41 Italian occupation.', 5, 1880, 1941),

  -- Pacific
  ('CARR_HIST_GAP_LAPITA',     'displacement',  'Settlement saturation',
   'Pacific island ecosystems became fully colonized by ~500 BCE; founder voyaging culture transitions into local Polynesian identities.', 2, -700, -500),
  ('CARR_HIST_GAP_POLYNESIAN_EXP','displacement', 'European contact',
   'Cook''s voyages 1769-1779 began European exploration, missionization, disease introduction, and colonization across the Pacific.', 4, 1750, 1850),
  ('CARR_HIST_GAP_HAWAIIAN',   'disease',       'Old-world epidemics',
   'Smallpox, measles, syphilis cumulatively killed most of the pre-contact Hawaiian population by the late 19th c.', 5, 1800, 1900),
  ('CARR_HIST_GAP_HAWAIIAN',   'colonization',  'US annexation',
   'Coup against Queen Liliʻuokalani in 1893; annexation in 1898; statehood in 1959.', 5, 1893, 1959),
  ('CARR_HIST_GAP_MAORI',      'colonization',  'British colonization',
   'Treaty of Waitangi 1840; subsequent New Zealand Wars 1845-1872; large-scale land confiscation; population trough ~1896.', 5, 1840, 1900),

  -- Siberia / Arctic
  ('CARR_HIST_GAP_CHUKCHI',    'colonization',  'Russian conquest',
   'Cossack expeditions 1640s-1750s; treaty of formal Russian sovereignty 1789; epidemic disease decimated the population.', 4, 1640, 1900),
  ('CARR_HIST_GAP_YAKUT',      'colonization',  'Russian conquest',
   'Yakutia incorporated into the Tsardom 1638; tribute (yasak) imposed; smallpox and measles epidemics through the 18th c.', 4, 1620, 1900),
  ('CARR_HIST_GAP_THULE_INUIT','climate',       'Little Ice Age',
   'Cooling 1300-1850 forced abandonment of high-Arctic settlements; some groups moved south, others resorted to lower-protein winter strategies.', 3, 1300, 1850),

  -- North America
  ('CARR_HIST_GAP_MISSISSIPPIAN','climate',     'Medieval Drought + LIA',
   'Drought ~1300 CE undermined maize agriculture at Cahokia; Little Ice Age cooling ~1450 finished the largest centers.', 4, 1200, 1500),
  ('CARR_HIST_GAP_MISSISSIPPIAN','disease',     'Old-world epidemics',
   'De Soto-era 1540s and later epidemics killed an estimated 50-90% of the surviving Mississippian successor populations.', 5, 1540, 1700),
  ('CARR_HIST_GAP_HAUDENOSAUNEE','war',         'Beaver Wars',
   'Mid-17th c. campaigns to control the fur trade displaced or destroyed several other Iroquoian nations (Hurons, Eries, Susquehannocks).', 4, 1640, 1701),
  ('CARR_HIST_GAP_HAUDENOSAUNEE','war',         'American Revolution',
   'Confederacy split (Oneida + Tuscarora pro-American, others pro-British); Sullivan campaign 1779 destroyed villages and crops.', 5, 1775, 1800),
  ('CARR_HIST_GAP_NAVAJO_APACHE','war',         'Long Walk',
   'US Army campaign 1863-64 forced ~10,000 Navajo on the Long Walk to Bosque Redondo; ~25% died en route or in detention.', 5, 1863, 1868);

-- Step 1: one claim per (carrier_id, threat display_name).
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', carrier_id,
       '[AUTO-THREAT-021] ' || carrier_id || ' :: ' || display_name,
       3
FROM _threats_021;

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim WHERE statement LIKE '[AUTO-THREAT-021]%';

-- Step 2: threats joining back to those claims by the encoded statement tag.
INSERT INTO carrier_threat (carrier_id, threat_type, display_name, description, severity, date_min_year, date_max_year, claim_id)
SELECT t.carrier_id, t.threat_type::threat_type, t.display_name, t.description,
       t.severity, t.year_min, t.year_max,
       c.id
FROM _threats_021 t
JOIN claim c
  ON c.subject_type = 'Carrier'
 AND c.subject_id = t.carrier_id
 AND c.statement = '[AUTO-THREAT-021] ' || t.carrier_id || ' :: ' || t.display_name;

COMMIT;
