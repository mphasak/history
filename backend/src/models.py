from __future__ import annotations
from pydantic import BaseModel
from typing import Any


class GeoPoint(BaseModel):
    lat: float
    lon: float


class Perspective(BaseModel):
    id: str
    display_name: str
    domain_scope: list[str]
    summary: str
    proponents: str | None
    methodology_notes: str
    parent_perspective_id: str | None
    default_active: bool
    status: str


class TraitMixEntry(BaseModel):
    trait_id: str
    display_name: str | None
    domain: str
    fraction: float
    stderr: float | None
    endorsement: dict | None = None


class EndorsementSummary(BaseModel):
    stance: str
    override_statement: str | None
    override_quantitative_value: Any | None
    source_weight_overrides: Any | None


class CarrierView(BaseModel):
    id: str
    display_name: str
    type: str
    date_min_year: int
    date_max_year: int
    centroid: GeoPoint | None
    archaeological_culture: str | None
    linguistic_affiliation: str | None
    trait_mix: list[TraitMixEntry]
    endorsement: EndorsementSummary | None = None
    distance_km: float | None = None
    covers_point: bool | None = None
    # extent_geojson is a GeoJSON geometry string (Polygon or MultiPolygon).
    # Falls back to a buffered circle around the centroid when no real extent
    # exists in the database. extent_is_real=true means the polygon was authored.
    extent_geojson: str | None = None
    extent_is_real: bool = False


class TraitObservationView(BaseModel):
    id: str
    carrier_id: str | None
    sample_label: str | None
    date_min_year: int | None
    date_max_year: int | None
    location: GeoPoint | None
    domain: str
    trait_id: str | None
    trait_display_name: str | None
    fraction: float | None
    stderr: float | None
    method: str | None


class PropagationEventView(BaseModel):
    id: str
    display_name: str
    domain: str
    date_min_year: int
    date_max_year: int
    mechanism: str | None
    source_point: GeoPoint | None
    destination_point: GeoPoint | None
    endorsement: EndorsementSummary | None = None


class PerspectiveWorldView(BaseModel):
    perspective_id: str
    carriers: list[CarrierView]
    propagation_events: list[PropagationEventView]


class WorldResponse(BaseModel):
    year: int
    bbox: list[float]
    perspectives: dict[str, PerspectiveWorldView]
    observations: list[TraitObservationView] = []
    # Carriers in view whose claims (about the carrier itself, its trait mixes,
    # or propagation events overlapping it) receive different stances under the
    # active perspectives. The diff-overlay uses this directly.
    disagreed_carrier_ids: list[str] = []


class WorldAtPointResponse(BaseModel):
    year: int
    query_point: GeoPoint
    perspectives: dict[str, PerspectiveWorldView]


class ClaimSourceEntry(BaseModel):
    source_id: str
    citation: str
    stance: str
    weight_override: float | None
    default_weight: float


class ClaimPerspectiveView(BaseModel):
    perspective_id: str
    stance: str
    override_statement: str | None
    override_quantitative_value: Any | None
    source_weight_overrides: Any | None
    sources: list[ClaimSourceEntry]


class ClaimResponse(BaseModel):
    id: int
    subject_type: str
    subject_id: str
    statement: str
    quantitative_value: Any | None
    default_aggregated_confidence: int | None
    perspectives: dict[str, ClaimPerspectiveView]


class CarrierThreat(BaseModel):
    """A threat (climate, war, disease, etc.) faced by a carrier in some
    year window, optionally backed by a citation via claim_id.
    """
    id: int
    threat_type: str
    display_name: str
    description: str | None
    severity: int  # 1..5
    date_min_year: int
    date_max_year: int
    sources: list[ClaimSourceEntry] = []


class CarrierThreatsResponse(BaseModel):
    carrier_id: str
    year: int | None
    threats: list[CarrierThreat]


class CarrierClaim(BaseModel):
    """A claim relevant to a carrier, with per-Perspective stance + sources.

    `subject_kind` discriminates how the claim relates to the carrier — directly
    about the carrier, about one of its trait mixes, or about a propagation
    event whose destination overlaps it. `has_disagreement` is set whenever
    stances differ across the active perspectives, and is what the diff
    overlay uses to mark a carrier as contested.
    """
    id: int
    subject_type: str
    subject_id: str
    subject_kind: str
    statement: str
    quantitative_value: Any | None = None
    default_aggregated_confidence: int | None = None
    has_disagreement: bool
    perspectives: dict[str, ClaimPerspectiveView]


class CarrierClaimsResponse(BaseModel):
    carrier_id: str
    claims: list[CarrierClaim]


class TraitRelationNode(BaseModel):
    trait_id: str
    display_name: str
    relation_type: str
    weight: float | None
    endorsement: EndorsementSummary | None = None
    parents: list[TraitRelationNode] = []


class TraitLineageResponse(BaseModel):
    trait_id: str
    display_name: str
    lineage: list[TraitRelationNode]


class TraitLineageDiffResponse(BaseModel):
    trait_id: str
    display_name: str
    perspectives: dict[str, list[TraitRelationNode]]


class CarrierTimelineSnapshot(BaseModel):
    as_of_year: int
    domain: str
    traits: list[TraitMixEntry]


class CarrierTimelineResponse(BaseModel):
    carrier_id: str
    display_name: str
    perspective_id: str
    timeline: list[CarrierTimelineSnapshot]


class CarrierPlight(BaseModel):
    """Editorial 1-2 paragraph narrative covering everyday life, origin,
    and ending for a carrier — pairs with the itemized Threats list to
    answer "what was it like to live as one of these people?".
    """
    carrier_id: str
    everyday_life: str
    origin: str | None
    ending: str | None
    source_id: str | None


class CarrierLineageNode(BaseModel):
    """A single carrier in the lineage view (focal, ancestor, or descendant).

    For multi-hop lineage, `depth` is the number of BFS hops from the focal
    (0 = focal, 1 = direct ancestor/descendant, 2 = ancestor-of-ancestor /
    descendant-of-descendant, etc.). `side` discriminates the BFS direction.
    For depth-1 entries `shared_trait_ids` are the traits bridging this
    carrier to the focal; for deeper entries it bridges this carrier to
    the *source* of the hop (the parent in the BFS tree).
    """
    id: str
    display_name: str
    type: str
    date_min_year: int
    date_max_year: int
    centroid: GeoPoint | None
    shared_trait_ids: list[str] = []
    depth: int = 0
    side: str = "focal"  # 'focal' | 'past' | 'future'


class CarrierLineageEdge(BaseModel):
    """A single (parent → child) lineage edge.

    Edges are oriented older → newer temporally regardless of the side: for
    past edges `from_id` is the older ancestor and `to_id` is the newer
    source carrier; for future edges `from_id` is the older source and
    `to_id` is the newer descendant. The frontend uses this to lay out the
    DAG in time without inferring direction from coordinates.
    """
    from_id: str
    to_id: str
    side: str  # 'past' | 'future'
    shared_trait_ids: list[str] = []


class CarrierLineageResponse(BaseModel):
    """Multi-hop lineage DAG for a focal carrier.

    `nodes` and `edges` describe the full BFS tree (up to `max_depth` hops
    from the focal, capped per-hop by `max_per_hop`). `ancestors` /
    `descendants` are kept for backward compatibility — they're depth-1
    direct neighbors, equivalent to the original single-hop response.
    """
    carrier_id: str
    year: int
    direction: str
    max_depth: int
    focal: CarrierLineageNode | None
    nodes: list[CarrierLineageNode] = []
    edges: list[CarrierLineageEdge] = []
    ancestors: list[CarrierLineageNode]
    descendants: list[CarrierLineageNode]


class PaleoBasemapResponse(BaseModel):
    year: int
    sea_level_meters: float | None
    temp_anomaly_c: float | None
    physical_features: list[dict]
