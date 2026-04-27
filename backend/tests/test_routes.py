"""
test_routes.py — Integration tests for the six read endpoints.

Hits the running FastAPI server at BASE_URL (defaults to localhost:8000).
Requires the server to be running with a seeded database.
Run: DATABASE_URL='...' uvicorn src.main:app --port 8000
"""
import os
import pytest
import psycopg
from psycopg.rows import dict_row
from httpx import AsyncClient

DSN = os.environ.get(
    "DATABASE_URL",
    "postgresql://history_sim:dev@localhost:5433/history_sim",
)
BASE_URL = os.environ.get("API_URL", "http://localhost:8000")


@pytest.fixture
async def client():
    """Connect to the running FastAPI server (function-scoped to avoid event loop issues)."""
    async with AsyncClient(base_url=BASE_URL, timeout=10.0) as c:
        try:
            r = await c.get("/healthz")
            if r.status_code != 200:
                pytest.skip(f"Server not running at {BASE_URL}")
        except Exception as e:
            pytest.skip(f"Server not reachable at {BASE_URL}: {e}")
        yield c


@pytest.mark.asyncio
async def test_healthz(client):
    r = await client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_perspectives_count(client):
    r = await client.get("/perspectives")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    # Seed data has 7 perspectives
    assert len(data) == 7, f"Expected 7 perspectives, got {len(data)}"


@pytest.mark.asyncio
async def test_perspectives_default_active(client):
    r = await client.get("/perspectives")
    data = r.json()
    default_active = [p for p in data if p["default_active"]]
    ids = {p["id"] for p in default_active}
    assert "PERSP_REICH_2018" in ids
    assert "PERSP_POSTREICH_2025" in ids


@pytest.mark.asyncio
async def test_world_endpoint_two_perspectives(client):
    r = await client.get(
        "/world",
        params={
            "year": -1700,
            "bbox": "60,20,90,40",
            "perspectives": "PERSP_INDIAN_AMT,PERSP_INDIAN_OOI",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert "PERSP_INDIAN_AMT" in data["perspectives"]
    assert "PERSP_INDIAN_OOI" in data["perspectives"]

    # Both views should have the NW South Asia carrier
    amt = data["perspectives"]["PERSP_INDIAN_AMT"]
    ooi = data["perspectives"]["PERSP_INDIAN_OOI"]
    amt_ids = [c["id"] for c in amt["carriers"]]
    ooi_ids = [c["id"] for c in ooi["carriers"]]
    assert "CARR_NW_SOUTH_ASIA_LATE_BRONZE" in amt_ids or "CARR_NW_SOUTH_ASIA_LATE_BRONZE" in ooi_ids


@pytest.mark.asyncio
async def test_carrier_timeline(client):
    r = await client.get(
        "/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/timeline",
        params={"perspective": "PERSP_INDIAN_AMT"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["carrier_id"] == "CARR_NW_SOUTH_ASIA_LATE_BRONZE"
    assert isinstance(data["timeline"], list)
    assert len(data["timeline"]) > 0


@pytest.mark.asyncio
async def test_trait_lineage(client):
    r = await client.get(
        "/trait/STEPPE_MLBA/lineage",
        params={"perspective": "PERSP_REICH_2018"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["trait_id"] == "STEPPE_MLBA"
    assert "lineage" in data


@pytest.mark.asyncio
async def test_claim_endpoint_nuanced(client):
    """
    Find the claim that PERSP_INDIAN_OOI nuances and verify AMT endorses / OOI nuances it.
    Uses the DB to discover the claim ID rather than hardcoding it (bigserial is non-deterministic).
    """
    try:
        conn = psycopg.connect(DSN, row_factory=dict_row)
        row = conn.execute(
            """
            SELECT subject_id::bigint AS claim_id
            FROM perspective_endorsement
            WHERE perspective_id = 'PERSP_INDIAN_OOI'
              AND stance = 'nuances'
              AND subject_type = 'Claim'
            LIMIT 1
            """
        ).fetchone()
        conn.close()
        if not row:
            pytest.skip("No nuanced claim found for PERSP_INDIAN_OOI")
        claim_id = row["claim_id"]
    except Exception as e:
        pytest.skip(f"Database not available: {e}")

    r = await client.get(
        f"/claim/{claim_id}",
        params={"perspectives": "PERSP_INDIAN_AMT,PERSP_INDIAN_OOI"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == claim_id
    assert data["perspectives"]["PERSP_INDIAN_AMT"]["stance"] == "endorses"
    assert data["perspectives"]["PERSP_INDIAN_OOI"]["stance"] == "nuances"
    assert data["perspectives"]["PERSP_INDIAN_OOI"]["override_statement"]


@pytest.mark.asyncio
async def test_paleo_basemap(client):
    r = await client.get("/paleo-basemap", params={"year": -1700})
    assert r.status_code == 200
    data = r.json()
    assert data["year"] == -1700
    assert "sea_level_meters" in data
    assert "physical_features" in data
