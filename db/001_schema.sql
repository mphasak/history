-- 001_schema.sql — Human History Simulator v0.3
-- Run with: psql -f 001_schema.sql

CREATE EXTENSION IF NOT EXISTS postgis;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE trait_domain AS ENUM (
  'genetic', 'technological', 'linguistic', 'religious',
  'ideological', 'artistic', 'institutional', 'material_culture', 'other'
);

CREATE TYPE trait_relation_type AS ENUM (
  'descends_from', 'admixture_of', 'sister_of', 'derived_from',
  'influenced_by', 'reaction_against', 'syncretism_of', 'revival_of'
);

CREATE TYPE carrier_type AS ENUM (
  'population', 'community', 'institution', 'nation_state',
  'sub_national_region', 'diaspora', 'virtual'
);

CREATE TYPE propagation_mechanism AS ENUM (
  'demic', 'elite_dominance', 'pastoralist', 'conquest', 'missionary',
  'trade', 'mass_media', 'education_system', 'viral_propagation',
  'institutional_capture', 'colonization', 'demic_plus_cultural'
);

CREATE TYPE feature_type AS ENUM (
  'coastline', 'ice_sheet', 'glacier', 'lake', 'inland_sea', 'river',
  'desert', 'forest', 'savanna', 'tundra', 'land_bridge', 'volcano', 'sea'
);

CREATE TYPE source_type AS ENUM (
  'book_chapter', 'peer_reviewed_paper', 'preprint', 'dataset',
  'popular_book', 'wikipedia', 'primary_record', 'oral_tradition',
  'press', 'think_tank_paper'
);

CREATE TYPE claim_stance AS ENUM ('supports', 'disputes', 'nuances');

CREATE TYPE perspective_status AS ENUM (
  'admitted', 'provisional', 'rejected', 'retired'
);

CREATE TYPE endorsement_stance AS ENUM (
  'endorses', 'rejects', 'nuances', 'asserts'
);

-- ---------------------------------------------------------------------------
-- geo_region (named "geo_region" to avoid conflict with the PostGIS "geography" type)
-- ---------------------------------------------------------------------------

CREATE TABLE geo_region (
  id            text PRIMARY KEY,
  display_name  text NOT NULL,
  type          text,
  centroid      geography(POINT, 4326),
  extent        geography(MULTIPOLYGON, 4326),
  parent_id     text REFERENCES geo_region(id)
);

-- ---------------------------------------------------------------------------
-- source (early — referenced by claim_source, perspective_source_weight)
-- ---------------------------------------------------------------------------

CREATE TABLE source (
  id                text PRIMARY KEY,
  type              source_type NOT NULL,
  citation          text NOT NULL,
  authors           text[],
  year              integer,
  pages_section     text,
  doi_url           text,
  edition           text,
  default_weight    numeric(3,2) NOT NULL DEFAULT 1.0
                    CHECK (default_weight BETWEEN 0 AND 1),
  superseded_by     text REFERENCES source(id),
  tags              text[]
);

-- ---------------------------------------------------------------------------
-- trait
-- ---------------------------------------------------------------------------

CREATE TABLE trait (
  id                   text PRIMARY KEY,
  domain               trait_domain NOT NULL,
  display_name         text NOT NULL,
  aliases              text[],
  first_detected_year  integer,
  last_detected_year   integer,
  origin_region_id     text REFERENCES geo_region(id),
  origin_point         geography(POINT, 4326),
  defining_exemplars   text[],
  description          text,
  politically_sensitive boolean DEFAULT false,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- claim (no FK to entity tables — subject is polymorphic text)
-- ---------------------------------------------------------------------------

CREATE TABLE claim (
  id                       bigserial PRIMARY KEY,
  subject_type             text NOT NULL,
  subject_id               text NOT NULL,
  statement                text NOT NULL,
  quantitative_value       jsonb,
  default_aggregated_confidence smallint
                           CHECK (default_aggregated_confidence BETWEEN 1 AND 5),
  politically_sensitive    boolean DEFAULT false,
  created_at               timestamptz DEFAULT now()
);

CREATE TABLE claim_source (
  id              bigserial PRIMARY KEY,
  claim_id        bigint NOT NULL REFERENCES claim(id) ON DELETE CASCADE,
  source_id       text NOT NULL REFERENCES source(id),
  stance          claim_stance NOT NULL DEFAULT 'supports',
  weight_override numeric(3,2)
);

-- ---------------------------------------------------------------------------
-- trait_relation (nullable claim_id; ON DELETE SET NULL for idempotency)
-- ---------------------------------------------------------------------------

CREATE TABLE trait_relation (
  id            bigserial PRIMARY KEY,
  child_id      text NOT NULL REFERENCES trait(id),
  parent_id     text NOT NULL REFERENCES trait(id),
  relation_type trait_relation_type NOT NULL,
  weight        numeric(4,3),
  claim_id      bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- carrier
-- ---------------------------------------------------------------------------

CREATE TABLE carrier (
  id                       text PRIMARY KEY,
  display_name             text NOT NULL,
  type                     carrier_type NOT NULL,
  date_min_year            integer NOT NULL,
  date_max_year            integer NOT NULL,
  centroid                 geography(POINT, 4326),
  extent                   geography(MULTIPOLYGON, 4326),
  archaeological_culture   text,
  linguistic_affiliation   text,
  description              text
);

-- ---------------------------------------------------------------------------
-- carrier_trait_mix
-- ---------------------------------------------------------------------------

CREATE TABLE carrier_trait_mix (
  id            bigserial PRIMARY KEY,
  carrier_id    text NOT NULL REFERENCES carrier(id),
  as_of_year    integer NOT NULL,
  domain        trait_domain NOT NULL,
  trait_id      text NOT NULL REFERENCES trait(id),
  fraction      numeric(4,3) NOT NULL CHECK (fraction BETWEEN 0 AND 1),
  stderr        numeric(4,3),
  claim_id      bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- Per (carrier, as_of_year, domain), SUM(fraction) should be in [0.95, 1.05].

-- ---------------------------------------------------------------------------
-- trait_observation
-- ---------------------------------------------------------------------------

CREATE TABLE trait_observation (
  id           text PRIMARY KEY,
  carrier_id   text REFERENCES carrier(id),
  sample_label text,
  date_min_year integer,
  date_max_year integer,
  location     geography(POINT, 4326),
  domain       trait_domain NOT NULL,
  trait_id     text REFERENCES trait(id),
  fraction     numeric(4,3),
  stderr       numeric(4,3),
  method       text,
  claim_id     bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- physical_feature + snapshot
-- ---------------------------------------------------------------------------

CREATE TABLE physical_feature (
  id           text PRIMARY KEY,
  type         feature_type NOT NULL,
  display_name text,
  description  text
);

CREATE TABLE physical_feature_snapshot (
  id           bigserial PRIMARY KEY,
  feature_id   text NOT NULL REFERENCES physical_feature(id),
  as_of_year   integer NOT NULL,
  geometry     geography(MULTIPOLYGON, 4326),
  centroid     geography(POINT, 4326),
  claim_id     bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- paleoclimate_state
-- ---------------------------------------------------------------------------

CREATE TABLE paleoclimate_state (
  id                    text PRIMARY KEY,
  year                  integer NOT NULL,
  scope                 text CHECK (scope IN ('global', 'regional')),
  region_id             text REFERENCES geo_region(id),
  sea_level_meters      numeric(6,2),
  temp_anomaly_c        numeric(4,2),
  ice_volume_relative   text,
  co2_ppm               numeric(5,1),
  claim_id              bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- propagation_event + resulting_change
-- ---------------------------------------------------------------------------

CREATE TABLE propagation_event (
  id                      text PRIMARY KEY,
  display_name            text NOT NULL,
  domain                  trait_domain NOT NULL,
  date_min_year           integer NOT NULL,
  date_max_year           integer NOT NULL,
  source_trait_ids        text[],
  source_region_id        text REFERENCES geo_region(id),
  source_point            geography(POINT, 4326),
  destination_region_id   text REFERENCES geo_region(id),
  destination_point       geography(POINT, 4326),
  mechanism               propagation_mechanism,
  politically_sensitive   boolean DEFAULT false,
  claim_id                bigint REFERENCES claim(id) ON DELETE SET NULL
);

CREATE TABLE propagation_resulting_change (
  id                    bigserial PRIMARY KEY,
  propagation_event_id  text NOT NULL REFERENCES propagation_event(id),
  trait_id              text NOT NULL REFERENCES trait(id),
  fraction_change       numeric(5,3),
  claim_id              bigint REFERENCES claim(id) ON DELETE SET NULL
);

-- ---------------------------------------------------------------------------
-- perspective + source weights + endorsements
-- ---------------------------------------------------------------------------

CREATE TABLE perspective (
  id                     text PRIMARY KEY,
  display_name           text NOT NULL,
  domain_scope           trait_domain[],
  summary                text NOT NULL,
  proponents             text,
  methodology_notes      text NOT NULL,
  parent_perspective_id  text REFERENCES perspective(id),
  default_active         boolean DEFAULT false,
  status                 perspective_status NOT NULL DEFAULT 'provisional',
  admitted_by            uuid,
  admitted_at            timestamptz,
  created_at             timestamptz DEFAULT now()
);

CREATE TABLE perspective_source_weight (
  id              bigserial PRIMARY KEY,
  perspective_id  text NOT NULL REFERENCES perspective(id),
  source_id       text NOT NULL REFERENCES source(id),
  weight          numeric(3,2) NOT NULL CHECK (weight BETWEEN 0 AND 1),
  excluded        boolean NOT NULL DEFAULT false,
  UNIQUE (perspective_id, source_id)
);

CREATE TABLE perspective_endorsement (
  id                          bigserial PRIMARY KEY,
  perspective_id              text NOT NULL REFERENCES perspective(id),
  subject_type                text NOT NULL,
  subject_id                  text NOT NULL,
  stance                      endorsement_stance NOT NULL,
  override_statement          text,
  override_quantitative_value jsonb,
  source_weight_overrides     jsonb,
  asserted_relation           jsonb,
  notes                       text,
  created_at                  timestamptz DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- edit (Phase 2 governance — included for schema completeness)
-- ---------------------------------------------------------------------------

CREATE TABLE edit (
  id            bigserial PRIMARY KEY,
  user_id       uuid NOT NULL,
  perspective_id text REFERENCES perspective(id),
  entity_table  text NOT NULL,
  entity_id     text NOT NULL,
  before        jsonb,
  after         jsonb,
  summary       text,
  created_at    timestamptz DEFAULT now()
);
