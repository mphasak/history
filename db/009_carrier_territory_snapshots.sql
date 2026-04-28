-- 009_carrier_territory_snapshots.sql
--
-- Per-year territory polygons. Without these, fill-mode rendering falls back
-- to a radius-buffered circle around the carrier's centroid, which is
-- meaningless for political states (Roman Empire as a 600 km circle is
-- nonsense — at peak it covered 5 Mkm² from Britannia to Mesopotamia).
--
-- Schema is `carrier_extent_snapshot(carrier_id, as_of_year, geometry)`
-- indexed on (carrier_id, as_of_year). The resolver picks the latest
-- snapshot at or before the queried year and serves that as the carrier's
-- extent for that frame; otherwise it falls back to carrier.extent (always
-- NULL in the current seed) and finally to the centroid-radius buffer.
--
-- Polygons here are coarse — dev-grade cartography to make territorial
-- evolution legible at a glance, NOT cartographically authoritative. A
-- production deployment would replace these with Natural Earth /
-- HistoricalAtlas / Geacron polygons.
--
-- Idempotent: DELETE keyed on the seeded carriers, then re-insert.

CREATE TABLE IF NOT EXISTS carrier_extent_snapshot (
  id            BIGSERIAL PRIMARY KEY,
  carrier_id    TEXT NOT NULL REFERENCES carrier(id) ON DELETE CASCADE,
  as_of_year    INTEGER NOT NULL,
  geometry      geography(MultiPolygon, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_carrier_extent_snapshot_carrier_year
  ON carrier_extent_snapshot (carrier_id, as_of_year);
CREATE INDEX IF NOT EXISTS idx_carrier_extent_snapshot_geom
  ON carrier_extent_snapshot USING GIST (geometry);

-- ---------------------------------------------------------------------------
-- Idempotency
-- ---------------------------------------------------------------------------

DELETE FROM carrier_extent_snapshot
WHERE carrier_id IN (
  'CARR_HIST_ROMAN', 'CARR_HIST_BYZANTINE',
  'CARR_HIST_MONGOL', 'CARR_HIST_ACHAEMENID', 'CARR_HIST_SASANIAN',
  'CARR_HIST_HAN_CHINESE_EMPIRE', 'CARR_HIST_TANG_CHINESE',
  'CARR_HIST_MAURYAN', 'CARR_HIST_MUGHAL_N_INDIAN',
  'CARR_HIST_AZTEC', 'CARR_HIST_INCA', 'CARR_HIST_MAYA_CLASSICAL',
  'CARR_HIST_KHMER_ANGKOR', 'CARR_HIST_MISSISSIPPIAN',
  'CARR_HIST_OTTOMAN', 'CARR_HIST_ABBASID',
  'CARR_HIST_BABYLONIAN', 'CARR_HIST_HITTITE',
  'CARR_HIST_EGYPT_OK', 'CARR_HIST_EGYPT_MK_NK',
  'CARR_HIST_GREEK_CLASSICAL', 'CARR_HIST_MYCENAEAN',
  'CARR_HIST_NORSE', 'CARR_HIST_CARTHAGINIAN',
  'CARR_HIST_MALI_EMPIRE', 'CARR_HIST_AKSUMITE',
  'CARR_HIST_RASHIDUN_UMAYYAD', 'CARR_HIST_MOORS_AL_ANDALUS',
  'CARR_HIST_VEDIC_ARYAN',
  'CARR_SF_BAY_AREA_2025', 'CARR_RURAL_SOUTH_US_2025'
);

-- ---------------------------------------------------------------------------
-- Helper: insert a polygon expressed as a 2D coord array (closed ring)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _seed_extent(
  carrier_id TEXT,
  as_of_year INTEGER,
  wkt_multipolygon TEXT
) RETURNS BIGINT AS $$
DECLARE
  new_id BIGINT;
BEGIN
  INSERT INTO carrier_extent_snapshot (carrier_id, as_of_year, geometry)
  VALUES (carrier_id, as_of_year, ST_GeogFromText('SRID=4326;' || wkt_multipolygon))
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Polygons. Coordinates are lon, lat. Each MULTIPOLYGON has one or more
-- closed rings approximating the territory. Coarse on purpose.
-- ---------------------------------------------------------------------------

-- Roman Empire — three snapshots: late Republic Italy (~ -100), Augustan
-- core (~0 CE), and Trajanic peak (117 CE).
SELECT _seed_extent('CARR_HIST_ROMAN', -200,
  'MULTIPOLYGON(((7.5 44.5, 13.5 46.0, 18.0 45.5, 19.0 39.5, 17.0 37.0, 12.5 36.5, 9.0 38.0, 7.5 41.5, 7.5 44.5)))');
SELECT _seed_extent('CARR_HIST_ROMAN', 0,
  'MULTIPOLYGON(((-9 36, 8 51, 17 47, 24 42, 28 37, 36 35, 36 31, 32 30, 25 32, 18 38, 12 36, 1 35, -6 35, -9 36)))');
SELECT _seed_extent('CARR_HIST_ROMAN', 117,
  'MULTIPOLYGON(((-9 36, 0 56, 8 56, 16 51, 22 49, 30 47, 36 41, 42 39, 45 37, 47 34, 41 31, 32 30, 25 31, 18 32, 10 32, 1 35, -7 35, -9 36)))');
SELECT _seed_extent('CARR_HIST_ROMAN', 300,
  'MULTIPOLYGON(((-9 36, 0 54, 8 54, 16 49, 22 47, 30 45, 36 41, 41 39, 41 31, 32 30, 25 31, 18 33, 10 33, 1 35, -7 35, -9 36)))');

-- Byzantine — Justinian peak (~565 CE) before the Arab + Lombard losses,
-- and a late Komnenian state (~1180).
SELECT _seed_extent('CARR_HIST_BYZANTINE', 565,
  'MULTIPOLYGON(((10 38, 14 41, 18 45, 22 47, 26 47, 30 45, 36 41, 42 39, 47 36, 41 31, 32 30, 25 31, 18 33, 13 36, 10 38)))');
SELECT _seed_extent('CARR_HIST_BYZANTINE', 1180,
  'MULTIPOLYGON(((23 36, 27 42, 32 41, 38 42, 41 38, 35 36, 30 36, 26 36, 23 36)))');
SELECT _seed_extent('CARR_HIST_BYZANTINE', 1400,
  'MULTIPOLYGON(((26 40, 29 41.5, 30 41, 28 40, 26 40)))');

-- Mongol Empire — peak under Kublai (~1279).
SELECT _seed_extent('CARR_HIST_MONGOL', 1279,
  'MULTIPOLYGON(((30 50, 50 60, 100 65, 130 55, 130 45, 122 35, 110 30, 100 30, 90 30, 80 35, 70 36, 60 38, 50 40, 40 42, 30 45, 30 50)))');

-- Achaemenid Persian Empire — peak under Darius I (~-500).
SELECT _seed_extent('CARR_HIST_ACHAEMENID', -500,
  'MULTIPOLYGON(((26 41, 35 42, 45 42, 55 40, 65 38, 72 35, 70 28, 60 23, 52 23, 50 28, 45 30, 38 30, 33 28, 30 30, 28 35, 26 38, 26 41)))');

-- Sasanian — peak ~620 CE.
SELECT _seed_extent('CARR_HIST_SASANIAN', 620,
  'MULTIPOLYGON(((36 39, 44 39, 52 38, 60 36, 64 32, 64 27, 56 25, 50 27, 44 28, 38 32, 36 36, 36 39)))');

-- Han Chinese Empire — eastern Han peak (~150 CE).
SELECT _seed_extent('CARR_HIST_HAN_CHINESE_EMPIRE', 150,
  'MULTIPOLYGON(((100 20, 105 24, 110 28, 117 30, 122 35, 122 42, 113 42, 100 41, 90 39, 90 30, 95 25, 100 20)))');

-- Tang Chinese — Tang peak (~750 CE).
SELECT _seed_extent('CARR_HIST_TANG_CHINESE', 750,
  'MULTIPOLYGON(((100 20, 105 24, 110 28, 117 30, 122 35, 124 42, 113 42, 100 41, 90 39, 80 41, 75 38, 80 33, 90 28, 95 23, 100 20)))');

-- Mauryan — Ashoka peak (~-250).
SELECT _seed_extent('CARR_HIST_MAURYAN', -250,
  'MULTIPOLYGON(((68 25, 72 30, 78 33, 86 32, 92 27, 95 22, 90 18, 84 17, 78 15, 73 18, 70 22, 68 25)))');

-- Mughal — Aurangzeb peak (~1690).
SELECT _seed_extent('CARR_HIST_MUGHAL_N_INDIAN', 1690,
  'MULTIPOLYGON(((68 25, 72 32, 78 33, 86 30, 92 26, 90 22, 86 17, 80 15, 76 17, 73 19, 70 22, 68 25)))');

-- Aztec Triple Alliance — peak (~1500).
SELECT _seed_extent('CARR_HIST_AZTEC', 1500,
  'MULTIPOLYGON(((-101 16, -98 18, -96 19, -94 18, -94 17, -97 15, -99 15, -101 16)))');

-- Inca Empire — peak (~1525).
SELECT _seed_extent('CARR_HIST_INCA', 1525,
  'MULTIPOLYGON(((-79 -2, -78 -8, -73 -16, -70 -25, -71 -36, -72 -36, -75 -29, -78 -18, -80 -8, -80 -2, -79 -2)))');

-- Classic Maya — Late Classic core (~750 CE).
SELECT _seed_extent('CARR_HIST_MAYA_CLASSICAL', 750,
  'MULTIPOLYGON(((-92 14, -91 18, -89 21, -87 21, -87 17, -88 15, -91 14, -92 14)))');

-- Khmer / Angkor — peak under Jayavarman VII (~1180).
SELECT _seed_extent('CARR_HIST_KHMER_ANGKOR', 1180,
  'MULTIPOLYGON(((100 9, 102 13, 105 14, 108 13, 108 10, 106 9, 102 9, 100 9)))');

-- Mississippian — Cahokia peak extent (~1100).
SELECT _seed_extent('CARR_HIST_MISSISSIPPIAN', 1100,
  'MULTIPOLYGON(((-95 32, -92 38, -88 40, -85 39, -82 37, -82 32, -85 30, -88 30, -92 30, -95 32)))');

-- Ottoman Empire — Suleiman peak (~1550).
SELECT _seed_extent('CARR_HIST_OTTOMAN', 1550,
  'MULTIPOLYGON(((10 32, 16 38, 22 45, 28 47, 36 45, 42 39, 46 37, 47 31, 36 27, 30 21, 22 25, 16 30, 10 32)))');

-- Abbasid — peak (~800 CE).
SELECT _seed_extent('CARR_HIST_ABBASID', 800,
  'MULTIPOLYGON(((-10 30, 0 32, 12 32, 24 32, 36 33, 48 36, 56 36, 64 33, 70 28, 60 22, 50 20, 40 22, 30 24, 20 28, 8 28, -4 28, -10 30)))');

-- Babylonian — Neo-Babylonian peak (~-580).
SELECT _seed_extent('CARR_HIST_BABYLONIAN', -580,
  'MULTIPOLYGON(((33 30, 38 33, 44 36, 49 36, 52 32, 50 30, 45 29, 40 30, 35 30, 33 30)))');

-- Hittite — New Kingdom peak (~-1300).
SELECT _seed_extent('CARR_HIST_HITTITE', -1300,
  'MULTIPOLYGON(((26 36, 30 41, 36 42, 42 41, 44 38, 42 36, 38 36, 33 36, 28 36, 26 36)))');

-- Old Kingdom Egypt — Nile valley (~-2500).
SELECT _seed_extent('CARR_HIST_EGYPT_OK', -2500,
  'MULTIPOLYGON(((30 24, 31 31, 32 31, 32 24, 33 23, 30 23, 30 24)))');

-- New Kingdom Egypt — Thutmosid peak (~-1450).
SELECT _seed_extent('CARR_HIST_EGYPT_MK_NK', -1450,
  'MULTIPOLYGON(((25 22, 30 31, 32 32, 35 35, 38 33, 36 30, 32 28, 32 22, 28 18, 25 22)))');

-- Classical Greece — Delian-League era (~-450).
SELECT _seed_extent('CARR_HIST_GREEK_CLASSICAL', -450,
  'MULTIPOLYGON(((19 35, 21 39, 23 41, 27 41, 28 38, 26 35, 23 35, 21 35, 19 35)))');

-- Mycenaean palaces (~-1300).
SELECT _seed_extent('CARR_HIST_MYCENAEAN', -1300,
  'MULTIPOLYGON(((20 36, 22 38, 23 39, 25 39, 25 35, 23 35, 21 35, 20 36)))');

-- Norse Viking-Age core homelands (~900).
SELECT _seed_extent('CARR_HIST_NORSE', 900,
  'MULTIPOLYGON(((4 55, 6 59, 9 64, 14 68, 22 70, 28 67, 25 60, 18 58, 12 56, 6 55, 4 55)))');

-- Carthaginian — pre-Punic-War sphere (~-300).
SELECT _seed_extent('CARR_HIST_CARTHAGINIAN', -300,
  'MULTIPOLYGON(((-10 36, -7 37, -2 36, 6 38, 12 37, 11 33, 6 32, 0 32, -7 33, -10 36)))');

-- Mali Empire — Mansa Musa peak (~1325).
SELECT _seed_extent('CARR_HIST_MALI_EMPIRE', 1325,
  'MULTIPOLYGON(((-12 10, -10 15, -5 17, 0 16, 4 14, 4 10, 0 8, -6 8, -12 10)))');

-- Aksum — peak (~525 CE).
SELECT _seed_extent('CARR_HIST_AKSUMITE', 525,
  'MULTIPOLYGON(((37 11, 38 16, 41 17, 43 14, 42 10, 39 9, 37 11)))');

-- Rashidun/Umayyad — peak (~750).
SELECT _seed_extent('CARR_HIST_RASHIDUN_UMAYYAD', 750,
  'MULTIPOLYGON(((-10 30, 0 36, 12 36, 24 36, 30 38, 36 36, 42 35, 50 32, 56 30, 60 26, 56 22, 48 18, 40 18, 32 22, 24 25, 12 28, 0 28, -10 30)))');

-- Al-Andalus — Caliphate of Córdoba peak (~1000).
SELECT _seed_extent('CARR_HIST_MOORS_AL_ANDALUS', 1000,
  'MULTIPOLYGON(((-9 36, -7 41, -2 41, 2 41, 3 38, 0 36, -3 36, -7 36, -9 36)))');

-- Vedic Aryan — early Iron Age Sapta Sindhu (~-1000).
SELECT _seed_extent('CARR_HIST_VEDIC_ARYAN', -1000,
  'MULTIPOLYGON(((68 27, 72 33, 78 32, 82 28, 80 24, 76 23, 72 25, 68 27)))');

-- Modern US carrier polygons --------------------------------------------------

-- SF Bay Area (counties): coarse box covering the 9-county region.
SELECT _seed_extent('CARR_SF_BAY_AREA_2025', 2025,
  'MULTIPOLYGON(((-122.85 37.05, -122.85 38.20, -121.30 38.20, -121.30 37.05, -122.85 37.05)))');

-- Rural US South: a multi-state band (Tennessee/Kentucky/Alabama/Mississippi/
-- Louisiana/Arkansas/Georgia core, excluding metro areas).
SELECT _seed_extent('CARR_RURAL_SOUTH_US_2025', 2025,
  'MULTIPOLYGON(((-94.5 30.0, -94.5 36.5, -82.5 36.5, -82.5 30.0, -94.5 30.0)))');

DROP FUNCTION _seed_extent(TEXT, INTEGER, TEXT);
