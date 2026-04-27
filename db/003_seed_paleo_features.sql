-- 003_seed_paleo_features.sql
--
-- Hand-authored paleo features (land bridges, ice sheets) for the period
-- ~20,000 BCE to early Holocene. Coordinates are coarse; this is dev-grade
-- cartography to make scrubbing through deglaciation visible on the map.
--
-- A snapshot with NULL geometry signals "feature has disappeared as of this year"
-- — the API returns the latest snapshot at or before the queried year, so a NULL
-- snapshot causes the frontend to stop rendering it.
--
-- All inserts are idempotent: features use stable IDs (PF_PALEO_*) and snapshots
-- use a uniqueness check on (feature_id, as_of_year).

-- ---------------------------------------------------------------------------
-- physical_feature rows
-- ---------------------------------------------------------------------------

INSERT INTO physical_feature (id, type, display_name, description) VALUES
  ('PF_PALEO_BERINGIA',          'land_bridge', 'Beringia (Bering land bridge)',
   'Subaerial land connection between NE Asia and NW North America during glacial low-stands.'),
  ('PF_PALEO_DOGGERLAND',        'land_bridge', 'Doggerland',
   'Lowland connecting Britain to continental Europe across the southern North Sea.'),
  ('PF_PALEO_SUNDALAND',         'land_bridge', 'Sundaland',
   'Exposed Sunda Shelf joining peninsular SE Asia with Sumatra, Java, and Borneo.'),
  ('PF_PALEO_SAHUL',             'land_bridge', 'Sahul',
   'Combined Australia–New Guinea landmass exposed during low sea levels.'),
  ('PF_PALEO_LAURENTIDE_ICE',    'ice_sheet',   'Laurentide Ice Sheet',
   'Continental ice sheet covering most of Canada and the northern US during the LGM.'),
  ('PF_PALEO_FENNOSCANDIAN_ICE', 'ice_sheet',   'Fennoscandian Ice Sheet',
   'Continental ice sheet over Scandinavia, the UK, and parts of northern Europe.')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- physical_feature_snapshot rows
-- ---------------------------------------------------------------------------
-- Use DELETE + INSERT for idempotency: re-running this file replaces the
-- paleo snapshots without touching anything ingested from the spreadsheet.

DELETE FROM physical_feature_snapshot
WHERE feature_id IN (
  'PF_PALEO_BERINGIA','PF_PALEO_DOGGERLAND','PF_PALEO_SUNDALAND',
  'PF_PALEO_SAHUL','PF_PALEO_LAURENTIDE_ICE','PF_PALEO_FENNOSCANDIAN_ICE'
);

-- Beringia: full at LGM, narrowing by -12000, submerged by -10000
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_BERINGIA', -20000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((158 55, 180 55, 180 72, 158 72, 158 55)),((-180 55, -160 55, -160 72, -180 72, -180 55)))'),
   ST_GeogFromText('SRID=4326;POINT(180 65)')),
  ('PF_PALEO_BERINGIA', -12000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((168 60, 180 60, 180 70, 168 70, 168 60)),((-180 60, -168 60, -168 70, -180 70, -180 60)))'),
   ST_GeogFromText('SRID=4326;POINT(180 65)')),
  ('PF_PALEO_BERINGIA', -10000, NULL, NULL);

-- Doggerland: present at -12000, retreating by -8000, gone by -6500
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_DOGGERLAND', -12000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-2 51, 8 51, 8 56, -2 56, -2 51)))'),
   ST_GeogFromText('SRID=4326;POINT(3 53.5)')),
  ('PF_PALEO_DOGGERLAND', -8000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((1 53, 6 53, 6 55, 1 55, 1 53)))'),
   ST_GeogFromText('SRID=4326;POINT(3.5 54)')),
  ('PF_PALEO_DOGGERLAND', -6500, NULL, NULL);

-- Sundaland: full at LGM, gone by -10000
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_SUNDALAND', -20000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((100 -5, 120 -5, 120 12, 100 12, 100 -5)))'),
   ST_GeogFromText('SRID=4326;POINT(110 3)')),
  ('PF_PALEO_SUNDALAND', -10000, NULL, NULL);

-- Sahul: full at LGM, separated by -8000
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_SAHUL', -20000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((130 -12, 145 -12, 145 -3, 130 -3, 130 -12)))'),
   ST_GeogFromText('SRID=4326;POINT(137 -7)')),
  ('PF_PALEO_SAHUL', -8000, NULL, NULL);

-- Laurentide Ice Sheet: max LGM, smaller at -12000, residual at -8000, gone by -6000
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_LAURENTIDE_ICE', -20000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-135 45, -55 45, -55 75, -135 75, -135 45)))'),
   ST_GeogFromText('SRID=4326;POINT(-95 60)')),
  ('PF_PALEO_LAURENTIDE_ICE', -12000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-115 50, -65 50, -65 73, -115 73, -115 50)))'),
   ST_GeogFromText('SRID=4326;POINT(-90 62)')),
  ('PF_PALEO_LAURENTIDE_ICE', -8000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-95 55, -70 55, -70 68, -95 68, -95 55)))'),
   ST_GeogFromText('SRID=4326;POINT(-82 62)')),
  ('PF_PALEO_LAURENTIDE_ICE', -6000, NULL, NULL);

-- Fennoscandian Ice Sheet: max LGM, smaller at -12000, gone by -10000
INSERT INTO physical_feature_snapshot (feature_id, as_of_year, geometry, centroid) VALUES
  ('PF_PALEO_FENNOSCANDIAN_ICE', -20000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-10 53, 50 53, 50 75, -10 75, -10 53)))'),
   ST_GeogFromText('SRID=4326;POINT(20 64)')),
  ('PF_PALEO_FENNOSCANDIAN_ICE', -12000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((5 58, 35 58, 35 72, 5 72, 5 58)))'),
   ST_GeogFromText('SRID=4326;POINT(20 65)')),
  ('PF_PALEO_FENNOSCANDIAN_ICE', -10000, NULL, NULL);
