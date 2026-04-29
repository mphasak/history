-- 024_seed_plight_narratives.sql
--
-- Adds a `carrier_plight` table — a 1-2 paragraph editorial narrative
-- per carrier covering everyday life, what led to their beginning, and
-- what led to their end. Pairs with the existing `carrier_threat` table:
-- threats are *itemized event-window* records, plight is the *narrative
-- gestalt* of what it meant to live as one of these people.
--
-- Schema-wise this is additive; no changes to 001_schema.sql, no
-- changes to ingest.py.
--
-- Idempotent: DELETE-by-prefix on carrier_id list.

CREATE TABLE IF NOT EXISTS carrier_plight (
  carrier_id text PRIMARY KEY REFERENCES carrier(id) ON DELETE CASCADE,
  everyday_life text NOT NULL,
  origin text,
  ending text,
  source_id text REFERENCES source(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DELETE FROM carrier_plight
WHERE carrier_id IN (
  SELECT carrier_id FROM (VALUES
    -- carriers we touch in this seed (subset chosen for high visibility):
    ('CARR_HOMININ_NEANDERTHAL'),
    ('CARR_HOMININ_DENISOVAN'),
    ('CARR_OOA_LEVANT_55K'),
    ('CARR_AUS_ABORIGINAL'),
    ('CARR_PAPUAN_45K'),
    ('CARR_PALEO_AMER_15K'),
    ('CARR_NATUFIAN_12K'),
    ('CARR_MALTA_24K'),
    ('CARR_HARAPPAN'),
    ('CARR_NW_SOUTH_ASIA_LATE_BRONZE'),
    ('CARR_HIST_VEDIC_ARYAN'),
    ('CARR_HIST_ROMAN'),
    ('CARR_HIST_HAN_CHINESE_EMPIRE'),
    ('CARR_HIST_NORSE'),
    ('CARR_HIST_MONGOL'),
    ('CARR_HIST_AZTEC'),
    ('CARR_HIST_INCA'),
    ('CARR_HIST_GAP_MALI_EMPIRE'),
    ('CARR_HIST_GAP_MAORI'),
    ('CARR_HIST_GAP_NAVAJO_APACHE'),
    ('CARR_HIST_POST1492_AFRICAN_AMERICAN'),
    ('CARR_HIST_POST1492_COLONIAL_NA'),
    ('CARR_HIST_POST1492_AFRIKANER'),
    ('CARR_RURAL_SOUTH_US_2025'),
    ('CARR_SF_BAY_AREA_2025')
  ) AS t(carrier_id)
);

-- Filter to carriers that actually exist — refactors / renames may
-- have changed IDs since this seed was written.
WITH proposed(carrier_id, everyday_life, origin, ending, source_id) AS (VALUES
  ('CARR_HOMININ_NEANDERTHAL',
   'Small bands of 10-30 people moved through cold-temperate Eurasia following game herds. Diet was meat-heavy: red deer, ibex, mammoth, supplemented with seasonal plants and shellfish along the Mediterranean coasts. Stone toolkits centered on the Mousterian flake industry; hide clothing was sewn with bone awls but not yet tailored. Caves were used for shelter, fire was managed, and the dead were sometimes deliberately buried with grave goods. Lifespans rarely exceeded 40, and skeletons are riddled with healed fractures from close-quarters hunting.',
   'Diverged from a heidelbergensis-like ancestor in Eurasia ~430-300 kya; a separate sister lineage to the African ancestors of modern humans.',
   'Outcompeted and absorbed during the modern-human spread across Europe ~45-40 kya. The lineage did not vanish biologically — every non-African modern human carries 1-4% Neanderthal DNA from interbreeding — but the cultural and morphological lineage ended.',
   'DEDUCED_PHASE_0'),

  ('CARR_HOMININ_DENISOVAN',
   'Almost everything we know about Denisovans comes from a few teeth, a finger bone, and a partial skull, plus the genome those samples produced. Inferred range covered Siberia, the Tibetan plateau, and probably much of insular SE Asia. They likely lived in small mobile bands like Neanderthals, with stone tools and at least some hide clothing, but the archaeological signature is genuinely sparse — much of what we infer comes from the archaic DNA in modern populations.',
   'Diverged from the Neanderthal lineage ~400 kya, persisting in Asia while Neanderthals dominated Europe.',
   'Disappeared as a distinct lineage during the same modern-human expansion that absorbed Neanderthals; the genetic legacy is most concentrated today in Papuans (3-6%) and Aboriginal Australians (~4%).',
   'DEDUCED_PHASE_0'),

  ('CARR_OOA_LEVANT_55K',
   'A small founder population of perhaps a few thousand individuals in the Levant, post-bottleneck, surviving by hunting gazelle and ibex along Mediterranean uplands and gathering wild cereals. Already encountering Neanderthals in the same landscape — the admixture event that gives all non-Africans their 1-4% Neanderthal ancestry happened here, around this time.',
   'Recent African migrants who exited via Sinai or Bab-el-Mandeb after a population bottleneck of unknown cause; not the first sapiens out of Africa, but the founder population from which most non-Africans descend.',
   'Differentiated rapidly into the Eurasian, East Eurasian, and Australasian lineages over the next 10,000 years as small daughter groups dispersed eastward.',
   'DEDUCED_PHASE_0'),

  ('CARR_AUS_ABORIGINAL',
   'Continuous occupation of the Australian continent for the better part of 50,000 years. Pre-contact lifeways spanned an enormous range — Top-End wetlands fishers, Western-Desert quartzite-tool foragers, Tasmanian sea-mammal hunters, riverine Murray-Darling sedentary villagers. Custodianship of country grounded in song-cycles encoding ancestral journeys; technical mastery of fire-stick farming maintained mosaic habitats across most of the continent.',
   'Crossed open water from Sundaland to Sahul ~50-65 kya, among the earliest seafaring human dispersals; carries elevated Denisovan ancestry from admixture en route.',
   'Did not end as a population — modern Aboriginal Australians are direct descendants. But the pre-contact way of life was severely disrupted by British colonization 1788 onward: massacre, disease, the Stolen Generations, and ongoing dispossession have erased an estimated 90%+ of pre-contact languages and cultural practices.',
   'DEDUCED_PHASE_0'),

  ('CARR_PAPUAN_45K',
   'Highland New Guinea hosts the world''s greatest linguistic density: ~800 mutually unintelligible languages across a few hundred miles. Pre-contact lifeways were sedentary horticultural by ~9,000 years ago — taro and yam cultivation predates the Neolithic of the Levant. Pig husbandry, sago palm processing, and elaborate big-man political systems characterized the highlands; coastal groups fished and traded with island Melanesia.',
   'Sister lineage to Australian Aboriginals after the Sahul split; carries the highest Denisovan ancestry observed (3-6%).',
   'Continues to the present. Western New Guinea (West Papua) is under Indonesian sovereignty with ongoing tensions over independence; Eastern New Guinea forms the independent state of Papua New Guinea since 1975.',
   'DEDUCED_PHASE_0'),

  ('CARR_PALEO_AMER_15K',
   'Small, highly mobile bands following Pleistocene megafauna across an unfamiliar continent. Clovis-tradition fluted points appear from Alaska to the Atlantic within centuries — a remarkably fast techno-cultural spread. Diet was megafauna-heavy at first (mammoth, mastodon, bison antiquus) but quickly diversified to include smaller game, fish, and plants as the climate warmed.',
   'Crossed Beringia from northeast Asia during the Last Glacial Maximum, then dispersed south through ice-free corridors and along the Pacific coast as the continent deglaciated ~16-13 kya.',
   'Diversified rapidly into the regional Native American populations — Clovis ended ~12,800 years ago coincident with the Younger Dryas climate event and megafaunal extinctions.',
   'DEDUCED_PHASE_0'),

  ('CARR_NATUFIAN_12K',
   'Sedentary or semi-sedentary villages in the Levant 13,000-9,500 years ago — among the earliest human populations to *stay put* before agriculture. Diet was wild cereals (emmer, barley) gathered with sickle blades, plus gazelle, fish, and waterfowl. Stone houses with plastered floors, communal storage pits, dog burials, decorative shell ornaments. Rich inhumation tradition with red-ochre and bone-bead grave goods.',
   'Late-Pleistocene Levantine population, possibly with North African / sub-Saharan substrate.',
   'Transitioned into the Pre-Pottery Neolithic A and B as deliberate cereal cultivation took hold ~10,500 BCE — the lineage didn''t end so much as become Neolithic farmers.',
   'DEDUCED_PHASE_0'),

  ('CARR_MALTA_24K',
   'Mammoth-bone hut dwellers in central Siberia during the depths of the LGM. The "Mal''ta boy" individual — a 4-year-old with a Venus-figurine grave inclusion — yielded the first Ancient North Eurasian (ANE) genome. Microblade lithic technology, ivory pendants, and what may be the oldest known sewing needles. Climate was sub-arctic, with bands following migratory ungulate herds across an open mammoth-steppe.',
   'Upper Paleolithic Eurasian descendants of the OOA dispersal who pushed east-of-the-Urals along high-latitude refugia.',
   'Mal''ta-Buret'' culture proper ended ~16 kya, but its descendants — the Ancient North Eurasian lineage — contributed substantially to both the First Americans and to post-LGM European populations via the Bronze Age Yamnaya.',
   'DEDUCED_PHASE_0'),

  ('CARR_HARAPPAN',
   'The first true cities of South Asia: Mohenjo-daro and Harappa each housed perhaps 30,000 people behind brick-walled grids with covered drainage and standardized weights and measures. Subsistence rested on wheat / barley agriculture and Indus floodplain irrigation; trade reached as far as Mesopotamia (the Akkadians called it Meluḫḫa). The undeciphered Indus script appears on stamp seals depicting deities, animals, and ritual scenes.',
   'Grew out of the Mehrgarh Neolithic farmers of Balochistan over several millennia; the trait mix is Iranian Neolithic + Ancestral South Indian, with no Steppe component yet.',
   'Decline 1900-1300 BCE: monsoon weakening, possible Sarasvati-river drying, abandonment of major centers. Population dispersed eastward into the Ganges plain and was absorbed by the incoming Indo-Aryan-speaking Steppe-derived migrants.',
   'DEDUCED_PHASE_0'),

  ('CARR_NW_SOUTH_ASIA_LATE_BRONZE',
   'A transitional population: the demographic substrate of the Punjab and the Indus Valley as the Harappan urban order collapsed and Steppe-derived pastoralists arrived from the northwest. Lifeways were a mix of declining urbanism, Vedic ritual texts being composed in oral tradition, agricultural intensification along the Ganges-Yamuna doab, and incoming horse-and-chariot warrior elites.',
   'Substrate descended from the Harappan / Mehrgarh Neolithic complex, with new Steppe MLBA admixture from incoming Indo-Iranian-speaking pastoralists.',
   'Ancestor of the Vedic Aryan / classical North Indian populations; the lineage didn''t end so much as fully synthesize into the next stage of South Asian history.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_VEDIC_ARYAN',
   'Sanskrit-speaking pastoralist-warrior society in the Punjab and upper Ganges, organized around tribal confederations (the Kuru, Pañchāla, etc.). The Rig Veda — the world''s oldest extant religious text, transmitted orally for ~1500 years — was composed during this period. Cattle were the primary measure of wealth; horse sacrifice (aśvamedha) was the kingly rite. Iron metallurgy spread late in the period.',
   'Indo-Aryan-speaking migrants from the Steppe (Sintashta-Andronovo culture) integrated with the post-Harappan population of NW South Asia.',
   'Transitioned into the Mahājanapada period ~600 BCE, when the tribal confederations consolidated into 16 great kingdoms; Vedic religion gradually elaborated into classical Hinduism.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_ROMAN',
   'A society organized obsessively around legal status: citizen, freedman, slave, peregrine, with each gradient affecting dress, taxation, marriage, capital punishment. Daily life for citizens involved the forum, public baths, the patron-client morning salutatio. For the rural majority — most Romans were small-holding farmers, not legionnaires — life was harvest cycles, tax-rolls, and military levies. For slaves it was anything from being tutor to a senator''s children to dying in a lead mine.',
   'Latin city-state on the Tiber that absorbed its neighbors through warfare and citizenship offers, then expanded across the Italian peninsula and the Mediterranean basin over four centuries.',
   'Western Empire fragmented under Germanic federate kingdoms 476 CE; the Eastern Empire continued as Byzantium until 1453 CE. Roman civil law and the Latin literary tradition were absorbed into every successor state in Europe.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_HAN_CHINESE_EMPIRE',
   'A Confucian bureaucratic state of perhaps 60 million people — comparable to contemporary Rome. Civil-service examinations selected county-level administrators from the literati; the imperial court ran a coordinated system of state monopolies (iron, salt, alcohol). For peasants, life centered on the rice or millet harvest, corvée labor on canals and walls, and the ever-present threat of nomadic raids from the Xiongnu. Paper, the seismograph, and the rudder were Han-era innovations.',
   'Liu Bang''s peasant rebellion against the brief Qin dynasty established the Han in 206 BCE.',
   'Collapsed into the Three Kingdoms period 220 CE under combined eunuch-court paralysis, imperial-tax-collapse, and the Yellow Turban Rebellion.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_NORSE',
   'Scandinavian seafarers who combined raiding, trading, and colonizing across an extraordinary range — Iceland, Greenland, Vinland (Newfoundland), the Hebrides, Normandy, the Volga, Constantinople. Domestic society was small-scale agropastoral with ironworking; social stratification ran karl (free farmer), jarl (chief), thrall (slave). The Things — open-air assemblies — pre-figure later Scandinavian parliamentary tradition.',
   'Late Iron Age Scandinavian populations whose maritime technology (clinker-built longships, magnetic compass, sun-stone navigation) outpaced their neighbors in the 8th c.',
   'The Viking-era sea-raider economy was extinguished by the consolidation of European Christian kingdoms and the conversion of Scandinavia itself ~1000-1200 CE; the descendant populations are the modern Norwegians, Swedes, Danes, and Icelanders.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_MONGOL',
   'Steppe horse-pastoralist confederations welded together by Genghis Khan. Daily life centered on the ger (yurt), seasonal migration with herds of horses, sheep, goats, cattle, camels; an adult male could be expected to ride and shoot a recurve composite bow simultaneously. Imperial administration overlaid this with a courier-post (yam) system, religious tolerance as policy, and the codified Yassa law.',
   'Genghis Khan unified the Mongolic and Turkic clans of the Mongolian Plateau in 1206.',
   'The unified empire fractured into four khanates (Yuan, Chagatai, Ilkhanate, Golden Horde) by the late 13th c.; each was absorbed by local successor states (Ming, Timurids, Iranians, Russians) over the next two centuries.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_AZTEC',
   'A tributary empire centered on Tenochtitlan — an island city of perhaps 200,000, larger than any contemporary European capital. Daily life was ordered by the calpulli (neighborhood corporate group): collective land-holding, intramural schools, and the steam-bathing ritual. Food was maize-based — tortillas, tamales, atole — supplemented by amaranth, beans, squash, chia, chinampa-grown vegetables, and (for elites) chocolate, dog meat, and the human-flesh ritual feasts.',
   'The Mexica migrated into the Valley of Mexico from the north (Aztlán in legend, possibly Chichimec country) ~1300 CE and founded Tenochtitlan in 1325.',
   'Conquered by Hernán Cortés and his Tlaxcalan allies 1519-1521; the population collapsed by 80-90% from smallpox and forced labor over the following century.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_INCA',
   'A Quechua-administered empire stretching from southern Colombia to central Chile, organized in vertical complementarity: each community held lands at multiple altitudes for tubers, maize, alpaca herding. The mit''a labor draft built terraces, roads (the Qhapaq Ñan stretched ~40,000 km), and the storehouses (qollqa) that buffered famine years. No writing in the alphabetic sense; record-keeping by knotted-cord khipu.',
   'A Cuzco-valley chiefdom that conquered its neighbors ~1430 CE under Pachakuti and his successors.',
   'Conquered by Francisco Pizarro and his small Spanish force 1532-1572. Civil war between Atahualpa and Huáscar, plus old-world disease, undid the empire faster than the conquistadors did.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_GAP_MALI_EMPIRE',
   'A Sudanic gold-and-salt trade state spanning the Sahel from the Atlantic to the Niger bend. Daily life ranged from the Mande-speaking peasantry (millet, sorghum, fishing along the Niger) to the urban scholarly classes of Timbuktu and Djenné, where Islamic law schools produced manuscripts that still survive in the Mamma Haidara library. The mansa (king) was sacred-monarchic; Mansa Musa''s 1324 hajj famously crashed Egyptian gold prices for a decade.',
   'Sundiata Keita founded the empire ~1235 by defeating the Sosso king Sumanguru at the Battle of Kirina.',
   'Internal succession struggles plus Songhai expansion stripped the empire''s territory through the 15th c.; reduced to a small chieftaincy by 1670.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_GAP_MAORI',
   'Polynesian society in the cool temperate latitudes of Aotearoa, organized around iwi (tribes) and hapū (clans). Subsistence was kūmara (sweet potato), seasonal moa hunting (until extinction ~1450), seabird and shellfish gathering. Fortified pā on volcanic cones, elaborate carved meeting houses (whare runanga), full-body tā moko tattooing as a record of genealogy and rank.',
   'Polynesian voyagers settling Aotearoa ~1280-1320 CE — among the last large landmasses humans reached.',
   'Did not end. Treaty of Waitangi 1840 with the British Crown is the constitutional basis of modern New Zealand; subsequent New Zealand Wars and land alienation reduced the population to a low of ~42,000 in 1896, but it has since recovered to over 850,000 with a vigorous cultural and political revival.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_GAP_NAVAJO_APACHE',
   'Athabaskan-speaking pastoralist and agricultural societies in the US Southwest. Diné (Navajo) life traditionally centered on the four sacred mountains, sheep herding (post-Spanish-introduction), maize / bean / squash farming, and matrilineal hogan-based households. Apache groups varied from the agricultural Chiricahua and Mescalero to the more mobile Western Apache; raiding economies persisted into the late 19th c.',
   'Migrated south from the Athabaskan homelands of subarctic Canada ~1400 CE, arriving in the SW around the time of Pueblo cultural reorganization.',
   'Did not end. The Long Walk (1864) and subsequent reservation period devastated the population, but the Diné now number over 400,000, governing themselves through the Navajo Nation; the Apache nations persist on multiple reservations across the SW.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_POST1492_AFRICAN_AMERICAN',
   'A people forged under conditions designed to deny their existence as a people. The plantation South: cotton or tobacco from sunup to sundown, enforced family separations, codified illiteracy laws. The post-emancipation South: sharecropping, Jim Crow, lynching, the resilience of Black churches, fraternal lodges, and historically Black colleges. The Great Migration (1910-70) reshaped the country: Chicago jazz clubs, Harlem Renaissance, Detroit auto plants, Watts and the South Side. Civil-rights organizing produced legislation that reordered American law in the 1960s; the demographic and cultural reach now is national.',
   'Atlantic-slave-trade-derived from West and West-Central African source populations 1619-1808 (legal trade end), with smaller continued illegal imports through the Civil War. Substantial European-American admixture under slavery; smaller Native American admixture especially in the SE.',
   'Has not ended; rather, has continuously evolved. Demographic share is ~13.6% of the modern US population.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_POST1492_COLONIAL_NA',
   'English / Dutch / French settler communities along the Atlantic seaboard. Daily life turned on subsistence farming (corn, wheat, livestock), Atlantic merchant trade, and — for southern colonies — chattel slavery as the labor system. Religious dissent (Puritans, Quakers, Huguenots, Moravians) drove much of the migration. Town meetings in New England, plantation politics in the Tidewater, frontier-warfare militia culture along the western edge.',
   'Founded at Jamestown (1607) and Plymouth (1620); consolidated through 13 colonies by the mid-18th c.',
   'Transitioned into the United States after independence 1776-1783; subsequent expansion westward and demographic absorption of post-1840 immigrants reshaped the population continuously.',
   'DEDUCED_PHASE_0'),

  ('CARR_HIST_POST1492_AFRIKANER',
   'Cape-Dutch settler society shaped by the trekboer (trekking-farmer) frontier life: cattle ranching across the Karoo and Highveld, ox-wagon migration, intense Calvinist piety, and centuries of warfare with the Khoekhoe, Xhosa, and Zulu. Twentieth-century urbanization built Johannesburg and Pretoria; the National Party''s 1948-1994 apartheid regime institutionalized racial separation as state policy.',
   'Dutch East India Company refreshment station at the Cape, founded 1652; substantial later Huguenot and German migration.',
   'Apartheid ended through internal resistance and international sanctions 1990-1994. Afrikaners are now ~5% of the South African population, navigating a multi-racial democratic state.',
   'DEDUCED_PHASE_0'),

  ('CARR_RURAL_SOUTH_US_2025',
   'A demographically aging, predominantly white, predominantly Christian population spread across small towns, county seats, and unincorporated rural areas across the US South. Economy turns on agriculture, manufacturing, military bases, and the service sector; healthcare and broadband access lag urban areas; opioid mortality has scarred Appalachian and Gulf-coast counties. Strong evangelical Protestant majorities, NASCAR / college-football fandom, country music, hunting culture.',
   'Descended from English / Scots-Irish / German colonial settlers of 17th-19th centuries, with later European admixture and historic intermixture with Native American (small fraction) and African American (small fraction) populations.',
   'Has not ended. Politically and demographically central to the modern US Republican coalition.',
   'DEDUCED_PHASE_0'),

  ('CARR_SF_BAY_AREA_2025',
   'A demographically diverse, metropolitan tech-economy population spanning San Francisco, Oakland, San Jose, and the inner East Bay. Economy dominated by technology (software, semiconductors, biotech, AI) plus finance, media, university research, and knowledge-services. Housing is acutely scarce and expensive; demographic profile is roughly one-third European-American, one-third Asian-American, one-fifth Latino, and ~6% African-American, with very high rates of foreign-born residents (~30%).',
   'Spanish mission outpost (1776) → US territory (1846) → Gold Rush (1849) → Stanford and Berkeley founding (1880s-90s) → wartime industrial buildup (1940s) → post-1970s tech industry → 2010s second tech boom.',
   'Has not ended. Faces structural challenges around housing, homelessness, and inequality despite extraordinary aggregate wealth.',
   'DEDUCED_PHASE_0')
)
INSERT INTO carrier_plight (carrier_id, everyday_life, origin, ending, source_id)
SELECT p.carrier_id, p.everyday_life, p.origin, p.ending, p.source_id
FROM proposed p
WHERE EXISTS (SELECT 1 FROM carrier WHERE carrier.id = p.carrier_id);
