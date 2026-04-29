-- 011_holocene_carrier_threats.sql
--
-- Adds threats for the Holocene gap-filler carriers from 010 plus a few
-- threats for the older Pleistocene/Mesolithic carriers that 007 left
-- empty. Without these, clicking on e.g. Cucuteni-Trypillia or a Predynastic
-- Egyptian dot in the DetailPanel shows no "Threats at {year}" section.
--
-- Most Holocene carrier collapses share the same handful of abrupt-climate
-- forcings — the 8.2 ka cooling, the 5.9 ka aridification (which ends the
-- Green Sahara), the 4.2 ka aridification (which ends the Old Kingdom and
-- the Akkadian Empire), and the 3.2 ka Late Bronze Age megadrought — so
-- those events recur with citations to the same papers.
--
-- Idempotent: re-uses the [AUTO-THREAT] statement-prefix idempotency from
-- 007. The DELETE in 007 wipes all `[AUTO-THREAT]%` claims, so this file
-- must run AFTER 007 (it does — see docker-compose.yml ordering).

-- Local helper (mirrors 007's, redeclared here so 011 can run standalone).
CREATE OR REPLACE FUNCTION _seed_threat_011(
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
-- Holocene carriers (from 010)
-- ---------------------------------------------------------------------------

-- Mesopotamia / Levant
SELECT _seed_threat_011('CARR_HIST_HOL_HASSUNA', 'climate', '8.2 ka cooling event',
  'Centennial-scale cooling and aridification across W Asia at ~-6200, disrupting early farming villages.',
  4::smallint, -6300, -6000, ARRAY['BOND_1997']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_HALAF', 'climate', '6.2 ka aridification',
  'Drying trend across N Mesopotamia contributing to settlement contraction at the Halaf-Ubaid transition.',
  3::smallint, -5500, -5100, ARRAY['DEMENOCAL_2000']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_UBAID', 'resource_competition', 'Ubaid → Uruk transition',
  'Late Ubaid settlement aggregation into Uruk-period proto-cities; smaller villages absorbed or abandoned.',
  3::smallint, -4000, -3700, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_URUK_PRESTATE', 'resource_competition', 'State-formation pressure',
  'Centralization of land, labor, and water in temple-economy elites during the Uruk Expansion.',
  3::smallint, -3500, -3100, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_LEVANT_PN', 'climate', '8.2 ka cooling event',
  'Cooler / drier conditions across the southern Levant tied to the 8.2 ka event.',
  3::smallint, -6300, -6000, ARRAY['BOND_1997']::text[]);

-- Egypt / N Africa
SELECT _seed_threat_011('CARR_HIST_HOL_CAPSIAN', 'climate', 'Early-Holocene desiccation onset',
  'Beginning of post-Green-Sahara aridification gradually compressing forager habitat in the Maghreb.',
  3::smallint, -7000, -6000, ARRAY['DEMENOCAL_2000']::text[]);
SELECT _seed_threat_011('CARR_HIST_HOL_CAPSIAN', 'displacement', 'Cardial farmer arrival',
  'Mediterranean Cardial / Impressa farmers expanding along the Maghreb coast displacing or assimilating Capsian foragers.',
  3::smallint, -6500, -6000, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_SAHARAN_PASTORAL', 'climate', '5.9 ka aridification (end of Green Sahara)',
  'Abrupt aridification ~-3900 ending the African Humid Period; Saharan pastoralist populations forced to disperse south, east, or into the Nile valley.',
  5::smallint, -4000, -3500, ARRAY['DEMENOCAL_2000','CLAUSSEN_1999']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_PREDYNASTIC_EGYPT', 'climate', 'Saharan refugee influx',
  'Saharan pastoralists displaced into the Nile valley by the 5.9 ka aridification, contributing to the population concentration that drove early state formation.',
  3::smallint, -4000, -3300, ARRAY['DEMENOCAL_2000']::text[]);
SELECT _seed_threat_011('CARR_HIST_HOL_PREDYNASTIC_EGYPT', 'war', 'Unification conflicts',
  'Inter-polity warfare between Upper and Lower Egypt culminating in unification under Narmer ~-3100.',
  3::smallint, -3300, -3100, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_C_GROUP_NUBIAN', 'colonization', 'Egyptian conquest',
  'Middle Kingdom Egyptian expansion south of the First Cataract; New Kingdom incorporation as the Egyptian province of Kush.',
  4::smallint, -1900, -1550, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_NOK', 'climate', 'West African aridification',
  'Late Holocene drying contributing to the late Nok phase decline; site abandonment by ~500 CE.',
  3::smallint, 200, 500, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_KINTAMPO', 'displacement', 'Forest expansion / Bantu pressure',
  'Forest re-expansion in the Sahel and southward population pressure absorbing Kintampo agropastoralists.',
  3::smallint, -1800, -1400, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Europe
SELECT _seed_threat_011('CARR_HIST_HOL_CARDIAL', 'climate', '8.2 ka cooling event',
  'Cooler/wetter conditions across the western Mediterranean disrupting Cardial farming villages.',
  3::smallint, -6300, -6000, ARRAY['BOND_1997']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_VINCA', 'displacement', 'Steppe / migration pressure',
  'Late Vinča settlements abandoned through the early-4th-millennium ahead of pre-Yamnaya steppe contacts.',
  3::smallint, -4700, -4500, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_CUCUTENI_TRYP', 'displacement', 'Yamnaya / steppe expansion',
  'Late Cucuteni-Trypillia mega-sites depopulated through the 4th millennium BCE under pressure from Pontic-Caspian steppe groups.',
  4::smallint, -3500, -2750, ARRAY['HAAK_2015','REICH_CH5']::text[]);
SELECT _seed_threat_011('CARR_HIST_HOL_CUCUTENI_TRYP', 'climate', 'Holocene Climatic Optimum decline',
  'Cooler/drier conditions across the eastern European steppe-forest border in the late 5th millennium.',
  2::smallint, -4500, -3500, ARRAY['BOND_1997']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_FUNNELBEAKER', 'displacement', 'Corded Ware / Steppe replacement',
  'Replacement by Corded Ware / Steppe-derived populations across northern Europe ~-2900-2500 BCE.',
  4::smallint, -3000, -2800, ARRAY['HAAK_2015']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_MEGALITHIC_ATL', 'displacement', 'Bell Beaker replacement',
  'Bell Beaker populations replacing the Atlantic Megalithic builders; British Isles population turnover ~-2400-2000 estimated at ~90% by ancient DNA.',
  5::smallint, -2500, -2000, ARRAY['HAAK_2015','REICH_CH5']::text[]);

-- South Asia
SELECT _seed_threat_011('CARR_HIST_HOL_MEHRGARH', 'climate', 'Late Indus monsoon weakening',
  'Weakening of the Indian Summer Monsoon during the late phase contributing to Mehrgarh''s eventual abandonment.',
  3::smallint, -3000, -2500, ARRAY['DEMENOCAL_2000']::text[]);

-- East Asia
SELECT _seed_threat_011('CARR_HIST_HOL_YANGSHAO', 'climate', 'Mid-Holocene cooling',
  'Cooling and drying at the Yangshao→Longshan transition contributing to settlement reorganization.',
  3::smallint, -3300, -3000, ARRAY['BOND_1997']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_LIANGZHU', 'natural_disaster', 'Yangtze flooding + sea-level rise',
  'Catastrophic floods and a rising delta drowning Liangzhu hydraulic infrastructure ~-2300, ending the culture.',
  5::smallint, -2400, -2300, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_LONGSHAN', 'climate', '4.2 ka aridification',
  'North China experienced cooling/drying contributing to the Longshan→Erlitou transition.',
  3::smallint, -2200, -1900, ARRAY['DEMENOCAL_2000','WEISS_1993']::text[]);

-- Americas
SELECT _seed_threat_011('CARR_HIST_HOL_ARCHAIC_NA', 'climate', 'Holocene Climatic Optimum',
  'Mid-Holocene warming peaks ~-6000-4000 BCE; regional shifts in subsistence (e.g. Altithermal aridity in the Great Basin).',
  2::smallint, -7000, -3000, ARRAY['RENSSEN_2012','BOND_1997']::text[]);
SELECT _seed_threat_011('CARR_HIST_HOL_ARCHAIC_NA', 'megafauna_loss', 'End-Pleistocene fauna loss aftermath',
  'Continuing adjustment to the loss of Pleistocene megafauna; subsistence shifts toward broad-spectrum foraging.',
  2::smallint, -8000, -5000, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_NORTE_CHICO', 'natural_disaster', 'El Niño + earthquake hazards',
  'Periodic El Niño-driven flooding and seismic activity along the Peruvian coast.',
  3::smallint, -3000, -1800, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_OLMEC', 'climate', 'Mid-Holocene climate shifts',
  'Mid-Holocene wet/dry oscillations along the Gulf coast affecting maize agriculture.',
  2::smallint, -1500, -400, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_PRECLASSIC_MAYA', 'climate', 'Preclassic drought / abandonment',
  'Late Preclassic abandonment (e.g. El Mirador) implicated in regional drought events ~150-250 CE.',
  4::smallint, 100, 250, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_CHAVIN', 'climate', 'Late Chavín climate stress',
  'Drought and shifting Andean precipitation contributing to Chavín de Huántar''s decline ~-200.',
  3::smallint, -300, -200, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_HOPEWELL', 'climate', 'Late Hopewell decline',
  'Cooling and shifting subsistence patterns contributing to the dissolution of the Hopewell exchange network.',
  3::smallint, 400, 500, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_ADENA', 'displacement', 'Hopewell absorption',
  'Adena traditions absorbed into / overshadowed by the broader Hopewell sphere by ~200 BCE-200 CE.',
  2::smallint, -200, 200, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_HIST_HOL_EASTERN_WOODLAND_ARCH', 'climate', 'Mid-to-late Holocene transition',
  'Climatic shifts driving subsistence changes from broad-spectrum foraging toward incipient horticulture.',
  2::smallint, -3500, -1000, ARRAY['BOND_1997']::text[]);

-- Sub-Saharan / pan-African
SELECT _seed_threat_011('CARR_HIST_HOL_SS_AFR_LSA', 'climate', 'Late-Holocene aridification',
  'Sahelian and east-African aridification reducing forager carrying capacity through the late Holocene.',
  3::smallint, -4000, -2000, ARRAY['DEMENOCAL_2000']::text[]);
SELECT _seed_threat_011('CARR_HIST_HOL_SS_AFR_LSA', 'displacement', 'Bantu expansion',
  'Bantu agriculturalist expansion absorbing or displacing forager populations across central / southern Africa from ~-3000 onward.',
  4::smallint, -3000, 1000, ARRAY['DEDUCED_PHASE_0']::text[]);

-- Anatolia
SELECT _seed_threat_011('CARR_HIST_HOL_ANATOLIA_LATE_NEO', 'climate', '6.2 ka cooling',
  'Centennial-scale cooling at ~-4200 in central Anatolia disrupting late Neolithic / Chalcolithic villages.',
  3::smallint, -4300, -4000, ARRAY['BOND_1997']::text[]);

-- ---------------------------------------------------------------------------
-- Existing forager / Mesolithic carriers (from spreadsheet + 004) — extend
-- coverage so users clicking on Aboriginal / Papuan / Andamanese / Jomon /
-- early carriers at any year see at least one threat.
-- ---------------------------------------------------------------------------

SELECT _seed_threat_011('CARR_PAPUAN_45K', 'displacement', 'Austronesian / Lapita arrival',
  'Austronesian expansion into Near Oceania from ~-1500 absorbing or partitioning coastal Papuan groups; highland Papuans largely retain their lineage.',
  3::smallint, -1500, 0, ARRAY['LIPSON_2018']::text[]);

SELECT _seed_threat_011('CARR_HIST_ANDAMANESE', 'colonization', 'British penal colony + 19th-c. epidemics',
  'British colonization of the Andaman Islands from 1789 (Port Blair penal colony) and successive epidemics reduced the Great Andamanese to near extinction.',
  5::smallint, 1789, 2025, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_JOMON', 'displacement', 'Yayoi / continental rice farmer arrival',
  'Yayoi-period continental migrants from -1000 to -300 introduced wet-rice agriculture and largely replaced or absorbed the Jomon population genetically across mainland Japan.',
  4::smallint, -1000, -300, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_AUS_ABORIGINAL', 'climate', 'Holocene aridification of central Australia',
  'Late-Holocene desert expansion across central Australia restricting habitable zones.',
  2::smallint, -4000, -1, ARRAY['DEDUCED_PHASE_0']::text[]);

SELECT _seed_threat_011('CARR_BANTU_EXPANSION', 'climate', 'Equatorial forest contraction',
  'Late-Holocene equatorial-forest fragmentation opened savanna corridors that facilitated the Bantu agropastoralist expansion.',
  2::smallint, -3000, 1000, ARRAY['DEDUCED_PHASE_0']::text[]);

DROP FUNCTION _seed_threat_011(TEXT, threat_type, TEXT, TEXT, SMALLINT, INTEGER, INTEGER, TEXT[]);
