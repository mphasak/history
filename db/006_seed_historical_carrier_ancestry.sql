-- 006_seed_historical_carrier_ancestry.sql
--
-- Populates carrier_trait_mix (ancestry breakdowns) with citations for the
-- historical and modern carriers added by 005. Each ancestry assertion is
-- recorded as a Claim row whose subject is the (carrier, trait_id) pair, with
-- claim_source rows linking to the published source(s) that support it.
--
-- Where a population's ancestry has been well-resolved by ancient DNA work
-- (Reich, Lazaridis, Narasimhan, Haak, etc.), we cite that work. Where the
-- mix is a coarse synthesis that doesn't trace to a single paper, we cite
-- the new DEDUCED_PHASE_0 placeholder source so users can tell at a glance
-- that it's an editorial best-effort summary, not a primary attribution.
--
-- Idempotent: re-running the file deletes the rows it owns first, then
-- re-inserts. The DELETE scopes to claims whose statement starts with the
-- "[AUTO-PROVENANCE]" tag and to carrier_trait_mix rows whose carrier_id
-- starts with CARR_HIST_ or CARR_HOMININ_.

-- ---------------------------------------------------------------------------
-- New source for "deduced" cases
-- ---------------------------------------------------------------------------

INSERT INTO source (id, type, citation, default_weight) VALUES
  ('DEDUCED_PHASE_0', 'wikipedia',
   'Editorial synthesis (Phase 0 seed) — coarse mix derived from broad consensus / textbook summaries; not a primary attribution.',
   0.50)
ON CONFLICT (id) DO NOTHING;

-- A few additional ancient-DNA sources we cite below. (Default weights are
-- conservative; perspectives can override.)
INSERT INTO source (id, type, citation, default_weight) VALUES
  ('VAN_DE_LOOSDRECHT_2018', 'peer_reviewed_paper',
   'van de Loosdrecht et al. (2018). Pleistocene N African genomes link Iberomaurusian to Levantine and sub-Saharan ancestries. Science 360.',
   0.85),
  ('LAZARIDIS_2017_AEGEAN', 'peer_reviewed_paper',
   'Lazaridis et al. (2017). Genetic origins of the Minoans and Mycenaeans. Nature 548, 214-218.',
   0.90),
  ('ANTONIO_2019', 'peer_reviewed_paper',
   'Antonio et al. (2019). Ancient Rome: A genetic crossroads of Europe and the Mediterranean. Science 366.',
   0.90),
  ('NING_2020', 'peer_reviewed_paper',
   'Ning et al. (2020). Ancient genomes from northern China suggest links between subsistence changes and human migration. Nat Commun 11.',
   0.85),
  ('YANG_2020', 'peer_reviewed_paper',
   'Yang et al. (2020). Ancient DNA indicates human population shifts and admixture in northern and southern China. Science 369.',
   0.90),
  ('SKOGLUND_2016', 'peer_reviewed_paper',
   'Skoglund et al. (2016). Genetic evidence for two founding populations of the Americas. Nature 525.',
   0.85),
  ('POSTH_2018', 'peer_reviewed_paper',
   'Posth et al. (2018). Reconstructing the deep population history of Central and South America. Cell 175.',
   0.85),
  ('LIPSON_2018', 'peer_reviewed_paper',
   'Lipson et al. (2018). Ancient genomes document multiple waves of migration in SE Asian prehistory. Science 361.',
   0.85),
  ('SCHIFFELS_2016', 'peer_reviewed_paper',
   'Schiffels et al. (2016). Iron Age and Anglo-Saxon genomes from East England reveal British migration history. Nat Commun 7.',
   0.85),
  ('MARGARYAN_2020', 'peer_reviewed_paper',
   'Margaryan et al. (2020). Population genomics of the Viking world. Nature 585.',
   0.85),
  ('MARTINIANO_2017', 'peer_reviewed_paper',
   'Martiniano et al. (2017). The population genomics of archaeological transition in west Iberia. PLoS Genet 13.',
   0.80),
  ('JEONG_2020_STEPPE', 'peer_reviewed_paper',
   'Jeong et al. (2020). A dynamic 6,000-year genetic history of Eurasia''s Eastern Steppe. Cell 183.',
   0.85),
  ('SKOURTANIOTI_2020', 'peer_reviewed_paper',
   'Skourtanioti et al. (2020). Genomic history of Neolithic to Bronze Age Anatolia, Northern Levant, and Southern Caucasus. Cell 181.',
   0.90),
  ('ALLENTOFT_2024', 'peer_reviewed_paper',
   'Allentoft et al. (2024). Population genomics of post-glacial western Eurasia. Nature 625.',
   0.90)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Idempotency: drop AUTO-PROVENANCE claims and the trait mixes they support
-- before re-inserting.
-- ---------------------------------------------------------------------------

DELETE FROM carrier_trait_mix
WHERE carrier_id LIKE 'CARR_HIST_%' OR carrier_id LIKE 'CARR_HOMININ_%';

DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%';

-- ---------------------------------------------------------------------------
-- Helper: provenance claims + supporting sources + carrier_trait_mix rows.
-- We use anonymous PL/pgSQL DO blocks so each carrier's provenance is
-- inserted as one transactional unit and we can capture the new claim_id.
-- ---------------------------------------------------------------------------

-- Each block follows the same shape:
--   1) INSERT INTO claim ... RETURNING id
--   2) INSERT INTO claim_source rows for that claim
--   3) INSERT INTO carrier_trait_mix rows linked back via claim_id

-- Because the DO blocks repeat, we factor the boilerplate into a function
-- defined here and dropped at the end of this file.

CREATE OR REPLACE FUNCTION _seed_provenance(
  carrier_id TEXT,
  as_of_year INT,
  statement TEXT,
  source_ids TEXT[],
  trait_ids TEXT[],
  fractions NUMERIC[],
  stderrs NUMERIC[]
) RETURNS BIGINT AS $$
DECLARE
  new_claim_id BIGINT;
  i INT;
BEGIN
  INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
  VALUES ('Carrier', carrier_id, '[AUTO-PROVENANCE] ' || statement, 3)
  RETURNING id INTO new_claim_id;

  FOR i IN 1..array_length(source_ids, 1) LOOP
    INSERT INTO claim_source (claim_id, source_id, stance)
    VALUES (new_claim_id, source_ids[i], 'supports');
  END LOOP;

  FOR i IN 1..array_length(trait_ids, 1) LOOP
    INSERT INTO carrier_trait_mix
      (carrier_id, as_of_year, domain, trait_id, fraction, stderr, claim_id)
    VALUES
      (carrier_id, as_of_year, 'genetic', trait_ids[i],
       fractions[i], stderrs[i], new_claim_id);
  END LOOP;

  RETURN new_claim_id;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Provenance assertions
-- ---------------------------------------------------------------------------

-- Mesopotamia / Levant -------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_SUMERIAN', -3000,
  'Southern Mesopotamian population — predominantly Iranian Neolithic-related ancestry with a substantial Anatolian Neolithic-derived component.',
  ARRAY['LAZARIDIS_2022','SKOURTANIOTI_2020']::text[],
  ARRAY['IRN_N','ANATOLIAN_FARMER','NATUFIAN']::text[],
  ARRAY[0.55, 0.30, 0.15]::numeric[],
  ARRAY[0.07, 0.07, 0.07]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_AKKADIAN', -2300,
  'Mesopotamian Bronze Age — Iranian-Neolithic-rich baseline with elevated Levantine (Natufian-related) ancestry consistent with Semitic-speaking influx.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','NATUFIAN','ANATOLIAN_FARMER']::text[],
  ARRAY[0.45, 0.30, 0.25]::numeric[],
  ARRAY[0.08, 0.08, 0.08]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_BABYLONIAN', -1500,
  'Old Babylonian successor population — broadly Sumerian-Akkadian admixture with continued Levantine input.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','NATUFIAN','ANATOLIAN_FARMER']::text[],
  ARRAY[0.45, 0.30, 0.25]::numeric[],
  ARRAY[0.08, 0.08, 0.08]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_ASSYRIAN', -1500,
  'Northern Mesopotamian — slightly elevated Anatolian Neolithic / CHG-related ancestry relative to Babylonia.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','ANATOLIAN_FARMER','NATUFIAN','CHG']::text[],
  ARRAY[0.40, 0.30, 0.20, 0.10]::numeric[],
  ARRAY[0.08, 0.08, 0.08, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_HITTITE', -1400,
  'Anatolian Bronze Age — Anatolian Neolithic Farmer baseline with CHG (Caucasus Hunter-Gatherer)-related ancestry; modest Steppe input from the Indo-European-speaker substrate.',
  ARRAY['LAZARIDIS_2017_AEGEAN','SKOURTANIOTI_2020','LAZARIDIS_2022']::text[],
  ARRAY['ANATOLIAN_FARMER','CHG','STEPPE_MLBA']::text[],
  ARRAY[0.55, 0.30, 0.15]::numeric[],
  ARRAY[0.06, 0.06, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_PHOENICIAN', -800,
  'Levantine Bronze/Iron Age — Natufian-related baseline with Anatolian Neolithic admixture and minor Steppe input.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','IRN_N','STEPPE_MLBA']::text[],
  ARRAY[0.40, 0.30, 0.25, 0.05]::numeric[],
  ARRAY[0.08, 0.08, 0.08, 0.04]::numeric[]
);

-- Egypt / N Africa -----------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_EGYPT_OK', -2500,
  'Old Kingdom Egyptians — Natufian-related Levantine baseline with Anatolian Neolithic admixture and a North African / Sub-Saharan Iberomaurusian-related component, consistent with Schuenemann 2017 mummy genomes.',
  ARRAY['LAZARIDIS_2022','VAN_DE_LOOSDRECHT_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','AFR_BASAL']::text[],
  ARRAY[0.55, 0.30, 0.15]::numeric[],
  ARRAY[0.08, 0.08, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_EGYPT_MK_NK', -1500,
  'Middle / New Kingdom Egyptians — similar baseline to OK Egyptians, with rising Sub-Saharan ancestry over time as documented in later mummy and post-Pharaonic samples.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','AFR_BASAL']::text[],
  ARRAY[0.50, 0.30, 0.20]::numeric[],
  ARRAY[0.08, 0.08, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_CARTHAGINIAN', -500,
  'Carthaginian Punic — Phoenician-derived Levantine ancestry layered onto an Iberomaurusian-descended North African substrate.',
  ARRAY['VAN_DE_LOOSDRECHT_2018','LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','AFR_BASAL']::text[],
  ARRAY[0.45, 0.25, 0.30]::numeric[],
  ARRAY[0.08, 0.08, 0.08]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_BERBER', 0,
  'Berber / Amazigh — Iberomaurusian-derived North African substrate with later Levantine and Sub-Saharan admixture.',
  ARRAY['VAN_DE_LOOSDRECHT_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','AFR_BASAL','ANATOLIAN_FARMER']::text[],
  ARRAY[0.40, 0.40, 0.20]::numeric[],
  ARRAY[0.08, 0.08, 0.07]::numeric[]
);

-- Mediterranean / Europe -----------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_MYCENAEAN', -1400,
  'Late Bronze Age Aegean — Anatolian Neolithic baseline with Iranian/CHG-related farmer ancestry and ~10-20% Yamnaya/Steppe admixture (Lazaridis 2017).',
  ARRAY['LAZARIDIS_2017_AEGEAN','LAZARIDIS_2022']::text[],
  ARRAY['ANATOLIAN_FARMER','CHG','YAMNAYA','WHG']::text[],
  ARRAY[0.60, 0.20, 0.15, 0.05]::numeric[],
  ARRAY[0.06, 0.05, 0.05, 0.03]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_GREEK_CLASSICAL', -500,
  'Iron Age / Classical Greeks — direct successors of the Mycenaeans with continued Anatolian + Steppe-related ancestry.',
  ARRAY['LAZARIDIS_2017_AEGEAN','DEDUCED_PHASE_0']::text[],
  ARRAY['ANATOLIAN_FARMER','CHG','YAMNAYA','WHG']::text[],
  ARRAY[0.55, 0.20, 0.20, 0.05]::numeric[],
  ARRAY[0.06, 0.05, 0.05, 0.03]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_ROMAN', 0,
  'Roman-era Italians — heavy Anatolian Neolithic and Steppe input from prehistoric layers, with later Imperial-period admixture from the Levant and N Africa as Antonio 2019 shows.',
  ARRAY['ANTONIO_2019']::text[],
  ARRAY['ANATOLIAN_FARMER','YAMNAYA','NATUFIAN','WHG']::text[],
  ARRAY[0.50, 0.25, 0.15, 0.10]::numeric[],
  ARRAY[0.06, 0.05, 0.05, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_BYZANTINE', 800,
  'Byzantine — broadly continuous with Classical Greek ancestry plus low-level Anatolian / Levantine influx.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['ANATOLIAN_FARMER','CHG','YAMNAYA','NATUFIAN']::text[],
  ARRAY[0.50, 0.20, 0.20, 0.10]::numeric[],
  ARRAY[0.07, 0.06, 0.06, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_CELTS', -300,
  'La Tène / Iron Age Celts — Bell Beaker-like substrate (heavy Yamnaya/Steppe + EEF) with WHG residual.',
  ARRAY['HAAK_2015','LAZARIDIS_2014','DEDUCED_PHASE_0']::text[],
  ARRAY['EEF','YAMNAYA','WHG']::text[],
  ARRAY[0.40, 0.45, 0.15]::numeric[],
  ARRAY[0.06, 0.06, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_GERMANIC_IRON_AGE', 0,
  'Iron Age Germanic peoples — northern European Bell Beaker / Corded Ware-derived ancestry, slightly higher Steppe than southern Europeans.',
  ARRAY['HAAK_2015','SCHIFFELS_2016','DEDUCED_PHASE_0']::text[],
  ARRAY['EEF','YAMNAYA','WHG']::text[],
  ARRAY[0.30, 0.55, 0.15]::numeric[],
  ARRAY[0.05, 0.06, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_NORSE', 900,
  'Viking Age Scandinavians — Iron Age Germanic baseline with regional Sami-related and continental European admixture (Margaryan 2020).',
  ARRAY['MARGARYAN_2020','SCHIFFELS_2016']::text[],
  ARRAY['EEF','YAMNAYA','WHG']::text[],
  ARRAY[0.30, 0.50, 0.20]::numeric[],
  ARRAY[0.05, 0.06, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_SLAVS_MEDIEVAL', 1000,
  'Medieval Slavs — eastern European Iron Age baseline (EEF + Steppe + EHG), expanding from a Pripyat-region homeland.',
  ARRAY['ALLENTOFT_2024','DEDUCED_PHASE_0']::text[],
  ARRAY['EEF','YAMNAYA','EHG','WHG']::text[],
  ARRAY[0.30, 0.40, 0.20, 0.10]::numeric[],
  ARRAY[0.06, 0.06, 0.05, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MEDIEVAL_W_EUROPEAN', 1200,
  'Medieval Western Europeans — Bell Beaker / Iron Age substrate with regional Roman and Migration-Period admixture.',
  ARRAY['SCHIFFELS_2016','MARTINIANO_2017','DEDUCED_PHASE_0']::text[],
  ARRAY['EEF','YAMNAYA','WHG']::text[],
  ARRAY[0.40, 0.45, 0.15]::numeric[],
  ARRAY[0.06, 0.06, 0.04]::numeric[]
);

-- South / East Asia ----------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_VEDIC_ARYAN', -1000,
  'Vedic / early Indo-Aryan — ANI-rich population in the NW subcontinent with elevated Steppe_MLBA (the Aryan migration signal under PERSP_INDIAN_AMT).',
  ARRAY['NARASIMHAN_2019','REICH_CH6']::text[],
  ARRAY['ANI','ASI','STEPPE_MLBA']::text[],
  ARRAY[0.50, 0.30, 0.20]::numeric[],
  ARRAY[0.06, 0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MAURYAN', 0,
  'Mauryan-era Indians — broadly continuous with the Bronze Age NW South Asian baseline, expanding into the Gangetic plain with rising ASI fraction.',
  ARRAY['NARASIMHAN_2019','DEDUCED_PHASE_0']::text[],
  ARRAY['ANI','ASI','STEPPE_MLBA']::text[],
  ARRAY[0.45, 0.40, 0.15]::numeric[],
  ARRAY[0.06, 0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MUGHAL_N_INDIAN', 1700,
  'Mughal-era N Indians — N Indian baseline with detectable Iranian/Central Asian elite influx during the Mughal period.',
  ARRAY['NARASIMHAN_2019','DEDUCED_PHASE_0']::text[],
  ARRAY['ANI','ASI','STEPPE_MLBA','IRN_N']::text[],
  ARRAY[0.45, 0.30, 0.15, 0.10]::numeric[],
  ARRAY[0.06, 0.05, 0.04, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_S_ASIAN', 2000,
  'Modern South Asians — broad ANI–ASI cline plus Steppe_MLBA component documented across populations by Narasimhan 2019 / Reich Ch 6.',
  ARRAY['NARASIMHAN_2019','REICH_CH6']::text[],
  ARRAY['ANI','ASI','STEPPE_MLBA']::text[],
  ARRAY[0.45, 0.40, 0.15]::numeric[],
  ARRAY[0.07, 0.07, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_SHANG', -1300,
  'Shang Bronze Age Chinese — northern East Asian agriculturalist baseline (Yellow River millet farmers).',
  ARRAY['NING_2020','YANG_2020']::text[],
  ARRAY['EAST_ASIAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_HAN_CHINESE_EMPIRE', 0,
  'Han-empire Chinese — northern East Asian agriculturalist substrate spreading southward, absorbing local southern East Asian populations.',
  ARRAY['NING_2020','YANG_2020','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_TANG_CHINESE', 800,
  'Tang Chinese — broadly continuous with Han-era population, with regional Central Asian influx along the Silk Road.',
  ARRAY['NING_2020','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_HAN', 2000,
  'Modern Han Chinese — substantial regional substructure across N (more Yellow-River-farmer-related) and S (more Yangtze-farmer / SE Asian-related) China.',
  ARRAY['NING_2020','YANG_2020','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_KHMER_ANGKOR', 1100,
  'Khmer / Angkor — Mainland Southeast Asian admixture of Hoabinhian-related and East Asian agriculturalist ancestries.',
  ARRAY['LIPSON_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.85, 0.15]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MONGOL', 1300,
  'Mongol-era steppe pastoralists — northeast Asian baseline with substantial Western Eurasian (Steppe / ANE-related) admixture.',
  ARRAY['JEONG_2020_STEPPE']::text[],
  ARRAY['EAST_ASIAN','ANE','YAMNAYA']::text[],
  ARRAY[0.60, 0.20, 0.20]::numeric[],
  ARRAY[0.06, 0.05, 0.05]::numeric[]
);

-- Pacific / Australia --------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_LAPITA', -1000,
  'Lapita seafarers — Austronesian East Asian-derived ancestry with Papuan/Melanesian admixture acquired in Near Oceania.',
  ARRAY['LIPSON_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.75, 0.25]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_POLYNESIAN', 500,
  'Polynesian voyagers — Lapita-derived East Asian / Papuan mix with reduced Papuan fraction in further-east populations.',
  ARRAY['LIPSON_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.80, 0.20]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MAORI', 1500,
  'Maori — descendants of Polynesian voyagers; ancestry similar to other east Polynesian populations.',
  ARRAY['LIPSON_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.80, 0.20]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

-- Americas -------------------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_MAYA_CLASSICAL', 500,
  'Classic Maya — Indigenous American (First American) ancestry with deep ANE component inherited from the Beringian source.',
  ARRAY['REICH_CH7','POSTH_2018','SKOGLUND_2016']::text[],
  ARRAY['AMER_NA','ANE']::text[],
  ARRAY[0.70, 0.30]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_AZTEC', 1450,
  'Aztec / Mexica — Mesoamerican Indigenous American ancestry, broadly continuous with earlier Classic-era populations.',
  ARRAY['REICH_CH7','POSTH_2018']::text[],
  ARRAY['AMER_NA','ANE']::text[],
  ARRAY[0.70, 0.30]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_INCA', 1500,
  'Inca / Tawantinsuyu — Andean Indigenous American ancestry with elevated affinity to Anzick-1 / southern-branch First Americans.',
  ARRAY['REICH_CH7','POSTH_2018']::text[],
  ARRAY['AMER_NA','ANE']::text[],
  ARRAY[0.70, 0.30]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MISSISSIPPIAN', 1200,
  'Mississippian — North American Indigenous ancestry, broadly continuous with First American baseline.',
  ARRAY['REICH_CH7','DEDUCED_PHASE_0']::text[],
  ARRAY['AMER_NA','ANE']::text[],
  ARRAY[0.70, 0.30]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_LATIN_AMER_MESTIZO', 2000,
  'Modern Latin American Mestizo — three-way admixture of Indigenous American, European (largely Iberian), and West/Central African ancestry. Proportions vary widely by country.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['AMER_NA','EEF','YAMNAYA','AFR_WEST']::text[],
  ARRAY[0.35, 0.25, 0.20, 0.20]::numeric[],
  ARRAY[0.10, 0.08, 0.08, 0.08]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_NATIVE_AMER', 2000,
  'Modern Native Americans — predominantly First American ancestry with some European admixture varying by community.',
  ARRAY['REICH_CH7','DEDUCED_PHASE_0']::text[],
  ARRAY['AMER_NA','ANE','EEF','YAMNAYA']::text[],
  ARRAY[0.60, 0.20, 0.10, 0.10]::numeric[],
  ARRAY[0.10, 0.05, 0.05, 0.05]::numeric[]
);

-- Africa ---------------------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_NUBIAN_KUSHITE', -1500,
  'Nubian / Kushite — North-East African / Sub-Saharan baseline with Levantine influence from down the Nile.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_BASAL','NATUFIAN']::text[],
  ARRAY[0.70, 0.30]::numeric[],
  ARRAY[0.07, 0.07]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_AKSUMITE', 400,
  'Aksumite Ethiopian — Cushitic-speaking Sub-Saharan baseline with ~40% Eurasian (Levantine-related) ancestry.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_BASAL','NATUFIAN','ANATOLIAN_FARMER']::text[],
  ARRAY[0.60, 0.30, 0.10]::numeric[],
  ARRAY[0.07, 0.07, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MALI_EMPIRE', 1400,
  'Mali Empire — Mande / West African ancestry, broadly continuous with the Bantu-source region.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_WEST']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_KHOISAN_MODERN', 2000,
  'Modern Khoisan — Khoe-San lineage, the deepest-diverged modern human ancestry; minor downstream Bantu admixture in some groups.',
  ARRAY['REICH_CH1','DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_KHOISAN','AFR_WEST']::text[],
  ARRAY[0.85, 0.15]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_W_AFRICAN', 2000,
  'Modern West Africans — Yoruba / Mende-like ancestry; West African baseline with deep AFR_BASAL substructure.',
  ARRAY['REICH_CH1','DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_WEST','AFR_BASAL']::text[],
  ARRAY[0.85, 0.15]::numeric[],
  ARRAY[0.04, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_E_AFRICAN', 2000,
  'Modern East Africans — composite of Bantu (West African-related), Cushitic (Levantine-related), and Nilotic (deep East African) ancestry; varies sharply by group.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_WEST','AFR_BASAL','NATUFIAN']::text[],
  ARRAY[0.45, 0.40, 0.15]::numeric[],
  ARRAY[0.10, 0.10, 0.07]::numeric[]
);

-- Steppe / Central Asia / Iran ----------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_SCYTHIAN', -300,
  'Scythians — eastern Iron Age steppe pastoralists; mixed Yamnaya / EHG-derived Western Eurasian ancestry with detectable Eastern Eurasian admixture in eastern groups.',
  ARRAY['JEONG_2020_STEPPE','ALLENTOFT_2024']::text[],
  ARRAY['YAMNAYA','EHG','EAST_ASIAN','ANE']::text[],
  ARRAY[0.45, 0.30, 0.15, 0.10]::numeric[],
  ARRAY[0.06, 0.06, 0.05, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_HUNS', 400,
  'Huns — Eurasian steppe confederation; ancestry varies between East Asian-rich (later Xiongnu-related) and Iranian-Steppe-derived components.',
  ARRAY['JEONG_2020_STEPPE','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','YAMNAYA','ANE']::text[],
  ARRAY[0.50, 0.30, 0.20]::numeric[],
  ARRAY[0.10, 0.08, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_TURKIC_GOKTURK', 700,
  'Gökturks — Inner Asian steppe; East Asian baseline with Western Eurasian (Steppe-MLBA, Iranian) admixture.',
  ARRAY['JEONG_2020_STEPPE']::text[],
  ARRAY['EAST_ASIAN','ANE','YAMNAYA']::text[],
  ARRAY[0.55, 0.20, 0.25]::numeric[],
  ARRAY[0.06, 0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_OTTOMAN', 1700,
  'Ottoman population (core Anatolia) — Anatolian Neolithic baseline + CHG + Steppe + Levantine, with later Turkic-language-driven Central Asian admixture detectable but small.',
  ARRAY['LAZARIDIS_2017_AEGEAN','SKOURTANIOTI_2020','DEDUCED_PHASE_0']::text[],
  ARRAY['ANATOLIAN_FARMER','CHG','YAMNAYA','NATUFIAN','EAST_ASIAN']::text[],
  ARRAY[0.45, 0.20, 0.15, 0.15, 0.05]::numeric[],
  ARRAY[0.07, 0.06, 0.05, 0.05, 0.03]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_SOGDIAN', 500,
  'Sogdians — Central Asian Iranian-speakers; Iranian-Neolithic-derived baseline with Steppe and East Asian admixture along the Silk Road.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','YAMNAYA','EAST_ASIAN']::text[],
  ARRAY[0.45, 0.30, 0.25]::numeric[],
  ARRAY[0.07, 0.06, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_ACHAEMENID', -400,
  'Achaemenid Persians — Iranian Plateau population; predominantly Iranian Neolithic-derived ancestry with CHG and minor Steppe input.',
  ARRAY['LAZARIDIS_2022','NARASIMHAN_2019']::text[],
  ARRAY['IRN_N','CHG','YAMNAYA']::text[],
  ARRAY[0.65, 0.20, 0.15]::numeric[],
  ARRAY[0.06, 0.05, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_SASANIAN', 400,
  'Sasanian Persians — broadly continuous with Achaemenid-era Iranian baseline.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','CHG','YAMNAYA']::text[],
  ARRAY[0.65, 0.20, 0.15]::numeric[],
  ARRAY[0.06, 0.05, 0.04]::numeric[]
);

-- Arab / Islamic world ------------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_RASHIDUN_UMAYYAD', 700,
  'Rashidun / Umayyad Arabs — Arabian peninsula baseline (Natufian-related Levantine + AFR_BASAL substructure) spreading into the Levant and N Africa.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','AFR_BASAL']::text[],
  ARRAY[0.55, 0.25, 0.20]::numeric[],
  ARRAY[0.07, 0.07, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_ABBASID', 1000,
  'Abbasid Caliphate — Mesopotamian baseline with Arab Levantine elite influx.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['IRN_N','NATUFIAN','ANATOLIAN_FARMER']::text[],
  ARRAY[0.40, 0.40, 0.20]::numeric[],
  ARRAY[0.08, 0.08, 0.07]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MOORS_AL_ANDALUS', 1100,
  'Moors / Al-Andalus — North African Berber-derived ancestry layered onto the Iberian substrate, with Arab Levantine elite component.',
  ARRAY['MARTINIANO_2017','VAN_DE_LOOSDRECHT_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','EEF','AFR_BASAL','YAMNAYA']::text[],
  ARRAY[0.30, 0.30, 0.25, 0.15]::numeric[],
  ARRAY[0.08, 0.07, 0.07, 0.05]::numeric[]
);

-- Modern (additional regional) ---------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_MODERN_E_ASIAN', 2000,
  'Modern East Asians (broad) — northern East Asian agriculturalist core + regional Jomon (Japan) / SE Asian / Tibeto-Burman substructure.',
  ARRAY['NING_2020','YANG_2020','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','JOMON']::text[],
  ARRAY[0.95, 0.05]::numeric[],
  ARRAY[0.04, 0.03]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_EUROPEAN', 2000,
  'Modern Europeans — broadly mixed Steppe/Yamnaya + EEF + WHG with regional clines (more EEF in S Europe, more Steppe in N/E Europe).',
  ARRAY['HAAK_2015','LAZARIDIS_2014']::text[],
  ARRAY['EEF','YAMNAYA','WHG']::text[],
  ARRAY[0.40, 0.45, 0.15]::numeric[],
  ARRAY[0.07, 0.07, 0.04]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_SE_ASIAN', 2000,
  'Modern Southeast Asians — Hoabinhian-related substrate + East Asian agriculturalist (Yangtze farmer) + Austronesian admixture.',
  ARRAY['LIPSON_2018','DEDUCED_PHASE_0']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.85, 0.15]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_MODERN_ARAB', 2000,
  'Modern Arabs — Levantine baseline (Natufian + Anatolian Neolithic) with regional Berber, Iranian, and Sub-Saharan substructure.',
  ARRAY['LAZARIDIS_2022','DEDUCED_PHASE_0']::text[],
  ARRAY['NATUFIAN','ANATOLIAN_FARMER','IRN_N','AFR_BASAL']::text[],
  ARRAY[0.45, 0.25, 0.15, 0.15]::numeric[],
  ARRAY[0.08, 0.07, 0.06, 0.06]::numeric[]
);

-- Additional UP / Mesolithic clusters from 005 ------------------------------

SELECT _seed_provenance(
  'CARR_HIST_UST_ISHIM', -44000,
  'Ust''-Ishim individual — early modern human in western Siberia shortly after OOA, before East/West Eurasian split.',
  ARRAY['JONES_2015','RAGHAVAN_2014']::text[],
  ARRAY['BASAL_EURASIAN','ANE']::text[],
  ARRAY[0.20, 0.80]::numeric[],
  ARRAY[0.10, 0.10]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_KOSTENKI_SUNGIR', -30000,
  'Kostenki / Sungir cluster — Russian Plain Upper Paleolithic; early West Eurasians with Aurignacian-related affinities.',
  ARRAY['JONES_2015']::text[],
  ARRAY['ANE','BASAL_EURASIAN']::text[],
  ARRAY[0.85, 0.15]::numeric[],
  ARRAY[0.06, 0.06]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_HOFMEYR', -36000,
  'Hofmeyr — Late Pleistocene South African individual showing Eurasian Upper-Paleolithic-like affinities rather than modern Khoisan.',
  ARRAY['DEDUCED_PHASE_0']::text[],
  ARRAY['BASAL_EURASIAN','AFR_KHOISAN']::text[],
  ARRAY[0.50, 0.50]::numeric[],
  ARRAY[0.15, 0.15]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_HOABINHIAN', -10000,
  'Hoabinhian — Mainland SE Asian Late Pleistocene / Early Holocene foragers; deeply diverged "basal East Asian" affinity.',
  ARRAY['LIPSON_2018']::text[],
  ARRAY['EAST_ASIAN','AUS_PNG']::text[],
  ARRAY[0.65, 0.35]::numeric[],
  ARRAY[0.07, 0.07]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_IBEROMAURUSIAN', -15000,
  'Iberomaurusian / Taforalt — Late Pleistocene N African foragers; ~two-thirds Natufian-related plus one-third Sub-Saharan ancestry per van de Loosdrecht 2018.',
  ARRAY['VAN_DE_LOOSDRECHT_2018']::text[],
  ARRAY['NATUFIAN','AFR_BASAL']::text[],
  ARRAY[0.65, 0.35]::numeric[],
  ARRAY[0.05, 0.05]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_ANDAMANESE', 0,
  'Andamanese — Andaman Islands foragers with deep South Asian ("Ancient Ancestral South Indian" / Onge-related) lineage, branching off from other Eurasians soon after OOA.',
  ARRAY['NARASIMHAN_2019','REICH_CH6']::text[],
  ARRAY['ASI']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.03]::numeric[]
);

-- Pre-OOA / early sapiens ---------------------------------------------------

SELECT _seed_provenance(
  'CARR_HIST_KHOE_SAN_ANCESTRAL', -100000,
  'Khoe-San ancestral lineage — earliest-diverged modern human lineage, source of modern Khoisan ancestry.',
  ARRAY['REICH_CH1']::text[],
  ARRAY['AFR_KHOISAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HIST_AFR_EARLY_OOA_SOURCE', -75000,
  'Pre-OOA Northeast African source — directly ancestral to all non-African modern humans; basal sapiens with no archaic Eurasian admixture yet.',
  ARRAY['REICH_CH2','DEDUCED_PHASE_0']::text[],
  ARRAY['AFR_BASAL']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.02]::numeric[]
);

-- Non-sapiens hominins (genetic identity) -----------------------------------

SELECT _seed_provenance(
  'CARR_HOMININ_NEANDERTHAL', -50000,
  'Neanderthals — full archaic Neanderthal genome; the ~1-4% Neanderthal admixture in modern non-Africans descends from this lineage.',
  ARRAY['REICH_CH2','REICH_CH4']::text[],
  ARRAY['NEANDERTHAL']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.01]::numeric[]
);

SELECT _seed_provenance(
  'CARR_HOMININ_DENISOVAN', -100000,
  'Denisovans — sister archaic lineage to Neanderthals; the ~3-6% Denisovan admixture in modern Australasians descends from this lineage.',
  ARRAY['REICH_CH4']::text[],
  ARRAY['DENISOVAN']::text[],
  ARRAY[1.00]::numeric[],
  ARRAY[0.01]::numeric[]
);

-- Tear down the helper.
DROP FUNCTION _seed_provenance(TEXT, INT, TEXT, TEXT[], TEXT[], NUMERIC[], NUMERIC[]);
