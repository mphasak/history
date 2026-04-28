-- 003_seed_paleo_features.sql
--
-- Hand-authored paleo features (ice sheets) for the deglaciation period.
-- Land bridges (Beringia, Doggerland, Sundaland, Sahul) are NOT seeded here
-- anymore — they're rendered client-side from a continental-shelf polygon
-- gated by paleoclimate_state.sea_level_meters (see frontend/public/paleo/).
--
-- Coordinates are coarse; this is dev-grade cartography to make scrubbing
-- through deglaciation visible on the map.
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
  ('PF_PALEO_LAURENTIDE_ICE',    'ice_sheet',   'Laurentide Ice Sheet',
   'Continental ice sheet covering most of Canada and the northern US during the LGM.'),
  ('PF_PALEO_FENNOSCANDIAN_ICE', 'ice_sheet',   'Fennoscandian Ice Sheet',
   'Continental ice sheet over Scandinavia, the UK, and parts of northern Europe.')
ON CONFLICT (id) DO NOTHING;

-- Clean up any rectangular land-bridge rows from earlier seed runs.
DELETE FROM physical_feature
WHERE id IN ('PF_PALEO_BERINGIA','PF_PALEO_DOGGERLAND','PF_PALEO_SUNDALAND','PF_PALEO_SAHUL');

-- ---------------------------------------------------------------------------
-- paleoclimate_state keyframes (sea level + temp anomaly)
-- ---------------------------------------------------------------------------
-- Coarse global sea-level keyframes spanning the sapiens timeframe and a bit
-- earlier. Frontend uses sea_level_meters to gate the continental-shelf
-- overlay (shelf shows when sea level <= ~-50 m). Values are approximate;
-- finer-grained reconstructions can replace these per-region later.

DELETE FROM paleoclimate_state WHERE id LIKE 'PCS_PALEO_%';

INSERT INTO paleoclimate_state (id, year, scope, sea_level_meters, temp_anomaly_c, ice_volume_relative) VALUES
  ('PCS_PALEO_PRESENT',          0,        'global',    0.0, 0.0,  'low'),
  ('PCS_PALEO_MID_HOLOCENE',    -6000,     'global',    1.0, 0.5,  'low'),
  ('PCS_PALEO_EARLY_HOLOCENE', -10000,     'global',  -50.0,-1.0,  'low_med'),
  ('PCS_PALEO_YOUNGER_DRYAS',  -12000,     'global',  -65.0,-3.0,  'med'),
  ('PCS_PALEO_LGM',            -20000,     'global', -120.0,-5.0,  'high'),
  ('PCS_PALEO_LATE_GLACIAL_30K',-30000,    'global', -100.0,-4.0,  'med_high'),
  ('PCS_PALEO_MIS3',           -50000,     'global',  -80.0,-3.0,  'med'),
  ('PCS_PALEO_MIS4',           -70000,     'global',  -75.0,-3.0,  'med'),
  ('PCS_PALEO_EEMIAN',        -125000,     'global',    6.0, 1.5,  'low'),
  ('PCS_PALEO_MIS6',          -150000,     'global', -100.0,-4.0,  'high'),
  ('PCS_PALEO_MIS7',          -200000,     'global',  -65.0,-2.5,  'med'),
  ('PCS_PALEO_SAPIENS_DAWN',  -300000,     'global', -100.0,-3.0,  'med_high');

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
