"""
gplates.py — proxy for GPlates Web Service paleo-coastlines.

For years older than ~3 Mya, plate motion makes sea-level-on-modern-bathymetry
unreliable. GPlates (https://gws.gplates.org) returns reconstructed
coastlines as GeoJSON for a given reconstruction time and tectonic model.

The service is rate-limited and CORS-restricted, so the backend proxies and
caches responses in-process.
"""
from __future__ import annotations

import asyncio
import logging

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter()

GPLATES_BASE = "https://gws.gplates.org"
DEFAULT_MODEL = "MULLER2019"
DEEP_TIME_THRESHOLD_YEAR = -3_000_000

# (time_ma, model) -> GeoJSON dict
_cache: dict[tuple[float, str], dict] = {}
_cache_lock = asyncio.Lock()
_MAX_CACHE_SIZE = 200

logger = logging.getLogger(__name__)


def _round_time_ma(year: int) -> float:
    """Years → million-years-ago, rounded to 0.5 Ma resolution.
    GPlates reconstructions are typically computed at integer Ma; 0.5 Ma is
    plenty of resolution for visualization."""
    return round((-year) / 1_000_000 * 2) / 2


@router.get("/paleo-coastlines")
async def get_paleo_coastlines(
    year: int = Query(..., description="Year (negative; deep time only)"),
    model: str = Query(DEFAULT_MODEL, description="GPlates plate model"),
):
    """
    Returns reconstructed coastlines as GeoJSON for the given year. For years
    >= -3 Mya, returns an empty FeatureCollection (clients should use the
    sea-level + bathymetry overlay instead).
    """
    if year > DEEP_TIME_THRESHOLD_YEAR:
        return {
            "type": "FeatureCollection",
            "features": [],
            "metadata": {
                "year": year,
                "deep_time": False,
                "note": "Use sea-level overlay for years >= -3 Mya.",
            },
        }

    time_ma = _round_time_ma(year)
    if time_ma < 0:
        time_ma = 0.0

    key = (time_ma, model)
    async with _cache_lock:
        cached = _cache.get(key)
    if cached is not None:
        return cached

    url = f"{GPLATES_BASE}/reconstruct/coastlines/"
    params = {"time": time_ma, "model": model}
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0, connect=10.0)) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as e:
        logger.warning("GPlates fetch failed for %s Ma (%s): %s", time_ma, model, e)
        # Surface a soft failure so the frontend can fall back gracefully.
        raise HTTPException(
            status_code=502,
            detail=f"Upstream GPlates request failed: {e}",
        )

    if not isinstance(data, dict) or "features" not in data:
        raise HTTPException(status_code=502, detail="GPlates returned non-GeoJSON")

    data.setdefault("metadata", {})
    data["metadata"].update(
        {
            "year": year,
            "time_ma": time_ma,
            "model": model,
            "deep_time": True,
            "source": "https://gws.gplates.org",
        }
    )

    async with _cache_lock:
        if len(_cache) >= _MAX_CACHE_SIZE:
            # Drop an arbitrary entry — simple LRU isn't worth the bookkeeping
            # for a 200-entry cache that rarely fills.
            _cache.pop(next(iter(_cache)))
        _cache[key] = data
    return data
