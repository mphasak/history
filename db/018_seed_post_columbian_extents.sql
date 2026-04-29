-- 018_seed_post_columbian_extents.sql
--
-- Authored extent polygons for the post-Columbian / globalization-era
-- carriers from 017. Without these they fall back to the
-- `_CARRIER_DEFAULT_RADIUS_M` 800 km buffer around their centroid, which
-- looks ridiculous for continent-scale populations like African
-- Americans (one circle in Alabama) or Modern Australians (one circle
-- around Canberra).
--
-- Polygons are deliberately rough — bounding-box-ish convex hulls that
-- approximate the modern demographic distribution. Per-year evolution
-- (Atlantic seaboard 1607 → Mississippi 1800 → Pacific 1900 for the US
-- whites, for example) would be lovely but out of scope here; we use a
-- single late-period snapshot per carrier that captures the bulk of
-- the distribution.
--
-- Idempotent: keyed on the as_of_year + carrier_id combination of the
-- 017 carriers; we delete those exact rows before insert. Other
-- carrier_extent_snapshot rows from 009 are untouched.

DELETE FROM carrier_extent_snapshot
WHERE carrier_id LIKE 'CARR_HIST_POST1492_%';

-- Helper: every geometry below uses ST_Multi() to coerce single-polygon
-- inputs into the MultiPolygon column type.
INSERT INTO carrier_extent_snapshot (carrier_id, as_of_year, geometry) VALUES

  -- Colonial NA (1607-1776): English/Dutch/French Atlantic seaboard.
  ('CARR_HIST_POST1492_COLONIAL_NA', 1700,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-77 32, -75.5 33.5, -76 36.5, -76.8 38.5, -75 39.5, -73 41, -71 42.5, -69.5 44, -68 45, -67 45.5, -69 42, -71.5 39, -75 36, -77 32))')::geometry)::geography),

  -- Republic-era US white (1776-1900): Atlantic seaboard expanding to
  -- Pacific via 1850.
  ('CARR_HIST_POST1492_REPUBLIC_US_WHITE', 1850,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-100 28, -75 27, -67 30, -68 45, -86 47, -96 49, -101 47, -100 28)),((-124 32, -118 33, -120 38, -123 39, -124 32)))')),

  -- Gilded-Age US (1865-1945): full continental US.
  ('CARR_HIST_POST1492_GILDED_AGE_US', 1920,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-124 24, -100 25, -97 25, -82 24, -75 25, -67 30, -67 45, -83 47, -95 49, -108 49, -124 49, -124 32, -124 24))')::geometry)::geography),

  -- African Americans (1700-2025): rural-South spine + Great-Migration
  -- urban centers (Chicago, Detroit, NY, LA, St Louis).
  ('CARR_HIST_POST1492_AFRICAN_AMERICAN', 2000,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-94 27, -77 27, -75 32, -76 38, -78 39, -84 36, -90 36, -93 33, -94 27)),((-89 41, -86 42, -86 44, -89 44, -89 41)),((-75 38, -73 39, -73 42, -75 42, -75 38)),((-119 33, -117 33, -117 35, -119 35, -119 33)),((-90 38, -88 38, -88 40, -90 40, -90 38)))')),

  -- Afro-Caribbean (1500-2025): Greater + Lesser Antilles.
  ('CARR_HIST_POST1492_AFRO_CARIBBEAN', 1800,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((-85 17, -73 17, -67 18, -60 17, -60 19, -68 23, -85 23, -85 17)),((-78 20, -76 20, -76 23, -78 23, -78 20)))')),

  -- Colonial Brazilian (1500-1822): Atlantic coast + Minas + interior fringe.
  ('CARR_HIST_POST1492_COLONIAL_BR', 1700,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-49 -7, -36 -8, -34 -8, -38 -13, -41 -22, -44 -23, -48 -25, -54 -28, -57 -25, -55 -20, -50 -15, -49 -7))')::geometry)::geography),

  -- Modern Brazilian (1900-2025): essentially all of Brazil.
  ('CARR_HIST_POST1492_MODERN_BRAZILIAN', 1980,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-73 5, -50 5, -36 -5, -34 -8, -38 -13, -41 -22, -49 -25, -54 -28, -57 -33, -64 -22, -71 -10, -73 5))')::geometry)::geography),

  -- Colonial Andean (1532-1810): Andean spine of modern Peru + Bolivia.
  ('CARR_HIST_POST1492_COLONIAL_ANDEAN', 1700,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((-79 -3, -76 -5, -73 -10, -69 -15, -66 -19, -68 -22, -71 -19, -75 -14, -79 -7, -80 -5, -79 -3))')::geometry)::geography),

  -- Colonial Australia (1788-1901): SE coast cities + Perth.
  ('CARR_HIST_POST1492_COLONIAL_AUS', 1880,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((140 -34, 154 -28, 154 -38, 147 -43, 144 -38, 140 -34)),((115 -32, 117 -32, 117 -35, 115 -35, 115 -32)))')),

  -- Modern Australian (1901-2025): most of the continent.
  ('CARR_HIST_POST1492_MODERN_AUS', 2000,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((113 -22, 141 -11, 154 -25, 154 -38, 147 -43, 130 -33, 113 -22))')::geometry)::geography),

  -- Pakeha NZ (1840-2025): both islands.
  ('CARR_HIST_POST1492_PAKEHA_NZ', 1980,
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((172 -34, 178 -36, 178 -42, 173 -41, 172 -34)),((166 -45, 174 -41, 174 -47, 166 -47, 166 -45)))')),

  -- Afrikaner (1652-2025): Western/Eastern Cape + Highveld.
  ('CARR_HIST_POST1492_AFRIKANER', 1900,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((17 -34, 27 -34, 32 -29, 31 -24, 28 -23, 22 -27, 17 -29, 17 -34))')::geometry)::geography),

  -- Modern Israeli (1948-2025): Israel + West Bank + Golan.
  ('CARR_HIST_POST1492_MODERN_ISRAELI', 2000,
   ST_Multi(ST_GeogFromText('SRID=4326;POLYGON((34.3 29.5, 35.7 29.5, 35.9 32.0, 35.7 33.3, 34.6 33.0, 34.2 31.5, 34.3 29.5))')::geometry)::geography);
