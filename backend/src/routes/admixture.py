"""
admixture.py — endpoints for the admixture-event headline feature.

The admixture timeline + on-map glow is the "drama" view: which ghost
populations met, when, where, and how violently. See db/025 for the
schema and seed.
"""
from fastapi import APIRouter, Depends, Query
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import AdmixtureEvent, AdmixtureEventsResponse, GeoPoint

router = APIRouter()


@router.get("/admixture-events", response_model=AdmixtureEventsResponse)
async def list_admixture_events(
    year: int | None = Query(
        None,
        description="If provided, only events whose [year_min, year_max] window covers this year.",
    ),
    bbox: str | None = Query(
        None,
        description="Optional W,S,E,N bbox. If set, filter events by centroid containment.",
    ),
    conn: AsyncConnection = Depends(get_conn),
):
    """
    All admixture events, optionally filtered by year (window-overlap) and
    bbox (centroid containment). The frontend timeline renders the full
    list and lets the user scrub; the map glow uses the year-filtered
    subset.
    """
    where = []
    params: dict = {}
    if year is not None:
        where.append("year_min <= %(year)s AND year_max >= %(year)s")
        params["year"] = year
    if bbox:
        try:
            w, s, e, n = (float(x.strip()) for x in bbox.split(","))
        except ValueError:
            pass
        else:
            where.append(
                "ST_Y(centroid::geometry) BETWEEN %(s)s AND %(n)s "
                "AND ST_X(centroid::geometry) BETWEEN %(w)s AND %(e)s"
            )
            params.update({"w": w, "s": s, "e": e, "n": n})
    where_clause = (" WHERE " + " AND ".join(where)) if where else ""

    rows = await conn.execute(
        f"""
        SELECT id, display_name, year_min, year_max,
               ST_Y(centroid::geometry) AS lat,
               ST_X(centroid::geometry) AS lon,
               description, parent_traits, result_traits,
               parent_carriers, result_carriers,
               severity, rupture_kind, source_id
        FROM admixture_event
        {where_clause}
        ORDER BY year_min, severity DESC
        """,
        params,
    )
    events = []
    async for r in rows:
        r = dict(r)
        events.append(AdmixtureEvent(
            id=r["id"],
            display_name=r["display_name"],
            year_min=r["year_min"],
            year_max=r["year_max"],
            centroid=GeoPoint(lat=float(r["lat"]), lon=float(r["lon"])),
            description=r["description"],
            parent_traits=list(r.get("parent_traits") or []),
            result_traits=list(r.get("result_traits") or []),
            parent_carriers=list(r.get("parent_carriers") or []),
            result_carriers=list(r.get("result_carriers") or []),
            severity=r["severity"],
            rupture_kind=r["rupture_kind"],
            source_id=r.get("source_id"),
        ))
    return AdmixtureEventsResponse(events=events)
