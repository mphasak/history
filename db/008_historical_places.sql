-- 008_historical_places.sql
--
-- Era-appropriate place labels: when the user picks "Historical" label mode,
-- the map suppresses the modern OSM labels and shows the names a place was
-- known by during the queried year. Constantinople from 330 to 1453, then
-- nothing (the modern Istanbul label is in OSM and only appears in "Modern"
-- mode). Tenochtitlan up to 1521, then Mexico City (which we leave to OSM).
--
-- Modeled as a small sibling table; one row per (place, name-era) pair so a
-- single point can have multiple successive names with different windows.
-- Idempotent: DELETE keyed on the HP_* id prefix.

CREATE TABLE IF NOT EXISTS historical_place (
  id              TEXT PRIMARY KEY,
  display_name    TEXT NOT NULL,
  centroid        geography(Point, 4326) NOT NULL,
  date_min_year   INTEGER NOT NULL,
  date_max_year   INTEGER NOT NULL,
  -- e.g. 'city', 'region', 'sea', 'kingdom'. Free-form for now.
  kind            TEXT,
  description     TEXT,
  CHECK (date_min_year <= date_max_year)
);

CREATE INDEX IF NOT EXISTS idx_historical_place_dates
  ON historical_place (date_min_year, date_max_year);
CREATE INDEX IF NOT EXISTS idx_historical_place_centroid
  ON historical_place USING GIST (centroid);

-- ---------------------------------------------------------------------------
-- Idempotent seed
-- ---------------------------------------------------------------------------

DELETE FROM historical_place WHERE id LIKE 'HP_%';

INSERT INTO historical_place (id, display_name, centroid, date_min_year, date_max_year, kind, description) VALUES
  -- Mesopotamia / Levant
  ('HP_UR',           'Ur',            ST_GeogFromText('SRID=4326;POINT(46.10 30.96)'), -3800, -500, 'city', 'Sumerian / Babylonian city.'),
  ('HP_URUK',         'Uruk',          ST_GeogFromText('SRID=4326;POINT(45.64 31.32)'), -4000, -500, 'city', 'Sumerian city; eponym for the Uruk period.'),
  ('HP_BABYLON',      'Babylon',       ST_GeogFromText('SRID=4326;POINT(44.42 32.54)'), -1900, 100,  'city', NULL),
  ('HP_NINEVEH',      'Nineveh',       ST_GeogFromText('SRID=4326;POINT(43.15 36.36)'), -1800, -612, 'city', 'Assyrian capital.'),
  ('HP_AKKAD',        'Akkad',         ST_GeogFromText('SRID=4326;POINT(44.40 33.10)'), -2350, -2150,'city', 'Capital of the Akkadian Empire.'),
  ('HP_TYRE',         'Tyre',          ST_GeogFromText('SRID=4326;POINT(35.20 33.27)'), -2500, 600,  'city', 'Phoenician maritime city.'),
  ('HP_JERUSALEM_OLD','Jerusalem',     ST_GeogFromText('SRID=4326;POINT(35.23 31.78)'), -1000, 2025, 'city', NULL),
  ('HP_DAMASCUS',     'Damascus',      ST_GeogFromText('SRID=4326;POINT(36.30 33.51)'), -2000, 2025, 'city', NULL),
  ('HP_PETRA',        'Petra',         ST_GeogFromText('SRID=4326;POINT(35.44 30.33)'), -312,  363,  'city', 'Nabataean capital.'),
  ('HP_PERSEPOLIS',   'Persepolis',    ST_GeogFromText('SRID=4326;POINT(52.89 29.94)'), -518,  -330, 'city', 'Achaemenid ceremonial capital.'),
  ('HP_CTESIPHON',    'Ctesiphon',     ST_GeogFromText('SRID=4326;POINT(44.58 33.09)'), -200,  651,  'city', 'Parthian / Sasanian capital.'),

  -- Egypt / N Africa
  ('HP_MEMPHIS',      'Memphis',       ST_GeogFromText('SRID=4326;POINT(31.25 29.85)'), -3100, 600,  'city', 'Old Kingdom Egyptian capital.'),
  ('HP_THEBES_EG',    'Thebes (Egypt)',ST_GeogFromText('SRID=4326;POINT(32.64 25.72)'), -2050, -1070,'city', 'New Kingdom capital.'),
  ('HP_ALEXANDRIA',   'Alexandria',    ST_GeogFromText('SRID=4326;POINT(29.92 31.20)'), -331,  2025, 'city', NULL),
  ('HP_CARTHAGE',     'Carthage',      ST_GeogFromText('SRID=4326;POINT(10.32 36.86)'), -814,  698,  'city', NULL),
  ('HP_AKSUM',        'Aksum',         ST_GeogFromText('SRID=4326;POINT(38.72 14.13)'), -100,  940,  'city', NULL),
  ('HP_MEROE',        'Meroë',         ST_GeogFromText('SRID=4326;POINT(33.72 16.93)'), -800,  350,  'city', 'Kushite capital.'),

  -- Mediterranean / Europe
  ('HP_TROY',         'Troy',          ST_GeogFromText('SRID=4326;POINT(26.24 39.96)'), -3000, -350, 'city', NULL),
  ('HP_KNOSSOS',      'Knossos',       ST_GeogFromText('SRID=4326;POINT(25.16 35.30)'), -2000, -1100,'city', 'Minoan palace.'),
  ('HP_MYCENAE',      'Mycenae',       ST_GeogFromText('SRID=4326;POINT(22.76 37.73)'), -1600, -1100,'city', NULL),
  ('HP_ATHENS_OLD',   'Athens',        ST_GeogFromText('SRID=4326;POINT(23.73 37.98)'), -1000, 2025, 'city', NULL),
  ('HP_SPARTA',       'Sparta',        ST_GeogFromText('SRID=4326;POINT(22.43 37.07)'), -900,  -300, 'city', NULL),
  ('HP_ROME_OLD',     'Roma',          ST_GeogFromText('SRID=4326;POINT(12.48 41.89)'), -753,  410,  'city', 'Roman Republic / Empire capital.'),
  ('HP_CONSTANTINOPLE','Constantinople',ST_GeogFromText('SRID=4326;POINT(28.98 41.01)'),330, 1453, 'city', 'Capital of the Eastern Roman / Byzantine Empire. Renamed Istanbul after 1453.'),
  ('HP_BYZANTIUM',    'Byzantium',     ST_GeogFromText('SRID=4326;POINT(28.98 41.01)'), -657,  329,  'city', 'Greek colony preceding Constantinople on the same site.'),
  ('HP_LUTETIA',      'Lutetia',       ST_GeogFromText('SRID=4326;POINT( 2.35 48.86)'), -250,  360,  'city', 'Roman-era Paris.'),
  ('HP_LONDINIUM',    'Londinium',     ST_GeogFromText('SRID=4326;POINT(-0.13 51.51)'), 47,    400,  'city', 'Roman London.'),

  -- Steppe / Iran / Central Asia
  ('HP_SAMARKAND',    'Samarkand',     ST_GeogFromText('SRID=4326;POINT(66.97 39.65)'), -700,  2025, 'city', NULL),
  ('HP_BUKHARA',      'Bukhara',       ST_GeogFromText('SRID=4326;POINT(64.42 39.77)'), -500,  2025, 'city', NULL),
  ('HP_MERV',         'Merv',          ST_GeogFromText('SRID=4326;POINT(62.20 37.66)'), -500,  1221, 'city', 'Sacked by the Mongols, 1221.'),
  ('HP_KARAKORUM',    'Karakorum',     ST_GeogFromText('SRID=4326;POINT(102.85 47.43)'), 1220, 1380, 'city', 'Mongol imperial capital under Ögedei.'),

  -- South / East Asia
  ('HP_PATALIPUTRA',  'Pataliputra',   ST_GeogFromText('SRID=4326;POINT(85.14 25.61)'), -490,  600,  'city', 'Mauryan / Gupta capital.'),
  ('HP_TAXILA',       'Taxila',        ST_GeogFromText('SRID=4326;POINT(72.83 33.74)'), -518,  500,  'city', 'Gandharan center of learning.'),
  ('HP_ANGKOR',       'Angkor',        ST_GeogFromText('SRID=4326;POINT(103.87 13.41)'), 800, 1431, 'city', 'Khmer imperial capital.'),
  ('HP_PAGAN',        'Pagan',         ST_GeogFromText('SRID=4326;POINT(94.86 21.17)'), 849, 1297,  'city', 'Burmese imperial capital.'),
  ('HP_AYUTTHAYA',    'Ayutthaya',     ST_GeogFromText('SRID=4326;POINT(100.57 14.36)'),1351,1767, 'city', NULL),
  ('HP_ANYANG',       'Yin (Anyang)',  ST_GeogFromText('SRID=4326;POINT(114.39 36.10)'), -1300, -1046, 'city', 'Late Shang capital.'),
  ('HP_CHANGAN',      'Chang''an',     ST_GeogFromText('SRID=4326;POINT(108.94 34.27)'), -200, 1000, 'city', 'Han / Tang capital, modern Xi''an.'),
  ('HP_LUOYANG',      'Luoyang',       ST_GeogFromText('SRID=4326;POINT(112.43 34.62)'), -700, 1300, 'city', 'Eastern Han / Tang / Song capital.'),
  ('HP_HEIANKYO',     'Heian-kyō',     ST_GeogFromText('SRID=4326;POINT(135.77 35.01)'), 794, 1869, 'city', 'Heian / Edo-era Kyoto.'),

  -- Africa
  ('HP_TIMBUKTU',     'Timbuktu',      ST_GeogFromText('SRID=4326;POINT(-2.99 16.77)'), 1100, 2025, 'city', 'Sahel scholarly + trade center.'),
  ('HP_GAO',          'Gao',           ST_GeogFromText('SRID=4326;POINT( 0.00 16.27)'), 700,  1591, 'city', 'Songhai capital.'),
  ('HP_GREAT_ZIM',    'Great Zimbabwe',ST_GeogFromText('SRID=4326;POINT(30.93 -20.27)'),1100, 1450, 'city', 'Stone-walled city of the Shona kingdom.'),
  ('HP_KILWA',        'Kilwa',         ST_GeogFromText('SRID=4326;POINT(39.51 -8.96)'), 800, 1500, 'city', 'Swahili coast trading city.'),

  -- Americas
  ('HP_TENOCHTITLAN', 'Tenochtitlan',  ST_GeogFromText('SRID=4326;POINT(-99.13 19.43)'), 1325, 1521,'city', 'Aztec / Mexica capital. Renamed Mexico City.'),
  ('HP_TEOTIHUACAN',  'Teotihuacan',   ST_GeogFromText('SRID=4326;POINT(-98.84 19.69)'),  -100, 750, 'city', NULL),
  ('HP_CHICHEN_ITZA', 'Chichén Itzá',  ST_GeogFromText('SRID=4326;POINT(-88.57 20.68)'),  600, 1200, 'city', NULL),
  ('HP_TIKAL',        'Tikal',         ST_GeogFromText('SRID=4326;POINT(-89.62 17.22)'),  -400, 900, 'city', 'Lowland Classic Maya city.'),
  ('HP_PALENQUE',     'Palenque',      ST_GeogFromText('SRID=4326;POINT(-92.05 17.48)'),  226, 800,  'city', NULL),
  ('HP_CUZCO',        'Cuzco',         ST_GeogFromText('SRID=4326;POINT(-71.97 -13.53)'), 1100, 2025,'city', 'Inca capital.'),
  ('HP_MACHU_PICCHU', 'Machu Picchu',  ST_GeogFromText('SRID=4326;POINT(-72.54 -13.16)'), 1450, 1572,'city', NULL),
  ('HP_CAHOKIA',      'Cahokia',       ST_GeogFromText('SRID=4326;POINT(-90.06 38.66)'),   800, 1400,'city', 'Largest pre-Columbian city north of Mexico.'),

  -- Regions (rendered as larger labels)
  ('HP_REG_MESOPOTAMIA','Mesopotamia', ST_GeogFromText('SRID=4326;POINT(44.0 33.0)'),     -3500, 651, 'region', NULL),
  ('HP_REG_GAUL',     'Gallia',        ST_GeogFromText('SRID=4326;POINT(2.0  47.0)'),      -700, 486, 'region', 'Pre-Frankish "Gaul".'),
  ('HP_REG_HISPANIA', 'Hispania',      ST_GeogFromText('SRID=4326;POINT(-4.0 40.0)'),      -200, 711, 'region', 'Roman Iberia.'),
  ('HP_REG_BRITANNIA','Britannia',     ST_GeogFromText('SRID=4326;POINT(-2.0 53.0)'),       43, 410,  'region', 'Roman Britain.'),
  ('HP_REG_ANATOLIA', 'Asia Minor',    ST_GeogFromText('SRID=4326;POINT(35.0 39.0)'),     -1500, 1453,'region', NULL),
  ('HP_REG_AEGYPTUS', 'Aegyptus',      ST_GeogFromText('SRID=4326;POINT(31.0 27.0)'),      -30, 641,  'region', 'Roman Egypt.'),
  ('HP_REG_BACTRIA',  'Bactria',       ST_GeogFromText('SRID=4326;POINT(67.0 36.5)'),     -2000, 700, 'region', NULL),
  ('HP_REG_SCYTHIA',  'Scythia',       ST_GeogFromText('SRID=4326;POINT(35.0 49.0)'),     -700, 300,  'region', NULL),
  ('HP_REG_BERINGIA', 'Beringia',      ST_GeogFromText('SRID=4326;POINT(-170.0 65.0)'),  -50000, -10000,'region', 'Land bridge between Asia and the Americas.'),
  ('HP_REG_DOGGERLAND','Doggerland',   ST_GeogFromText('SRID=4326;POINT(2.0 55.5)'),     -50000, -6500,'region', 'Submerged North Sea landmass.'),
  ('HP_REG_SUNDALAND','Sundaland',     ST_GeogFromText('SRID=4326;POINT(108.0 0.0)'),    -50000, -8000,'region', 'Pleistocene SE Asian landmass.'),
  ('HP_REG_SAHUL',    'Sahul',         ST_GeogFromText('SRID=4326;POINT(140.0 -15.0)'),  -65000, -8000,'region', 'Pleistocene Australia + New Guinea landmass.');
