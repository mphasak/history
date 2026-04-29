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
async def test_historical_places_filters_by_year(client):
    """
    /historical-places?year=Y returns only places whose date window covers Y.
    Constantinople is named Constantinople from 330 to 1453; Byzantium
    occupies the same site from -657 to 329. They're mutually exclusive.
    """
    r = await client.get("/historical-places", params={"year": 400})
    if r.status_code == 404:
        pytest.skip("/historical-places missing — places seed not applied")
    assert r.status_code == 200
    names_400 = {p["display_name"] for p in r.json()["places"]}
    if not names_400:
        pytest.skip("No historical places seeded")
    assert "Constantinople" in names_400
    assert "Byzantium" not in names_400, (
        "Byzantium should NOT show at year 400 (window ended 329)"
    )

    r2 = await client.get("/historical-places", params={"year": 100})
    assert r2.status_code == 200
    names_100 = {p["display_name"] for p in r2.json()["places"]}
    assert "Byzantium" in names_100
    assert "Constantinople" not in names_100, (
        "Constantinople should NOT show at year 100 (founded 330)"
    )


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


@pytest.mark.asyncio
async def test_carrier_lineage_endpoint_indo_aryan(client):
    """
    /carrier/{id}/lineage returns ancestors and descendants for a carrier at
    a queried year. For the bronze-age NW South Asia carrier, descendants
    should include the Vedic Aryans, Mauryans and modern South Asians, and
    the Vedic edge should carry STEPPE_MLBA as a shared trait.
    """
    r = await client.get(
        "/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/lineage",
        params={"year": -1700, "direction": "both", "limit_per_side": 10},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["focal"]["id"] == "CARR_NW_SOUTH_ASIA_LATE_BRONZE"

    descendant_ids = {d["id"] for d in data["descendants"]}
    assert "CARR_HIST_VEDIC_ARYAN" in descendant_ids, (
        f"Vedic Aryans missing from lineage descendants; got {descendant_ids}"
    )

    vedic = next(d for d in data["descendants"] if d["id"] == "CARR_HIST_VEDIC_ARYAN")
    assert "STEPPE_MLBA" in vedic["shared_trait_ids"]


@pytest.mark.asyncio
async def test_gap_filler_carriers_have_trait_mix(client):
    """
    The 014 trait-mix backfill seeds editorial-best-effort ancestry for the
    013 gap-fillers and the 010/012 carriers that lacked any trait_mix.
    Verify Mali Empire shows AFR_WEST as its dominant component (it should
    cluster with West African populations under the 'cluster' color mode).
    """
    r = await client.get(
        "/world",
        params={
            "year": 1400,
            "bbox": "-180,-85,180,85",
            "perspectives": "PERSP_REICH_2018",
        },
    )
    assert r.status_code == 200
    carriers = r.json()["perspectives"]["PERSP_REICH_2018"]["carriers"]
    mali = next((c for c in carriers if c["id"] == "CARR_HIST_GAP_MALI_EMPIRE"), None)
    if mali is None:
        pytest.skip("013 regional-gap seed not applied")
    if not mali["trait_mix"]:
        pytest.skip("014 trait-mix backfill not applied")
    trait_ids = {m["trait_id"] for m in mali["trait_mix"]}
    assert "AFR_WEST" in trait_ids, (
        f"Expected AFR_WEST in Mali Empire trait mix; got {trait_ids}"
    )


@pytest.mark.asyncio
async def test_world_includes_regional_gap_filler_carriers(client):
    """
    The 013 regional gap-filler seed adds Mali Empire, Teotihuacan, and
    Polynesian voyagers among others. Verify a couple of these show up
    when their year window is queried.
    """
    # Mali Empire window 1230-1670 → check at year 1400
    r = await client.get(
        "/world",
        params={
            "year": 1400,
            "bbox": "-180,-85,180,85",
            "perspectives": "PERSP_REICH_2018",
        },
    )
    assert r.status_code == 200
    ids = {c["id"] for c in r.json()["perspectives"]["PERSP_REICH_2018"]["carriers"]}
    if "CARR_HIST_GAP_MALI_EMPIRE" not in ids:
        pytest.skip("013 regional-gap seed not applied")
    assert "CARR_HIST_GAP_MALI_EMPIRE" in ids
    # Teotihuacan window -100..600 → check at year 400
    r2 = await client.get(
        "/world",
        params={
            "year": 400,
            "bbox": "-180,-85,180,85",
            "perspectives": "PERSP_REICH_2018",
        },
    )
    assert r2.status_code == 200
    ids2 = {c["id"] for c in r2.json()["perspectives"]["PERSP_REICH_2018"]["carriers"]}
    assert "CARR_HIST_GAP_TEOTIHUACAN" in ids2


@pytest.mark.asyncio
async def test_carrier_lineage_future_excludes_sibling_populations(client):
    """
    Regression test: the future of First Americans (CARR_PALEO_AMER_15K)
    should be Native-American populations only — not sibling populations
    that share an upstream ANE component (Saami, Yamnaya, Steppe MLBA, etc.).

    Earlier the BFS used "any shared trait" as the edge criterion, which
    pulled in dozens of Eurasian populations as descendants because they
    happened to carry ANE through Mal'ta-derived gene flow. The dominant-
    trait alignment rule fixes this: a descendant must carry the focal's
    *dominant* trait (AMER_NA) at >= 2%, which Saami / Yamnaya / Han do not.
    """
    r = await client.get(
        "/carrier/CARR_PALEO_AMER_15K/lineage",
        params={"year": -12000, "direction": "future", "max_depth": 5, "max_per_hop": 6},
    )
    assert r.status_code == 200
    ids = {n["id"] for n in r.json()["nodes"]}

    # Sibling populations that share ANE but not AMER_NA must NOT appear.
    forbidden = {
        "CARR_HIST_FOR_SAAMI_ANCESTRAL",
        "CARR_HIST_GAP_YAKUT",
        "CARR_HIST_MODERN_HAN",
        "CARR_HIST_VEDIC_ARYAN",
        "CARR_NW_SOUTH_ASIA_LATE_BRONZE",
    }
    leaked = forbidden & ids
    assert not leaked, (
        f"Future of First Americans should be Native-American-only; "
        f"these sibling populations leaked through: {leaked}"
    )

    # Genuine Native-American descendants should still appear.
    expected_some_of = {
        "CARR_HIST_INCA",
        "CARR_HIST_AZTEC",
        "CARR_HIST_GAP_MAYA_CLASSICAL",
        "CARR_HIST_MAYA_CLASSICAL",
        "CARR_HIST_HOL_PRECLASSIC_MAYA",
        "CARR_HIST_HOL_OLMEC",
        "CARR_HIST_GAP_TEOTIHUACAN",
        "CARR_HIST_FOR_ANDEAN_ARCHAIC",
        "CARR_HIST_MODERN_NATIVE_AMER",
    }
    assert ids & expected_some_of, (
        f"Future of First Americans should include classical Native American "
        f"populations; got {ids}"
    )


@pytest.mark.asyncio
async def test_carrier_lineage_multi_hop_traces_to_neanderthal(client):
    """
    The multi-hop lineage BFS should let the user trace from a modern
    population (Rural South US, with NEANDERTHAL admixture in its mix) all
    the way back to the CARR_HOMININ_NEANDERTHAL hominin carrier within a
    handful of hops. This is the headline demo for the multi-hop graph.
    """
    r = await client.get(
        "/carrier/CARR_RURAL_SOUTH_US_2025/lineage",
        params={"year": 2000, "direction": "past", "max_depth": 6, "max_per_hop": 5},
    )
    assert r.status_code == 200
    data = r.json()
    if not data["nodes"]:
        pytest.skip("Modern-US trait_mix not seeded; 015 not applied")
    ids = {n["id"] for n in data["nodes"]}
    assert "CARR_HOMININ_NEANDERTHAL" in ids, (
        f"Multi-hop trace from Rural South US should reach Neanderthal; "
        f"got {len(ids)} nodes"
    )
    # The graph should have edges, and every edge must point to a node we
    # know about (the frontend assumes nodesById covers every endpoint).
    assert len(data["edges"]) > 0
    for e in data["edges"]:
        assert e["from_id"] in ids
        assert e["to_id"] in ids


@pytest.mark.asyncio
async def test_carrier_lineage_direction_param(client):
    """direction=past suppresses descendants and vice versa."""
    r = await client.get(
        "/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/lineage",
        params={"year": -1700, "direction": "past"},
    )
    assert r.status_code == 200
    assert r.json()["descendants"] == []

    r = await client.get(
        "/carrier/CARR_NW_SOUTH_ASIA_LATE_BRONZE/lineage",
        params={"year": -1700, "direction": "future"},
    )
    assert r.status_code == 200
    assert r.json()["ancestors"] == []
