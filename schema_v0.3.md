# Human History Simulator — Schema v0.3

> Revised after deciding (a) the basemap itself must evolve over time, (b) genetic ancestry
> is one of many heritable, propagating things and should not be a privileged primitive,
> and (c) disagreement between scholarly/ideological traditions must be a **structural**
> feature of the data, not just an aggregation footnote.

---

## 1. Three core moves from v0.2

### 1.1 Trait replaces AncestryComponent
A **Trait** is anything that propagates over time, admixes between groups, and has lineage:
genes, technologies, languages, religions, ideologies, art forms, institutions, material
cultures. Domain is a field, not a separate table. The same machinery — descent, admixture,
mixing into Carriers, propagation events — operates uniformly across domains.

### 1.2 Physical environment as first-class entities
**PhysicalFeature** (coastlines, ice sheets, rivers, deserts, land bridges) and
**PaleoclimateState** (sea level, temperature, ice volume) make the basemap time-varying.
Both go through the same Claim/Source machinery — paleo-coastlines have citations too.

### 1.3 Perspective is the unit of disagreement
A **Perspective** is a curated, internally-coherent worldview: a bundle of source preferences,
endorsed claims, and asserted lineage trees. The same (time, place) coordinate can yield
different worlds under different Perspectives. The UI renders single-perspective, side-by-side,
diff-overlay, or weighted-blend views.

---

## 2. Entity overview

```
                    ┌─────────────────────┐
                    │       Trait         │   atomic; domain-tagged
                    │ (genes, tech, lang, │   (genetic, ideological, …)
                    │  religion, ideology)│
                    └─────────┬───────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼──────────┐  ┌───────▼──────────┐  ┌───────▼──────────┐
│ TraitRelation    │  │ TraitObservation │  │     Carrier      │
│ (descent, admix, │  │ (sample evidence)│  │ (group, place,   │
│  influence, …)   │  │                  │  │  institution)    │
└──────────────────┘  └──────────────────┘  └────────┬─────────┘
                                                     │
                                            ┌────────▼─────────┐
                                            │ CarrierTraitMix  │
                                            │ (time-varying)   │
                                            └────────┬─────────┘
                                                     │
                                            ┌────────▼─────────┐
                                            │ PropagationEvent │
                                            │ (mechanisms:     │
                                            │  demic, missionary,│
                                            │  conquest, media…)│
                                            └──────────────────┘

  ┌─────────────────────┐         ┌─────────────────────┐
  │  PhysicalFeature    │         │ PaleoclimateState   │
  │  (coastlines, ice,  │         │ (sea level, temp,   │
  │   land bridges, …)  │         │  CO2, ice volume)   │
  └─────────────────────┘         └─────────────────────┘

         every fact ─►  ┌──────────────┐ many-to-many ┌──────────┐
                        │    Claim     │◄────────────►│  Source  │
                        └──────┬───────┘              └──────────┘
                               │
                       ┌───────▼────────┐
                       │  Perspective   │   endorses / rejects / nuances /
                       │ (worldview as  │   asserts new claims
                       │  source-set +  │
                       │  endorsements) │
                       └────────────────┘
```

---

## 3. Tables (PostgreSQL + PostGIS)

### 3.1 `trait`

```sql
CREATE TYPE trait_domain AS ENUM (
  'genetic', 'technological', 'linguistic', 'religious',
  'ideological', 'artistic', 'institutional', 'material_culture', 'other'
);

CREATE TABLE trait (
  id                   text PRIMARY KEY,
  domain               trait_domain NOT NULL,
  display_name         text NOT NULL,
  aliases              text[],
  first_detected_year  integer,
  last_detected_year   integer,
  origin_region_id     text REFERENCES geography(id),
  origin_point         geography(POINT, 4326),
  defining_exemplars   text[],
  description          text,
  politically_sensitive boolean DEFAULT false,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now()
);
```

### 3.2 `trait_relation`

```sql
CREATE TYPE trait_relation_type AS ENUM (
  'descends_from', 'admixture_of', 'sister_of', 'derived_from',
  'influenced_by', 'reaction_against', 'syncretism_of', 'revival_of'
);

CREATE TABLE trait_relation (
  id            bigserial PRIMARY KEY,
  child_id      text NOT NULL REFERENCES trait(id),
  parent_id     text NOT NULL REFERENCES trait(id),
  relation_type trait_relation_type NOT NULL,
  weight        numeric(4,3),
  claim_id      bigint REFERENCES claim(id)
);
```

> The same `(child, parent, relation_type)` may appear endorsed by some Perspectives and
> rejected by others. The default tree (rows in this table) is what you get with no
> Perspective filter; per-Perspective overrides live in `perspective_endorsement`.

### 3.3 `carrier`

```sql
CREATE TYPE carrier_type AS ENUM (
  'population', 'community', 'institution', 'nation_state',
  'sub_national_region', 'diaspora', 'virtual'
);

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
```

### 3.4 `carrier_trait_mix`

```sql
CREATE TABLE carrier_trait_mix (
  id            bigserial PRIMARY KEY,
  carrier_id    text NOT NULL REFERENCES carrier(id),
  as_of_year    integer NOT NULL,
  domain        trait_domain NOT NULL,
  trait_id      text NOT NULL REFERENCES trait(id),
  fraction      numeric(4,3) NOT NULL CHECK (fraction BETWEEN 0 AND 1),
  stderr        numeric(4,3),
  claim_id      bigint REFERENCES claim(id)
);

-- Per (carrier, as_of_year, domain), SUM(fraction) should be in [0.95, 1.05].
-- Enforce via trigger or batch validation rather than constraint.
```

### 3.5 `trait_observation`

```sql
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
  claim_id     bigint REFERENCES claim(id)
);
```

### 3.6 `propagation_event`

```sql
CREATE TYPE propagation_mechanism AS ENUM (
  'demic', 'elite_dominance', 'pastoralist', 'conquest', 'missionary',
  'trade', 'mass_media', 'education_system', 'viral_propagation',
  'institutional_capture', 'colonization', 'demic_plus_cultural'
);

CREATE TABLE propagation_event (
  id                      text PRIMARY KEY,
  display_name            text NOT NULL,
  domain                  trait_domain NOT NULL,
  date_min_year           integer NOT NULL,
  date_max_year           integer NOT NULL,
  source_trait_ids        text[],
  source_region_id        text REFERENCES geography(id),
  source_point            geography(POINT, 4326),
  destination_region_id   text REFERENCES geography(id),
  destination_point       geography(POINT, 4326),
  mechanism               propagation_mechanism,
  politically_sensitive   boolean DEFAULT false,
  claim_id                bigint REFERENCES claim(id)
);

CREATE TABLE propagation_resulting_change (
  id                    bigserial PRIMARY KEY,
  propagation_event_id  text NOT NULL REFERENCES propagation_event(id),
  trait_id              text NOT NULL REFERENCES trait(id),
  fraction_change       numeric(5,3),
  claim_id              bigint REFERENCES claim(id)
);
```

### 3.7 `physical_feature`

```sql
CREATE TYPE feature_type AS ENUM (
  'coastline', 'ice_sheet', 'glacier', 'lake', 'inland_sea', 'river',
  'desert', 'forest', 'savanna', 'tundra', 'land_bridge', 'volcano', 'sea'
);

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
  claim_id     bigint REFERENCES claim(id)
);
```

> **Rendering trick:** for Holocene coastlines you usually don't need to store explicit
> snapshot geometries. Store the `paleoclimate_state.sea_level_meters` claim and let the
> renderer subtract it from modern bathymetry (ETOPO/GEBCO). Same for ice sheets if you
> have an ice-volume model. Snapshots only required where the feature can't be derived
> (e.g. Doggerland's exact extent, pre-Messinian Mediterranean configuration).

### 3.8 `paleoclimate_state`

```sql
CREATE TABLE paleoclimate_state (
  id                    text PRIMARY KEY,
  year                  integer NOT NULL,
  scope                 text CHECK (scope IN ('global', 'regional')),
  region_id             text REFERENCES geography(id),
  sea_level_meters      numeric(6,2),  -- relative to present
  temp_anomaly_c        numeric(4,2),
  ice_volume_relative   text,
  co2_ppm               numeric(5,1),
  claim_id              bigint REFERENCES claim(id)
);
```

### 3.9 `source`

```sql
CREATE TYPE source_type AS ENUM (
  'book_chapter', 'peer_reviewed_paper', 'preprint', 'dataset',
  'popular_book', 'wikipedia', 'primary_record', 'oral_tradition',
  'press', 'think_tank_paper'
);

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
```

### 3.10 `claim`

```sql
CREATE TABLE claim (
  id                       bigserial PRIMARY KEY,
  subject_type             text NOT NULL,  -- 'trait', 'trait_relation', 'carrier',
                                            -- 'carrier_trait_mix', 'trait_observation',
                                            -- 'propagation_event', 'physical_feature',
                                            -- 'paleoclimate_state', 'general'
  subject_id               text NOT NULL,
  statement                text NOT NULL,
  quantitative_value       jsonb,
  default_aggregated_confidence smallint
                           CHECK (default_aggregated_confidence BETWEEN 1 AND 5),
  politically_sensitive    boolean DEFAULT false,
  created_at               timestamptz DEFAULT now()
);

CREATE TYPE claim_stance AS ENUM ('supports', 'disputes', 'nuances');

CREATE TABLE claim_source (
  id              bigserial PRIMARY KEY,
  claim_id        bigint NOT NULL REFERENCES claim(id),
  source_id       text NOT NULL REFERENCES source(id),
  stance          claim_stance NOT NULL DEFAULT 'supports',
  weight_override numeric(3,2)
);
```

### 3.11 `perspective` and friends

```sql
CREATE TYPE perspective_status AS ENUM (
  'admitted', 'provisional', 'rejected', 'retired'
);

CREATE TABLE perspective (
  id                     text PRIMARY KEY,
  display_name           text NOT NULL,
  domain_scope           trait_domain[],   -- empty array = all domains
  summary                text NOT NULL,
  proponents             text,             -- named scholars / traditions
  methodology_notes      text NOT NULL,    -- what it privileges / rejects / blind spots
  parent_perspective_id  text REFERENCES perspective(id),
  default_active         boolean DEFAULT false,
  status                 perspective_status NOT NULL DEFAULT 'provisional',
  admitted_by            uuid,             -- editorial board user id
  admitted_at            timestamptz,
  created_at             timestamptz DEFAULT now()
);

-- Per-Perspective source weight overrides (applied when this Perspective is active)
CREATE TABLE perspective_source_weight (
  id              bigserial PRIMARY KEY,
  perspective_id  text NOT NULL REFERENCES perspective(id),
  source_id       text NOT NULL REFERENCES source(id),
  weight          numeric(3,2) NOT NULL CHECK (weight BETWEEN 0 AND 1),
  excluded        boolean NOT NULL DEFAULT false,
  UNIQUE (perspective_id, source_id)
);

CREATE TYPE endorsement_stance AS ENUM (
  'endorses', 'rejects', 'nuances', 'asserts'
);

-- The heart of the system: per-Perspective overrides on facts
CREATE TABLE perspective_endorsement (
  id                       bigserial PRIMARY KEY,
  perspective_id           text NOT NULL REFERENCES perspective(id),
  subject_type             text NOT NULL,   -- same vocabulary as claim.subject_type,
                                             -- plus 'claim' to endorse/reject a claim itself
  subject_id               text NOT NULL,
  stance                   endorsement_stance NOT NULL,
  override_statement       text,
  override_quantitative_value jsonb,
  source_weight_overrides  jsonb,            -- {SOURCE_ID: weight, ...}
  asserted_relation        jsonb,            -- for stance='asserts' on TraitRelation:
                                             -- {parent_id, relation_type, weight}
  notes                    text,
  created_at               timestamptz DEFAULT now()
);
```

### 3.12 `geography`

```sql
CREATE TABLE geography (
  id            text PRIMARY KEY,
  display_name  text NOT NULL,
  type          text,
  centroid      geography(POINT, 4326),
  extent        geography(MULTIPOLYGON, 4326),
  parent_id     text REFERENCES geography(id)
);
```

### 3.13 `edit` (Phase 2 governance)

```sql
CREATE TABLE edit (
  id            bigserial PRIMARY KEY,
  user_id       uuid NOT NULL,
  perspective_id text REFERENCES perspective(id),  -- which Perspective was being edited
  entity_table  text NOT NULL,
  entity_id     text NOT NULL,
  before        jsonb,
  after         jsonb,
  summary       text,
  created_at    timestamptz DEFAULT now()
);
```

---

## 4. Perspective resolution

The runtime "what does the world look like?" question is answered by resolving a
**PerspectiveSet** (one or more active Perspectives, with weights) against the data:

```
def resolve(perspective_set, query):
    # 1. Source weights = base default × per-Perspective override × user toggle
    # 2. For each candidate Claim, compute aggregated_confidence as before,
    #    but using the resolved source weights.
    # 3. For each Trait/Carrier/Mix/etc. relevant to the query, check
    #    perspective_endorsement for stance overrides:
    #      - 'rejects' → drop this fact from the resolved world
    #      - 'nuances' → use override_statement / override_quantitative_value
    #      - 'asserts' → add this fact even if no default Claim exists
    #      - 'endorses' or absent → use default Claim
    # 4. Return the assembled world.
```

For **side-by-side mode** the API runs `resolve()` twice and returns both worlds plus a
diff. For **blend mode** it runs once per Perspective and the renderer blends opacities.

---

## 5. Renderer modes

| Mode             | Active Perspectives | Visual                                    |
| ---------------- | ------------------- | ----------------------------------------- |
| Single           | 1                   | Clean map; footer shows active Perspective |
| Side-by-side     | 2                   | Two synchronized maps; diffs highlighted   |
| Diff overlay     | 2–N on one map      | Hatched fills on disagreement; agree=solid |
| Weighted blend   | N with weights      | Opacity = sum of endorsing weights         |

The detail panel (when a user clicks anything) always shows what the element is under
*every active Perspective*, never just the active one — this is what makes the system
honest about contestation rather than hiding it behind a default.

---

## 6. Reading patterns the API must serve

1. **`GET /world?year=Y&bbox=W,S,E,N&perspectives=P1,P2`**
   Returns features, carriers, mixes, and propagation events valid at `Y`, intersecting
   `bbox`, resolved against the given Perspective set. Optionally returns diffs.

2. **`GET /trait/:id/lineage?perspective=P`**
   Walks `trait_relation` recursively, applying P's endorsements, returns a Sankey-shaped
   graph (parents, weights, relation_type).

3. **`GET /trait/:id/lineage-diff?perspectives=P1,P2`**
   Returns two lineage trees with edges color-coded by which Perspective endorses each.
   The killer view for "how does Perspective A trace Trumpism vs Perspective B?".

4. **`GET /claim/:id?perspective=P`**
   Returns the claim plus, for each active Perspective, the stance, weighted source list,
   and override (if any).

5. **`GET /carrier/:id/timeline?perspective=P`**
   All `carrier_trait_mix` snapshots for this carrier, resolved against P, sorted by year.
   Drives the "watch this group's mix evolve" animation.

6. **`GET /paleo-basemap?year=Y&perspective=P`**
   Returns the renderable basemap: derived coastlines (modern bathymetry minus
   `paleoclimate_state.sea_level_meters` at Y) plus any `physical_feature_snapshot`s
   active at Y, all resolved against P.

---

## 7. Phase 0 deliverable mapping

| Spreadsheet sheet         | Postgres table(s)                                         |
| ------------------------- | --------------------------------------------------------- |
| Traits                    | `trait`                                                   |
| TraitRelations            | `trait_relation`                                          |
| Carriers                  | `carrier`                                                 |
| CarrierTraitMix           | `carrier_trait_mix`                                       |
| TraitObservations         | `trait_observation`                                       |
| PropagationEvents         | `propagation_event`, `propagation_resulting_change`       |
| PhysicalFeatures          | `physical_feature`, `physical_feature_snapshot`           |
| PaleoclimateStates        | `paleoclimate_state`                                      |
| Sources                   | `source`                                                  |
| Claims                    | `claim`, `claim_source`                                   |
| Perspectives              | `perspective`, `perspective_source_weight`                |
| PerspectiveEndorsements   | `perspective_endorsement`                                 |
| Geographies               | `geography`                                               |

---

## 8. What v0.3 deliberately does NOT do

- **Plate tectonics / continental drift.** Out of scope for v1; the time horizon (~70kya
  to present) doesn't need it. Add later as `plate_configuration` snapshots if/when you
  push back to deep time.
- **Per-individual genealogy.** This is a population-level / group-level system. Don't
  store individual family trees beyond `defining_exemplars` strings.
- **Auto-resolved consensus across Perspectives.** The system never reduces multiple
  Perspectives to a single "true" view. Aggregated confidence is per-Perspective-set,
  not global.

---

## 9. Open questions to resolve before Phase 1

1. **Blend mode visual language.** Hatched fills, opacity-stacked polygons, animated
   noise textures — what reads cleanly on a small screen?
2. **Perspective admission criteria.** Codified in the editorial policy doc; needs to be
   road-tested on contested cases (Out-of-India is an admit; Hancock-style hyperdiffusionism
   probably isn't; how about Renfrew's Anatolian hypothesis? Likely admit).
3. **Modern-trait Carriers and the survey/voting-record problem.** For
   `CARR_SF_BAY_AREA_2025` the "fraction of ideological trait X" is measurable in a way
   that ancient genetics isn't — survey data, voting patterns, donation records. Worth
   thinking about whether modern Carriers have a richer evidence vocabulary than the
   ancient ones. Probably yes; might need a `modern_evidence_type` enum on observations.
4. **Confidence math under Perspective sets.** The arithmetic in §4 is a sketch. Worked
   examples should be validated against the Indo-Aryan case before committing.

