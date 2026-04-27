from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import ClaimResponse, ClaimPerspectiveView, ClaimSourceEntry
from ..resolver import resolve_claim

router = APIRouter()


@router.get("/claim/{claim_id}", response_model=ClaimResponse)
async def get_claim(
    claim_id: int,
    perspectives: str | None = Query(None, description="Comma-separated perspective IDs"),
    conn: AsyncConnection = Depends(get_conn),
):
    persp_ids = [p.strip() for p in perspectives.split(",") if p.strip()] if perspectives else []

    # Verify claim exists
    row = await conn.execute("SELECT id FROM claim WHERE id = %s", (claim_id,))
    if not await row.fetchone():
        raise HTTPException(404, f"Claim {claim_id} not found")

    raw = await resolve_claim(conn, claim_id, persp_ids)

    persp_views = {}
    for pid, pv in raw["perspectives"].items():
        sources = [
            ClaimSourceEntry(
                source_id=s["source_id"],
                citation=s["citation"],
                stance=s["stance"],
                weight_override=s.get("weight_override"),
                default_weight=s["default_weight"],
            )
            for s in pv["sources"]
        ]
        persp_views[pid] = ClaimPerspectiveView(
            perspective_id=pid,
            stance=pv["stance"],
            override_statement=pv.get("override_statement"),
            override_quantitative_value=pv.get("override_quantitative_value"),
            source_weight_overrides=pv.get("source_weight_overrides"),
            sources=sources,
        )

    return ClaimResponse(
        id=raw["id"],
        subject_type=raw["subject_type"],
        subject_id=raw["subject_id"],
        statement=raw["statement"],
        quantitative_value=raw.get("quantitative_value"),
        default_aggregated_confidence=raw.get("default_aggregated_confidence"),
        perspectives=persp_views,
    )
