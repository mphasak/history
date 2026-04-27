from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import TraitLineageResponse, TraitLineageDiffResponse, TraitRelationNode
from ..resolver import resolve_trait_lineage

router = APIRouter()


def _build_nodes(raw: list[dict]) -> list[TraitRelationNode]:
    return [
        TraitRelationNode(
            trait_id=n["trait_id"],
            display_name=n["display_name"],
            relation_type=n["relation_type"],
            weight=n.get("weight"),
            endorsement=n.get("endorsement"),
            parents=_build_nodes(n.get("parents", [])),
        )
        for n in raw
    ]


@router.get("/trait/{trait_id}/lineage", response_model=TraitLineageResponse)
async def get_trait_lineage(
    trait_id: str,
    perspective: str = Query(..., description="Single perspective ID"),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute("SELECT id, display_name FROM trait WHERE id = %s", (trait_id,))
    trait = await row.fetchone()
    if not trait:
        raise HTTPException(404, f"Trait {trait_id!r} not found")

    lineage = await resolve_trait_lineage(conn, trait_id, perspective)
    return TraitLineageResponse(
        trait_id=trait_id,
        display_name=trait["display_name"],
        lineage=_build_nodes(lineage),
    )


@router.get("/trait/{trait_id}/lineage-diff", response_model=TraitLineageDiffResponse)
async def get_trait_lineage_diff(
    trait_id: str,
    perspectives: str = Query(..., description="Comma-separated perspective IDs"),
    conn: AsyncConnection = Depends(get_conn),
):
    row = await conn.execute("SELECT id, display_name FROM trait WHERE id = %s", (trait_id,))
    trait = await row.fetchone()
    if not trait:
        raise HTTPException(404, f"Trait {trait_id!r} not found")

    persp_ids = [p.strip() for p in perspectives.split(",") if p.strip()]
    per_persp: dict[str, list[TraitRelationNode]] = {}
    for pid in persp_ids:
        lineage = await resolve_trait_lineage(conn, trait_id, pid)
        per_persp[pid] = _build_nodes(lineage)

    return TraitLineageDiffResponse(
        trait_id=trait_id,
        display_name=trait["display_name"],
        perspectives=per_persp,
    )
