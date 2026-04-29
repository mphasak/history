/**
 * Geographically-plausible routing for lineage connector lines.
 *
 * The default lineage edge geometry is a straight LineString from one
 * carrier centroid to another, which produces obvious nonsense (a line
 * cutting straight across the Pacific from Siberia to South America, or
 * straight through the Mediterranean from sub-Saharan Africa to the Levant).
 * This module hand-curates a small set of major migration *waypoints*
 * (Bering, Khyber, Levantine corridor, Wallacea) and a list of bounding-
 * box predicates that match edges crossing those choke points.
 *
 * For each edge we test the predicates in order and emit a polyline that
 * threads through the matching waypoints. Edges that don't match any rule
 * stay as a straight 2-point LineString — paleo movements within a region
 * (e.g. the Bantu expansion across Africa) read fine without curvature
 * because the endpoints are close together.
 *
 * Coordinates are [lon, lat] throughout (matches MapLibre's GeoJSON
 * convention).
 */
type LngLat = [number, number]

interface Route {
  /** Human-readable rationale shown in code review / debug, not surfaced in UI. */
  name: string
  match: (from: LngLat, to: LngLat) => boolean
  /** Waypoints inserted between `from` and `to`, in order. */
  waypoints: LngLat[]
}

const inBox = (
  p: LngLat,
  west: number,
  south: number,
  east: number,
  north: number,
): boolean =>
  p[0] >= west && p[0] <= east && p[1] >= south && p[1] <= north

const ROUTES: Route[] = [
  // ── Bering Land Bridge: ANY Old-World ↔ N-Americas edge.
  //
  // Earlier this rule only matched when the non-Americas endpoint was
  // specifically in (60–180 E, 35–80 N). That left edges from e.g. the
  // First Americans (lat 50, lon -115) to a deeper-time Levantine /
  // European ancestor cutting straight across the Atlantic, which is
  // historically nonsense — every Americas-bound migration came through
  // Beringia. We now match any edge with one endpoint in N America (lon
  // < -50, lat > -10 to skip South-America-only edges) and the other
  // east of -30, and thread through a NE-Asia waypoint (≈ Lake Baikal)
  // before the strait so the Old-World-side approach reads as land-route
  // across Eurasia rather than a straight line through Greenland.
  //
  // South-America-only edges (both endpoints lat < -10) stay straight —
  // their relevant migrations are intra-Americas Holocene moves, not a
  // Bering trip.
  {
    name: 'Old World → N Americas via Bering',
    match: (f, t) => f[0] > -30 && t[0] < -50 && t[1] > -10,
    waypoints: [[105, 55], [170, 62], [-170, 66], [-155, 64], [-140, 60]],
  },
  {
    name: 'N Americas → Old World via Bering',
    match: (f, t) => f[0] < -50 && f[1] > -10 && t[0] > -30,
    waypoints: [[-140, 60], [-155, 64], [-170, 66], [170, 62], [105, 55]],
  },

  // S-America ↔ Old World. Same Bering trip but with two extra
  // waypoints down through Central America so the line doesn't cut
  // straight across the Pacific from e.g. Mal'ta-Buret' to Mapuche.
  {
    name: 'Old World → S Americas via Bering + Mesoamerica',
    match: (f, t) => f[0] > -30 && t[0] < -50 && t[1] <= -10,
    waypoints: [[105, 55], [170, 62], [-170, 66], [-155, 64], [-110, 35], [-90, 15], [-80, 0]],
  },
  {
    name: 'S Americas → Old World via Mesoamerica + Bering',
    match: (f, t) => f[0] < -50 && f[1] <= -10 && t[0] > -30,
    waypoints: [[-80, 0], [-90, 15], [-110, 35], [-155, 64], [-170, 66], [170, 62], [105, 55]],
  },

  // ── Sundaland → Sahul (Australia / Papua New Guinea). The crossing
  // requires open-water hops through Wallacea; mark via Wallace and the
  // short Sahul leg so the connector reads as island-hopping rather than
  // straight ocean traversal.
  {
    name: 'Sundaland → Sahul',
    match: (f, t) => inBox(f, 90, -10, 130, 25) && inBox(t, 125, -50, 180, -5),
    waypoints: [[120, -2], [128, -5], [134, -8]],
  },
  {
    name: 'Sahul → Sundaland',
    match: (f, t) => inBox(f, 125, -50, 180, -5) && inBox(t, 90, -10, 130, 25),
    waypoints: [[134, -8], [128, -5], [120, -2]],
  },

  // ── Sub-Saharan Africa ↔ Eurasia via Levantine corridor (Sinai, Levant).
  // Catches the OOA northern route and any later N-Africa ↔ Levant
  // movements (Egyptian → Anatolian Farmer, etc.). Bab-el-Mandeb southern
  // route is much closer to the centroid line so it doesn't need
  // adjustment.
  {
    name: 'Africa → Eurasia via Levant',
    match: (f, t) =>
      inBox(f, -20, -10, 55, 30) &&
      (t[1] > 35 || (t[1] > 25 && t[0] > 50)),
    waypoints: [[32, 28], [35, 32]],
  },
  {
    name: 'Eurasia → Africa via Levant',
    match: (f, t) =>
      (f[1] > 35 || (f[1] > 25 && f[0] > 50)) &&
      inBox(t, -20, -10, 55, 30),
    waypoints: [[35, 32], [32, 28]],
  },

  // ── Pontic-Caspian Steppe → South Asia via Bactria / Khyber. The
  // headline Indo-European route — without this the line bisects the
  // Tibetan Plateau, which is wrong both archaeologically and as terrain.
  {
    name: 'Steppe → South Asia via Khyber',
    match: (f, t) => inBox(f, 30, 42, 90, 60) && inBox(t, 60, 5, 95, 35),
    waypoints: [[63, 41], [66, 36], [71, 34]],
  },
  {
    name: 'South Asia → Steppe via Khyber',
    match: (f, t) => inBox(f, 60, 5, 95, 35) && inBox(t, 30, 42, 90, 60),
    waypoints: [[71, 34], [66, 36], [63, 41]],
  },

  // ── East Asia → SE Asia / Pacific. Lapita / Austronesian / rice-farmer
  // dispersals all funnel through the Taiwan / Philippines corridor. Without
  // this the line cuts straight through mainland China.
  {
    name: 'E Asia → SE Asia / Oceania',
    match: (f, t) => inBox(f, 100, 25, 145, 50) && inBox(t, 110, -25, 180, 25),
    waypoints: [[120, 23], [122, 15], [125, 5]],
  },

  // ── Levant / Arabia → Oceania (the OOA southern-coastal route). Spans
  // ~120° of longitude; without waypoints the line cuts straight through
  // the Indian Ocean. Threads through the Indus delta, peninsular India,
  // SE Asia, and Sundaland → Sahul.
  {
    name: 'Levant → Oceania (southern coastal route)',
    match: (f, t) => inBox(f, 25, 12, 60, 40) && inBox(t, 110, -50, 180, -5),
    waypoints: [[55, 22], [70, 22], [85, 18], [100, 8], [120, 0], [128, -5], [134, -8]],
  },

  // ── Levant / Arabia → East Asia. Same southern coastal route minus the
  // Wallacea hop; carries OOA → Tianyuan and Levant → Han-era populations
  // around the Tibetan Plateau via India.
  {
    name: 'Levant → East Asia (via India)',
    match: (f, t) => inBox(f, 25, 12, 60, 40) && inBox(t, 95, 15, 145, 50),
    waypoints: [[55, 22], [70, 22], [85, 18], [100, 8], [115, 22]],
  },

  // ── Africa → Oceania. Composes the Levant route + Oceanic route. We
  // route through the Levantine corridor first, then continue along the
  // southern coastal path.
  {
    name: 'Africa → Oceania (via Levant + SE Asia)',
    match: (f, t) => inBox(f, -20, -10, 55, 30) && inBox(t, 110, -50, 180, -5),
    waypoints: [[32, 28], [35, 32], [55, 22], [70, 22], [85, 18], [100, 8], [120, 0], [128, -5], [134, -8]],
  },
]

/**
 * Returns a polyline of [lon, lat] points connecting `from` to `to` through
 * the appropriate waypoints (when a route rule matches), or just
 * `[from, to]` for edges with no special routing.
 */
export function routeBetween(from: LngLat, to: LngLat): LngLat[] {
  for (const r of ROUTES) {
    if (r.match(from, to)) {
      return [from, ...r.waypoints, to]
    }
  }
  return [from, to]
}

/**
 * Position of a pulse dot at parameter `t ∈ [0, 1]` along a polyline.
 *
 * Walks the polyline accumulating segment lengths in degree-space (good
 * enough at continent scale — we're not navigating, just sliding a marker).
 * The dot moves at a constant degree-rate, so on short segments it appears
 * to slow down and on long segments it speeds up; this reads as "fast
 * across the open ocean, careful through the strait" which is a happy
 * accident.
 */
export function pointAlongPolyline(
  poly: LngLat[],
  t: number,
): LngLat {
  if (poly.length === 0) return [0, 0]
  if (poly.length === 1) return poly[0]
  const tt = Math.min(1, Math.max(0, t))
  // Per-segment lengths in degrees (Euclidean — sufficient for visualization).
  const segLen: number[] = []
  let total = 0
  for (let i = 0; i < poly.length - 1; i++) {
    const dx = poly[i + 1][0] - poly[i][0]
    const dy = poly[i + 1][1] - poly[i][1]
    const len = Math.hypot(dx, dy)
    segLen.push(len)
    total += len
  }
  if (total === 0) return poly[0]
  const target = tt * total
  let consumed = 0
  for (let i = 0; i < segLen.length; i++) {
    if (consumed + segLen[i] >= target) {
      const local = segLen[i] === 0 ? 0 : (target - consumed) / segLen[i]
      const a = poly[i]
      const b = poly[i + 1]
      return [a[0] + (b[0] - a[0]) * local, a[1] + (b[1] - a[1]) * local]
    }
    consumed += segLen[i]
  }
  return poly[poly.length - 1]
}
