-- 028_seed_audit_gap_fillers.sql
--
-- Targeted carriers to close the highest-impact gaps surfaced by
-- harness/audit_gaps.py. Each entry fills a specific (region, year)
-- emptiness flanked by populated periods on both sides — i.e. a place
-- the user could scroll to and see *nothing on the map* even though
-- humans were there continuously.
--
-- East Asia (the headline complaint — "no Chinese at 472 BCE")
--   * Zhou + Spring/Autumn + Warring States  (CARR_HIST_BRIDGE_ZHOU)
--   * Three Kingdoms + Jin + N+S Dynasties   (CARR_HIST_BRIDGE_THREEKINGS_JIN)
--   * Five Dynasties + Song + Liao + Jurchen Jin (CARR_HIST_BRIDGE_SONG_LIAO)
--   * Mumun + Three-Kingdoms + Unified Silla Korea (CARR_HIST_BRIDGE_KOREA_PRE_GORYEO)
--   * Yangtze pre-Han Bronze states          (CARR_HIST_BRIDGE_YANGTZE_PRE_HAN)
--
-- SE Asia (Java H. erectus → Majapahit hole, ~16k yrs scrub-relevant)
--   * Đông Sơn (Vietnam Bronze Age)          (CARR_HIST_DONG_SON)
--   * Funan + Chenla + Pre-Angkor Khmer      (CARR_HIST_FUNAN_PREANGKOR)
--   * Champa                                  (CARR_HIST_CHAMPA)
--
-- Inner Asia / Steppe (Denisovan → Tang and Mal'ta-Buret' → Mongol holes)
--   * Xiongnu confederation                  (CARR_HIST_XIONGNU)
--   * Saka (Iranian-speaking nomads)         (CARR_HIST_SAKA)
--   * Kushan Empire                          (CARR_HIST_KUSHAN)
--
-- Africa (15kya Sahara emptiness, Sahel pre-Mali)
--   * Numidian / Mauretanian                 (CARR_HIST_NUMIDIAN)
--   * Kanem-Bornu                             (CARR_HIST_KANEM_BORNU)
--
-- N America (Archaic NA → Mississippian gap in mid-South cell)
--   * Plains/Mississippi pre-Mississippian   (CARR_HIST_PROTO_MISSISSIPPIAN)
--
-- Idempotent on the explicit id list (DELETE+INSERT). All carriers
-- cited via DEDUCED_PHASE_0; trait_mix attached as [AUTO-PROVENANCE]
-- claims following the existing convention. Threats added inline for
-- the long-lived ones, tagged [AUTO-THREAT-028].

-- ─────────────────────────────────────────────────────────────────────
-- Cleanup (idempotent)
-- ─────────────────────────────────────────────────────────────────────
DELETE FROM carrier_threat WHERE claim_id IN (
  SELECT id FROM claim WHERE statement LIKE '[AUTO-THREAT-028]%'
);
DELETE FROM claim_source WHERE claim_id IN (
  SELECT id FROM claim
  WHERE (statement LIKE '[AUTO-PROVENANCE]%' OR statement LIKE '[AUTO-THREAT-028]%')
    AND subject_id IN (
      'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
      'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
      'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
      'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
      'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
      'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
    )
);
DELETE FROM claim
WHERE (statement LIKE '[AUTO-PROVENANCE]%' OR statement LIKE '[AUTO-THREAT-028]%')
  AND subject_id IN (
    'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
    'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
    'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
    'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
    'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
    'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
  );
DELETE FROM carrier_trait_mix WHERE carrier_id IN (
  'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
  'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
  'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
  'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
  'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
  'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
);
DELETE FROM carrier WHERE id IN (
  'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
  'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
  'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
  'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
  'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
  'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
);

-- ─────────────────────────────────────────────────────────────────────
-- Carriers
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO carrier (id, display_name, type, date_min_year, date_max_year, centroid,
                     archaeological_culture, linguistic_affiliation, description) VALUES

  -- East Asia
  ('CARR_HIST_BRIDGE_ZHOU', 'Zhou Chinese (Western + Eastern Zhou, Spring & Autumn, Warring States)', 'population',
   -1046, -221, ST_GeogFromText('SRID=4326;POINT(112.5 34.7)'),
   'Zhou Dynasty', 'Old Chinese',
   '825 years of Chinese demographic continuity from the Mandate-of-Heaven conquest of Shang to Qin unification. Spans Western Zhou (1046-771 BCE), Eastern Zhou (770-256), Spring & Autumn period (770-476), and Warring States period (475-221). The era of Confucius, Laozi, Mencius, and Sunzi; iron metallurgy spreads; the canonical "Hundred Schools of Thought" emerges. Without this carrier the map shows nothing in the Yellow River basin between Shang and Han.'),

  ('CARR_HIST_BRIDGE_THREEKINGS_JIN', 'Three Kingdoms + Jin + N/S Dynasties', 'population',
   220, 589, ST_GeogFromText('SRID=4326;POINT(113.5 34.5)'),
   'Wei/Shu/Wu/Jin/Northern-Southern', 'Middle Chinese',
   'Demographic continuity through the post-Han fragmentation: Wei/Shu/Wu Three Kingdoms (220-280), brief Jin reunification (266-420), then the Northern/Southern Dynasties parallel realms (420-589). Buddhism takes deep root; the "Five Barbarians" period sees Xianbei / Xiongnu polities establish northern dynasties; Tao Yuanming, Wang Xizhi, and the Sui reunification close the era.'),

  ('CARR_HIST_BRIDGE_SONG_LIAO', 'Song + Liao + Jurchen Jin', 'population',
   907, 1279, ST_GeogFromText('SRID=4326;POINT(118.0 32.0)'),
   'Five Dynasties + Song + Liao + Jurchen Jin', 'Middle/Early-Mandarin Chinese',
   'Post-Tang continuity: Five Dynasties + Ten Kingdoms (907-979), Northern Song (960-1127), Southern Song (1127-1279) co-existing with Khitan Liao (916-1125) and Jurchen Jin (1115-1234) in the north. Neo-Confucianism, woodblock printing, gunpowder, paper money, the largest cities in the world (Kaifeng then Hangzhou), Song landscape painting. Ends with the Mongol conquest.'),

  ('CARR_HIST_BRIDGE_KOREA_PRE_GORYEO', 'Mumun + Three-Kingdoms + Unified Silla Korea', 'population',
   -1500, 935, ST_GeogFromText('SRID=4326;POINT(127.5 37.0)'),
   'Mumun + Goguryeo/Baekje/Silla/Gaya + Unified Silla', 'Old Korean / Para-Japonic',
   'Korean peninsula continuity from the Mumun pottery agriculturalists (1500-300 BCE), through the proto-historical Three Kingdoms period (Goguryeo, Baekje, Silla, Gaya — ~57 BCE-668 CE), to Unified Silla (668-935). Buddhism arrives 4th c., Chinese script adapted, the Tripitaka Koreana under Goryeo successors. Bridges the Chulmun→Goryeo gap.'),

  ('CARR_HIST_BRIDGE_YANGTZE_PRE_HAN', 'Yangtze Bronze cultures (Chu, Wu, Yue, Sanxingdui)', 'population',
   -1300, -221, ST_GeogFromText('SRID=4326;POINT(112.5 30.0)'),
   'Sanxingdui + Chu + Wu + Yue', 'Old Chinese / Yue substrate',
   'Distinctive Bronze Age and pre-Han polities of the Yangtze and Sichuan basins: Sanxingdui (c. 1200 BCE), Chu (c. 1030-223 BCE) — the largest of the Warring States by territory — plus Wu and Yue along the lower Yangtze. Distinct material culture from the Zhou heartland; Chu shamanism, lacquerware, and the Chu Ci poetic tradition. Ends with Qin absorption.'),

  -- SE Asia
  ('CARR_HIST_DONG_SON', 'Đông Sơn (Vietnam Bronze Age)', 'population',
   -1000, -100, ST_GeogFromText('SRID=4326;POINT(106.0 21.0)'),
   'Đông Sơn', 'Proto-Vietic / proto-Austroasiatic',
   'Bronze and early-Iron-Age culture of the Red River delta and northern Vietnam: bronze drums (the "Đông Sơn drums" are diagnostic across SE Asia), wet-rice agriculture, stilt houses, and the Văn Lang / Âu Lạc proto-states. Direct cultural ancestor of the Vietnamese people; Han conquest of Nanyue (111 BCE) ends the era.'),

  ('CARR_HIST_FUNAN_PREANGKOR', 'Funan + Chenla + Pre-Angkor Khmer', 'population',
   100, 802, ST_GeogFromText('SRID=4326;POINT(105.0 12.0)'),
   'Funan + Chenla', 'Old Khmer / Pyu-Mon Sanskrit borrowings',
   'Indianized polities of the lower Mekong: Funan (1st-6th c.), an entrepôt thalassocracy with Indian-style kingship, Sanskrit inscriptions, and Roman-era trade goods (Oc-Eo); succeeded by Chenla (~550-802) leading directly into the founding of Angkor under Jayavarman II. The whole pre-Angkor lineage of Khmer civilization.'),

  ('CARR_HIST_CHAMPA', 'Champa', 'population',
   192, 1832, ST_GeogFromText('SRID=4326;POINT(108.5 14.5)'),
   'Champa', 'Cham (Austronesian)',
   'Austronesian-speaking maritime kingdom along the central Vietnamese coast for ~1640 years. Hindu Shaivite then Sunni Muslim from the 17th c.; My Son temple complex; long rivalry with Đại Việt to the north and Khmer to the south; absorbed piecemeal by Vietnamese southward expansion (Nam Tiến), final extinction 1832.'),

  -- Inner Asia / Steppe
  ('CARR_HIST_XIONGNU', 'Xiongnu confederation', 'population',
   -209, 200, ST_GeogFromText('SRID=4326;POINT(105.0 47.0)'),
   'Xiongnu', 'unclear (proto-Turkic? proto-Mongolic? Yeniseian?)',
   'Steppe nomadic confederation that emerged on the Mongolian plateau under Modu Chanyu (~209 BCE) and dominated the eastern steppe for four centuries — the existential threat that prompted Han China to build / extend the Great Wall and launch the Hexi Corridor campaigns. Mixed economy of mobile pastoralism with limited agriculture; royal kurgans at Noin-Ula. Often equated (controversially) with the later Huns of Europe.'),

  ('CARR_HIST_SAKA', 'Saka (Eastern Iranian-speaking nomads)', 'population',
   -700, 200, ST_GeogFromText('SRID=4326;POINT(75.0 42.0)'),
   'Saka kurgan complex', 'Saka (Eastern Iranian)',
   'Eastern-Iranian-speaking nomads of Central Asia and the Tarim Basin — the steppe peoples Persians called "Saka" and Greeks called "Asian Scythians". Spectacular kurgan burials (Issyk gold-armored prince, Berel), horsemanship, gold animal-style art. Some Saka groups (Indo-Scythians) invaded the Indian subcontinent in the 1st c. BCE; Tarim Basin Sakas left behind the Khotanese language.'),

  ('CARR_HIST_KUSHAN', 'Kushan Empire', 'population',
   30, 375, ST_GeogFromText('SRID=4326;POINT(70.0 36.5)'),
   'Kushan', 'Bactrian (Eastern Iranian, Greek script)',
   'Yuezhi-descended dynasty ruling Bactria, Gandhara, and parts of north India at its 2nd-c. height. Patrons of Mahayana Buddhism (Kanishka''s council); Greco-Buddhist Gandharan art; gold dinars; trade hub linking Han China, the Roman Mediterranean, and Indian Ocean ports. Divided and absorbed by the Sasanians and Gupta from the late 3rd c.'),

  -- Africa
  ('CARR_HIST_NUMIDIAN', 'Numidian / Mauretanian', 'population',
   -300, 50, ST_GeogFromText('SRID=4326;POINT(5.0 35.5)'),
   'Numidian / Mauretanian', 'Numidian (Berber) + Punic',
   'Berber kingdoms of the Maghreb (Massyli + Masaesyli + Mauretania) that emerged after Carthaginian decline. Masinissa unified Numidia and was Rome''s ally against Hannibal; Jugurtha later fought Rome to a stalemate. Punic + Berber bilingualism; mausolea at Madghacen and Tipasa; absorbed into Roman Africa Proconsularis and Mauretania Caesariensis after 46 BCE / 40 CE.'),

  ('CARR_HIST_KANEM_BORNU', 'Kanem-Bornu', 'population',
   700, 1900, ST_GeogFromText('SRID=4326;POINT(15.0 13.5)'),
   'Kanem + Bornu', 'Kanuri (Saharan)',
   'Twelve-century Sahel-Saharan empire centered on Lake Chad: Kanem (c. 700-1380) on the eastern shore, Bornu (1380-1893) on the western. Trans-Saharan trade in salt, copper, and slaves; Islamized in the 11th c. under Mai Hummay; Sayfawa dynasty ruled ~ 800 years — among the longest in African history. Ended by Rabih''s wars and French colonial conquest.'),

  -- N America
  ('CARR_HIST_PROTO_MISSISSIPPIAN', 'Plains/Mississippi-Valley Late Woodland (proto-Mississippian)', 'population',
   -500, 800, ST_GeogFromText('SRID=4326;POINT(-90.0 38.0)'),
   'Plains Woodland / Coles Creek / Late Woodland', 'proto-Algonquian / Caddoan',
   'Pre-Mississippian Late Woodland populations of the central / lower Mississippi Valley and eastern Plains: Coles Creek and Plum Bayou cultures, Plains Woodland, the Effigy-Mound builders. Maize-bean-squash agriculture intensifies; bow-and-arrow replaces atlatl; small-scale platform-mound construction begins. Direct ancestors of the Mississippian / Cahokia florescence.');

-- ─────────────────────────────────────────────────────────────────────
-- Provenance claims
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
SELECT 'Carrier', id,
       '[AUTO-PROVENANCE] ' || display_name ||
       ' is a gap-filler carrier added to close a (region, year) emptiness ' ||
       'flagged by harness/audit_gaps.py — see DEDUCED_PHASE_0 + the carrier ' ||
       'description for editorial citations.',
       3
FROM carrier WHERE id IN (
  'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
  'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
  'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
  'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
  'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
  'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
);

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c
WHERE c.statement LIKE '[AUTO-PROVENANCE]%'
  AND c.subject_id IN (
    'CARR_HIST_BRIDGE_ZHOU','CARR_HIST_BRIDGE_THREEKINGS_JIN',
    'CARR_HIST_BRIDGE_SONG_LIAO','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',
    'CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','CARR_HIST_DONG_SON',
    'CARR_HIST_FUNAN_PREANGKOR','CARR_HIST_CHAMPA','CARR_HIST_XIONGNU',
    'CARR_HIST_SAKA','CARR_HIST_KUSHAN','CARR_HIST_NUMIDIAN',
    'CARR_HIST_KANEM_BORNU','CARR_HIST_PROTO_MISSISSIPPIAN'
  );

-- ─────────────────────────────────────────────────────────────────────
-- trait_mix (genetic profiles) — copying the regional consensus.
-- East-Asian dynasties are essentially demographic continuations of the
-- Han Chinese profile; SE-Asian polities mix EAST_ASIAN with AUS_PNG;
-- steppe carriers blend EAST_ASIAN + ANE + STEPPE_MLBA + IRN_N.
-- ─────────────────────────────────────────────────────────────────────
WITH mix(carrier_id, trait_id, fraction, as_of_year) AS (VALUES
  -- East Asian dynasties — copy Shang/Han profile (single dominant trait)
  ('CARR_HIST_BRIDGE_ZHOU',                'EAST_ASIAN', 1.000, -600),
  ('CARR_HIST_BRIDGE_THREEKINGS_JIN',      'EAST_ASIAN', 1.000, 400),
  ('CARR_HIST_BRIDGE_SONG_LIAO',           'EAST_ASIAN', 1.000, 1100),
  ('CARR_HIST_BRIDGE_KOREA_PRE_GORYEO',    'EAST_ASIAN', 1.000, -300),
  ('CARR_HIST_BRIDGE_YANGTZE_PRE_HAN',     'EAST_ASIAN', 1.000, -700),

  -- SE Asia — EAST_ASIAN-leaning admixed with deeper Australasian substrate
  ('CARR_HIST_DONG_SON',                   'EAST_ASIAN', 0.700, -500),
  ('CARR_HIST_DONG_SON',                   'AUS_PNG',    0.300, -500),
  ('CARR_HIST_FUNAN_PREANGKOR',            'EAST_ASIAN', 0.500, 400),
  ('CARR_HIST_FUNAN_PREANGKOR',            'AUS_PNG',    0.500, 400),
  ('CARR_HIST_CHAMPA',                     'EAST_ASIAN', 0.400, 800),
  ('CARR_HIST_CHAMPA',                     'AUS_PNG',    0.600, 800),

  -- Steppe / Inner Asia — see Damgaard 2018 / Jeong 2020 for typical
  -- composition: large East Asian + ANE component, smaller Steppe + IRN_N
  ('CARR_HIST_XIONGNU',                    'EAST_ASIAN', 0.500, -100),
  ('CARR_HIST_XIONGNU',                    'ANE',        0.300, -100),
  ('CARR_HIST_XIONGNU',                    'STEPPE_MLBA',0.200, -100),
  ('CARR_HIST_SAKA',                       'STEPPE_MLBA',0.400, -300),
  ('CARR_HIST_SAKA',                       'IRN_N',      0.300, -300),
  ('CARR_HIST_SAKA',                       'ANE',        0.200, -300),
  ('CARR_HIST_SAKA',                       'EAST_ASIAN', 0.100, -300),
  ('CARR_HIST_KUSHAN',                     'IRN_N',      0.300, 200),
  ('CARR_HIST_KUSHAN',                     'STEPPE_MLBA',0.250, 200),
  ('CARR_HIST_KUSHAN',                     'ANI',        0.200, 200),
  ('CARR_HIST_KUSHAN',                     'ASI',        0.150, 200),
  ('CARR_HIST_KUSHAN',                     'EAST_ASIAN', 0.100, 200),

  -- N Africa / Sahel
  ('CARR_HIST_NUMIDIAN',                   'NATUFIAN',         0.350, -150),
  ('CARR_HIST_NUMIDIAN',                   'ANATOLIAN_FARMER', 0.300, -150),
  ('CARR_HIST_NUMIDIAN',                   'AFR_BASAL',        0.200, -150),
  ('CARR_HIST_NUMIDIAN',                   'IRN_N',            0.150, -150),
  ('CARR_HIST_KANEM_BORNU',                'AFR_WEST',         0.600, 1300),
  ('CARR_HIST_KANEM_BORNU',                'AFR_BASAL',        0.250, 1300),
  ('CARR_HIST_KANEM_BORNU',                'NATUFIAN',         0.150, 1300),

  -- Eastern N America — Native American profile, like Adena/Hopewell
  ('CARR_HIST_PROTO_MISSISSIPPIAN',        'AMER_NA',    1.000, 100)
)
INSERT INTO carrier_trait_mix (carrier_id, trait_id, fraction, as_of_year, domain, claim_id)
SELECT m.carrier_id, m.trait_id, m.fraction, m.as_of_year, t.domain, c.id
FROM mix m
JOIN trait t ON t.id = m.trait_id
JOIN claim c ON c.subject_type = 'Carrier'
            AND c.subject_id = m.carrier_id
            AND c.statement LIKE '[AUTO-PROVENANCE]%';

-- ─────────────────────────────────────────────────────────────────────
-- Threats — major recurring stressors per carrier, tagged
-- [AUTO-THREAT-028]. Idempotent via the carrier_threat.claim_id link.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO claim (subject_type, subject_id, statement, default_aggregated_confidence)
VALUES
  ('Carrier','CARR_HIST_BRIDGE_ZHOU','[AUTO-THREAT-028] Warring States era saw centuries of inter-state war culminating in Qin conquest (-475 to -221).',3),
  ('Carrier','CARR_HIST_BRIDGE_ZHOU','[AUTO-THREAT-028] Repeated Quanrong / Xianyun raids on Western Zhou heartland, contributing to fall of Western Zhou in -771.',3),
  ('Carrier','CARR_HIST_BRIDGE_THREEKINGS_JIN','[AUTO-THREAT-028] Wars of the Three Kingdoms + Five Barbarians upheaval drove population in N China from ~50M to ~16M between 200 and 400.',3),
  ('Carrier','CARR_HIST_BRIDGE_THREEKINGS_JIN','[AUTO-THREAT-028] Multiple plague waves through 3rd-6th c. China, including a major epidemic in 217 that killed five of the Seven Sages.',3),
  ('Carrier','CARR_HIST_BRIDGE_SONG_LIAO','[AUTO-THREAT-028] Jurchen Jin conquest of Northern Song (1127, "Jingkang Incident") forced the dynasty south.',3),
  ('Carrier','CARR_HIST_BRIDGE_SONG_LIAO','[AUTO-THREAT-028] Mongol conquests 1234 (Jin) and 1279 (Southern Song) ended Han political continuity for ~90 years.',3),
  ('Carrier','CARR_HIST_BRIDGE_KOREA_PRE_GORYEO','[AUTO-THREAT-028] Sui-Goguryeo wars (598-614) and Tang-Goguryeo war (645-668) ended Goguryeo as a separate polity.',3),
  ('Carrier','CARR_HIST_BRIDGE_YANGTZE_PRE_HAN','[AUTO-THREAT-028] Qin annexation of Chu (-223) and Wu/Yue absorption (-334, -222) ended distinct Yangtze polities.',3),
  ('Carrier','CARR_HIST_DONG_SON','[AUTO-THREAT-028] Han conquest of Nanyue (-111) brought 1,000 years of Chinese rule over the Red River delta.',3),
  ('Carrier','CARR_HIST_FUNAN_PREANGKOR','[AUTO-THREAT-028] Sea-level changes in the Mekong delta and Chenla''s rise broke up Funan from the 6th c.',3),
  ('Carrier','CARR_HIST_CHAMPA','[AUTO-THREAT-028] Vietnamese Nam Tiến (southward expansion) absorbed Champa piecemeal 982-1832; final fall under Minh Mạng.',3),
  ('Carrier','CARR_HIST_CHAMPA','[AUTO-THREAT-028] 1471 Lê-Champa war saw the sack of Vijaya and death of an estimated 60,000 Cham.',3),
  ('Carrier','CARR_HIST_XIONGNU','[AUTO-THREAT-028] Han-Xiongnu wars (-133 to -89 and 73 to 91 CE) and Han diplomatic divide-and-rule split the confederation into Northern + Southern Xiongnu.',3),
  ('Carrier','CARR_HIST_SAKA','[AUTO-THREAT-028] Yuezhi displacement of the Saka from the Ili Valley (~ -160) drove Saka migrations into Bactria and India.',3),
  ('Carrier','CARR_HIST_KUSHAN','[AUTO-THREAT-028] Sasanian campaigns (Shapur I, Shapur II) reduced the Kushan to a Sasanian client (Kushano-Sasanians) in the 3rd c.',3),
  ('Carrier','CARR_HIST_NUMIDIAN','[AUTO-THREAT-028] Jugurthine War (-112 to -106) and successive Roman annexations ended Numidian autonomy.',3),
  ('Carrier','CARR_HIST_KANEM_BORNU','[AUTO-THREAT-028] Bulala raids displaced Kanem from its eastern heartland to Bornu in the 14th c.',3),
  ('Carrier','CARR_HIST_KANEM_BORNU','[AUTO-THREAT-028] Rabih az-Zubayr''s wars (1893-1900) and French colonial conquest ended Bornu independence.',3),
  ('Carrier','CARR_HIST_PROTO_MISSISSIPPIAN','[AUTO-THREAT-028] Late-Holocene drought episodes documented in Mid-South tree-ring + lake-sediment records around 800 stressed maize agriculture.',3);

INSERT INTO claim_source (claim_id, source_id, stance, weight_override)
SELECT c.id, 'DEDUCED_PHASE_0', 'supports', NULL
FROM claim c WHERE c.statement LIKE '[AUTO-THREAT-028]%';

-- carrier_threat rows linked to the claims above
INSERT INTO carrier_threat (carrier_id, threat_type, display_name, description,
                            severity, date_min_year, date_max_year, claim_id)
SELECT
  c.subject_id,
  CASE
    WHEN c.statement ILIKE '%Warring States%' THEN 'war'
    WHEN c.statement ILIKE '%Quanrong%' OR c.statement ILIKE '%Xianyun%' THEN 'raids'
    WHEN c.statement ILIKE '%Wars of the Three Kingdoms%' THEN 'war'
    WHEN c.statement ILIKE '%plague%' OR c.statement ILIKE '%epidemic%' THEN 'disease'
    WHEN c.statement ILIKE '%Jingkang Incident%' OR c.statement ILIKE '%Mongol conquests%' THEN 'war'
    WHEN c.statement ILIKE '%Sui-Goguryeo%' OR c.statement ILIKE '%Tang-Goguryeo%' THEN 'war'
    WHEN c.statement ILIKE '%Qin annexation%' THEN 'colonization'
    WHEN c.statement ILIKE '%Han conquest of Nanyue%' THEN 'colonization'
    WHEN c.statement ILIKE '%Sea-level%' OR c.statement ILIKE '%Late-Holocene drought%' THEN 'climate'
    WHEN c.statement ILIKE '%Nam Tiến%' OR c.statement ILIKE '%Lê-Champa%' THEN 'displacement'
    WHEN c.statement ILIKE '%Han-Xiongnu%' THEN 'war'
    WHEN c.statement ILIKE '%Yuezhi%' THEN 'displacement'
    WHEN c.statement ILIKE '%Sasanian%' THEN 'war'
    WHEN c.statement ILIKE '%Jugurthine%' OR c.statement ILIKE '%Roman annexations%' THEN 'colonization'
    WHEN c.statement ILIKE '%Bulala raids%' THEN 'raids'
    WHEN c.statement ILIKE '%Rabih%' OR c.statement ILIKE '%French colonial%' THEN 'colonization'
    ELSE 'other'
  END::threat_type,
  -- display_name: short label derived from the statement's lead clause
  CASE
    WHEN c.statement ILIKE '%Warring States%' THEN 'Warring States wars'
    WHEN c.statement ILIKE '%Quanrong%' THEN 'Quanrong / Xianyun raids'
    WHEN c.statement ILIKE '%Wars of the Three Kingdoms%' THEN 'Three-Kingdoms civil war + Five Barbarians collapse'
    WHEN c.statement ILIKE '%plague%' OR c.statement ILIKE '%epidemic%' THEN 'Recurring plague waves'
    WHEN c.statement ILIKE '%Jingkang Incident%' THEN 'Jurchen Jin conquest of Northern Song (Jingkang Incident)'
    WHEN c.statement ILIKE '%Mongol conquests%' THEN 'Mongol conquest of the Jin and Southern Song'
    WHEN c.statement ILIKE '%Sui-Goguryeo%' THEN 'Sui & Tang wars on Goguryeo'
    WHEN c.statement ILIKE '%Qin annexation%' THEN 'Qin conquest of Chu / Wu / Yue'
    WHEN c.statement ILIKE '%Han conquest of Nanyue%' THEN 'Han conquest of Nanyue'
    WHEN c.statement ILIKE '%Sea-level%' THEN 'Mekong delta sea-level changes'
    WHEN c.statement ILIKE '%Late-Holocene drought%' THEN 'Late-Holocene drought'
    WHEN c.statement ILIKE '%Nam Tiến%' THEN 'Vietnamese Nam Tiến (southward absorption)'
    WHEN c.statement ILIKE '%Lê-Champa%' THEN '1471 Lê-Champa war and sack of Vijaya'
    WHEN c.statement ILIKE '%Han-Xiongnu%' THEN 'Han-Xiongnu wars'
    WHEN c.statement ILIKE '%Yuezhi%' THEN 'Yuezhi displacement of the Saka'
    WHEN c.statement ILIKE '%Sasanian%' THEN 'Sasanian campaigns reduce Kushan to client status'
    WHEN c.statement ILIKE '%Jugurthine%' THEN 'Jugurthine War + Roman annexation'
    WHEN c.statement ILIKE '%Bulala raids%' THEN 'Bulala raids force Kanem westward'
    WHEN c.statement ILIKE '%Rabih%' THEN 'Rabih''s wars + French colonial conquest'
    ELSE 'Recorded threat'
  END,
  c.statement,
  CASE
    WHEN c.statement ILIKE '%Five Barbarians%' OR c.statement ILIKE '%Mongol conquests%'
      OR c.statement ILIKE '%Jingkang%' OR c.statement ILIKE '%Vijaya%' THEN 5
    WHEN c.statement ILIKE '%plague%' OR c.statement ILIKE '%Warring States%'
      OR c.statement ILIKE '%Han conquest of Nanyue%' OR c.statement ILIKE '%French colonial%'
      OR c.statement ILIKE '%Han-Xiongnu%' THEN 4
    ELSE 3
  END,
  -- Heuristic year window: pull the first parenthesized signed integer
  -- as start, "to <signed integer>" as end. Falls back to the carrier's
  -- date range if not parseable.
  COALESCE(
    NULLIF((regexp_match(c.statement, '\(([+-]?\d+)'))[1], '')::int,
    car.date_min_year
  ),
  COALESCE(
    NULLIF((regexp_match(c.statement, 'to ([+-]?\d+)'))[1], '')::int,
    car.date_max_year
  ),
  c.id
FROM claim c
JOIN carrier car ON car.id = c.subject_id
WHERE c.statement LIKE '[AUTO-THREAT-028]%';
