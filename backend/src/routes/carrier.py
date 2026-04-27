from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import CarrierTimelineResponse, CarrierTimelineSnapshot, TraitMixEntry
from ..resolver import resolve_carrier_timeline

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
