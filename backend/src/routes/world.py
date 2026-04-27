from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import WorldResponse, PerspectiveWorldView, CarrierView, PropagationEventView, TraitMixEntry, GeoPoint, EndorsementSummary
from ..resolver import resolve_world

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

    persp_views = {}
    for pid, view in raw.items():
        carriers = [_build_carrier_view(c) for c in view["carriers"]]
        props = [_build_prop_view(p) for p in view["propagation_events"]]
        persp_views[pid] = PerspectiveWorldView(
            perspective_id=pid,
            carriers=carriers,
            propagation_events=props,
        )

    return WorldResponse(year=year, bbox=bbox_list, perspectives=persp_views)
