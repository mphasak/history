"""
places.py — historical place labels filtered by year.

The frontend's "Historical" label mode swaps the modern OSM labels out
for these so the map shows era-appropriate names (Constantinople vs
Istanbul, Tenochtitlan vs Mexico City, etc.).
"""
from fastapi import APIRouter, Depends, Query
from psycopg import AsyncConnection
from pydantic import BaseModel

from ..db import get_conn
from ..models import GeoPoint

router = APIRouter()


class HistoricalPlace(BaseModel):
    id: str
    display_name: str
    centroid: GeoPoint
    date_min_year: int
    date_max_year: int
    kind: str | None
    description: str | None


class HistoricalPlacesResponse(BaseModel):
    year: int
    places: list[HistoricalPlace]


@router.get("/historical-places", response_model=HistoricalPlacesResponse)
async def get_historical_places(
    year: int = Query(..., description="Year (negative = BCE, no year 0)"),
    conn: AsyncConnection = Depends(get_conn),
):
    rows = await conn.execute(
        """
        SELECT id, display_name,
               ST_Y(centroid::geometry) AS lat,
               ST_X(centroid::geometry) AS lon,
               date_min_year, date_max_year, kind, description
        FROM historical_place
        WHERE date_min_year <= %(y)s AND date_max_year >= %(y)s
        ORDER BY kind, display_name
        """,
        {"y": year},
    )
    places = []
    async for r in rows:
        places.append(
            HistoricalPlace(
                id=r["id"],
                display_name=r["display_name"],
                centroid=GeoPoint(lat=r["lat"], lon=r["lon"]),
                date_min_year=r["date_min_year"],
                date_max_year=r["date_max_year"],
                kind=r.get("kind"),
                description=r.get("description"),
            )
        )
    return HistoricalPlacesResponse(year=year, places=places)
