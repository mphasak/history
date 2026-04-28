-- 002_indexes.sql — Performance indexes

-- Time-window queries are the hottest path
CREATE INDEX idx_carrier_dates ON carrier (date_min_year, date_max_year);
CREATE INDEX idx_carrier_trait_mix_year ON carrier_trait_mix (as_of_year);
CREATE INDEX idx_propagation_event_dates ON propagation_event (date_min_year, date_max_year);

-- Spatial
CREATE INDEX idx_carrier_centroid ON carrier USING GIST (centroid);
CREATE INDEX idx_carrier_extent ON carrier USING GIST (extent);
CREATE INDEX idx_propagation_source_point ON propagation_event USING GIST (source_point);
CREATE INDEX idx_propagation_dest_point ON propagation_event USING GIST (destination_point);

-- Perspective lookups
CREATE INDEX idx_endorsement_perspective ON perspective_endorsement (perspective_id);
CREATE INDEX idx_endorsement_subject ON perspective_endorsement (subject_type, subject_id);

-- Claim subject lookups
CREATE INDEX idx_claim_subject ON claim (subject_type, subject_id);
CREATE INDEX idx_claim_source ON claim_source (claim_id);

-- Additional useful indexes
CREATE INDEX idx_carrier_trait_mix_carrier ON carrier_trait_mix (carrier_id, as_of_year);
CREATE INDEX idx_trait_relation_child ON trait_relation (child_id);
CREATE INDEX idx_trait_relation_parent ON trait_relation (parent_id);

-- Paleo-basemap DISTINCT ON (feature_id ORDER BY as_of_year DESC)
CREATE INDEX idx_pfs_feature_year ON physical_feature_snapshot (feature_id, as_of_year DESC);

-- trait_observation date+location filter
CREATE INDEX idx_trait_obs_dates ON trait_observation (date_min_year, date_max_year);
CREATE INDEX idx_trait_obs_location ON trait_observation USING GIST (location);
