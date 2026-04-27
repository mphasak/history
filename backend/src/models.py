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


class PaleoBasemapResponse(BaseModel):
    year: int
    sea_level_meters: float | None
    temp_anomaly_c: float | None
    physical_features: list[dict]
