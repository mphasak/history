import maplibregl from 'maplibre-gl'
import { CarrierView, PropagationEventView, AdmixtureEvent, CarrierLineageResponse } from '../api'
import { DOMAIN_COLORS } from './Map'
import { routeBetween } from '../lib/migrationRoutes'

// Spike: canvas-based particle overlay. Each carrier owns N particles
// rejection-sampled inside its extent_geojson polygon (Polygon or
// MultiPolygon) doing tiny lng/lat Brownian motion around per-particle
// "home" positions, with point-in-polygon containment so they stay inside
// the territory. Migration streams continually emit particles at the origin
// and advance them along a polyline to the destination. In lineage trail
// mode the canvas isn't fully cleared between frames — a translucent fade
// rect produces the smear.

export type ParticleMigrationSource = 'extents' | 'admixture' | 'lineage'

// `rings` is always an array of polygon-pieces; each piece is [outerRing,
// hole1, hole2, ...]; each ring is [[lon, lat], ...]. A GeoJSON Polygon maps
// to one piece, MultiPolygon to many. Same shape regardless of input simplifies
// containment.
type PolygonRings = number[][][][]

interface CarrierParticles {
  carrierId: string
  centroidLon: number
  centroidLat: number
  color: string
  // Source polygon — kept for change detection on world-data updates so
  // re-sampling only happens when the extent actually changes.
  extentSig: string
  rings: PolygonRings | null
  // Bbox of the extent (or a tiny box around the centroid for the buffered
  // fallback). Used for fast outside-test before the polygon containment
  // check, and to derive the per-frame Brownian step magnitude.
  bboxMinLon: number
  bboxMaxLon: number
  bboxMinLat: number
  bboxMaxLat: number
  // Per-particle state. Stored as parallel Float32Arrays for cache locality.
  // `home` is the initial sample (used as the spring anchor); `lon/lat` is
  // the live position; `vLon/vLat` is the lng/lat velocity per second.
  count: number
  homeLon: Float32Array
  homeLat: Float32Array
  pLon: Float32Array
  pLat: Float32Array
  vLon: Float32Array
  vLat: Float32Array
}

interface Migration {
  id: string
  polyline: [number, number][] // lng/lat polyline (already routed through choke points)
  totalLengthDeg: number       // approximate path length in degrees, for spawn cadence
  color: string
  yearMin: number
  yearMax: number
}

interface StreamParticle {
  migrationIdx: number
  t: number       // 0..1 along the polyline
  speed: number   // delta-t per second
  life: number    // accumulated, used as a tiny size jitter
}

// Particle count adapts to extent size so a 4°-wide tribal carrier doesn't
// drown in dots and a continental empire reads as densely populated.
const PARTICLES_MIN = 8
const PARTICLES_MAX = 80
// Visual count target: ~ sqrt(bbox_area_deg²) * scale, clamped. Square-root
// keeps the per-area density roughly constant across two orders of magnitude.
const PARTICLES_PER_DEG = 1.6
// Buffered-fallback (no real extent) carriers get a small fixed cluster
// around the centroid — feels intentional rather than empty.
const PARTICLES_FALLBACK = 7
// Soft spring back to the per-particle home so the distribution stays
// even rather than drifting into a corner over time. Also prevents
// particles from pooling at polygon edges via bounce reflection.
const SPRING_K_PER_SEC = 0.55
const VELOCITY_DECAY_PER_SEC = 1.6   // exponential damping rate
// Brownian velocity injection per second — magnitude is scaled per-carrier
// by extent size (small extents = small noise) so the wander feels right.
const BROWNIAN_NOISE_PER_SEC = 0.9
// The buffered-fallback cluster radius in degrees — small so it reads
// as a tight knot.
const FALLBACK_RADIUS_DEG = 1.2

const PARTICLE_RADIUS_PX = 2.2

const STREAM_SPAWN_PER_SEC_PER_DEG = 0.18   // emission cadence ∝ path length
const STREAM_PARTICLE_RADIUS_PX = 2.6
const STREAM_SPEED_T_PER_SEC = 0.22         // ~4.5s end-to-end at default
const STREAM_FADE_BG = 'rgba(0,0,0,0.18)'   // per-frame overlay for non-trail mode
const STREAM_FADE_BG_TRAIL = 'rgba(0,0,0,0.045)' // gentler — leaves visible trails

// Dim the carrier-cluster particles a bit when streams are flowing so the
// streams read as the foreground motion. Numbers chosen by eye.
const CARRIER_PARTICLE_ALPHA = 0.85

// ─── Geometry helpers ────────────────────────────────────────────────────────

function ringContainsPoint(ring: number[][], lon: number, lat: number): boolean {
  // Ray-cast point-in-polygon for one ring. Caller is responsible for
  // outer/hole semantics.
  let inside = false
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i][0], yi = ring[i][1]
    const xj = ring[j][0], yj = ring[j][1]
    if (((yi > lat) !== (yj > lat)) &&
        (lon < ((xj - xi) * (lat - yi)) / (yj - yi) + xi)) {
      inside = !inside
    }
  }
  return inside
}

function ringsContainPoint(rings: PolygonRings, lon: number, lat: number): boolean {
  // True iff the point is inside the outer ring of any piece AND outside
  // every hole of that piece. Multipiece polygons OR across pieces.
  for (const piece of rings) {
    if (piece.length === 0) continue
    if (!ringContainsPoint(piece[0], lon, lat)) continue
    let inHole = false
    for (let h = 1; h < piece.length; h++) {
      if (ringContainsPoint(piece[h], lon, lat)) { inHole = true; break }
    }
    if (!inHole) return true
  }
  return false
}

interface ExtentInfo {
  rings: PolygonRings
  minLon: number; maxLon: number
  minLat: number; maxLat: number
  /** Bbox area in square degrees — used to budget particle count + step size. */
  bboxAreaDeg: number
}

function parseExtentGeojson(s: string | null | undefined): ExtentInfo | null {
  if (!s) return null
  let geom: GeoJSON.Geometry
  try { geom = JSON.parse(s) as GeoJSON.Geometry } catch { return null }
  let pieces: number[][][][] = []
  if (geom.type === 'Polygon') {
    pieces = [geom.coordinates as number[][][]]
  } else if (geom.type === 'MultiPolygon') {
    pieces = geom.coordinates as number[][][][]
  } else {
    return null
  }
  let minLon = Infinity, maxLon = -Infinity
  let minLat = Infinity, maxLat = -Infinity
  for (const piece of pieces) {
    for (const ring of piece) {
      for (const [x, y] of ring) {
        if (x < minLon) minLon = x
        if (x > maxLon) maxLon = x
        if (y < minLat) minLat = y
        if (y > maxLat) maxLat = y
      }
    }
  }
  if (!isFinite(minLon)) return null
  return {
    rings: pieces,
    minLon, maxLon, minLat, maxLat,
    bboxAreaDeg: Math.max(0.01, (maxLon - minLon) * (maxLat - minLat)),
  }
}

function samplePointInRings(info: ExtentInfo, attempts = 40): [number, number] {
  const w = info.maxLon - info.minLon
  const h = info.maxLat - info.minLat
  for (let i = 0; i < attempts; i++) {
    const lon = info.minLon + Math.random() * w
    const lat = info.minLat + Math.random() * h
    if (ringsContainPoint(info.rings, lon, lat)) return [lon, lat]
  }
  // Pathological narrow polygon: walk the outer-ring vertices and pick one.
  // Strictly inside the polygon by construction.
  const piece = info.rings[0]
  if (piece && piece[0] && piece[0].length > 0) {
    const v = piece[0][Math.floor(Math.random() * piece[0].length)]
    return [v[0], v[1]]
  }
  return [(info.minLon + info.maxLon) / 2, (info.minLat + info.maxLat) / 2]
}

function pathLengthDeg(polyline: [number, number][]): number {
  let total = 0
  for (let i = 1; i < polyline.length; i++) {
    const dx = polyline[i][0] - polyline[i - 1][0]
    const dy = polyline[i][1] - polyline[i - 1][1]
    total += Math.sqrt(dx * dx + dy * dy)
  }
  return total
}

function pointAlongPolylineLngLat(
  polyline: [number, number][],
  t: number,
): [number, number] {
  // Same idea as lib/migrationRoutes.pointAlongPolyline but inlined here so
  // we don't pay the Float64Array allocation per stream particle per frame.
  if (polyline.length === 0) return [0, 0]
  if (polyline.length === 1) return polyline[0]
  const total = pathLengthDeg(polyline)
  if (total === 0) return polyline[0]
  const target = Math.max(0, Math.min(1, t)) * total
  let acc = 0
  for (let i = 1; i < polyline.length; i++) {
    const dx = polyline[i][0] - polyline[i - 1][0]
    const dy = polyline[i][1] - polyline[i - 1][1]
    const seg = Math.sqrt(dx * dx + dy * dy)
    if (acc + seg >= target) {
      const r = seg === 0 ? 0 : (target - acc) / seg
      return [
        polyline[i - 1][0] + dx * r,
        polyline[i - 1][1] + dy * r,
      ]
    }
    acc += seg
  }
  return polyline[polyline.length - 1]
}

export class ParticleOverlay {
  private map: maplibregl.Map
  private container: HTMLElement
  private canvas: HTMLCanvasElement
  private ctx: CanvasRenderingContext2D
  private dpr = 1
  private rafId: number | null = null
  private lastTimeMs = 0
  private visible = false
  private trailMode = false

  private carriers: CarrierParticles[] = []
  private migrations: Migration[] = []
  private streamParticles: StreamParticle[] = []
  private spawnAccumulators: number[] = []   // per-migration partial-particle accumulator

  constructor(map: maplibregl.Map, container: HTMLElement) {
    this.map = map
    this.container = container
    this.canvas = document.createElement('canvas')
    this.canvas.style.cssText = [
      'position:absolute',
      'inset:0',
      'pointer-events:none',
      'z-index:5',
      'display:none',
    ].join(';')
    container.appendChild(this.canvas)
    const ctx = this.canvas.getContext('2d')
    if (!ctx) throw new Error('canvas 2d context unavailable')
    this.ctx = ctx
    this.resize()
    this.map.on('resize', this.resize)
  }

  destroy() {
    this.stop()
    this.map.off('resize', this.resize)
    this.canvas.remove()
  }

  setVisible(v: boolean) {
    if (this.visible === v) return
    this.visible = v
    this.canvas.style.display = v ? 'block' : 'none'
    if (v) {
      // Wipe any leftover trail when re-showing.
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height)
      this.start()
    } else {
      this.stop()
    }
  }

  setTrailMode(v: boolean) {
    this.trailMode = v
  }

  setCarriers(carriers: CarrierView[], colorFor: (c: CarrierView) => string) {
    // Reuse existing per-carrier particle state on update so clusters don't
    // visibly resnap on every year tick. Re-sample particles only when the
    // extent_geojson actually changes (detected via a stable signature).
    const prevById = new Map(this.carriers.map((c) => [c.carrierId, c]))
    const next: CarrierParticles[] = []
    for (const c of carriers) {
      if (!c.centroid) continue
      const sig = c.extent_geojson ?? `__buf:${c.centroid.lon.toFixed(3)}:${c.centroid.lat.toFixed(3)}`
      const existing = prevById.get(c.id)
      if (existing && existing.extentSig === sig) {
        existing.centroidLon = c.centroid.lon
        existing.centroidLat = c.centroid.lat
        existing.color = colorFor(c)
        next.push(existing)
        continue
      }
      next.push(this.buildCarrierParticles(c, colorFor(c), sig))
    }
    this.carriers = next
  }

  private buildCarrierParticles(
    c: CarrierView,
    color: string,
    sig: string,
  ): CarrierParticles {
    const info = parseExtentGeojson(c.extent_geojson)
    if (info) {
      // Particle count scales with extent area but flattens for empires
      // so the canvas doesn't get overwhelmed.
      const count = Math.max(
        PARTICLES_MIN,
        Math.min(PARTICLES_MAX, Math.round(Math.sqrt(info.bboxAreaDeg) * PARTICLES_PER_DEG)),
      )
      const homeLon = new Float32Array(count)
      const homeLat = new Float32Array(count)
      for (let i = 0; i < count; i++) {
        const [lon, lat] = samplePointInRings(info)
        homeLon[i] = lon
        homeLat[i] = lat
      }
      return {
        carrierId: c.id,
        centroidLon: c.centroid!.lon,
        centroidLat: c.centroid!.lat,
        color,
        extentSig: sig,
        rings: info.rings,
        bboxMinLon: info.minLon, bboxMaxLon: info.maxLon,
        bboxMinLat: info.minLat, bboxMaxLat: info.maxLat,
        count,
        homeLon, homeLat,
        pLon: new Float32Array(homeLon),
        pLat: new Float32Array(homeLat),
        vLon: new Float32Array(count),
        vLat: new Float32Array(count),
      }
    }
    // Fallback: no extent geometry. Tight cluster around centroid in lng/lat
    // space — small radius keeps it from looking like a real territory.
    const count = PARTICLES_FALLBACK
    const homeLon = new Float32Array(count)
    const homeLat = new Float32Array(count)
    for (let i = 0; i < count; i++) {
      const r = Math.random() * FALLBACK_RADIUS_DEG
      const a = Math.random() * Math.PI * 2
      homeLon[i] = c.centroid!.lon + Math.cos(a) * r
      homeLat[i] = c.centroid!.lat + Math.sin(a) * r
    }
    return {
      carrierId: c.id,
      centroidLon: c.centroid!.lon,
      centroidLat: c.centroid!.lat,
      color,
      extentSig: sig,
      rings: null,
      bboxMinLon: c.centroid!.lon - FALLBACK_RADIUS_DEG,
      bboxMaxLon: c.centroid!.lon + FALLBACK_RADIUS_DEG,
      bboxMinLat: c.centroid!.lat - FALLBACK_RADIUS_DEG,
      bboxMaxLat: c.centroid!.lat + FALLBACK_RADIUS_DEG,
      count,
      homeLon, homeLat,
      pLon: new Float32Array(homeLon),
      pLat: new Float32Array(homeLat),
      vLon: new Float32Array(count),
      vLat: new Float32Array(count),
    }
  }

  /** Replace the active migrations (origin/destination polylines). Particles
   * already in flight are kept if their migration is still present, dropped
   * otherwise — this avoids a visible snap when the source toggle changes. */
  setMigrations(migrations: Migration[]) {
    const prevIds = this.migrations.map((m) => m.id)
    const nextIdSet = new Set(migrations.map((m) => m.id))
    // Remap surviving stream particles' migrationIdx to the new array.
    const idxRemap = new Map<number, number>()
    migrations.forEach((m, ni) => {
      const oi = prevIds.indexOf(m.id)
      if (oi >= 0) idxRemap.set(oi, ni)
    })
    this.streamParticles = this.streamParticles
      .map((p) => {
        const ni = idxRemap.get(p.migrationIdx)
        return ni !== undefined ? { ...p, migrationIdx: ni } : null
      })
      .filter((p): p is StreamParticle => p !== null)
    this.migrations = migrations
    this.spawnAccumulators = migrations.map((_, i) => this.spawnAccumulators[i] ?? 0)
  }

  private resize = () => {
    const rect = this.container.getBoundingClientRect()
    this.dpr = window.devicePixelRatio || 1
    this.canvas.width = Math.max(1, Math.floor(rect.width * this.dpr))
    this.canvas.height = Math.max(1, Math.floor(rect.height * this.dpr))
    this.canvas.style.width = `${rect.width}px`
    this.canvas.style.height = `${rect.height}px`
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0)
  }

  private start() {
    if (this.rafId !== null) return
    this.lastTimeMs = performance.now()
    const loop = (t: number) => {
      const dt = Math.min(0.05, (t - this.lastTimeMs) / 1000) // clamp for tab-switch jumps
      this.lastTimeMs = t
      this.frame(dt)
      this.rafId = requestAnimationFrame(loop)
    }
    this.rafId = requestAnimationFrame(loop)
  }

  private stop() {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }

  private frame(dt: number) {
    const ctx = this.ctx
    const w = this.canvas.width / this.dpr
    const h = this.canvas.height / this.dpr

    // Background pass: fade for trails OR a stronger overlay so motion blur
    // doesn't pile up indefinitely. A pure clear would defeat the trail
    // effect; an overlay fade is what gives both modes their look.
    ctx.globalCompositeOperation = 'destination-out'
    ctx.fillStyle = this.trailMode ? STREAM_FADE_BG_TRAIL : STREAM_FADE_BG
    ctx.fillRect(0, 0, w, h)
    ctx.globalCompositeOperation = 'source-over'

    // 1. Carrier clusters — lng/lat Brownian step + spring back to home,
    //    polygon containment, project + draw.
    //
    //    Per-carrier step magnitude scales with extent bbox so a tribal
    //    carrier doesn't shoot particles continent-wide and a continental
    //    empire doesn't have particles barely twitching.
    const decay = Math.exp(-VELOCITY_DECAY_PER_SEC * dt)
    for (const c of this.carriers) {
      // Cull entire carrier if its bbox is fully off-screen with a margin.
      // Project the four bbox corners; any corner inside (or both outside on
      // opposite sides) → keep. Cheap upper bound on the cluster's reach.
      const c1 = this.map.project([c.bboxMinLon, c.bboxMinLat])
      const c2 = this.map.project([c.bboxMaxLon, c.bboxMaxLat])
      const xMin = Math.min(c1.x, c2.x), xMax = Math.max(c1.x, c2.x)
      const yMin = Math.min(c1.y, c2.y), yMax = Math.max(c1.y, c2.y)
      const offscreen = xMax < -20 || yMax < -20 || xMin > w + 20 || yMin > h + 20
      // Step size in degrees, scaled by extent dimension. min() so a long
      // narrow extent doesn't get a runaway step from its long axis.
      const extDim = Math.min(
        c.bboxMaxLon - c.bboxMinLon,
        c.bboxMaxLat - c.bboxMinLat,
      )
      const noiseDeg = Math.max(0.02, Math.min(0.5, extDim * 0.04))

      ctx.fillStyle = c.color
      ctx.globalAlpha = CARRIER_PARTICLE_ALPHA
      for (let i = 0; i < c.count; i++) {
        // Spring back toward home — keeps the polygon evenly populated over
        // long timescales rather than drifting to a corner. Strength is
        // proportional to (current - home), classic damped oscillator.
        const sx = (c.homeLon[i] - c.pLon[i]) * SPRING_K_PER_SEC
        const sy = (c.homeLat[i] - c.pLat[i]) * SPRING_K_PER_SEC
        c.vLon[i] = c.vLon[i] * decay
                    + sx * dt
                    + (Math.random() - 0.5) * BROWNIAN_NOISE_PER_SEC * noiseDeg * dt * 2
        c.vLat[i] = c.vLat[i] * decay
                    + sy * dt
                    + (Math.random() - 0.5) * BROWNIAN_NOISE_PER_SEC * noiseDeg * dt * 2
        const newLon = c.pLon[i] + c.vLon[i] * dt * 60   // *60 so velocity tunes
        const newLat = c.pLat[i] + c.vLat[i] * dt * 60   // around per-second feel
        // Containment: if the proposed step leaves the polygon, reverse the
        // velocity (soft bounce) and skip the position update. Bbox quick-
        // reject first so most checks short-circuit without the ring scan.
        let inside = true
        if (c.rings) {
          if (newLon < c.bboxMinLon || newLon > c.bboxMaxLon ||
              newLat < c.bboxMinLat || newLat > c.bboxMaxLat) {
            inside = false
          } else {
            inside = ringsContainPoint(c.rings, newLon, newLat)
          }
        }
        if (inside) {
          c.pLon[i] = newLon
          c.pLat[i] = newLat
        } else {
          c.vLon[i] *= -0.4
          c.vLat[i] *= -0.4
        }
        if (offscreen) continue
        const proj = this.map.project([c.pLon[i], c.pLat[i]])
        if (proj.x < -10 || proj.y < -10 || proj.x > w + 10 || proj.y > h + 10) continue
        ctx.beginPath()
        ctx.arc(proj.x, proj.y, PARTICLE_RADIUS_PX, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    ctx.globalAlpha = 1

    // 2. Migration streams — spawn new particles, advance existing ones, draw.
    for (let i = 0; i < this.migrations.length; i++) {
      const m = this.migrations[i]
      const target = STREAM_SPAWN_PER_SEC_PER_DEG * Math.max(1, m.totalLengthDeg) * dt
      this.spawnAccumulators[i] += target
      while (this.spawnAccumulators[i] >= 1) {
        this.spawnAccumulators[i] -= 1
        this.streamParticles.push({
          migrationIdx: i,
          t: Math.random() * 0.05, // jitter the start so they don't pulse in unison
          speed: STREAM_SPEED_T_PER_SEC * (0.85 + Math.random() * 0.3),
          life: 0,
        })
      }
    }

    const survivors: StreamParticle[] = []
    for (const p of this.streamParticles) {
      p.t += p.speed * dt
      p.life += dt
      if (p.t >= 1) continue
      const m = this.migrations[p.migrationIdx]
      if (!m) continue
      const [lon, lat] = pointAlongPolylineLngLat(m.polyline, p.t)
      const proj = this.map.project([lon, lat])
      if (proj.x < -10 || proj.y < -10 || proj.x > w + 10 || proj.y > h + 10) {
        survivors.push(p)
        continue
      }
      // Slight pulse: brighter near the head of the stream, softer mid-flight.
      const pulse = 0.7 + 0.3 * Math.sin(p.life * 6 + p.t * 8)
      ctx.globalAlpha = pulse
      ctx.fillStyle = m.color
      ctx.beginPath()
      ctx.arc(proj.x, proj.y, STREAM_PARTICLE_RADIUS_PX, 0, Math.PI * 2)
      ctx.fill()
      survivors.push(p)
    }
    ctx.globalAlpha = 1
    this.streamParticles = survivors
  }
}

// ─── Migration source builders ────────────────────────────────────────────────
//
// Each builder takes the current world payload + slider year and returns a list
// of Migration {polyline, color, year window}. The overlay only animates
// streams whose year window overlaps the slider year — so scrubbing time
// causes streams to appear / disappear naturally.

const RUPTURE_COLOR: Record<string, string> = {
  gradual_blend: '#22c55e',
  elite_dominance: '#fbbf24',
  demographic_swamp: '#f97316',
  violent_replacement: '#ef4444',
  forced_diaspora: '#a855f7',
  island_settlement: '#06b6d4',
}

export function buildMigrationsFromPropagation(
  events: PropagationEventView[],
  year: number,
): Migration[] {
  const out: Migration[] = []
  for (const p of events) {
    if (!p.source_point || !p.destination_point) continue
    if (year < p.date_min_year || year > p.date_max_year) continue
    const a: [number, number] = [p.source_point.lon, p.source_point.lat]
    const b: [number, number] = [p.destination_point.lon, p.destination_point.lat]
    const polyline = routeBetween(a, b)
    out.push({
      id: `prop:${p.id}`,
      polyline,
      totalLengthDeg: pathLengthDeg(polyline),
      color: DOMAIN_COLORS[p.domain] ?? DOMAIN_COLORS.other,
      yearMin: p.date_min_year,
      yearMax: p.date_max_year,
    })
  }
  return out
}

export function buildMigrationsFromAdmixture(
  events: AdmixtureEvent[],
  carriers: CarrierView[],
): Migration[] {
  const centroidById = new Map<string, [number, number]>()
  for (const c of carriers) {
    if (c.centroid) centroidById.set(c.id, [c.centroid.lon, c.centroid.lat])
  }
  const avg = (ids: string[]): [number, number] | null => {
    const pts = ids.map((i) => centroidById.get(i)).filter(Boolean) as [number, number][]
    if (pts.length === 0) return null
    let sx = 0, sy = 0
    for (const p of pts) { sx += p[0]; sy += p[1] }
    return [sx / pts.length, sy / pts.length]
  }
  const out: Migration[] = []
  for (const e of events) {
    const a = avg(e.parent_carriers)
    const b = avg(e.result_carriers)
    if (!a || !b) continue
    const polyline = routeBetween(a, b)
    out.push({
      id: `admix:${e.id}`,
      polyline,
      totalLengthDeg: pathLengthDeg(polyline),
      color: RUPTURE_COLOR[e.rupture_kind] ?? '#9ca3af',
      yearMin: e.year_min,
      yearMax: e.year_max,
    })
  }
  return out
}

export function buildMigrationsFromLineage(
  lineage: CarrierLineageResponse | null,
): Migration[] {
  if (!lineage || !lineage.focal) return []
  const nodesById = new Map(lineage.nodes.map((n) => [n.id, n]))
  const out: Migration[] = []
  for (const e of lineage.edges) {
    const a = nodesById.get(e.from_id)
    const b = nodesById.get(e.to_id)
    if (!a?.centroid || !b?.centroid) continue
    const polyline = routeBetween(
      [a.centroid.lon, a.centroid.lat],
      [b.centroid.lon, b.centroid.lat],
    )
    out.push({
      id: `lin:${e.from_id}->${e.to_id}`,
      polyline,
      totalLengthDeg: pathLengthDeg(polyline),
      color: e.side === 'past' ? '#fbbf24' : '#22d3ee',
      yearMin: a.date_min_year,
      yearMax: b.date_max_year,
    })
  }
  return out
}
