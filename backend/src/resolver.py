"""
resolver.py — Perspective resolution logic.

Every API read that depends on active Perspectives funnels through here.
The resolver never merges Perspectives into a single truth; it returns
separate per-Perspective views that the frontend decides how to render.
"""
from __future__ import annotations

from typing import Any


def _point(lat: Any, lon: Any) -> dict | None:
    if lat is None or lon is None:
        return None
    return {"lat": float(lat), "lon": float(lon)}


def _endorsement(e: dict | None) -> dict | None:
    if e is None:
        return None
    return {
        "stance": e["stance"],
        "override_statement": e.get("override_statement"),
        "override_quantitative_value": e.get("override_quantitative_value"),
        "source_weight_overrides": e.get("source_weight_overrides"),
    }


async def _default_perspective_ids(conn) -> list[str]:
    rows = await conn.execute(
        "SELECT id FROM perspective WHERE default_active = true AND status = 'admitted'"
    )
    return [r["id"] async for r in rows]


async def _fetch_endorsements(conn, perspective_ids: list[str]) -> dict[str, list[dict]]:
    """Return {perspective_id: [endorsement_row, ...]}."""
    result: dict[str, list[dict]] = {pid: [] for pid in perspective_ids}
    if not perspective_ids:
        return result
    rows = await conn.execute(
        """
        SELECT perspective_id, subject_type, subject_id, stance,
               override_statement, override_quantitative_value, source_weight_overrides
        FROM perspective_endorsement
        WHERE perspective_id = ANY(%s)
        """,
        (perspective_ids,),
    )
    async for r in rows:
        result[r["perspective_id"]].append(dict(r))
    return result


_SUBJECT_TYPE_MAP = {
    "claim": "claim",
    "Claim": "claim",
    "traitrelation": "trait_relation",
    "TraitRelation": "trait_relation",
    "trait_relation": "trait_relation",
    "carrier": "carrier",
    "Carrier": "carrier",
    "carriertrait_mix": "carrier_trait_mix",
    "CarrierTraitMix": "carrier_trait_mix",
    "carrier_trait_mix": "carrier_trait_mix",
    "propagation_event": "propagation_event",
    "PropagationEvent": "propagation_event",
    "physical_feature": "physical_feature",
    "PhysicalFeature": "physical_feature",
    "paleoclimate_state": "paleoclimate_state",
    "general": "general",
}


def _normalize_subject_type(t: str) -> str:
    return _SUBJECT_TYPE_MAP.get(t, t.lower())


def _index_endorsements(rows: list[dict]) -> dict[tuple[str, str], dict]:
    """Index endorsements by (normalized_subject_type, subject_id) for O(1) lookup."""
    idx: dict[tuple[str, str], dict] = {}
    for e in rows:
        key = (_normalize_subject_type(e["subject_type"]), e["subject_id"])
        idx[key] = e
    return idx


_CARRIER_DEFAULT_RADIUS_M = {
    "population": 800_000,
    "community": 300_000,
    "institution": 100_000,
    "nation_state": 600_000,
    "sub_national_region": 250_000,
    "diaspora": 1_500_000,
    "virtual": 500_000,
}


async def resolve_world(
    conn,
    year: int,
    bbox: list[float],
    perspective_ids: list[str],
) -> dict[str, dict]:
    """
    Returns per-Perspective world views for the given year and bbox, keyed by
    perspective id. Each view contains resolved carriers (with trait mixes) and
    propagation events.

    Note: a side-channel `_observations` key on the result holds raw
    trait_observation rows in the bbox/year window. Observations are not
    Perspective-filtered (they are the underlying samples that Perspectives
    interpret). Callers iterating perspectives should skip keys starting with `_`.
    """
    west, south, east, north = bbox

    if not perspective_ids:
        perspective_ids = await _default_perspective_ids(conn)

    # Fetch carriers valid at year
    # For antimeridian-crossing bboxes (west > east), use OR logic on longitude.
    if west <= east:
        lon_clause = "ST_X(centroid::geometry) BETWEEN %(west)s AND %(east)s"
    else:
        lon_clause = "(ST_X(centroid::geometry) >= %(west)s OR ST_X(centroid::geometry) <= %(east)s)"

    # extent_geojson: real extent if present, else a buffered circle around centroid
    # whose radius scales with carrier type (so fill mode always has a polygon).
    radius_case = "CASE type " + " ".join(
        f"WHEN '{t}' THEN {r}" for t, r in _CARRIER_DEFAULT_RADIUS_M.items()
    ) + " ELSE 500000 END"

    # Extent priority (most → least specific):
    #   1) carrier_extent_snapshot row at or before `year`
    #      (latest such snapshot wins; lets a single carrier evolve over time)
    #   2) carrier.extent (a fixed authored polygon, e.g. NW South Asia carrier)
    #   3) ST_Buffer(centroid, radius_for_carrier_type)
    # `extent_is_real` flips on for (1) and (2) so the UI can solid-outline
    # them, and stays off for the buffered fallback (rendered dashed).
    #
    # The LATERAL subquery picks the most recent snapshot per carrier at the
    # current year — equivalent to an `ORDER BY as_of_year DESC LIMIT 1` join.
    carrier_rows = await conn.execute(
        f"""
        SELECT c.id, c.display_name, c.type, c.date_min_year, c.date_max_year,
               ST_Y(c.centroid::geometry) AS lat,
               ST_X(c.centroid::geometry) AS lon,
               c.archaeological_culture, c.linguistic_affiliation,
               ST_AsGeoJSON(
                 COALESCE(
                   snap.geometry::geometry,
                   c.extent::geometry,
                   ST_Buffer(c.centroid, {radius_case})::geometry
                 )
               ) AS extent_geojson,
               (snap.geometry IS NOT NULL OR c.extent IS NOT NULL) AS extent_is_real
        FROM carrier c
        LEFT JOIN LATERAL (
          SELECT geometry
          FROM carrier_extent_snapshot
          WHERE carrier_id = c.id AND as_of_year <= %(year)s
          ORDER BY as_of_year DESC
          LIMIT 1
        ) snap ON TRUE
        WHERE c.date_min_year <= %(year)s AND c.date_max_year >= %(year)s
          AND (
            c.centroid IS NULL
            OR (
              ST_Y(c.centroid::geometry) BETWEEN %(south)s AND %(north)s
              AND {lon_clause.replace("centroid", "c.centroid")}
            )
          )
        """,
        {"year": year, "west": west, "east": east, "south": south, "north": north},
    )
    carriers: list[dict] = [dict(r) async for r in carrier_rows]

    # Batch-fetch trait mixes for all carriers in one query (avoids N+1).
    # For each carrier, select only the most recent snapshot at or before year.
    carrier_ids = [c["id"] for c in carriers]
    trait_mix_by_carrier: dict[str, list[dict]] = {cid: [] for cid in carrier_ids}
    if carrier_ids:
        mix_rows = await conn.execute(
            """
            WITH ranked AS (
                SELECT ctm.carrier_id, ctm.trait_id, t.display_name, ctm.domain,
                       ctm.fraction, ctm.stderr, ctm.as_of_year,
                       RANK() OVER (
                           PARTITION BY ctm.carrier_id
                           ORDER BY ctm.as_of_year DESC
                       ) AS rn
                FROM carrier_trait_mix ctm
                JOIN trait t ON t.id = ctm.trait_id
                WHERE ctm.carrier_id = ANY(%(carrier_ids)s)
                  AND ctm.as_of_year <= %(year)s
            )
            SELECT carrier_id, trait_id, display_name, domain, fraction, stderr, as_of_year
            FROM ranked
            WHERE rn = 1
            ORDER BY carrier_id, domain, trait_id
            """,
            {"carrier_ids": carrier_ids, "year": year},
        )
        async for r in mix_rows:
            trait_mix_by_carrier[r["carrier_id"]].append(dict(r))
    for c in carriers:
        c["trait_mix"] = trait_mix_by_carrier[c["id"]]

    # Fetch trait_observation rows in bbox + year window (Perspective-agnostic)
    if west <= east:
        obs_lon_clause = "ST_X(o.location::geometry) BETWEEN %(west)s AND %(east)s"
    else:
        obs_lon_clause = "(ST_X(o.location::geometry) >= %(west)s OR ST_X(o.location::geometry) <= %(east)s)"

    obs_rows = await conn.execute(
        f"""
        SELECT o.id, o.carrier_id, o.sample_label,
               o.date_min_year, o.date_max_year,
               ST_Y(o.location::geometry) AS lat,
               ST_X(o.location::geometry) AS lon,
               o.domain, o.trait_id, t.display_name AS trait_display_name,
               o.fraction, o.stderr, o.method
        FROM trait_observation o
        JOIN trait t ON t.id = o.trait_id
        WHERE o.location IS NOT NULL
          AND COALESCE(o.date_min_year, -100000) <= %(year)s
          AND COALESCE(o.date_max_year,  100000) >= %(year)s
          AND ST_Y(o.location::geometry) BETWEEN %(south)s AND %(north)s
          AND {obs_lon_clause}
        """,
        {"year": year, "west": west, "east": east, "south": south, "north": north},
    )
    observations: list[dict] = []
    async for r in obs_rows:
        r = dict(r)
        observations.append({
            "id": r["id"],
            "carrier_id": r["carrier_id"],
            "sample_label": r["sample_label"],
            "date_min_year": r["date_min_year"],
            "date_max_year": r["date_max_year"],
            "location": _point(r["lat"], r["lon"]),
            "domain": r["domain"],
            "trait_id": r["trait_id"],
            "trait_display_name": r["trait_display_name"],
            "fraction": float(r["fraction"]) if r["fraction"] is not None else None,
            "stderr": float(r["stderr"]) if r["stderr"] is not None else None,
            "method": r["method"],
        })

    # Fetch propagation events valid at year
    prop_rows = await conn.execute(
        """
        SELECT id, display_name, domain, date_min_year, date_max_year, mechanism,
               ST_Y(source_point::geometry)      AS src_lat,
               ST_X(source_point::geometry)      AS src_lon,
               ST_Y(destination_point::geometry) AS dst_lat,
               ST_X(destination_point::geometry) AS dst_lon
        FROM propagation_event
        WHERE date_min_year <= %(year)s AND date_max_year >= %(year)s
        """,
        {"year": year},
    )
    propagation_events: list[dict] = [dict(r) async for r in prop_rows]

    # Fetch all endorsements for active perspectives
    all_endorsements = await _fetch_endorsements(conn, perspective_ids)

    # Build per-perspective resolved views
    result: dict[str, dict] = {}
    for pid in perspective_ids:
        idx = _index_endorsements(all_endorsements[pid])

        # --- Resolve carriers ---
        resolved_carriers = []
        for c in carriers:
            carrier_end = idx.get(("carrier", c["id"]))
            if carrier_end and carrier_end["stance"] == "rejects":
                continue

            # Resolve trait mix with per-mix endorsements
            resolved_mix = []
            for mix in c["trait_mix"]:
                mix_key = ("carrier_trait_mix", f"{c['id']}:{mix['trait_id']}")
                mix_end = idx.get(mix_key)
                if mix_end and mix_end["stance"] == "rejects":
                    continue
                resolved_mix.append({**mix, "endorsement": _endorsement(mix_end)})

            resolved_carriers.append({
                "id": c["id"],
                "display_name": c["display_name"],
                "type": c["type"],
                "date_min_year": c["date_min_year"],
                "date_max_year": c["date_max_year"],
                "centroid": _point(c["lat"], c["lon"]),
                "archaeological_culture": c["archaeological_culture"],
                "linguistic_affiliation": c["linguistic_affiliation"],
                "trait_mix": resolved_mix,
                "endorsement": _endorsement(carrier_end),
                "extent_geojson": c.get("extent_geojson"),
                "extent_is_real": bool(c.get("extent_is_real")),
            })

        # Add any asserted carriers not already present
        for e in all_endorsements[pid]:
            if e["subject_type"] == "carrier" and e["stance"] == "asserts":
                if not any(rc["id"] == e["subject_id"] for rc in resolved_carriers):
                    resolved_carriers.append({
                        "id": e["subject_id"],
                        "display_name": e["subject_id"],
                        "type": "population",
                        "date_min_year": year,
                        "date_max_year": year,
                        "centroid": None,
                        "archaeological_culture": None,
                        "linguistic_affiliation": None,
                        "trait_mix": [],
                        "endorsement": _endorsement(e),
                    })

        # --- Resolve propagation events ---
        resolved_props = []
        for prop in propagation_events:
            prop_end = idx.get(("propagation_event", prop["id"]))
            if prop_end and prop_end["stance"] == "rejects":
                continue
            resolved_props.append({
                "id": prop["id"],
                "display_name": prop["display_name"],
                "domain": prop["domain"],
                "date_min_year": prop["date_min_year"],
                "date_max_year": prop["date_max_year"],
                "mechanism": prop["mechanism"],
                "source_point": _point(prop["src_lat"], prop["src_lon"]),
                "destination_point": _point(prop["dst_lat"], prop["dst_lon"]),
                "endorsement": _endorsement(prop_end),
            })

        result[pid] = {
            "perspective_id": pid,
            "carriers": resolved_carriers,
            "propagation_events": resolved_props,
        }

    # Side-channel: observations live under `_observations`. Callers iterating
    # perspectives must skip keys starting with `_`.
    result["_observations"] = observations  # type: ignore[assignment]

    # Side-channel: precompute which carriers in view have claim-level stance
    # disagreements across the active perspectives. The diff overlay reads this
    # so it can mark carriers contested even when the disagreement lives on an
    # adjacent claim/propagation event rather than the carrier itself.
    result["_disagreed_carrier_ids"] = await _compute_disagreed_carrier_ids(  # type: ignore[assignment]
        conn,
        carrier_ids=[c["id"] for c in carriers],
        perspective_ids=perspective_ids,
        all_endorsements=all_endorsements,
    )
    return result


async def _compute_disagreed_carrier_ids(
    conn,
    carrier_ids: list[str],
    perspective_ids: list[str],
    all_endorsements: dict[str, list[dict]],
) -> list[str]:
    """
    For each carrier in view, find the claims relevant to it (claims about the
    carrier itself, its trait mixes, or propagation events whose destination
    overlaps it) and mark the carrier as disagreed if any of those claims
    receive different stances under different active perspectives.
    """
    if not carrier_ids or len(perspective_ids) < 2:
        return []

    # Single batch SQL: list every (carrier_id, claim_id) pair where the claim
    # is relevant to the carrier under the same relevance rules used by
    # resolve_carrier_claims.
    rows = await conn.execute(
        """
        WITH cv(cid) AS (SELECT unnest(%(carrier_ids)s::text[]))
        SELECT car.id AS carrier_id, c.id AS claim_id
        FROM cv
        JOIN carrier car ON car.id = cv.cid
        JOIN claim c ON (
          c.statement NOT LIKE '[AUTO-THREAT]%%'
          AND (
            (lower(c.subject_type) = 'carrier' AND c.subject_id = car.id)
            OR (lower(c.subject_type) IN ('carriertrait_mix','carrier_trait_mix')
                AND c.subject_id LIKE car.id || ':%%')
            OR (lower(c.subject_type) IN ('propagationevent','propagation_event')
                AND c.subject_id IN (
                  SELECT pe.id FROM propagation_event pe
                  WHERE
                    (car.extent IS NOT NULL AND ST_Intersects(pe.destination_point, car.extent))
                    OR (car.extent IS NULL AND car.centroid IS NOT NULL
                        AND ST_DWithin(pe.destination_point, car.centroid, %(radius)s))
                    OR pe.source_trait_ids && (
                      SELECT array_agg(trait_id) FROM carrier_trait_mix
                      WHERE carrier_id = car.id
                    )
                ))
          )
        )
        """,
        {"carrier_ids": carrier_ids, "radius": _PROP_RELEVANCE_RADIUS_M},
    )
    pairs = [(r["carrier_id"], r["claim_id"]) async for r in rows]
    if not pairs:
        return []

    indexed = {pid: _index_endorsements(all_endorsements[pid]) for pid in perspective_ids}

    contested: set[str] = set()
    by_carrier: dict[str, set[int]] = {}
    for cid, clid in pairs:
        by_carrier.setdefault(cid, set()).add(clid)

    for cid, claim_ids in by_carrier.items():
        for clid in claim_ids:
            stances = set()
            for pid in perspective_ids:
                end = indexed[pid].get(("claim", str(clid)))
                stances.add(end["stance"] if end else "endorses")
            if len(stances) > 1:
                contested.add(cid)
                break

    return sorted(contested)


async def resolve_world_at_point(
    conn,
    year: int,
    lat: float,
    lon: float,
    perspective_ids: list[str],
    limit: int = 5,
    max_distance_km: float = 3000.0,
) -> dict[str, dict]:
    """
    Returns per-Perspective views of carriers at the given (lat, lon, year).

    Ranking:
      - distance 0 if `extent` covers the point
      - else great-circle distance from centroid

    Carriers beyond `max_distance_km` are filtered out. Up to `limit` returned.
    """
    if not perspective_ids:
        perspective_ids = await _default_perspective_ids(conn)

    carrier_rows = await conn.execute(
        """
        WITH q AS (
            SELECT ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326)::geography AS p
        )
        SELECT c.id, c.display_name, c.type, c.date_min_year, c.date_max_year,
               ST_Y(c.centroid::geometry) AS lat,
               ST_X(c.centroid::geometry) AS lon,
               c.archaeological_culture, c.linguistic_affiliation,
               (c.extent IS NOT NULL AND ST_Covers(c.extent, q.p)) AS covers_point,
               CASE
                 WHEN c.extent IS NOT NULL AND ST_Covers(c.extent, q.p) THEN 0.0
                 WHEN c.centroid IS NOT NULL THEN ST_Distance(c.centroid, q.p)
                 ELSE NULL
               END AS distance_m
        FROM carrier c, q
        WHERE c.date_min_year <= %(year)s AND c.date_max_year >= %(year)s
          AND c.centroid IS NOT NULL
        ORDER BY distance_m ASC NULLS LAST
        LIMIT %(limit)s
        """,
        {"year": year, "lat": lat, "lon": lon, "limit": limit},
    )
    carriers: list[dict] = []
    async for r in carrier_rows:
        r = dict(r)
        dist_m = r.get("distance_m")
        if dist_m is None:
            continue
        dist_km = float(dist_m) / 1000.0
        if dist_km > max_distance_km and not r.get("covers_point"):
            continue
        r["distance_km"] = dist_km
        carriers.append(r)

    # Batch-fetch trait mixes for all carriers in one query (avoids N+1).
    carrier_ids = [c["id"] for c in carriers]
    trait_mix_by_carrier: dict[str, list[dict]] = {cid: [] for cid in carrier_ids}
    if carrier_ids:
        mix_rows = await conn.execute(
            """
            WITH ranked AS (
                SELECT ctm.carrier_id, ctm.trait_id, t.display_name, ctm.domain,
                       ctm.fraction, ctm.stderr, ctm.as_of_year,
                       RANK() OVER (
                           PARTITION BY ctm.carrier_id
                           ORDER BY ctm.as_of_year DESC
                       ) AS rn
                FROM carrier_trait_mix ctm
                JOIN trait t ON t.id = ctm.trait_id
                WHERE ctm.carrier_id = ANY(%(carrier_ids)s)
                  AND ctm.as_of_year <= %(year)s
            )
            SELECT carrier_id, trait_id, display_name, domain, fraction, stderr, as_of_year
            FROM ranked
            WHERE rn = 1
            ORDER BY carrier_id, domain, trait_id
            """,
            {"carrier_ids": carrier_ids, "year": year},
        )
        async for r in mix_rows:
            trait_mix_by_carrier[r["carrier_id"]].append(dict(r))
    for c in carriers:
        c["trait_mix"] = trait_mix_by_carrier[c["id"]]

    all_endorsements = await _fetch_endorsements(conn, perspective_ids)

    result: dict[str, dict] = {}
    for pid in perspective_ids:
        idx = _index_endorsements(all_endorsements[pid])
        resolved_carriers = []
        for c in carriers:
            carrier_end = idx.get(("carrier", c["id"]))
            if carrier_end and carrier_end["stance"] == "rejects":
                continue
            resolved_mix = []
            for mix in c["trait_mix"]:
                mix_key = ("carrier_trait_mix", f"{c['id']}:{mix['trait_id']}")
                mix_end = idx.get(mix_key)
                if mix_end and mix_end["stance"] == "rejects":
                    continue
                resolved_mix.append({**mix, "endorsement": _endorsement(mix_end)})

            resolved_carriers.append({
                "id": c["id"],
                "display_name": c["display_name"],
                "type": c["type"],
                "date_min_year": c["date_min_year"],
                "date_max_year": c["date_max_year"],
                "centroid": _point(c["lat"], c["lon"]),
                "archaeological_culture": c["archaeological_culture"],
                "linguistic_affiliation": c["linguistic_affiliation"],
                "trait_mix": resolved_mix,
                "endorsement": _endorsement(carrier_end),
                "distance_km": c["distance_km"],
                "covers_point": bool(c.get("covers_point")),
            })

        result[pid] = {
            "perspective_id": pid,
            "carriers": resolved_carriers,
            "propagation_events": [],
        }

    return result


async def resolve_claim(
    conn,
    claim_id: int,
    perspective_ids: list[str],
) -> dict:
    """
    Returns a claim with per-Perspective stance, override, and weighted sources.
    """
    if not perspective_ids:
        perspective_ids = await _default_perspective_ids(conn)

    # Fetch the claim
    claim_row = await conn.execute(
        "SELECT * FROM claim WHERE id = %s", (claim_id,)
    )
    claim = dict(await claim_row.fetchone())

    # Fetch claim sources with their default weights
    src_rows = await conn.execute(
        """
        SELECT cs.source_id, s.citation, cs.stance, cs.weight_override, s.default_weight
        FROM claim_source cs
        JOIN source s ON s.id = cs.source_id
        WHERE cs.claim_id = %s
        """,
        (claim_id,),
    )
    default_sources = [dict(r) async for r in src_rows]

    # Fetch perspective endorsements for this specific claim
    all_endorsements = await _fetch_endorsements(conn, perspective_ids)

    perspectives_view: dict[str, dict] = {}
    for pid in perspective_ids:
        idx = _index_endorsements(all_endorsements[pid])
        claim_end = idx.get(("claim", str(claim_id)))

        # Resolve source weights: default → perspective override
        resolved_sources = []
        for src in default_sources:
            src_entry = {**src}
            if claim_end and claim_end.get("source_weight_overrides"):
                overrides = claim_end["source_weight_overrides"]
                if src["source_id"] in overrides:
                    src_entry["weight_override"] = overrides[src["source_id"]]
            resolved_sources.append(src_entry)

        perspectives_view[pid] = {
            "perspective_id": pid,
            "stance": claim_end["stance"] if claim_end else "endorses",
            "override_statement": claim_end.get("override_statement") if claim_end else None,
            "override_quantitative_value": claim_end.get("override_quantitative_value") if claim_end else None,
            "source_weight_overrides": claim_end.get("source_weight_overrides") if claim_end else None,
            "sources": resolved_sources,
        }

    return {**claim, "perspectives": perspectives_view}


async def resolve_trait_lineage(
    conn,
    trait_id: str,
    perspective_id: str,
    max_depth: int = 6,
) -> list[dict]:
    """
    Walks trait_relation recursively up to max_depth levels, applying
    the given Perspective's endorsements. Returns a list of parent nodes.
    """
    endorsements = await _fetch_endorsements(conn, [perspective_id])
    idx = _index_endorsements(endorsements[perspective_id])

    async def _walk(tid: str, depth: int) -> list[dict]:
        if depth <= 0:
            return []
        rows = await conn.execute(
            """
            SELECT tr.id, tr.parent_id, tr.relation_type, tr.weight,
                   t.display_name
            FROM trait_relation tr
            JOIN trait t ON t.id = tr.parent_id
            WHERE tr.child_id = %s
            """,
            (tid,),
        )
        nodes = []
        async for r in rows:
            r = dict(r)
            rel_end = idx.get(("trait_relation", str(r["id"])))
            if rel_end and rel_end["stance"] == "rejects":
                continue
            node = {
                "trait_id": r["parent_id"],
                "display_name": r["display_name"],
                "relation_type": r["relation_type"],
                "weight": r["weight"],
                "endorsement": _endorsement(rel_end),
                "parents": await _walk(r["parent_id"], depth - 1),
            }
            nodes.append(node)

        # Add asserted relations from this perspective
        for e in endorsements[perspective_id]:
            if (
                e["subject_type"] == "trait_relation"
                and e["stance"] == "asserts"
                and e.get("asserted_relation")
            ):
                ar = e["asserted_relation"]
                if ar.get("child_id") == tid:
                    nodes.append({
                        "trait_id": ar["parent_id"],
                        "display_name": ar.get("display_name", ar["parent_id"]),
                        "relation_type": ar["relation_type"],
                        "weight": ar.get("weight"),
                        "endorsement": _endorsement(e),
                        "parents": await _walk(ar["parent_id"], depth - 1),
                    })
        return nodes

    return await _walk(trait_id, max_depth)


async def resolve_carrier_timeline(
    conn,
    carrier_id: str,
    perspective_id: str,
) -> list[dict]:
    """
    Returns all carrier_trait_mix snapshots for this carrier, resolved
    against the given Perspective, sorted ascending by year.
    """
    endorsements = await _fetch_endorsements(conn, [perspective_id])
    idx = _index_endorsements(endorsements[perspective_id])

    rows = await conn.execute(
        """
        SELECT ctm.as_of_year, ctm.domain, ctm.trait_id,
               t.display_name, ctm.fraction, ctm.stderr
        FROM carrier_trait_mix ctm
        JOIN trait t ON t.id = ctm.trait_id
        WHERE ctm.carrier_id = %s
        ORDER BY ctm.as_of_year, ctm.domain, ctm.trait_id
        """,
        (carrier_id,),
    )

    # Group by (as_of_year, domain)
    snapshots: dict[tuple, list] = {}
    async for r in rows:
        r = dict(r)
        mix_end = idx.get(("carrier_trait_mix", f"{carrier_id}:{r['trait_id']}"))
        if mix_end and mix_end["stance"] == "rejects":
            continue
        key = (r["as_of_year"], r["domain"])
        snapshots.setdefault(key, []).append({
            "trait_id": r["trait_id"],
            "display_name": r["display_name"],
            "domain": r["domain"],
            "fraction": r["fraction"],
            "stderr": r["stderr"],
            "endorsement": _endorsement(mix_end),
        })

    # Carrier-level endorsement might override things
    carrier_end = idx.get(("carrier", carrier_id))

    return [
        {
            "as_of_year": year,
            "domain": domain,
            "traits": traits,
            "carrier_endorsement": _endorsement(carrier_end),
        }
        for (year, domain), traits in sorted(snapshots.items())
    ]


# Claims about a propagation event whose destination is within this radius of the
# carrier's centroid count as relevant to that carrier (when the carrier has no
# explicit extent polygon). Roughly the size of a culture-area for "population"-
# type carriers; tight enough to keep the Indo-Aryan demo focused on the right
# carrier, loose enough to surface migrations that arrived nearby.
_PROP_RELEVANCE_RADIUS_M = 1_500_000


async def resolve_carrier_threats(
    conn,
    carrier_id: str,
    year: int | None = None,
) -> list[dict]:
    """
    Return threats faced by a carrier, optionally filtered to those whose
    year window overlaps `year`. Threats are pulled with their supporting
    sources (joined through claim_id → claim_source → source) so the frontend
    can show citations alongside each threat.
    """
    if year is None:
        rows = await conn.execute(
            """
            SELECT id, threat_type::text AS threat_type, display_name, description,
                   severity, date_min_year, date_max_year, claim_id
            FROM carrier_threat
            WHERE carrier_id = %(cid)s
            ORDER BY severity DESC, date_min_year
            """,
            {"cid": carrier_id},
        )
    else:
        rows = await conn.execute(
            """
            SELECT id, threat_type::text AS threat_type, display_name, description,
                   severity, date_min_year, date_max_year, claim_id
            FROM carrier_threat
            WHERE carrier_id = %(cid)s
              AND date_min_year <= %(y)s AND date_max_year >= %(y)s
            ORDER BY severity DESC, date_min_year
            """,
            {"cid": carrier_id, "y": year},
        )
    threats = [dict(r) async for r in rows]
    if not threats:
        return []

    # Batch-fetch citations for all threat claims at once.
    claim_ids = [t["claim_id"] for t in threats if t["claim_id"] is not None]
    sources_by_claim: dict[int, list[dict]] = {}
    if claim_ids:
        src_rows = await conn.execute(
            """
            SELECT cs.claim_id, cs.source_id, s.citation, cs.stance,
                   cs.weight_override, s.default_weight
            FROM claim_source cs
            JOIN source s ON s.id = cs.source_id
            WHERE cs.claim_id = ANY(%(ids)s)
            """,
            {"ids": claim_ids},
        )
        async for r in src_rows:
            sources_by_claim.setdefault(r["claim_id"], []).append(dict(r))

    for t in threats:
        t["sources"] = sources_by_claim.get(t["claim_id"], [])
    return threats


async def _one_hop_lineage(
    conn,
    source_carrier_id: str,
    source_trait_ids: list[str],
    source_date_min: int,
    source_date_max: int,
    side: str,
    max_per_hop: int,
    exclude_ids: list[str],
) -> list[dict]:
    """
    One BFS hop in the lineage graph.

    Given a *source* carrier (already in the graph), find up to `max_per_hop`
    other carriers that:
      * share at least one trait_id with the source's trait mix, OR fall
        within ~3000 km of its centroid (spatial fallback for trait-less
        carriers);
      * are temporally before (side='past') or after (side='future') the
        source;
      * are not already in `exclude_ids` (the visited set).

    Returns a list of dicts with `id`, `display_name`, `type`, `date_*_year`,
    `centroid`, `shared_trait_ids` (the traits that bridge this candidate to
    the *source* — not to the focal).
    """
    if side == "past":
        where_time = "c.date_max_year <= %(src_min)s"
        order = "has_trait_edge DESC, c.date_max_year DESC"
    else:
        where_time = "c.date_min_year >= %(src_max)s"
        order = "has_trait_edge DESC, c.date_min_year ASC"

    rows = await conn.execute(
        f"""
        WITH shared AS (
            SELECT carrier_id, array_agg(DISTINCT trait_id) AS shared_trait_ids
            FROM carrier_trait_mix
            WHERE trait_id = ANY(%(trait_ids)s::text[])
              AND carrier_id <> %(src_id)s
            GROUP BY carrier_id
        ),
        src_ref AS (
            SELECT centroid FROM carrier WHERE id = %(src_id)s
        )
        SELECT c.id, c.display_name, c.type,
               c.date_min_year, c.date_max_year,
               ST_Y(c.centroid::geometry) AS lat,
               ST_X(c.centroid::geometry) AS lon,
               COALESCE(s.shared_trait_ids, ARRAY[]::text[]) AS shared_trait_ids,
               (s.shared_trait_ids IS NOT NULL) AS has_trait_edge
        FROM carrier c
        CROSS JOIN src_ref sr
        LEFT JOIN shared s ON s.carrier_id = c.id
        WHERE c.id <> %(src_id)s
          AND NOT (c.id = ANY(%(excluded)s::text[]))
          AND {where_time}
          AND (
            s.shared_trait_ids IS NOT NULL
            OR (c.centroid IS NOT NULL AND sr.centroid IS NOT NULL
                AND ST_DWithin(c.centroid, sr.centroid, 3000000))
          )
        ORDER BY {order}
        LIMIT %(lim)s
        """,
        {
            "src_id": source_carrier_id,
            "trait_ids": source_trait_ids or [],
            "src_min": source_date_min,
            "src_max": source_date_max,
            "excluded": exclude_ids or [],
            "lim": max_per_hop,
        },
    )
    out = []
    async for r in rows:
        r = dict(r)
        out.append({
            "id": r["id"],
            "display_name": r["display_name"],
            "type": r["type"],
            "date_min_year": r["date_min_year"],
            "date_max_year": r["date_max_year"],
            "centroid": _point(r["lat"], r["lon"]),
            "shared_trait_ids": list(r.get("shared_trait_ids") or []),
        })
    return out


async def _carrier_trait_ids(conn, carrier_id: str) -> list[str]:
    """Distinct trait_ids carried by a carrier across all its mix snapshots."""
    rows = await conn.execute(
        "SELECT DISTINCT trait_id FROM carrier_trait_mix WHERE carrier_id = %s",
        (carrier_id,),
    )
    return [r["trait_id"] async for r in rows]


async def resolve_carrier_lineage(
    conn,
    carrier_id: str,
    year: int,
    direction: str = "both",
    limit_per_side: int = 12,
    max_depth: int = 4,
    max_per_hop: int = 6,
) -> dict:
    """
    Returns the multi-hop lineage DAG rooted at `carrier_id`.

    Traversal:
      * Past direction expands hop-by-hop into temporally older carriers
        that share trait_ids (or are spatially close) with each frontier
        node — depth 1 is the focal's direct ancestors, depth 2 is *their*
        ancestors, and so on.
      * Future direction is the symmetric forward expansion.

    The result includes:
      * `focal`: the root carrier (depth=0, side='focal').
      * `nodes`: every unique carrier encountered, with `depth` (hops from
        focal) and `side` ('past' | 'future' | 'focal').
      * `edges`: every (parent → child) hop. For past edges,
        `from_id` is the older carrier, `to_id` is the newer one; for
        future edges, vice versa. Edges always point older → newer
        temporally so the frontend can lay out the graph in time.
      * `ancestors` / `descendants` (legacy, depth-1 only) for backward
        compatibility with the original 1-hop response shape.

    `max_depth` caps the BFS depth (default 4); `max_per_hop` caps how many
    new neighbors any single source contributes per hop (default 6). Both
    bound the graph size — population ancestry graphs converge fast in
    practice (~30–60 unique nodes at the defaults).
    """
    direction = direction.lower()
    if direction not in {"past", "future", "both"}:
        raise ValueError(f"direction must be past|future|both, got {direction!r}")

    focal_row = await conn.execute(
        """
        SELECT id, display_name, type, date_min_year, date_max_year,
               ST_Y(centroid::geometry) AS lat,
               ST_X(centroid::geometry) AS lon
        FROM carrier
        WHERE id = %s
        """,
        (carrier_id,),
    )
    focal = await focal_row.fetchone()
    if not focal:
        return {
            "focal": None, "nodes": [], "edges": [],
            "ancestors": [], "descendants": [],
            "max_depth": max_depth,
        }
    focal = dict(focal)
    focal_node = {
        "id": focal["id"],
        "display_name": focal["display_name"],
        "type": focal["type"],
        "date_min_year": focal["date_min_year"],
        "date_max_year": focal["date_max_year"],
        "centroid": _point(focal["lat"], focal["lon"]),
        "shared_trait_ids": [],
        "depth": 0,
        "side": "focal",
    }
    nodes: list[dict] = [focal_node]
    edges: list[dict] = []
    visited: set[str] = {focal["id"]}
    # Per-carrier trait_ids cache so we don't re-fetch within a BFS.
    trait_cache: dict[str, list[str]] = {focal["id"]: await _carrier_trait_ids(conn, focal["id"])}
    # Per-carrier date bounds cache (frontier carriers need them for the
    # temporal predicate without re-querying).
    bounds: dict[str, tuple[int, int]] = {
        focal["id"]: (focal["date_min_year"], focal["date_max_year"])
    }

    async def _bfs(side: str) -> list[dict]:
        """Run the BFS for one side and return depth-1 nodes for the legacy
        `ancestors` / `descendants` arrays."""
        depth_one: list[dict] = []
        frontier: list[str] = [focal["id"]]
        for depth in range(1, max_depth + 1):
            next_frontier: list[str] = []
            for src_id in frontier:
                src_min, src_max = bounds[src_id]
                src_traits = trait_cache.get(src_id) or []
                if not src_traits:
                    src_traits = await _carrier_trait_ids(conn, src_id)
                    trait_cache[src_id] = src_traits
                neighbors = await _one_hop_lineage(
                    conn,
                    source_carrier_id=src_id,
                    source_trait_ids=src_traits,
                    source_date_min=src_min,
                    source_date_max=src_max,
                    side=side,
                    max_per_hop=max_per_hop,
                    exclude_ids=list(visited),
                )
                for nb in neighbors:
                    # Edges are always older → newer temporally; for past
                    # hops the *neighbor* is older than the source, for
                    # future hops the *source* is older than the neighbor.
                    if side == "past":
                        edges.append({
                            "from_id": nb["id"],
                            "to_id": src_id,
                            "side": "past",
                            "shared_trait_ids": nb["shared_trait_ids"],
                        })
                    else:
                        edges.append({
                            "from_id": src_id,
                            "to_id": nb["id"],
                            "side": "future",
                            "shared_trait_ids": nb["shared_trait_ids"],
                        })

                    if nb["id"] in visited:
                        continue
                    visited.add(nb["id"])
                    bounds[nb["id"]] = (nb["date_min_year"], nb["date_max_year"])
                    node = {**nb, "depth": depth, "side": side}
                    nodes.append(node)
                    next_frontier.append(nb["id"])
                    if depth == 1:
                        depth_one.append(nb)
            frontier = next_frontier
            if not frontier:
                break
        return depth_one

    # honor `limit_per_side` by slicing the depth-1 output (kept for
    # backward compat with the prior 1-hop callers).
    ancestors_d1: list[dict] = []
    descendants_d1: list[dict] = []
    if direction in {"past", "both"}:
        ancestors_d1 = (await _bfs("past"))[:limit_per_side]
    if direction in {"future", "both"}:
        descendants_d1 = (await _bfs("future"))[:limit_per_side]

    return {
        "focal": focal_node,
        "nodes": nodes,
        "edges": edges,
        "ancestors": ancestors_d1,
        "descendants": descendants_d1,
        "max_depth": max_depth,
    }


async def resolve_carrier_claims(
    conn,
    carrier_id: str,
    perspective_ids: list[str],
) -> list[dict]:
    """
    Returns all claims relevant to a carrier, resolved per active Perspective.

    "Relevant" here means a claim whose subject is one of:
      * the carrier itself (subject_type=Carrier),
      * one of the carrier's CarrierTraitMix rows,
      * a PropagationEvent whose destination is within the carrier's extent (or
        within ~1500 km of the centroid if no extent polygon exists), OR whose
        source_trait_ids overlap any trait the carrier carries.

    Each returned claim includes per-Perspective stance + override + sources
    (re-uses resolve_claim) plus a `subject_kind` discriminator and a derived
    `has_disagreement` flag that the frontend uses to drive the diff overlay.
    """
    if not perspective_ids:
        perspective_ids = await _default_perspective_ids(conn)

    carrier_row = await conn.execute(
        """
        SELECT id, extent IS NOT NULL AS has_extent, centroid
        FROM carrier
        WHERE id = %s
        """,
        (carrier_id,),
    )
    carrier = await carrier_row.fetchone()
    if not carrier:
        return []

    claim_id_rows = await conn.execute(
        """
        WITH carrier_traits AS (
            SELECT array_agg(DISTINCT trait_id) AS trait_ids
            FROM carrier_trait_mix
            WHERE carrier_id = %(cid)s
        ),
        relevant_props AS (
            SELECT pe.id
            FROM propagation_event pe
            CROSS JOIN carrier_traits ct
            JOIN carrier c ON c.id = %(cid)s
            WHERE
              -- Destination intersects the carrier's authored extent ...
              (c.extent IS NOT NULL AND ST_Intersects(pe.destination_point, c.extent))
              -- ... or falls within a buffer around the centroid
              OR (c.extent IS NULL AND c.centroid IS NOT NULL
                  AND ST_DWithin(pe.destination_point, c.centroid, %(radius)s))
              -- ... or shares a trait with the carrier's mix
              OR (ct.trait_ids IS NOT NULL AND pe.source_trait_ids && ct.trait_ids)
        )
        SELECT DISTINCT id
        FROM claim
        WHERE
          -- [AUTO-THREAT] claims are surfaced separately by the
          -- /carrier/{id}/threats endpoint and shouldn't double up in
          -- the "Claims about this population" panel section.
          statement NOT LIKE '[AUTO-THREAT]%%'
          AND (
            (lower(subject_type) IN ('carrier') AND subject_id = %(cid)s)
            OR (lower(subject_type) IN ('carriertrait_mix','carrier_trait_mix')
                AND subject_id LIKE %(cid_prefix)s)
            OR (lower(subject_type) IN ('propagationevent','propagation_event')
                AND subject_id IN (SELECT id FROM relevant_props))
          )
        ORDER BY id
        """,
        {
            "cid": carrier_id,
            "cid_prefix": f"{carrier_id}:%",
            "radius": _PROP_RELEVANCE_RADIUS_M,
        },
    )
    claim_ids = [r["id"] async for r in claim_id_rows]

    resolved: list[dict] = []
    for cid in claim_ids:
        claim = await resolve_claim(conn, cid, perspective_ids)
        # Disagreement = stances differ across the active perspectives.
        stances = {pv["stance"] for pv in claim["perspectives"].values()}
        claim["has_disagreement"] = len(stances) > 1
        claim["subject_kind"] = _normalize_subject_type(claim["subject_type"])
        resolved.append(claim)

    return resolved
