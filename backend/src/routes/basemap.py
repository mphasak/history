from fastapi import APIRouter, Depends, Query
from psycopg import AsyncConnection

from ..db import get_conn
from ..models import PaleoBasemapResponse

router = APIRouter()


_GAP_EXTRAPOLATION_FLOOR_YEAR = -3_000_000


async def _resolve_climate(conn: AsyncConnection, year: int) -> dict | None:
    """
    Linear-interpolate sea level and temperature anomaly between bracketing
    paleoclimate_state keyframes.

    Sea level varies continuously, so a "nearest at-or-before" lookup over a
    handful of keyframes produces visible discontinuities (e.g. -89 ka snapping
    to the Eemian +6 m peak). Interpolating between the two surrounding
    keyframes gives smooth shelf-band transitions as the slider moves.

    Beyond the oldest keyframe (currently -300 ka) we hold its value constant
    out to -3 Mya, where GPlates takes over. Past -3 Mya we return None so
    the deep-time path stays the source of truth.
    """
    if year < _GAP_EXTRAPOLATION_FLOOR_YEAR:
        return None

    # Pull the bracketing keyframes in a single round-trip.
    rows_q = await conn.execute(
        """
        WITH before AS (
            SELECT year, sea_level_meters, temp_anomaly_c
            FROM paleoclimate_state
            WHERE scope = 'global' AND year <= %(year)s
            ORDER BY year DESC
            LIMIT 1
        ),
        after AS (
            SELECT year, sea_level_meters, temp_anomaly_c
            FROM paleoclimate_state
            WHERE scope = 'global' AND year >= %(year)s
            ORDER BY year ASC
            LIMIT 1
        )
        SELECT 'before' AS pos, year, sea_level_meters, temp_anomaly_c FROM before
        UNION ALL
        SELECT 'after'  AS pos, year, sea_level_meters, temp_anomaly_c FROM after
        """,
        {"year": year},
    )
    rows = {r["pos"]: r async for r in rows_q}
    before, after = rows.get("before"), rows.get("after")

    if before is None and after is None:
        return None
    if before is None:
        # Younger than newest keyframe (shouldn't happen — present is at year 0
        # — but stay defensive).
        return {"sea_level_meters": after["sea_level_meters"],
                "temp_anomaly_c": after["temp_anomaly_c"]}
    if after is None:
        # Older than oldest keyframe; extrapolate by holding the oldest value
        # so the gap between the last keyframe and the GPlates threshold
        # still shows a plausible shelf.
        return {"sea_level_meters": before["sea_level_meters"],
                "temp_anomaly_c": before["temp_anomaly_c"]}
    if before["year"] == after["year"]:
        return {"sea_level_meters": before["sea_level_meters"],
                "temp_anomaly_c": before["temp_anomaly_c"]}

    span = after["year"] - before["year"]
    t = (year - before["year"]) / span  # 0 at `before`, 1 at `after`

    def lerp(a, b):
        if a is None or b is None:
            return a if a is not None else b
        return float(a) + t * (float(b) - float(a))

    return {
        "sea_level_meters": lerp(before["sea_level_meters"], after["sea_level_meters"]),
        "temp_anomaly_c":   lerp(before["temp_anomaly_c"],   after["temp_anomaly_c"]),
    }


@router.get("/paleo-basemap", response_model=PaleoBasemapResponse)
async def get_paleo_basemap(
    year: int = Query(..., description="Year (negative = BCE)"),
    perspective: str | None = Query(None, description="Perspective ID"),
    conn: AsyncConnection = Depends(get_conn),
):
    climate = await _resolve_climate(conn, year)

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
