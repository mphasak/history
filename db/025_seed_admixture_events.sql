-- 025_seed_admixture_events.sql
--
-- Adds the **admixture_event** table and seeds the 15-or-so major fusion
-- moments that recompose human populations: OOA + Neanderthal, Sahul +
-- Denisovan, the Yamnaya / Steppe-MLBA expansion into Europe, the
-- Steppe-into-South-Asia rupture, Bantu, Lapita / Polynesian, Han
-- southward, Arab conquests, Mongol expansion, European colonization
-- of the Americas, Atlantic slave trade.
--
-- Why this is its own table (not propagation_event):
--   propagation_event captures a *flow* (source → destination of a
--   trait) — useful for migration arrows. admixture_event captures the
--   moment of *fusion* — two or more ghost populations meeting and
--   producing something new. Different visual treatment in the UI:
--   propagation arrows vs. on-map "explosion" + timeline lane.
--
-- Severity (1-5) is *cultural rupture*, NOT death-toll: 1 = gradual
-- blend, 5 = mass demographic replacement. rupture_kind is a coarse
-- categorical: gradual_blend / elite_dominance / demographic_swamp /
-- violent_replacement / forced_diaspora / island_settlement.
--
-- Cited via DEDUCED_PHASE_0 (editorial summary, Reich Ch.6 + general
-- consensus). Idempotent on a fixed list of admixture_event IDs.

CREATE TABLE IF NOT EXISTS admixture_event (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  year_min int NOT NULL,
  year_max int NOT NULL,
  centroid geography(Point, 4326) NOT NULL,
  description text,
  -- Trait IDs (genetic ancestry components) being fused.
  parent_traits text[],
  -- Trait IDs that result from the fusion.
  result_traits text[],
  -- Carrier IDs most associated with each side of the fusion.
  parent_carriers text[],
  result_carriers text[],
  severity int NOT NULL CHECK (severity BETWEEN 1 AND 5),
  rupture_kind text NOT NULL CHECK (rupture_kind IN (
    'gradual_blend',          -- peaceful intermarriage / shared identity
    'elite_dominance',        -- small incoming elite, large local substrate
    'demographic_swamp',      -- incomers numerically dominate
    'violent_replacement',    -- documented or genetically inferred mass replacement
    'forced_diaspora',        -- forced movement (slave trade, deportation)
    'island_settlement'       -- arrival on previously uninhabited or sparsely-inhabited land
  )),
  source_id text REFERENCES source(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admixture_event_year ON admixture_event (year_min, year_max);

-- Idempotent re-run.
DELETE FROM admixture_event WHERE id LIKE 'ADMIX_%';

INSERT INTO admixture_event (id, display_name, year_min, year_max, centroid,
                              description, parent_traits, result_traits,
                              parent_carriers, result_carriers,
                              severity, rupture_kind, source_id) VALUES

  -- ==========================================================
  -- Deep-time speciation / divergence events (pre-OOA).
  --
  -- These aren't "admixture" in the strict population-genetics sense —
  -- they're branching points in the hominin family tree. We model them
  -- in the same table so the atlas can render the full lineage from
  -- Homo habilis → modern populations as a connected graph. Without
  -- these, the atlas appears to begin at the OOA × Neanderthal event
  -- ~50 kya, which makes Reich's "many ghost populations fused into
  -- a few" thesis impossible to see at the deepest scale.
  --
  -- rupture_kind is `gradual_blend` for slow speciation and
  -- `island_settlement` for major dispersal events (Erectus OOA,
  -- insular descendants on Flores / Luzon) since the existing CHECK
  -- constraint already permits these values.
  -- ==========================================================

  ('ADMIX_HABILIS_TO_ERECTUS',
   'Homo habilis → Homo erectus (Africa)',
   -2200000, -1900000,
   ST_GeogFromText('SRID=4326;POINT(36 4)'),
   'In East Africa, the descendants of Homo habilis evolved into Homo erectus / ergaster — the first hominin with a recognizably modern body plan, controlled fire, Acheulean handaxes, and the cognitive scaffolding to leave Africa. The transition was gradual; "where habilis ends and erectus begins" is a calibration choice, not a sharp event.',
   ARRAY['HOMININ_HABILIS']::text[],
   ARRAY['HOMININ_ERECTUS']::text[],
   ARRAY['CARR_HOMININ_HOMO_HABILIS']::text[],
   ARRAY['CARR_HOMININ_AFRICAN_ERECTUS']::text[],
   2, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_ERECTUS_OOA',
   'Homo erectus dispersal Out of Africa',
   -1900000, -1400000,
   ST_GeogFromText('SRID=4326;POINT(45 25)'),
   'The first hominin to leave Africa. Erectus / ergaster populations dispersed across Eurasia by ~1.8 Mya, reaching Dmanisi (Georgia), Java (Indonesia), and northern China, with later European descendants becoming antecessor and (eventually) heidelbergensis. The dispersal was probably not a single migration but multiple waves following large-mammal corridors.',
   ARRAY['HOMININ_ERECTUS']::text[],
   ARRAY['HOMININ_ERECTUS','HOMININ_ANTECESSOR']::text[],
   ARRAY['CARR_HOMININ_AFRICAN_ERECTUS']::text[],
   ARRAY['CARR_HOMININ_ASIAN_ERECTUS_JAVA','CARR_HOMININ_ASIAN_ERECTUS_CHINA','CARR_HOMININ_ANTECESSOR']::text[],
   3, 'island_settlement', 'DEDUCED_PHASE_0'),

  ('ADMIX_HEIDELBERGENSIS_EMERGENCE',
   'Heidelbergensis emerges from late Erectus / Antecessor',
   -800000, -600000,
   ST_GeogFromText('SRID=4326;POINT(20 35)'),
   'Across Africa and Eurasia, late-erectus and antecessor populations evolved into Homo heidelbergensis (and the African form sometimes split off as rhodesiensis). Larger brains, more sophisticated stone tools (transitional Acheulean / Levalloisian), early evidence of structured shelters and possibly hafted weapons.',
   ARRAY['HOMININ_ERECTUS','HOMININ_ANTECESSOR']::text[],
   ARRAY['HOMININ_HEIDELBERGENSIS','HOMININ_RHODESIENSIS']::text[],
   ARRAY['CARR_HOMININ_AFRICAN_ERECTUS','CARR_HOMININ_ANTECESSOR']::text[],
   ARRAY['CARR_HOMININ_HEIDELBERGENSIS','CARR_HOMININ_RHODESIENSIS']::text[],
   2, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_HEIDELBERGENSIS_SPLITS',
   'Heidelbergensis splits into Neanderthal + Denisovan + sapiens lineages',
   -600000, -400000,
   ST_GeogFromText('SRID=4326;POINT(30 35)'),
   'The Eurasian heidelbergensis populations diverge into two sister lineages — Neanderthals in the west, Denisovans in the east — while the African heidelbergensis / rhodesiensis lineage continues toward modern Homo sapiens. The three-way split is the "ghost-population trinity" of the modern human story: every living human carries genes from at least two of these three branches.',
   ARRAY['HOMININ_HEIDELBERGENSIS','HOMININ_RHODESIENSIS']::text[],
   ARRAY['NEANDERTHAL','DENISOVAN','AFR_BASAL']::text[],
   ARRAY['CARR_HOMININ_HEIDELBERGENSIS']::text[],
   ARRAY['CARR_HOMININ_NEANDERTHAL','CARR_HOMININ_DENISOVAN','CARR_HOMININ_RHODESIENSIS']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_INSULAR_HOMININS',
   'Insular Asian hominins: Floresiensis + Luzonensis + Naledi',
   -100000, -50000,
   ST_GeogFromText('SRID=4326;POINT(120 -8)'),
   'Multiple "side branches" of erectus persisted on Pleistocene islands long after their continental cousins disappeared. Homo floresiensis (Flores, Indonesia), Homo luzonensis (Luzon, Philippines), and the puzzling Homo naledi of South Africa each persisted into the time when modern humans were already spreading. Their relationships to the rest of the tree are still debated.',
   ARRAY['HOMININ_ERECTUS','HOMININ_HEIDELBERGENSIS']::text[],
   ARRAY['HOMININ_FLORESIENSIS','HOMININ_LUZONENSIS','HOMININ_NALEDI']::text[],
   ARRAY['CARR_HOMININ_ASIAN_ERECTUS_JAVA','CARR_HOMININ_HEIDELBERGENSIS']::text[],
   ARRAY['CARR_HOMININ_FLORESIENSIS','CARR_HOMININ_LUZONENSIS','CARR_HOMININ_NALEDI']::text[],
   2, 'island_settlement', 'DEDUCED_PHASE_0'),

  ('ADMIX_SAPIENS_EMERGENCE',
   'Anatomically modern Homo sapiens emerges in Africa',
   -315000, -200000,
   ST_GeogFromText('SRID=4326;POINT(20 15)'),
   'Across the African continent, late heidelbergensis / rhodesiensis populations evolve into anatomically modern Homo sapiens. The Jebel Irhoud finds (Morocco, ~315 kya) and the Omo / Herto remains (Ethiopia, ~200-160 kya) bookend this transition. Pan-African mosaic, not a single bottleneck — different sapiens-like traits (gracile face, globular braincase, prominent chin) appear in different regions over a hundred-thousand-year interval.',
   ARRAY['HOMININ_RHODESIENSIS','HOMININ_HEIDELBERGENSIS']::text[],
   ARRAY['AFR_BASAL']::text[],
   ARRAY['CARR_HOMININ_RHODESIENSIS','CARR_HOMININ_HEIDELBERGENSIS']::text[],
   ARRAY['CARR_HIST_JEBEL_IRHOUD','CARR_HIST_OMO_HERTO']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_AFRICAN_SAPIENS_DIVERSIFY',
   'African sapiens diversification (Khoe-San split + OOA source)',
   -200000, -70000,
   ST_GeogFromText('SRID=4326;POINT(25 0)'),
   'Within Africa, early sapiens populations diverge into deep regional lineages. The Khoe-San ancestral split is the deepest among living human populations (~200-150 kya). Other lineages persist in central / east / west Africa, and a small NE African subset eventually becomes the source of the Out-of-Africa dispersal that founds non-African humanity.',
   ARRAY['AFR_BASAL']::text[],
   ARRAY['AFR_BASAL','AFR_KHOISAN']::text[],
   ARRAY['CARR_HIST_OMO_HERTO','CARR_HIST_JEBEL_IRHOUD']::text[],
   ARRAY['CARR_HIST_KHOE_SAN_ANCESTRAL','CARR_HIST_AFR_EARLY_OOA_SOURCE']::text[],
   2, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_OOA_DEPARTURE',
   'Out-of-Africa dispersal',
   -75000, -55000,
   ST_GeogFromText('SRID=4326;POINT(40 20)'),
   'A small NE-African sapiens subset crosses into Eurasia, probably via Sinai or Bab-el-Mandeb, founding the population that becomes every non-African human alive today. The bottleneck is severe (effective founder population on the order of a few thousand), which is why all non-Africans are genetically more similar to each other than any of them are to many sub-Saharan populations.',
   ARRAY['AFR_BASAL']::text[],
   ARRAY['BASAL_EURASIAN','AFR_BASAL']::text[],
   ARRAY['CARR_HIST_AFR_EARLY_OOA_SOURCE']::text[],
   ARRAY['CARR_OOA_LEVANT_55K']::text[],
   3, 'island_settlement', 'DEDUCED_PHASE_0'),

  -- ==========================================================
  -- The original (post-OOA) admixture events.
  -- ==========================================================

  ('ADMIX_OOA_NEANDERTHAL_LEVANT',
   'Out-of-Africa × Neanderthal admixture',
   -55000, -47000,
   ST_GeogFromText('SRID=4326;POINT(35 31)'),
   'In the Levant, the small founder population emerging from the African bottleneck encountered Neanderthals who had been in Eurasia for 200,000+ years. The interbreeding event(s) gave every non-African modern human their 1-4% Neanderthal ancestry. Whether one or many encounters, the genetic trace is uniform across non-Africans.',
   ARRAY['AFR_BASAL','NEANDERTHAL']::text[],
   ARRAY['BASAL_EURASIAN','NEANDERTHAL']::text[],
   ARRAY['CARR_OOA_LEVANT_55K','CARR_HOMININ_NEANDERTHAL']::text[],
   ARRAY['CARR_OOA_LEVANT_55K']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_SAHUL_DENISOVAN',
   'Sahul founders × Denisovan admixture',
   -50000, -45000,
   ST_GeogFromText('SRID=4326;POINT(125 -3)'),
   'On the Wallacea / Sahul crossing, the ancestors of Australian Aboriginals and Papuans encountered Denisovans, producing the elevated Denisovan ancestry (3-6%) that distinguishes Australasians from other non-Africans. The crossings themselves required open-water voyaging between visible islands.',
   ARRAY['BASAL_EURASIAN','DENISOVAN']::text[],
   ARRAY['AUS_PNG','DENISOVAN']::text[],
   ARRAY['CARR_OOA_LEVANT_55K','CARR_HOMININ_DENISOVAN']::text[],
   ARRAY['CARR_AUS_ABORIGINAL','CARR_PAPUAN_45K']::text[],
   3, 'island_settlement', 'DEDUCED_PHASE_0'),

  -- ==========================================================
  -- Late Pleistocene events — fill the previously-empty
  -- ~45 kya → ~16 kya stretch on the timeline.
  -- ==========================================================

  ('ADMIX_EAST_WEST_EURASIAN_SPLIT',
   'Early Eurasian split: West vs East Eurasian',
   -45000, -38000,
   ST_GeogFromText('SRID=4326;POINT(60 35)'),
   'Within a few thousand years of the OOA dispersal, the Eurasian founder population fragmented into a Western branch (ancestor of Europeans, MENA, S Asians) and an Eastern branch (ancestor of E + SE Asians, Australasians via the earlier Sahul split, and Native Americans). The deepest extant Eurasian split.',
   ARRAY['BASAL_EURASIAN']::text[],
   ARRAY['BASAL_EURASIAN','EAST_ASIAN']::text[],
   ARRAY['CARR_OOA_LEVANT_55K']::text[],
   ARRAY['CARR_AURIGNACIAN_EU','CARR_TIANYUAN_40K']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_ANE_EMERGENCE',
   'Ancient North Eurasians (Mal''ta) form a third deep branch',
   -30000, -22000,
   ST_GeogFromText('SRID=4326;POINT(103 53)'),
   'In southern Siberia, a deep Eurasian lineage diverged before the West-Eurasian / East-Asian split fully consolidated. The Mal''ta-Buret'' boy is the type specimen for the Ancient North Eurasian (ANE) component, which later contributes to both the Yamnaya / Steppe ancestry of post-LGM Europe and the First Americans via the Beringian standstill.',
   ARRAY['BASAL_EURASIAN']::text[],
   ARRAY['ANE']::text[],
   ARRAY['CARR_OOA_LEVANT_55K','CARR_AURIGNACIAN_EU']::text[],
   ARRAY['CARR_MALTA_24K']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_LGM_REFUGIA',
   'Last Glacial Maximum bottleneck and refugia',
   -26000, -19000,
   ST_GeogFromText('SRID=4326;POINT(15 45)'),
   'At LGM peak (~21 kya), advancing ice sheets and tundra forced European hunter-gatherers into southern refugia (Iberian, Italian, Balkan). Steppe / mammoth-belt populations contracted east of the Urals. Many regional Aurignacian / Gravettian sub-lineages went extinct; the post-LGM repopulation re-mixed the survivors into what we now identify as Western Hunter-Gatherer (WHG) and Eastern Hunter-Gatherer (EHG) lineages.',
   ARRAY['BASAL_EURASIAN']::text[],
   ARRAY['WHG','EHG']::text[],
   ARRAY['CARR_AURIGNACIAN_EU','CARR_GRAVETTIAN_EU']::text[],
   ARRAY['CARR_WHG_MESO','CARR_EHG_MESO']::text[],
   4, 'demographic_swamp', 'DEDUCED_PHASE_0'),

  ('ADMIX_POSTLGM_HG_DIFFERENTIATION',
   'Post-LGM hunter-gatherer differentiation: WHG / EHG / CHG',
   -16000, -10000,
   ST_GeogFromText('SRID=4326;POINT(30 45)'),
   'As the ice sheets retreated, mesolithic Europe re-populated from refugia into three broad genetic clines: WHG (Western), EHG (Eastern), and CHG (Caucasus). The CHG component was largely isolated through the Caucasus mountains and contributed disproportionately to later Yamnaya ancestry. These three pre-Neolithic lineages are the substrate that Anatolian farmers and Steppe pastoralists later overlaid.',
   ARRAY['BASAL_EURASIAN']::text[],
   ARRAY['WHG','EHG','CHG']::text[],
   ARRAY['CARR_AURIGNACIAN_EU','CARR_GRAVETTIAN_EU']::text[],
   ARRAY['CARR_WHG_MESO','CARR_EHG_MESO','CARR_CHG_MESO']::text[],
   2, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_BERINGIAN_FIRST_AMERICANS',
   'Beringian crossing → First Americans',
   -16000, -13000,
   ST_GeogFromText('SRID=4326;POINT(-160 65)'),
   'A late-Pleistocene East Eurasian population mixed with Mal''ta-related Ancient North Eurasians (~35% ANE) in a Beringian standstill, then dispersed south into the Americas as the ice sheets retreated. Within ~2,000 years their descendants reached Tierra del Fuego — the most rapid continental-scale population spread in human history.',
   ARRAY['EAST_ASIAN','ANE']::text[],
   ARRAY['AMER_NA']::text[],
   ARRAY['CARR_TIANYUAN_40K','CARR_MALTA_24K']::text[],
   ARRAY['CARR_PALEO_AMER_15K']::text[],
   4, 'island_settlement', 'DEDUCED_PHASE_0'),

  ('ADMIX_ANATOLIAN_FARMERS_INTO_EUROPE',
   'Anatolian Farmer expansion into Europe',
   -7000, -5500,
   ST_GeogFromText('SRID=4326;POINT(15 45)'),
   'Anatolian Neolithic farmers expanded westward across the Mediterranean (Cardial Ware) and the Danube (Linearbandkeramik), bringing wheat / barley / sheep / goat / cattle to a continent of WHG hunter-gatherer foragers. Where farmers settled, they demographically dominated; small WHG admixture (5-30%) entered most early-Neolithic European communities. The end of European hunter-gatherer continuity.',
   ARRAY['ANATOLIAN_FARMER','WHG']::text[],
   ARRAY['EEF']::text[],
   ARRAY['CARR_ANATOLIAN_FARMER','CARR_WHG_MESO']::text[],
   ARRAY['CARR_HIST_HOL_CARDIAL','CARR_HIST_HOL_VINCA','CARR_HIST_HOL_FUNNELBEAKER']::text[],
   4, 'demographic_swamp', 'DEDUCED_PHASE_0'),

  ('ADMIX_IRN_ASI_INTO_HARAPPAN',
   'Iranian Neolithic × Ancient Ancestral South Indian → Harappan substrate',
   -7000, -3500,
   ST_GeogFromText('SRID=4326;POINT(72 28)'),
   'Pre-Harappan Indus Valley populations formed from a fusion of Iranian-Neolithic-derived farmers (entering from Mehrgarh) and Ancient Ancestral South Indians (the AASI / ASI substrate, related to the Andamanese). This is the genetic substrate the Indus Valley Civilization sat on — *before* any Steppe input.',
   ARRAY['IRN_N','ASI']::text[],
   ARRAY['ANI']::text[],
   ARRAY['CARR_IRAN_NEOLITHIC','CARR_HIST_FOR_S_ASIAN_MESO']::text[],
   ARRAY['CARR_HARAPPAN','CARR_HIST_HOL_MEHRGARH']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0'),

  ('ADMIX_YAMNAYA_INTO_EUROPE',
   'Steppe-MLBA expansion into Europe (Yamnaya / Corded Ware / Bell Beaker)',
   -3000, -2200,
   ST_GeogFromText('SRID=4326;POINT(15 50)'),
   'The headline Reich-Ch.6 event. Yamnaya pastoralists from the Pontic-Caspian steppe expanded westward, replacing ~50%+ of the male Y-chromosome lineage in northern Europe within a few centuries. Brought Indo-European languages, horse-and-wagon technology, and lactase persistence. Corded Ware and Bell Beaker cultures are the immediate fusion products. Cultural rupture is severe — Neolithic farming megaliths abandoned, new burial traditions, mass graves at e.g. Eulau interpreted as warfare.',
   ARRAY['YAMNAYA','EEF','WHG']::text[],
   ARRAY['STEPPE_MLBA']::text[],
   ARRAY['CARR_YAMNAYA','CARR_HIST_HOL_FUNNELBEAKER','CARR_HIST_HOL_CARDIAL']::text[],
   ARRAY['CARR_CORDED_WARE','CARR_BELL_BEAKER']::text[],
   5, 'violent_replacement', 'DEDUCED_PHASE_0'),

  ('ADMIX_STEPPE_INTO_SOUTH_ASIA',
   'Steppe-MLBA into South Asia (Indo-Aryan migrations)',
   -2000, -1200,
   ST_GeogFromText('SRID=4326;POINT(72 32)'),
   'Sintashta-Andronovo-derived Indo-Iranian-speaking pastoralists entered NW South Asia, fusing with the post-Harappan Iranian-Neolithic + AASI substrate to produce the modern North Indian / ANI demographic profile. Cultural rupture: Vedic religion, chariot warfare, varna social system. The contested Aryan migration / Out-of-India debate is over how this happened, not whether the genetic signal is real.',
   ARRAY['STEPPE_MLBA','ANI','ASI']::text[],
   ARRAY['ANI','ASI','STEPPE_MLBA']::text[],
   ARRAY['CARR_BELL_BEAKER','CARR_HIST_BRIDGE_ANDRONOVO','CARR_HARAPPAN']::text[],
   ARRAY['CARR_NW_SOUTH_ASIA_LATE_BRONZE','CARR_HIST_VEDIC_ARYAN']::text[],
   4, 'elite_dominance', 'DEDUCED_PHASE_0'),

  ('ADMIX_BANTU_EXPANSION',
   'Bantu expansion across sub-Equatorial Africa',
   -1500, 500,
   ST_GeogFromText('SRID=4326;POINT(20 -5)'),
   'Iron-Age agropastoralists from the Cameroon-Nigeria borderland expanded southward and eastward across most of sub-equatorial Africa over ~2000 years. Where they encountered Khoisan and pygmy forager populations, they typically demographically dominated; today most sub-equatorial Africans speak a Bantu language and carry primarily Niger-Congo / AFR_WEST ancestry. Substantial Khoisan admixture survives in the south; pygmy admixture survives in the rainforest.',
   ARRAY['AFR_WEST','AFR_KHOISAN','AFR_BASAL']::text[],
   ARRAY['AFR_WEST','AFR_KHOISAN']::text[],
   ARRAY['CARR_HIST_HOL_NOK','CARR_HIST_HOL_KINTAMPO','CARR_HIST_FOR_KHOISAN_HOL']::text[],
   ARRAY['CARR_HIST_GAP_BANTU_EXPANSION','CARR_HIST_GAP_GREAT_ZIMBABWE','CARR_HIST_GAP_KONGO']::text[],
   4, 'demographic_swamp', 'DEDUCED_PHASE_0'),

  ('ADMIX_LAPITA_PACIFIC',
   'Lapita expansion into Remote Oceania',
   -1500, -500,
   ST_GeogFromText('SRID=4326;POINT(170 -16)'),
   'Austronesian-speaking voyagers from the Bismarck Archipelago expanded into Vanuatu, Fiji, Samoa, Tonga — most of them previously uninhabited islands. The Lapita ceramic horizon marks the first peopling of Remote Oceania. Genetic evidence shows substantial Papuan admixture as voyagers passed through the Bismarcks.',
   ARRAY['EAST_ASIAN','AUS_PNG']::text[],
   ARRAY['EAST_ASIAN','AUS_PNG']::text[],
   ARRAY['CARR_PAPUAN_45K','CARR_HIST_MODERN_E_ASIAN']::text[],
   ARRAY['CARR_HIST_GAP_LAPITA','CARR_HIST_GAP_POLYNESIAN_EXP']::text[],
   3, 'island_settlement', 'DEDUCED_PHASE_0'),

  ('ADMIX_HAN_INTO_S_CHINA',
   'Han expansion southward into the Yangtze + South China',
   -200, 600,
   ST_GeogFromText('SRID=4326;POINT(112 25)'),
   'Han-Chinese-speakers expanded south from the Yellow River into the Yangtze basin and southern China over the Han and post-Han periods, demographically and linguistically replacing earlier Tai-Kadai, Hmong-Mien, and Austroasiatic populations. A continent-scale linguistic-and-demographic replacement that is often forgotten in narratives that focus on Eurasian westward movements.',
   ARRAY['EAST_ASIAN']::text[],
   ARRAY['EAST_ASIAN']::text[],
   ARRAY['CARR_HIST_HAN_CHINESE_EMPIRE']::text[],
   ARRAY['CARR_HIST_MODERN_HAN','CARR_HIST_TANG_CHINESE']::text[],
   3, 'demographic_swamp', 'DEDUCED_PHASE_0'),

  ('ADMIX_ARAB_CONQUESTS',
   'Early Islamic / Arab conquests',
   632, 750,
   ST_GeogFromText('SRID=4326;POINT(40 30)'),
   'In a single century, an Arabian peninsula confederation conquered Sasanian Persia, Byzantine Levant + Egypt + North Africa, Visigothic Spain, and Sind. Demographic replacement was modest in most regions but linguistic and religious rupture was profound — Arabic became the lingua franca from Morocco to Iraq, Islam the dominant faith, Greek and Coptic and Persian retreated. The Sephardi-Mizrahi-Arab demographic continuum dates from this fusion.',
   ARRAY['NATUFIAN','ANATOLIAN_FARMER','IRN_N']::text[],
   ARRAY['NATUFIAN']::text[],
   ARRAY['CARR_HIST_RASHIDUN_UMAYYAD']::text[],
   ARRAY['CARR_HIST_ABBASID','CARR_HIST_MODERN_ARAB','CARR_HIST_BERBER']::text[],
   3, 'elite_dominance', 'DEDUCED_PHASE_0'),

  ('ADMIX_TURKIC_INTO_ANATOLIA',
   'Turkic incursion into Anatolia + the Balkans',
   1071, 1500,
   ST_GeogFromText('SRID=4326;POINT(35 39)'),
   'Seljuk and later Ottoman Turkic speakers entered a Greek- and Armenian-speaking Anatolia after the 1071 Battle of Manzikert. Demographic replacement was partial — modern Turks carry significant Anatolian Neolithic ancestry — but the linguistic and religious replacement of Greek-Christian Anatolia by Turkish-Muslim Anatolia is profound.',
   ARRAY['EAST_ASIAN','ANATOLIAN_FARMER']::text[],
   ARRAY['ANATOLIAN_FARMER','EAST_ASIAN']::text[],
   ARRAY['CARR_HIST_TURKIC_GOKTURK','CARR_HIST_BYZANTINE']::text[],
   ARRAY['CARR_HIST_OTTOMAN']::text[],
   3, 'elite_dominance', 'DEDUCED_PHASE_0'),

  ('ADMIX_MONGOL_EXPANSION',
   'Mongol expansion across Eurasia',
   1206, 1294,
   ST_GeogFromText('SRID=4326;POINT(105 50)'),
   'In a single lifetime the Mongol Empire became the largest contiguous land empire in history. Demographic replacement was modest most places (the Pax Mongolica facilitated Eurasian trade rather than settlement), but the cultural rupture in Persia, Russia, and China was severe — Baghdad sacked 1258, Kyivan Rus dissolved, the Yuan dynasty replaced the Song.',
   ARRAY['EAST_ASIAN','ANE']::text[],
   ARRAY['EAST_ASIAN']::text[],
   ARRAY['CARR_HIST_MONGOL']::text[],
   ARRAY['CARR_HIST_MONGOL']::text[],
   2, 'elite_dominance', 'DEDUCED_PHASE_0'),

  ('ADMIX_EUROPEAN_AMERICAS',
   'European colonization of the Americas (1492-1800)',
   1492, 1800,
   ST_GeogFromText('SRID=4326;POINT(-75 5)'),
   'Spanish, Portuguese, English, French, Dutch settlement combined with old-world disease (smallpox, measles, influenza, typhus) reduced indigenous American populations by an estimated 90%+ in the first century after contact. Subsequent fusion produced the modern Mexican, Peruvian, Colombian, Brazilian, and Anglo-American demographic profiles. Severity is severe both as cultural rupture and as catastrophic mortality.',
   ARRAY['ANATOLIAN_FARMER','STEPPE_MLBA','WHG','AMER_NA']::text[],
   ARRAY['AMER_NA','ANATOLIAN_FARMER','STEPPE_MLBA','AFR_WEST']::text[],
   ARRAY['CARR_HIST_POST1492_COLONIAL_NA','CARR_HIST_AZTEC','CARR_HIST_INCA','CARR_HIST_GAP_TAINO']::text[],
   ARRAY['CARR_HIST_BRIDGE_COLONIAL_MESO','CARR_HIST_POST1492_COLONIAL_BR','CARR_HIST_POST1492_COLONIAL_ANDEAN','CARR_HIST_POST1492_REPUBLIC_US_WHITE']::text[],
   5, 'demographic_swamp', 'DEDUCED_PHASE_0'),

  ('ADMIX_ATLANTIC_SLAVE_TRADE',
   'Atlantic slave trade',
   1525, 1808,
   ST_GeogFromText('SRID=4326;POINT(-30 5)'),
   'Forced movement of an estimated 12.5 million West and West-Central Africans across the Atlantic into the Americas — the largest forced diaspora in human history. Mortality during the Middle Passage averaged 15-20%. The African American, Afro-Caribbean, and Afro-Brazilian populations are the demographic outcome; the West African source populations were demographically and economically devastated.',
   ARRAY['AFR_WEST','AFR_BASAL']::text[],
   ARRAY['AFR_WEST','ANATOLIAN_FARMER','STEPPE_MLBA','AMER_NA']::text[],
   ARRAY['CARR_HIST_GAP_KONGO','CARR_HIST_GAP_ASANTE','CARR_HIST_HOL_NOK']::text[],
   ARRAY['CARR_HIST_POST1492_AFRICAN_AMERICAN','CARR_HIST_POST1492_AFRO_CARIBBEAN','CARR_HIST_POST1492_COLONIAL_BR']::text[],
   5, 'forced_diaspora', 'DEDUCED_PHASE_0'),

  ('ADMIX_AFRICAN_AMERICAN_EURO_ADMIX',
   'European admixture into African American population (slavery + post-emancipation)',
   1700, 1965,
   ST_GeogFromText('SRID=4326;POINT(-87 33)'),
   'Genetic admixture between enslaved and post-emancipation African Americans and the surrounding European-American population. The African American population today carries roughly 80% West African + 14-20% European ancestry, with regional variation; the great majority of that European fraction was contributed under coercive plantation conditions before 1865, with smaller voluntary admixture afterward.',
   ARRAY['AFR_WEST','ANATOLIAN_FARMER','STEPPE_MLBA']::text[],
   ARRAY['AFR_WEST','ANATOLIAN_FARMER','STEPPE_MLBA']::text[],
   ARRAY['CARR_HIST_POST1492_COLONIAL_NA','CARR_HIST_POST1492_REPUBLIC_US_WHITE']::text[],
   ARRAY['CARR_HIST_POST1492_AFRICAN_AMERICAN']::text[],
   3, 'forced_diaspora', 'DEDUCED_PHASE_0'),

  ('ADMIX_GLOBAL_MIGRATION_C20',
   'Industrial-era global migration (post-1850)',
   1850, 2025,
   ST_GeogFromText('SRID=4326;POINT(0 30)'),
   'Steamship + air travel make demographic mixing global. European emigration to the Americas + Australasia, Indian indentured labour to the Caribbean / South Africa / Fiji, Chinese emigration across Southeast Asia and the Americas, post-WWII labour migration into Western Europe + the Gulf, post-1965 immigration to the United States. Modern cosmopolitan urban populations (SF Bay Area, Toronto, London, Sydney, Singapore) are the demographic outcome.',
   ARRAY['ANATOLIAN_FARMER','STEPPE_MLBA','AFR_WEST','EAST_ASIAN','ANI','ASI']::text[],
   ARRAY['ANATOLIAN_FARMER','STEPPE_MLBA','AFR_WEST','EAST_ASIAN','ANI','ASI']::text[],
   ARRAY['CARR_HIST_POST1492_GILDED_AGE_US','CARR_HIST_POST1492_MODERN_AUS','CARR_HIST_MODERN_EUROPEAN']::text[],
   ARRAY['CARR_SF_BAY_AREA_2025','CARR_HIST_POST1492_MODERN_USA','CARR_HIST_POST1492_PAKEHA_NZ']::text[],
   3, 'gradual_blend', 'DEDUCED_PHASE_0');
