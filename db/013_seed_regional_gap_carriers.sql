-- 013_seed_regional_gap_carriers.sql
--
-- Fills regional coverage gaps that remained after 005/010/012:
--
--   * South America: pre-Inca Andean (Moche, Nazca, Wari, Tiwanaku) +
--     Amazonian Marajoara + Mapuche (southern cone).
--   * Mesoamerica: Teotihuacan, Toltec, Zapotec, Mixtec, Purépecha (Tarascan),
--     Caribbean Taíno.
--   * Sub-Saharan Africa post-classical: Bantu expansion, Mali / Songhai
--     empires, Great Zimbabwe, Kingdom of Kongo, Swahili coast, Asante.
--   * Pacific: Lapita voyagers, Polynesian expansion, Maori, Hawaiians.
--   * Siberia / North Asia: Yakuts, Chukchi, Inuit / Thule.
--   * Modern indigenous-American populations the 005 seed skipped:
--     Navajo / Apache (Athabaskan southern expansion).
--
-- All citations point to DEDUCED_PHASE_0 (best-effort editorial summary)
-- since most of these populations don't have a single canonical genetics
-- paper attached, and the goal of this seed is *coverage* — the lineage,
-- threat, and trait-mix tables can refine these later when better citations
-- arrive.
--
-- Idempotent: DELETE keyed on the CARR_HIST_GAP_* prefix this file owns.
-- Must run AFTER carriers-seed (005) and holocene-carriers-seed (010) so
-- those don't wipe these entries.

DELETE FROM carrier_threat WHERE carrier_id LIKE 'CARR_HIST_GAP_%';
DELETE FROM carrier_trait_mix WHERE carrier_id LIKE 'CARR_HIST_GAP_%';
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_GAP_%'
);
DELETE FROM claim
WHERE statement LIKE '[AUTO-PROVENANCE]%' AND subject_id LIKE 'CARR_HIST_GAP_%';
DELETE FROM carrier WHERE id LIKE 'CARR_HIST_GAP_%';

INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- ---- South America ----
  ('CARR_HIST_GAP_MOCHE', 'Moche', 'population',
   100, 800, ST_GeogFromText('SRID=4326;POINT(-79.0 -8.0)'),
   'Moche', NULL,
   'North-coastal Peruvian state-level society; large adobe pyramids (Huaca del Sol/Luna), naturalistic ceramic portraiture, irrigation agriculture.'),
  ('CARR_HIST_GAP_NAZCA', 'Nazca', 'population',
   -100, 800, ST_GeogFromText('SRID=4326;POINT(-75.0 -14.5)'),
   'Nazca', NULL,
   'South-coastal Peruvian society; geoglyphs (Nazca Lines), polychrome textiles, ceramic vessels with stylized iconography.'),
  ('CARR_HIST_GAP_WARI', 'Wari (Huari)', 'population',
   500, 1100, ST_GeogFromText('SRID=4326;POINT(-74.2 -13.1)'),
   'Wari', NULL,
   'Andean Middle Horizon empire centered near Ayacucho; planned administrative centers, road network, terraced agriculture; precursor to Inca statecraft.'),
  ('CARR_HIST_GAP_TIWANAKU', 'Tiwanaku', 'population',
   400, 1100, ST_GeogFromText('SRID=4326;POINT(-68.7 -16.6)'),
   'Tiwanaku', NULL,
   'Lake Titicaca basin civilization (modern Bolivia); monumental architecture (Akapana, Gateway of the Sun), raised-field agriculture; collapsed during the Medieval Drought.'),
  ('CARR_HIST_GAP_MARAJOARA', 'Marajoara', 'population',
   400, 1300, ST_GeogFromText('SRID=4326;POINT(-49.5 -1.0)'),
   'Marajoara', NULL,
   'Pre-Columbian Amazonian society on Marajó Island (mouth of the Amazon); large mound complexes, polychrome ceramics, complex chiefdoms.'),
  ('CARR_HIST_GAP_MAPUCHE', 'Mapuche', 'population',
   500, 2025, ST_GeogFromText('SRID=4326;POINT(-72.0 -38.0)'),
   'Mapuche', 'Mapudungun',
   'Southern-cone Chilean/Argentine indigenous nation; resisted both Inca and Spanish conquest, retained autonomy until the late 19th c.'),

  -- ---- Mesoamerica & Caribbean ----
  ('CARR_HIST_GAP_TEOTIHUACAN', 'Teotihuacanos', 'population',
   -100, 600, ST_GeogFromText('SRID=4326;POINT(-98.8 19.7)'),
   'Teotihuacan', NULL,
   'Central-Mexican metropolis; Pyramids of the Sun and Moon, multi-ethnic city of >100k people, dominant influence across Mesoamerica before sudden collapse ~550.'),
  ('CARR_HIST_GAP_ZAPOTEC', 'Zapotec', 'population',
   -500, 1521, ST_GeogFromText('SRID=4326;POINT(-96.7 17.0)'),
   'Zapotec', 'Zapotecan',
   'Oaxaca Valley civilization centered on Monte Albán; one of the earliest Mesoamerican writing systems; persisted through the Classic and Post-Classic.'),
  ('CARR_HIST_GAP_MIXTEC', 'Mixtec', 'population',
   900, 1521, ST_GeogFromText('SRID=4326;POINT(-97.0 17.5)'),
   'Mixtec', 'Mixtecan',
   'Oaxacan post-classic civilization; codices documenting royal genealogies, fine metallurgy and turquoise mosaics.'),
  ('CARR_HIST_GAP_TOLTEC', 'Toltec', 'population',
   900, 1150, ST_GeogFromText('SRID=4326;POINT(-99.3 20.1)'),
   'Toltec', 'Nahuan',
   'Central-Mexican Post-Classic state centered on Tula; militaristic iconography (atlantes), heavy influence on Aztec self-mythology.'),
  ('CARR_HIST_GAP_PUREPECHA', 'Purépecha (Tarascan)', 'population',
   1300, 1521, ST_GeogFromText('SRID=4326;POINT(-101.7 19.6)'),
   'Tarascan', 'Purépecha',
   'Western-Mexican empire that successfully resisted Aztec expansion; advanced bronze metallurgy unique in pre-conquest Mesoamerica.'),
  ('CARR_HIST_GAP_TAINO', 'Taíno', 'population',
   1200, 1550, ST_GeogFromText('SRID=4326;POINT(-72.0 19.0)'),
   'Taíno', 'Arawakan',
   'Indigenous Caribbean population (Greater Antilles); first Native American group encountered by Columbus; demographically devastated within decades by disease and forced labor.'),

  -- ---- Sub-Saharan Africa post-classical ----
  ('CARR_HIST_GAP_BANTU_EXPANSION', 'Bantu expansion', 'population',
   -1500, 500, ST_GeogFromText('SRID=4326;POINT(15.0 0.0)'),
   'Bantu', 'Bantu',
   'Iron-age agropastoralist expansion from the Cameroon/Nigeria border across most of sub-equatorial Africa over ~2000 years; the demographic event that produced most modern speakers of Bantu languages.'),
  ('CARR_HIST_GAP_GHANA_EMPIRE', 'Ghana Empire', 'population',
   700, 1240, ST_GeogFromText('SRID=4326;POINT(-9.0 16.0)'),
   'Ghana / Wagadu', 'Soninke',
   'West African gold-and-salt trade empire (modern Mauritania/Mali); first of the Sahelian empires, conduit of Trans-Saharan commerce.'),
  ('CARR_HIST_GAP_MALI_EMPIRE', 'Mali Empire', 'population',
   1230, 1670, ST_GeogFromText('SRID=4326;POINT(-7.0 13.0)'),
   'Mali', 'Mande',
   'Successor of Ghana; Mansa Musa''s 1324 hajj displayed wealth that destabilized Mediterranean gold prices; Timbuktu as Islamic scholarly center.'),
  ('CARR_HIST_GAP_SONGHAI', 'Songhai Empire', 'population',
   1464, 1591, ST_GeogFromText('SRID=4326;POINT(-3.0 16.0)'),
   'Songhai', 'Songhai',
   'Largest of the Sahelian empires; centered on Gao and Timbuktu; collapsed after Moroccan invasion using firearms in 1591.'),
  ('CARR_HIST_GAP_GREAT_ZIMBABWE', 'Great Zimbabwe', 'population',
   1100, 1500, ST_GeogFromText('SRID=4326;POINT(30.9 -20.3)'),
   'Great Zimbabwe / Shona', 'Shona',
   'Southern African dry-stone-walled capital; gold and ivory trade with the Swahili coast; abandoned in the 15th c. for reasons still debated (drought, soil exhaustion, trade shifts).'),
  ('CARR_HIST_GAP_KONGO', 'Kingdom of Kongo', 'population',
   1390, 1914, ST_GeogFromText('SRID=4326;POINT(14.0 -6.0)'),
   'Kongo', 'Kikongo',
   'West-Central African state that converted to Christianity ~1490; became deeply enmeshed in the Atlantic slave trade; ravaged by colonial wars and partition.'),
  ('CARR_HIST_GAP_SWAHILI_COAST', 'Swahili coast city-states', 'population',
   800, 1700, ST_GeogFromText('SRID=4326;POINT(40.0 -5.0)'),
   'Swahili', 'Swahili',
   'East-African coastal merchant city-states (Kilwa, Mombasa, Zanzibar); Indian Ocean trade in gold, ivory, slaves; Swahili language/culture as Bantu-Arabic synthesis.'),
  ('CARR_HIST_GAP_ASANTE', 'Asante (Ashanti)', 'population',
   1670, 1900, ST_GeogFromText('SRID=4326;POINT(-1.6 6.7)'),
   'Asante', 'Twi',
   'Akan-speaking West-African empire centered on Kumasi; gold-rich, militarily formidable; resisted British expansion through five Anglo-Ashanti wars.'),
  ('CARR_HIST_GAP_ETHIOPIAN_HIGHLAND', 'Highland Ethiopians (Solomonic)', 'population',
   1270, 1974, ST_GeogFromText('SRID=4326;POINT(38.7 9.0)'),
   'Solomonic / Abyssinian', 'Amharic',
   'Christian highland-Ethiopian polity (post-Aksum); Solomonic dynasty traced descent from Solomon and the Queen of Sheba; one of two African states to retain independence through the colonial era.'),

  -- ---- Pacific / Oceania ----
  ('CARR_HIST_GAP_LAPITA', 'Lapita voyagers', 'population',
   -1500, -500, ST_GeogFromText('SRID=4326;POINT(170.0 -16.0)'),
   'Lapita', 'Proto-Oceanic',
   'Bismarck-archipelago to Polynesia maritime expansion; distinctive dentate-stamped pottery; ancestor of all Polynesian, Micronesian, and most Melanesian populations.'),
  ('CARR_HIST_GAP_POLYNESIAN_EXP', 'Polynesian expansion', 'population',
   -800, 1300, ST_GeogFromText('SRID=4326;POINT(-160.0 -15.0)'),
   'Polynesian', 'Polynesian',
   'Voyaging-canoe expansion from Samoa/Tonga across the Pacific to Hawaii, Easter Island, and Aotearoa (NZ); celestial navigation; one of the largest geographic dispersals of any culture.'),
  ('CARR_HIST_GAP_MAORI', 'Māori', 'population',
   1280, 2025, ST_GeogFromText('SRID=4326;POINT(174.0 -41.0)'),
   'Māori', 'Te Reo Māori',
   'Polynesian settlers of Aotearoa (New Zealand); developed a distinctive material culture, fortified pā, and (after British colonization) preserved indigenous sovereignty through the Treaty of Waitangi process.'),
  ('CARR_HIST_GAP_HAWAIIAN', 'Native Hawaiian (Kānaka Maoli)', 'population',
   1000, 2025, ST_GeogFromText('SRID=4326;POINT(-157.0 21.0)'),
   'Hawaiian', 'ʻŌlelo Hawaiʻi',
   'Polynesian-derived Hawaiian Archipelago population; unified under Kamehameha I in 1810; lost sovereignty to U.S. annexation in 1898.'),

  -- ---- Siberia / Arctic / North Asia ----
  ('CARR_HIST_GAP_YAKUT', 'Yakuts (Sakha)', 'population',
   1200, 2025, ST_GeogFromText('SRID=4326;POINT(129.7 62.0)'),
   'Sakha', 'Sakha (Turkic)',
   'Northern Siberian Turkic-speaking people; horse-and-cattle pastoralism in extreme cold; arrived in the Lena basin from the south ~13th c.'),
  ('CARR_HIST_GAP_CHUKCHI', 'Chukchi', 'population',
   -1000, 2025, ST_GeogFromText('SRID=4326;POINT(177.5 65.0)'),
   'Chukchi', 'Chukotko-Kamchatkan',
   'Arctic NE Siberian people of the Chukchi Peninsula; reindeer pastoralism + maritime hunting; resisted Russian conquest into the 18th c.'),
  ('CARR_HIST_GAP_THULE_INUIT', 'Thule / proto-Inuit', 'population',
   900, 1700, ST_GeogFromText('SRID=4326;POINT(-90.0 70.0)'),
   'Thule', 'Eskimo-Aleut',
   'Arctic maritime hunters who spread from Alaska across the Canadian Arctic to Greenland over ~300 years, displacing the earlier Dorset; ancestor of modern Inuit.'),

  -- ---- North America (post-Hopewell, pre-modern gaps) ----
  ('CARR_HIST_GAP_MISSISSIPPIAN', 'Mississippian moundbuilders', 'population',
   800, 1600, ST_GeogFromText('SRID=4326;POINT(-90.0 38.7)'),
   'Mississippian', NULL,
   'Eastern Woodlands chiefdoms with massive earthwork platform mounds (Cahokia); maize agriculture, regional ceremonial complexes; declined ~1450 before European contact.'),
  ('CARR_HIST_GAP_NAVAJO_APACHE', 'Navajo / Apache (Southern Athabaskan)', 'population',
   1400, 2025, ST_GeogFromText('SRID=4326;POINT(-109.0 36.0)'),
   'Athabaskan', 'Southern Athabaskan',
   'Athabaskan-language migration south from the boreal forest into the SW US ~14-15th c.; pastoralism after Spanish-introduced sheep; resisted U.S. expansion into the 19th c.'),
  ('CARR_HIST_GAP_HAUDENOSAUNEE', 'Haudenosaunee (Iroquois Confederacy)', 'population',
   1100, 2025, ST_GeogFromText('SRID=4326;POINT(-76.0 43.0)'),
   'Iroquois', 'Iroquoian',
   'Great-Lakes confederacy of five (later six) nations; longhouse society; Great Law of Peace cited as influence on U.S. federal design.');


-- Provenance claims (best-effort summaries citing DEDUCED_PHASE_0).
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is included as a regional gap-filler so the spatiotemporal map covers ' ||
       'this part of the world / era; ancestry composition not yet curated, ' ||
       'see DEDUCED_PHASE_0 for editorial methodology.',
       3
FROM carrier WHERE id LIKE 'CARR_HIST_GAP_%';

-- claim_source.stance enum is {supports, disputes, nuances}; use 'supports'
-- for the editorial best-effort attribution.
INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id LIKE 'CARR_HIST_GAP_%';
