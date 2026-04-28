"""
test_routes.py — Integration tests for the six read endpoints.

Hits the running FastAPI server at BASE_URL (defaults to localhost:8000).
Requires the server to be running with a seeded database.
Run: DATABASE_URL='...' uvicorn src.main:app --port 8000
"""
import os
import pytest
import pytest_asyncio
import psycopg
from psycopg.rows import dict_row
from httpx import AsyncClient

DSN = os.environ.get(
    "DATABASE_URL",
    "postgresql://history_sim:dev@localhost:5433/history_sim",
)
BASE_URL = os.environ.get("API_URL", "http://localhost:8000")


@pytest_asyncio.fixture
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


@pytest.mark.asyncio
async def test_world_disagreed_carrier_ids_indo_aryan(client):
    """
    /world surfaces disagreed_carrier_ids — the diff overlay reads this
    directly. The Indo-Aryan carrier must be flagged when AMT+OOI are active.
    """
    r = await client.get(
        "/world",
        params={
            "year": -1700,
            "bbox": "-180,-85,180,85",
            "perspectives": "PERSP_INDIAN_AMT,PERSP_INDIAN_OOI",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert "CARR_NW_SOUTH_ASIA_LATE_BRONZE" in data.get("disagreed_carrier_ids", []), (
        "Diff overlay would not mark the disputed Indo-Aryan carrier — "
        f"got disagreed={data.get('disagreed_carrier_ids')}"
    )


@pytest.mark.asyncio
async def test_carrier_claims_endpoint_indo_aryan(client):
    """
    /carrier/{id}/claims returns the Steppe migration claim with AMT endorses /
    OOI nuances and the OOI override statement attached.
    """
    r = await client.get(
        "/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/claims",
        params={"perspectives": "PERSP_INDIAN_AMT,PERSP_INDIAN_OOI"},
    )
    assert r.status_code == 200
    data = r.json()
    contested = [c for c in data["claims"] if c["has_disagreement"]]
    assert contested, "Expected at least one disputed claim for NW South Asia"

    steppe = next(
        (c for c in contested if c["subject_kind"] == "propagation_event"), None
    )
    assert steppe is not None
    assert steppe["perspectives"]["PERSP_INDIAN_AMT"]["stance"] == "endorses"
    assert steppe["perspectives"]["PERSP_INDIAN_OOI"]["stance"] == "nuances"
    assert steppe["perspectives"]["PERSP_INDIAN_OOI"]["override_statement"]


@pytest.mark.asyncio
async def test_carrier_claims_endpoint_roman_provenance(client):
    """
    Romans get an [AUTO-PROVENANCE] claim citing Antonio 2019 from the 006
    seed. Verify the route surfaces it.
    """
    r = await client.get(
        "/carrier/CARR_HIST_ROMAN/claims",
        params={"perspectives": "PERSP_REICH_2018"},
    )
    if r.status_code == 404:
        pytest.skip("CARR_HIST_ROMAN missing — historical-carriers seed not applied")
    assert r.status_code == 200
    data = r.json()
    sources = [
        s["source_id"]
        for c in data["claims"]
        if c["subject_kind"] == "carrier"
        for pv in c["perspectives"].values()
        for s in pv["sources"]
    ]
    assert "ANTONIO_2019" in sources, f"Expected ANTONIO_2019 cite for Romans; got {sources}"


@pytest.mark.asyncio
async def test_carrier_threats_endpoint_filters_by_year(client):
    """
    /carrier/{id}/threats?year=Y returns only threats whose date window
    covers Y. Romans face the Antonine + Cyprian plagues at year=200.
    """
    r = await client.get(
        "/carrier/CARR_HIST_ROMAN/threats", params={"year": 200}
    )
    if r.status_code == 404:
        pytest.skip("CARR_HIST_ROMAN missing — historical-carriers seed not applied")
    assert r.status_code == 200
    data = r.json()
    if not data["threats"]:
        pytest.skip("No threats seeded — 007 seed not applied")
    types = {t["threat_type"] for t in data["threats"]}
    assert "disease" in types, (
        f"Expected disease threat at year 200; got types={types}"
    )

    # At year 0 the disease window (165-270) should NOT match.
    r2 = await client.get(
        "/carrier/CARR_HIST_ROMAN/threats", params={"year": 0}
    )
    assert r2.status_code == 200
    types2 = {t["threat_type"] for t in r2.json()["threats"]}
    assert "disease" not in types2, (
        f"Year 0 is before the plague window; expected no disease threat, got {types2}"
    )


@pytest.mark.asyncio
async def test_world_carrier_count_grows_with_historical_seed(client):
    """
    The 005 seed adds historical/ethnolinguistic carriers across the Holocene.
    At 0 CE we expect well more than the spreadsheet's 3 active carriers
    (the Holocene was previously empty); now we should see double-digits.
    """
    r = await client.get(
        "/world",
        params={
            "year": 0,
            "bbox": "-180,-85,180,85",
            "perspectives": "PERSP_REICH_2018",
        },
    )
    assert r.status_code == 200
    data = r.json()
    carriers = data["perspectives"]["PERSP_REICH_2018"]["carriers"]
    if len(carriers) < 4:
        pytest.skip(
            f"Only {len(carriers)} carriers at year 0 — historical seed not applied"
        )
    assert len(carriers) >= 10, (
        f"Expected >=10 carriers at year 0 once 005 is seeded; got {len(carriers)}"
    )
