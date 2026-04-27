from fastapi import APIRouter, Depends, Query
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import PaleoBasemapResponse

router = APIRouter()


@router.get("/paleo-basemap", response_model=PaleoBasemapResponse)
async def get_paleo_basemap(
    year: int = Query(..., description="Year (negative = BCE)"),
    perspective: str | None = Query(None, description="Perspective ID"),
    conn: AsyncConnection = Depends(get_conn),
):
    # Fetch the closest paleoclimate state at or before year (global scope)
    climate_row = await conn.execute(
        """
        SELECT sea_level_meters, temp_anomaly_c
        FROM paleoclimate_state
        WHERE scope = 'global' AND year <= %(year)s
        ORDER BY ABS(year - %(year)s)
        LIMIT 1
        """,
        {"year": year},
    )
    climate = await climate_row.fetchone()

    # Fetch physical feature snapshots valid at or before year.
    # For each feature we want the most recent snapshot (the latest stored
    # frame). A NULL geometry signals "feature has disappeared" — we still
    # return the row so clients can stop rendering it.
    feat_rows = await conn.execute(
        """
        SELECT DISTINCT ON (pfs.feature_id)
               pf.id, pf.type, pf.display_name,
               pfs.as_of_year,
               ST_Y(pfs.centroid::geometry) AS lat,
               ST_X(pfs.centroid::geometry) AS lon,
               ST_AsGeoJSON(pfs.geometry::geometry) AS geometry_geojson
        FROM physical_feature_snapshot pfs
        JOIN physical_feature pf ON pf.id = pfs.feature_id
        WHERE pfs.as_of_year <= %(year)s
        ORDER BY pfs.feature_id, pfs.as_of_year DESC
        """,
        {"year": year},
    )

    features = []
    async for r in feat_rows:
        r = dict(r)
        features.append({
            "id": r["id"],
            "type": r["type"],
            "display_name": r["display_name"],
            "as_of_year": r["as_of_year"],
            "centroid": {"lat": r["lat"], "lon": r["lon"]} if r["lat"] is not None else None,
            "geometry_geojson": r.get("geometry_geojson"),
        })

    return PaleoBasemapResponse(
        year=year,
        sea_level_meters=climate["sea_level_meters"] if climate else None,
        temp_anomaly_c=climate["temp_anomaly_c"] if climate else None,
        physical_features=features,
    )
