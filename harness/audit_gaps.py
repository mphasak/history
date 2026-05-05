#!/usr/bin/env python3
"""
Audit timespace gaps in carrier coverage.

Crawls a coarse lat/lon grid and, for each cell that was inhabited at some
point, reports stretches of years with zero covering carriers — flanked by a
predecessor (latest carrier ending before the gap) and a successor (earliest
carrier starting after). These are the regions where the map shows nothing
even though humans were demonstrably present before *and* after.

Example: the Yellow River cell at 472 BCE has no carrier — Shang ends at
-1046, Han starts at -200, leaving an ~846-year hole covering the entire
Zhou / Spring-and-Autumn / Warring States period.

The audit deliberately ignores the deep paleolithic before any hominid is
recorded in a cell — those "gaps" are just pre-arrival stretches.

Usage:
    python3 harness/audit_gaps.py                       # default: post -15000 only
    python3 harness/audit_gaps.py --top 30              # 30 worst gaps
    python3 harness/audit_gaps.py --min-gap 200         # only gaps >= 200 yrs
    python3 harness/audit_gaps.py --from-year -3000000  # include deep paleolithic
    python3 harness/audit_gaps.py --cell 100,30,115,40  # one cell, full timeline
    python3 harness/audit_gaps.py --json                # machine-readable

The script mirrors the resolver's coverage logic (carrier_extent_snapshot →
carrier.extent → ST_Buffer(centroid, type-keyed radius)) but is permissive:
a carrier is considered to cover a cell across its entire date range if any
of those geometries ever intersects the cell. False negatives (real gaps
missed) matter more than false positives (gaps flagged that are actually
covered by a snapshot we didn't model precisely).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field

import psycopg
from psycopg.rows import dict_row


DEFAULT_DSN = os.environ.get(
    "DATABASE_URL", "postgresql://history_sim:dev@localhost:5433/history_sim"
)


# ---------------------------------------------------------------------------
# Sampling: dense in the Holocene + historical, sparse in deep paleolithic.
# ---------------------------------------------------------------------------
def sample_years() -> list[int]:
    ys: list[int] = []
    # Historical + Holocene: every 50 yrs from -10000 to 2025
    ys.extend(range(-10000, 2026, 50))
    # Last Glacial: every 500 yrs from -50000 to -10000
    ys.extend(range(-50000, -10000, 500))
    # Late Pleistocene: every 5000 yrs from -300000 to -50000
    ys.extend(range(-300000, -50000, 5000))
    # Earlier Pleistocene: every 50000 yrs back to -3M
    ys.extend(range(-3_000_000, -300000, 50_000))
    return sorted(set(ys))


# ---------------------------------------------------------------------------
# Grid: 15° lon × 10° lat. Empirically catches regional-scale gaps without
# being so coarse it lumps Britain in with Iran. Tweak via --grid-deg if needed.
# ---------------------------------------------------------------------------
def grid_cells(lon_step: float, lat_step: float) -> list[tuple[float, float, float, float]]:
    cells = []
    lon = -180.0
    while lon < 180.0:
        lat = -60.0
        while lat < 80.0:
            cells.append((lon, lat, lon + lon_step, lat + lat_step))
            lat += lat_step
        lon += lon_step
    return cells


# ---------------------------------------------------------------------------
# Hand-rolled region labels for human readability. Maps a (lon_center,
# lat_center) into a coarse name. Falls back to "lat,lon" if no match.
# ---------------------------------------------------------------------------
REGION_LABELS = [
    # (W, S, E, N, label)
    (-170, 50, -130, 75, "Alaska / Yukon"),
    (-130, 45, -100, 60, "NW North America"),
    (-130, 30, -100, 45, "American West"),
    (-100, 30, -70, 50, "Eastern N America"),
    (-100, 20, -85, 35, "American South / Gulf"),
    (-105, 10, -85, 25, "Mesoamerica"),
    (-85, 5, -55, 20, "N Andes / Caribbean"),
    (-85, -25, -55, 5, "Amazon Basin"),
    (-80, -55, -55, -25, "Southern Cone"),
    (-25, 50, 10, 75, "British Isles / N Atlantic"),
    (-15, 35, 10, 50, "Iberia / W Mediterranean"),
    (10, 35, 30, 50, "Italy / Balkans"),
    (10, 50, 30, 70, "N Europe / Scandinavia"),
    (30, 35, 60, 60, "E Europe / Caucasus / Caspian"),
    (-20, 5, 30, 35, "N Africa / Sahara"),
    (-20, -10, 30, 5, "W Africa"),
    (30, -15, 50, 15, "Horn / E Africa"),
    (10, -35, 40, -15, "Southern Africa"),
    (30, 15, 60, 40, "Levant / Mesopotamia / Iran"),
    (60, 5, 95, 35, "S Asia"),
    (60, 35, 95, 60, "Central Asia / Steppe"),
    (95, 30, 125, 45, "Yellow River / N China"),
    (95, 15, 125, 30, "S China / Yangtze"),
    (125, 30, 150, 50, "Korea / NE China"),
    (125, 25, 150, 45, "Japan"),
    (95, -15, 130, 15, "SE Asia / Indochina"),
    (95, -15, 145, 5, "Maritime SE Asia"),
    (110, -45, 155, -10, "Australia"),
    (140, -50, 180, -10, "Pacific / Oceania"),
    (60, 60, 180, 80, "Siberia / Arctic"),
]


def label_for(west: float, south: float, east: float, north: float) -> str:
    cx, cy = (west + east) / 2, (south + north) / 2
    for w, s, e, n, name in REGION_LABELS:
        if w <= cx <= e and s <= cy <= n:
            return name
    return f"{cy:+.0f}°,{cx:+.0f}°"


def fmt_year(y: int) -> str:
    if y < 0:
        if y <= -10000:
            return f"{-y // 1000} kya"
        return f"{-y} BCE"
    return f"{y} CE"


# ---------------------------------------------------------------------------
# Carrier coverage. Returns (id, display_name, type, date_min, date_max) for
# every carrier that ever intersects the cell — via authored extent, snapshot,
# or buffered centroid (matching the resolver).
# ---------------------------------------------------------------------------
COVERAGE_SQL = """
WITH cell AS (
  SELECT ST_MakeEnvelope(%(w)s, %(s)s, %(e)s, %(n)s, 4326)::geography AS g,
         ST_Centroid(ST_MakeEnvelope(%(w)s, %(s)s, %(e)s, %(n)s, 4326))::geography AS ctr
)
SELECT c.id, c.display_name, c.type, c.date_min_year, c.date_max_year,
       c.archaeological_culture, c.linguistic_affiliation,
       CASE
         WHEN c.extent IS NOT NULL
              AND ST_Intersects(c.extent, (SELECT g FROM cell)) THEN 'extent'
         WHEN EXISTS (
           SELECT 1 FROM carrier_extent_snapshot s
           WHERE s.carrier_id = c.id
             AND ST_Intersects(s.geometry, (SELECT g FROM cell))
         ) THEN 'snapshot'
         ELSE 'buffer'
       END AS via
FROM carrier c, cell
WHERE c.centroid IS NOT NULL
  AND (
    (c.extent IS NOT NULL AND ST_Intersects(c.extent, cell.g))
    OR EXISTS (
      SELECT 1 FROM carrier_extent_snapshot s
      WHERE s.carrier_id = c.id
        AND ST_Intersects(s.geometry, cell.g)
    )
    OR ST_DWithin(c.centroid, cell.ctr,
         CASE c.type
           WHEN 'population' THEN 800000
           WHEN 'community' THEN 300000
           WHEN 'institution' THEN 100000
           WHEN 'nation_state' THEN 600000
           WHEN 'sub_national_region' THEN 250000
           WHEN 'diaspora' THEN 1500000
           WHEN 'virtual' THEN 500000
           ELSE 500000
         END)
  )
ORDER BY c.date_min_year, c.date_max_year;
"""

GENETIC_MIX_SQL = """
SELECT carrier_id, trait_id, fraction
FROM carrier_trait_mix
WHERE domain = 'genetic'
  AND carrier_id = ANY(%(ids)s);
"""


@dataclass
class Carrier:
    id: str
    display_name: str
    type: str
    date_min: int
    date_max: int
    via: str
    archaeological_culture: str | None = None
    linguistic_affiliation: str | None = None
    genetic_mix: dict[str, float] = field(default_factory=dict)


# Words too generic to count as a culture/language match.
_NAME_STOPWORDS = {
    "the", "of", "and", "or", "a", "an", "early", "late", "middle",
    "old", "new", "ancient", "modern", "northern", "southern", "eastern",
    "western", "north", "south", "east", "west", "central", "upper", "lower",
    "period", "culture", "empire", "kingdom", "dynasty", "people", "peoples",
    "phase", "era", "age", "neolithic", "mesolithic", "paleolithic",
    "ce", "bce", "yr", "yrs", "bp",
}


def _tokens(s: str | None) -> set[str]:
    if not s:
        return set()
    out = set()
    for w in s.replace("/", " ").replace("-", " ").replace(",", " ").split():
        w = "".join(ch for ch in w.lower() if ch.isalpha())
        if w and w not in _NAME_STOPWORDS:
            out.add(w)
    return out


def _genetic_overlap(p: Carrier, s: Carrier) -> float:
    """Sum of min(p_frac, s_frac) across genetic traits — 0 (disjoint) to 1
    (identical). Returns -1 when either side has no genetic data (unknown)."""
    if not p.genetic_mix or not s.genetic_mix:
        return -1.0
    traits = set(p.genetic_mix) | set(s.genetic_mix)
    return sum(min(p.genetic_mix.get(t, 0.0), s.genetic_mix.get(t, 0.0)) for t in traits)


def classify_gap(p: Carrier | None, s: Carrier | None, gap_length: int) -> tuple[str, dict]:
    """Decide whether the gap is best fixed by extending an existing carrier
    (continuity) or by inserting a new bridge carrier (replacement / new
    polity)."""
    if p is None or s is None:
        return ("BOOKEND", {"reason": "missing predecessor or successor"})

    g = _genetic_overlap(p, s)

    pname_match = bool(_tokens(p.linguistic_affiliation) & _tokens(s.linguistic_affiliation))
    cname_match = bool(_tokens(p.archaeological_culture) & _tokens(s.archaeological_culture))

    details = {
        "genetic_overlap": None if g < 0 else round(g, 2),
        "linguistic_match": pname_match,
        "cultural_match": cname_match,
        "pred_dominant_trait": (
            max(p.genetic_mix, key=p.genetic_mix.get) if p.genetic_mix else None
        ),
        "succ_dominant_trait": (
            max(s.genetic_mix, key=s.genetic_mix.get) if s.genetic_mix else None
        ),
    }

    # Strong continuity signals → EXTEND. The fix is to widen one carrier's
    # date range (or seed a near-identical descendent) instead of inventing
    # a wholly new population.
    if g >= 0.7 or (g >= 0.5 and (pname_match or cname_match)):
        return ("EXTEND", details)

    # Strong discontinuity → BRIDGE. The two flanking carriers are
    # genuinely different populations; a new carrier needs to fill the time.
    if 0 <= g < 0.3 and not pname_match and not cname_match:
        return ("BRIDGE", details)

    # Genetic info missing → fall back on names alone.
    if g < 0:
        if pname_match or cname_match:
            return ("EXTEND", details)
        # No info at all — call it unclassified rather than guess.
        return ("UNCLEAR", details)

    return ("BLEND", details)


@dataclass
class Gap:
    cell: tuple[float, float, float, float]
    label: str
    start_year: int
    end_year: int
    predecessor: Carrier | None
    successor: Carrier | None
    n_carriers_ever: int
    first_carrier_year: int  # earliest date_min in the cell — pre-arrival cutoff
    kind: str = "UNCLEAR"
    classification_details: dict = field(default_factory=dict)

    @property
    def length(self) -> int:
        return self.end_year - self.start_year + 1


def find_gaps_in_cell(
    cell: tuple[float, float, float, float],
    carriers: list[Carrier],
    years: list[int],
    min_gap_years: int,
) -> list[Gap]:
    if not carriers:
        return []
    first_arrival = min(c.date_min for c in carriers)
    last_departure = max(c.date_max for c in carriers)
    label = label_for(*cell)

    # Walk sample years that fall within [first_arrival, last_departure].
    in_window = [y for y in years if first_arrival <= y <= last_departure]
    if not in_window:
        return []

    # For each sample year, count active carriers covering the cell.
    active_per_year: list[tuple[int, int]] = []
    for y in in_window:
        n = sum(1 for c in carriers if c.date_min <= y <= c.date_max)
        active_per_year.append((y, n))

    # Run-length-encode zero stretches, then expand into gap intervals.
    gaps: list[Gap] = []
    i = 0
    while i < len(active_per_year):
        if active_per_year[i][1] != 0:
            i += 1
            continue
        j = i
        while j < len(active_per_year) and active_per_year[j][1] == 0:
            j += 1
        # Empty stretch covers sample years [i..j-1]. Approximate the actual
        # gap interval as (last_active_before + 1) .. (next_active_after - 1).
        last_before = active_per_year[i - 1][0] if i > 0 else first_arrival
        next_after = active_per_year[j][0] if j < len(active_per_year) else last_departure
        # Be more precise by snapping to actual carrier boundaries:
        gap_start = max(
            (c.date_max + 1 for c in carriers if c.date_max < active_per_year[i][0]),
            default=first_arrival,
        )
        gap_end = min(
            (c.date_min - 1 for c in carriers if c.date_min > active_per_year[j - 1][0]),
            default=last_departure,
        )
        if gap_end < gap_start:
            i = j + 1
            continue
        # Identify predecessor and successor carriers.
        pred = max(
            (c for c in carriers if c.date_max < gap_start),
            key=lambda c: c.date_max,
            default=None,
        )
        succ = min(
            (c for c in carriers if c.date_min > gap_end),
            key=lambda c: c.date_min,
            default=None,
        )
        if gap_end - gap_start + 1 >= min_gap_years:
            kind, det = classify_gap(pred, succ, gap_end - gap_start + 1)
            gaps.append(
                Gap(
                    cell=cell,
                    label=label,
                    start_year=gap_start,
                    end_year=gap_end,
                    predecessor=pred,
                    successor=succ,
                    n_carriers_ever=len(carriers),
                    first_carrier_year=first_arrival,
                    kind=kind,
                    classification_details=det,
                )
            )
        i = j + 1
    return gaps


def fetch_cell_carriers(conn, cell) -> list[Carrier]:
    w, s, e, n = cell
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(COVERAGE_SQL, {"w": w, "s": s, "e": e, "n": n})
        carriers = [
            Carrier(
                id=r["id"],
                display_name=r["display_name"],
                type=r["type"],
                date_min=r["date_min_year"],
                date_max=r["date_max_year"],
                via=r["via"],
                archaeological_culture=r["archaeological_culture"],
                linguistic_affiliation=r["linguistic_affiliation"],
            )
            for r in cur.fetchall()
        ]
        if carriers:
            cur.execute(GENETIC_MIX_SQL, {"ids": [c.id for c in carriers]})
            mix_by_carrier: dict[str, dict[str, float]] = {}
            for r in cur.fetchall():
                mix_by_carrier.setdefault(r["carrier_id"], {})[r["trait_id"]] = float(
                    r["fraction"]
                )
            for c in carriers:
                c.genetic_mix = mix_by_carrier.get(c.id, {})
        return carriers


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def render_gap_text(g: Gap) -> str:
    pred = (
        f"after {g.predecessor.display_name} (ends {fmt_year(g.predecessor.date_max)})"
        if g.predecessor
        else "no predecessor"
    )
    succ = (
        f"before {g.successor.display_name} (starts {fmt_year(g.successor.date_min)})"
        if g.successor
        else "no successor"
    )
    det = g.classification_details
    g_overlap = det.get("genetic_overlap")
    bits = []
    if g_overlap is not None:
        bits.append(f"gen {g_overlap:.2f}")
    if det.get("linguistic_match"):
        bits.append("ling✓")
    if det.get("cultural_match"):
        bits.append("cult✓")
    sim = ", ".join(bits) if bits else "no comparable data"
    return (
        f"  [{g.kind:<7}] [{g.length:>5} yr] {g.label:<30} "
        f"{fmt_year(g.start_year)} → {fmt_year(g.end_year)}  "
        f"({sim})  {pred}; {succ}"
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dsn", default=DEFAULT_DSN)
    ap.add_argument("--lon-step", type=float, default=15.0, help="Cell width (deg lon)")
    ap.add_argument("--lat-step", type=float, default=10.0, help="Cell height (deg lat)")
    ap.add_argument("--min-gap", type=int, default=100, help="Ignore gaps shorter than N years")
    ap.add_argument(
        "--from-year",
        type=int,
        default=-15000,
        help="Ignore gaps that end before this year. Default -15000 keeps the report"
        " focused on post-LGM / Holocene / historical. Set to -3000000 to include"
        " the full paleolithic.",
    )
    ap.add_argument(
        "--no-merge",
        action="store_true",
        help="Don't merge gaps from adjacent cells with identical (label, predecessor, successor).",
    )
    ap.add_argument(
        "--kind",
        choices=["EXTEND", "BRIDGE", "BLEND", "BOOKEND", "UNCLEAR"],
        default=None,
        help="Filter to one classification (EXTEND = continuity, fix by extending"
        " a date range; BRIDGE = new population needed; BLEND = mixed; BOOKEND ="
        " missing pred or succ; UNCLEAR = no genetic/name signal).",
    )
    ap.add_argument(
        "--top",
        type=int,
        default=0,
        help="Show only the N longest gaps (0 = all). Sorted by length desc.",
    )
    ap.add_argument(
        "--cell",
        type=str,
        default=None,
        help="Audit one cell only: W,S,E,N (e.g. 100,30,115,40 for Yellow River)",
    )
    ap.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    args = ap.parse_args()

    if args.cell:
        try:
            w, s, e, n = (float(x) for x in args.cell.split(","))
        except ValueError:
            print(f"--cell expects W,S,E,N floats, got {args.cell!r}", file=sys.stderr)
            sys.exit(2)
        cells = [(w, s, e, n)]
    else:
        cells = grid_cells(args.lon_step, args.lat_step)

    years = sample_years()
    all_gaps: list[Gap] = []

    with psycopg.connect(args.dsn) as conn:
        for cell in cells:
            carriers = fetch_cell_carriers(conn, cell)
            gaps = find_gaps_in_cell(cell, carriers, years, args.min_gap)
            all_gaps.extend(gaps)

    # Clip each gap to the [--from-year, +inf) window. A gap whose predecessor
    # is in the deep paleolithic but whose successor is historical (e.g., Sahara
    # Jebel Irhoud at 250kya → Arab conquests at 632 CE) shouldn't report a
    # 250-millennium "length" — only the post-cutoff portion is what the user
    # actually scrolls through. The predecessor's real end_year is preserved
    # in g.predecessor for context.
    clipped: list[Gap] = []
    for g in all_gaps:
        if g.end_year < args.from_year:
            continue
        if g.start_year < args.from_year:
            g.start_year = args.from_year
        if g.length >= args.min_gap:
            clipped.append(g)
    all_gaps = clipped

    # Merge adjacent grid cells that produced the same logical gap. Two gaps
    # collapse if they share (region label, predecessor id, successor id) and
    # their year ranges overlap. We pick the widest [start..end] of the group.
    if not args.no_merge and not args.cell:
        merged: dict[tuple, Gap] = {}
        for g in all_gaps:
            key = (
                g.label,
                g.predecessor.id if g.predecessor else None,
                g.successor.id if g.successor else None,
            )
            if key in merged:
                m = merged[key]
                m.start_year = min(m.start_year, g.start_year)
                m.end_year = max(m.end_year, g.end_year)
            else:
                merged[key] = g
        all_gaps = list(merged.values())

    if args.kind:
        all_gaps = [g for g in all_gaps if g.kind == args.kind]

    all_gaps.sort(key=lambda g: g.length, reverse=True)
    if args.top > 0:
        all_gaps = all_gaps[: args.top]

    if args.json:
        print(
            json.dumps(
                [
                    {
                        "cell": list(g.cell),
                        "label": g.label,
                        "start_year": g.start_year,
                        "end_year": g.end_year,
                        "length_years": g.length,
                        "n_carriers_ever": g.n_carriers_ever,
                        "first_carrier_year": g.first_carrier_year,
                        "kind": g.kind,
                        "classification": g.classification_details,
                        "predecessor": (
                            None
                            if g.predecessor is None
                            else {
                                "id": g.predecessor.id,
                                "display_name": g.predecessor.display_name,
                                "date_max": g.predecessor.date_max,
                            }
                        ),
                        "successor": (
                            None
                            if g.successor is None
                            else {
                                "id": g.successor.id,
                                "display_name": g.successor.display_name,
                                "date_min": g.successor.date_min,
                            }
                        ),
                    }
                    for g in all_gaps
                ],
                indent=2,
            )
        )
        return

    if args.cell:
        cell = cells[0]
        with psycopg.connect(args.dsn) as conn:
            carriers = fetch_cell_carriers(conn, cell)
        print(f"Cell {cell}  ({label_for(*cell)})")
        print(f"  Carriers ever covering this cell: {len(carriers)}")
        for c in carriers:
            print(
                f"    {fmt_year(c.date_min):>10} → {fmt_year(c.date_max):<10} "
                f"[{c.via:<8}] {c.id:<40} {c.display_name}"
            )
        print()
        if not all_gaps:
            print("  No gaps found at this cell.")
        else:
            print(f"  Gaps (>= {args.min_gap} yr):")
            for g in all_gaps:
                print(render_gap_text(g))
        return

    if not all_gaps:
        print(f"No gaps >= {args.min_gap} years found across the grid.")
        return

    by_region: dict[str, list[Gap]] = {}
    for g in all_gaps:
        by_region.setdefault(g.label, []).append(g)

    print(
        f"Found {len(all_gaps)} gap(s) >= {args.min_gap} years across "
        f"{len(by_region)} region(s).  Sorted by length, longest first.\n"
    )
    for g in all_gaps:
        print(render_gap_text(g))

    print("\n── By region (cells aggregated) ──")
    for region, gaps in sorted(by_region.items(), key=lambda kv: -sum(g.length for g in kv[1])):
        total = sum(g.length for g in gaps)
        print(f"  {region:<30} {len(gaps):>3} gap(s), {total:>6} years total")

    print("\n── By kind ──")
    by_kind: dict[str, int] = {}
    by_kind_yr: dict[str, int] = {}
    for g in all_gaps:
        by_kind[g.kind] = by_kind.get(g.kind, 0) + 1
        by_kind_yr[g.kind] = by_kind_yr.get(g.kind, 0) + g.length
    legend = {
        "EXTEND": "fix by widening one carrier's date range (continuous population)",
        "BRIDGE": "fix by adding a new bridge carrier (different population)",
        "BLEND":  "ambiguous; partial genetic overlap or mixed signals",
        "BOOKEND":"missing predecessor or successor — region edge",
        "UNCLEAR":"no genetic/cultural/linguistic data on either side",
    }
    for kind in ["EXTEND", "BLEND", "BRIDGE", "BOOKEND", "UNCLEAR"]:
        if kind in by_kind:
            print(f"  {kind:<8} {by_kind[kind]:>3} gap(s), {by_kind_yr[kind]:>6} yr — {legend[kind]}")


if __name__ == "__main__":
    main()
