from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import (
    WorldResponse,
    WorldAtPointResponse,
    PerspectiveWorldView,
    CarrierView,
    PropagationEventView,
    TraitMixEntry,
    GeoPoint,
    EndorsementSummary,
    TraitObservationView,
)
from ..resolver import resolve_world, resolve_world_at_point

router = APIRouter()


def _parse_bbox(bbox_str: str) -> list[float]:
    try:
        parts = [float(x.strip()) for x in bbox_str.split(",")]
        if len(parts) != 4:
            raise ValueError
        return parts
    except ValueError:
        raise HTTPException(400, "bbox must be W,S,E,N (four floats)")


def _parse_perspectives(p: str | None) -> list[str]:
    if not p:
        return []
    return [x.strip() for x in p.split(",") if x.strip()]


def _build_carrier_view(c: dict) -> CarrierView:
    centroid = GeoPoint(**c["centroid"]) if c.get("centroid") else None
    end = EndorsementSummary(**c["endorsement"]) if c.get("endorsement") else None
    mix = [
        TraitMixEntry(
            trait_id=m["trait_id"],
            display_name=m.get("display_name"),
            domain=m["domain"],
            fraction=m["fraction"],
            stderr=m.get("stderr"),
            endorsement=m.get("endorsement"),
        )
        for m in c.get("trait_mix", [])
    ]
    return CarrierView(
        id=c["id"],
        display_name=c["display_name"],
        type=c["type"],
        date_min_year=c["date_min_year"],
        date_max_year=c["date_max_year"],
        centroid=centroid,
        archaeological_culture=c.get("archaeological_culture"),
        linguistic_affiliation=c.get("linguistic_affiliation"),
        trait_mix=mix,
        endorsement=end,
        distance_km=c.get("distance_km"),
        covers_point=c.get("covers_point"),
        extent_geojson=c.get("extent_geojson"),
        extent_is_real=bool(c.get("extent_is_real")),
    )


def _build_observation_view(o: dict) -> TraitObservationView:
    loc = GeoPoint(**o["location"]) if o.get("location") else None
    return TraitObservationView(
        id=o["id"],
        carrier_id=o.get("carrier_id"),
        sample_label=o.get("sample_label"),
        date_min_year=o.get("date_min_year"),
        date_max_year=o.get("date_max_year"),
        location=loc,
        domain=o["domain"],
        trait_id=o.get("trait_id"),
        trait_display_name=o.get("trait_display_name"),
        fraction=o.get("fraction"),
        stderr=o.get("stderr"),
        method=o.get("method"),
    )


def _build_prop_view(p: dict) -> PropagationEventView:
    src = GeoPoint(**p["source_point"]) if p.get("source_point") else None
    dst = GeoPoint(**p["destination_point"]) if p.get("destination_point") else None
    end = EndorsementSummary(**p["endorsement"]) if p.get("endorsement") else None
    return PropagationEventView(
        id=p["id"],
        display_name=p["display_name"],
        domain=p["domain"],
        date_min_year=p["date_min_year"],
        date_max_year=p["date_max_year"],
        mechanism=p.get("mechanism"),
        source_point=src,
        destination_point=dst,
        endorsement=end,
    )


@router.get("/world", response_model=WorldResponse)
async def get_world(
    year: int = Query(..., description="Year (negative = BCE, no year 0)"),
    bbox: str = Query(..., description="W,S,E,N bounding box"),
    perspectives: str | None = Query(None, description="Comma-separated perspective IDs"),
    conn: AsyncConnection = Depends(get_conn),
):
    bbox_list = _parse_bbox(bbox)
    perspective_ids = _parse_perspectives(perspectives)

    raw = await resolve_world(conn, year, bbox_list, perspective_ids)

    observations_raw = raw.pop("_observations", [])
    disagreed_carrier_ids = raw.pop("_disagreed_carrier_ids", [])
    persp_views = {}
    for pid, view in raw.items():
        if pid.startswith("_"):
            continue
        carriers = [_build_carrier_view(c) for c in view["carriers"]]
        props = [_build_prop_view(p) for p in view["propagation_events"]]
        persp_views[pid] = PerspectiveWorldView(
            perspective_id=pid,
            carriers=carriers,
            propagation_events=props,
        )

    observations = [_build_observation_view(o) for o in observations_raw]
    return WorldResponse(
        year=year,
        bbox=bbox_list,
        perspectives=persp_views,
        observations=observations,
        disagreed_carrier_ids=disagreed_carrier_ids,
    )


@router.get("/world/at", response_model=WorldAtPointResponse)
async def get_world_at(
    year: int = Query(..., description="Year (negative = BCE, no year 0)"),
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    perspectives: str | None = Query(None, description="Comma-separated perspective IDs"),
    limit: int = Query(5, ge=1, le=20),
    conn: AsyncConnection = Depends(get_conn),
):
    perspective_ids = _parse_perspectives(perspectives)
    raw = await resolve_world_at_point(conn, year, lat, lon, perspective_ids, limit=limit)
    persp_views = {}
    for pid, view in raw.items():
        carriers = [_build_carrier_view(c) for c in view["carriers"]]
        persp_views[pid] = PerspectiveWorldView(
            perspective_id=pid,
            carriers=carriers,
            propagation_events=[],
        )
    return WorldAtPointResponse(
        year=year,
        query_point=GeoPoint(lat=lat, lon=lon),
        perspectives=persp_views,
    )
