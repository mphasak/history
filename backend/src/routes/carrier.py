from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import (
    CarrierTimelineResponse,
    CarrierTimelineSnapshot,
    TraitMixEntry,
    CarrierClaimsResponse,
    CarrierClaim,
    ClaimPerspectiveView,
    ClaimSourceEntry,
    CarrierThreatsResponse,
    CarrierThreat,
    CarrierLineageResponse,
    CarrierLineageNode,
    CarrierLineageEdge,
    GeoPoint,
)
from ..resolver import (
    resolve_carrier_timeline,
    resolve_carrier_claims,
    resolve_carrier_threats,
    resolve_carrier_lineage,
)

router = APIRouter()


@router.get("/carrier/{carrier_id}/timeline", response_model=CarrierTimelineResponse)
async def get_carrier_timeline(
    carrier_id: str,
    perspective: str = Query(..., description="Single perspective ID"),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute(
        "SELECT id, display_name FROM carrier WHERE id = %s", (carrier_id,)
    )
    carrier = await row.fetchone()
    if not carrier:
        raise HTTPException(404, f"Carrier {carrier_id!r} not found")

    snapshots_raw = await resolve_carrier_timeline(conn, carrier_id, perspective)

    snapshots = [
        CarrierTimelineSnapshot(
            as_of_year=s["as_of_year"],
            domain=s["domain"],
            traits=[
                TraitMixEntry(
                    trait_id=t["trait_id"],
                    display_name=t.get("display_name"),
                    domain=t["domain"],
                    fraction=t["fraction"],
                    stderr=t.get("stderr"),
                    endorsement=t.get("endorsement"),
                )
                for t in s["traits"]
            ],
        )
        for s in snapshots_raw
    ]

    return CarrierTimelineResponse(
        carrier_id=carrier_id,
        display_name=carrier["display_name"],
        perspective_id=perspective,
        timeline=snapshots,
    )


@router.get("/carrier/{carrier_id}/claims", response_model=CarrierClaimsResponse)
async def get_carrier_claims(
    carrier_id: str,
    perspectives: str | None = Query(None, description="Comma-separated perspective IDs"),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute("SELECT id FROM carrier WHERE id = %s", (carrier_id,))
    if not await row.fetchone():
        raise HTTPException(404, f"Carrier {carrier_id!r} not found")

    persp_ids = [p.strip() for p in perspectives.split(",") if p.strip()] if perspectives else []
    raw = await resolve_carrier_claims(conn, carrier_id, persp_ids)

    claims = []
    for c in raw:
        persp_views = {
            pid: ClaimPerspectiveView(
                perspective_id=pid,
                stance=pv["stance"],
                override_statement=pv.get("override_statement"),
                override_quantitative_value=pv.get("override_quantitative_value"),
                source_weight_overrides=pv.get("source_weight_overrides"),
                sources=[
                    ClaimSourceEntry(
                        source_id=s["source_id"],
                        citation=s["citation"],
                        stance=s["stance"],
                        weight_override=s.get("weight_override"),
                        default_weight=s["default_weight"],
                    )
                    for s in pv["sources"]
                ],
            )
            for pid, pv in c["perspectives"].items()
        }
        claims.append(
            CarrierClaim(
                id=c["id"],
                subject_type=c["subject_type"],
                subject_id=c["subject_id"],
                subject_kind=c["subject_kind"],
                statement=c["statement"],
                quantitative_value=c.get("quantitative_value"),
                default_aggregated_confidence=c.get("default_aggregated_confidence"),
                has_disagreement=bool(c.get("has_disagreement")),
                perspectives=persp_views,
            )
        )

    return CarrierClaimsResponse(carrier_id=carrier_id, claims=claims)


@router.get("/carrier/{carrier_id}/threats", response_model=CarrierThreatsResponse)
async def get_carrier_threats(
    carrier_id: str,
    year: int | None = Query(
        None,
        description="If set, only threats whose year window covers this year are returned.",
    ),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute("SELECT id FROM carrier WHERE id = %s", (carrier_id,))
    if not await row.fetchone():
        raise HTTPException(404, f"Carrier {carrier_id!r} not found")

    raw = await resolve_carrier_threats(conn, carrier_id, year)
    threats = [
        CarrierThreat(
            id=t["id"],
            threat_type=t["threat_type"],
            display_name=t["display_name"],
            description=t.get("description"),
            severity=int(t["severity"]),
            date_min_year=t["date_min_year"],
            date_max_year=t["date_max_year"],
            sources=[
                ClaimSourceEntry(
                    source_id=s["source_id"],
                    citation=s["citation"],
                    stance=s["stance"],
                    weight_override=s.get("weight_override"),
                    default_weight=s["default_weight"],
                )
                for s in t.get("sources", [])
            ],
        )
        for t in raw
    ]
    return CarrierThreatsResponse(
        carrier_id=carrier_id, year=year, threats=threats
    )


@router.get("/carrier/{carrier_id}/lineage", response_model=CarrierLineageResponse)
async def get_carrier_lineage(
    carrier_id: str,
    year: int = Query(..., description="Year of focus (negative = BCE)."),
    direction: str = Query(
        "both", description="Which side(s) to return: past | future | both."
    ),
    limit_per_side: int = Query(12, ge=1, le=50),
    max_depth: int = Query(
        4, ge=1, le=8,
        description="Hops to expand the BFS — 1 is direct ancestors/descendants, 4+ traces back through multiple feeder populations.",
    ),
    max_per_hop: int = Query(
        6, ge=1, le=12,
        description="Max new neighbors per source carrier per hop (caps graph fan-out).",
    ),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute("SELECT id FROM carrier WHERE id = %s", (carrier_id,))
    if not await row.fetchone():
        raise HTTPException(404, f"Carrier {carrier_id!r} not found")
    if direction.lower() not in {"past", "future", "both"}:
        raise HTTPException(400, "direction must be past|future|both")

    raw = await resolve_carrier_lineage(
        conn, carrier_id, year,
        direction=direction.lower(),
        limit_per_side=limit_per_side,
        max_depth=max_depth,
        max_per_hop=max_per_hop,
    )

    def _node(n: dict) -> CarrierLineageNode:
        return CarrierLineageNode(
            id=n["id"],
            display_name=n["display_name"],
            type=n["type"],
            date_min_year=n["date_min_year"],
            date_max_year=n["date_max_year"],
            centroid=GeoPoint(**n["centroid"]) if n.get("centroid") else None,
            shared_trait_ids=n.get("shared_trait_ids") or [],
            depth=int(n.get("depth", 0)),
            side=n.get("side", "focal"),
        )

    def _edge(e: dict) -> CarrierLineageEdge:
        return CarrierLineageEdge(
            from_id=e["from_id"],
            to_id=e["to_id"],
            side=e["side"],
            shared_trait_ids=e.get("shared_trait_ids") or [],
        )

    return CarrierLineageResponse(
        carrier_id=carrier_id,
        year=year,
        direction=direction.lower(),
        max_depth=int(raw.get("max_depth", max_depth)),
        focal=_node(raw["focal"]) if raw.get("focal") else None,
        nodes=[_node(n) for n in raw.get("nodes", [])],
        edges=[_edge(e) for e in raw.get("edges", [])],
        ancestors=[_node(n) for n in raw.get("ancestors", [])],
        descendants=[_node(n) for n in raw.get("descendants", [])],
    )
