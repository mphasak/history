/**
 * AdmixtureAtlas — the expanded phylogeny-style view of admixture
 * events.
 *
 * The compact AdmixtureTimeline lays every event on a single Y. When
 * you want to actually *see* the ancestor → descendant flows that
 * produced e.g. African Americans (West African + Bantu + European
 * Colonial → African American), one row isn't enough. This component
 * gives every carrier referenced in any admixture event its own
 * horizontal lane and draws cubic-bezier connectors from every
 * parent's life-line to every result's life-line.
 *
 * Layout, top-to-bottom:
 *   1. Group carriers by region (Africa / Europe / S Asia / E Asia /
 *      Mesoamerica / S America / N America / Oceania / Mideast /
 *      Siberia). Within group, sort by date_min_year ascending.
 *   2. Each carrier is a horizontal bar from its date_min_year to its
 *      date_max_year, colored by its dominant ancestry trait (using
 *      lib/clusters.ts so the palette matches the map).
 *   3. For every (parent_carrier, result_carrier) pair in every
 *      admixture event, draw a cubic bezier from the parent's
 *      right-edge to the result's left-edge.
 *
 * X axis uses the same piecewise-log scale as the year slider, so
 * scrolling the map's slider while the Atlas is open keeps the same
 * "where am I in time?" feel.
 */
import { useEffect, useMemo, useState } from 'react'
import { useStore } from '../state'
import { api, AdmixtureEvent, GeoPoint } from '../api'
import { yearToFraction, formatYear } from '../lib/timeScale'
import { colorForTraitId } from '../lib/clusters'

interface CarrierMeta {
  id: string
  display_name: string
  type: string
  date_min_year: number
  date_max_year: number
  centroid: GeoPoint | null
  dominant_trait: string | null
}

const ROW_H = 26
const BAR_H = 14
const LABEL_W = 240   // left gutter for carrier display_name
const TIME_W_MIN = 1200 // minimum width of the time region
const PADDING_TOP = 16

// Region buckets — same ordering as the legend in lib/clusters so the
// Atlas reads consistently with the map. We DON'T import the regions
// helper from before (we removed it); roll our own coarse classifier
// scoped to this component.
type Region =
  | 'AFRICA'
  | 'MIDEAST'
  | 'EUROPE'
  | 'S_ASIA'
  | 'E_ASIA'
  | 'SE_ASIA_OCEANIA'
  | 'SIBERIA'
  | 'N_AMERICA'
  | 'MESOAMERICA'
  | 'S_AMERICA'
  | 'OTHER'

const REGION_ORDER: Region[] = [
  'AFRICA', 'MIDEAST', 'EUROPE', 'SIBERIA',
  'S_ASIA', 'E_ASIA', 'SE_ASIA_OCEANIA',
  'N_AMERICA', 'MESOAMERICA', 'S_AMERICA', 'OTHER',
]

const REGION_LABEL: Record<Region, string> = {
  AFRICA: 'Africa',
  MIDEAST: 'Middle East / Levant',
  EUROPE: 'Europe',
  SIBERIA: 'Siberia / N. Asia',
  S_ASIA: 'South Asia',
  E_ASIA: 'East Asia',
  SE_ASIA_OCEANIA: 'SE Asia / Oceania',
  N_AMERICA: 'North America',
  MESOAMERICA: 'Mesoamerica',
  S_AMERICA: 'South America',
  OTHER: 'Other',
}

function classifyRegion(c: CarrierMeta): Region {
  if (!c.centroid) return 'OTHER'
  const { lat, lon } = c.centroid
  if (lat < 36 && lat > -40 && lon >= -20 && lon <= 55) return 'AFRICA'
  if (lat > 12 && lat < 45 && lon >= 25 && lon <= 65) return 'MIDEAST'
  if (lat >= 35 && lat <= 75 && lon > -25 && lon < 60) return 'EUROPE'
  if (lat > 5 && lat < 38 && lon > 60 && lon < 95) return 'S_ASIA'
  if (lat > 15 && lat < 60 && lon >= 95 && lon < 145) return 'E_ASIA'
  if (lat > -55 && lat < 25 && lon >= 90 && lon < 180) return 'SE_ASIA_OCEANIA'
  if (lat > 45 && lon >= 60) return 'SIBERIA'
  if (lat >= 25 && lon < -50) return 'N_AMERICA'
  if (lat >= 8 && lat < 25 && lon >= -120 && lon < -60) return 'MESOAMERICA'
  if (lat < 8 && lon > -90 && lon < -30) return 'S_AMERICA'
  return 'OTHER'
}

const RUPTURE_COLOR: Record<string, string> = {
  gradual_blend: '#22c55e',
  elite_dominance: '#fbbf24',
  demographic_swamp: '#f97316',
  violent_replacement: '#ef4444',
  forced_diaspora: '#a855f7',
  island_settlement: '#06b6d4',
}

const RUPTURE_LABEL: Record<string, string> = {
  gradual_blend: 'gradual blend',
  elite_dominance: 'elite dominance',
  demographic_swamp: 'demographic swamp',
  violent_replacement: 'violent replacement',
  forced_diaspora: 'forced diaspora',
  island_settlement: 'island settlement',
}

export function AdmixtureAtlas() {
  const open = useStore((s) => s.admixtureAtlasOpen)
  const setOpen = useStore((s) => s.setAdmixtureAtlasOpen)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const year = useStore((s) => s.year)
  const setYear = useStore((s) => s.setYear)
  const [events, setEvents] = useState<AdmixtureEvent[]>([])
  const [carriers, setCarriers] = useState<Record<string, CarrierMeta>>({})
  const [hoverEdge, setHoverEdge] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    let cancelled = false
    api.admixtureEventsWithCarriers().then((res) => {
      if (cancelled) return
      setEvents(res.events)
      setCarriers(res.carriers)
    }).catch(() => {})
    return () => { cancelled = true }
  }, [open])

  // Sort carriers into rows. Group by region, then by date_min_year.
  // Returns: ordered list with row index + region-section start markers.
  const layout = useMemo(() => {
    const list = Object.values(carriers)
    const grouped: Record<Region, CarrierMeta[]> = {
      AFRICA: [], MIDEAST: [], EUROPE: [], SIBERIA: [],
      S_ASIA: [], E_ASIA: [], SE_ASIA_OCEANIA: [],
      N_AMERICA: [], MESOAMERICA: [], S_AMERICA: [], OTHER: [],
    }
    for (const c of list) grouped[classifyRegion(c)].push(c)
    for (const r of Object.keys(grouped) as Region[]) {
      grouped[r].sort((a, b) =>
        a.date_min_year - b.date_min_year ||
        a.display_name.localeCompare(b.display_name),
      )
    }
    const rows: { carrier: CarrierMeta; rowIndex: number; region: Region }[] = []
    const sectionStarts: { region: Region; rowIndex: number }[] = []
    let i = 0
    for (const region of REGION_ORDER) {
      const items = grouped[region]
      if (items.length === 0) continue
      sectionStarts.push({ region, rowIndex: i })
      // Region label takes one row of vertical space.
      i += 1
      for (const c of items) {
        rows.push({ carrier: c, rowIndex: i, region })
        i += 1
      }
    }
    const rowById: Record<string, number> = {}
    for (const r of rows) rowById[r.carrier.id] = r.rowIndex
    return { rows, sectionStarts, rowById, totalRows: i }
  }, [carriers])

  if (!open) return null

  // Sizing
  const innerWidth = Math.max(TIME_W_MIN, window.innerWidth - 100)
  const timeWidth = innerWidth - LABEL_W - 24 // room for right padding
  const totalHeight = PADDING_TOP + layout.totalRows * ROW_H + 32

  const xAt = (y: number): number => LABEL_W + yearToFraction(y) * timeWidth

  // Build edges (parent-carrier → result-carrier) per event.
  const edges: {
    eventId: string
    parentId: string
    resultId: string
    color: string
    severity: number
    label: string
  }[] = []
  for (const e of events) {
    const color = RUPTURE_COLOR[e.rupture_kind] ?? '#9ca3af'
    for (const p of e.parent_carriers) {
      for (const r of e.result_carriers) {
        if (!(p in layout.rowById) || !(r in layout.rowById)) continue
        edges.push({
          eventId: e.id,
          parentId: p,
          resultId: r,
          color,
          severity: e.severity,
          label: e.display_name,
        })
      }
    }
  }

  // Pretty-format the connector as a cubic bezier. The horizontal
  // distance between p_x and r_x drives the control-point offset so
  // long-range connectors curve gracefully without crossing the bars.
  const bezierPath = (px: number, py: number, rx: number, ry: number): string => {
    const dx = Math.max(40, Math.abs(rx - px) * 0.4)
    return `M ${px} ${py} C ${px + dx} ${py}, ${rx - dx} ${ry}, ${rx} ${ry}`
  }

  return (
    <div
      className="fixed inset-0 z-30 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={() => setOpen(false)}
    >
      <div
        className="bg-gray-950 text-white border border-gray-700 rounded-lg shadow-2xl w-full max-w-[1600px] max-h-[92vh] flex flex-col overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-4 py-2 border-b border-gray-700 shrink-0">
          <div>
            <h2 className="text-sm font-semibold">Admixture Atlas</h2>
            <p className="text-[11px] text-gray-400 mt-0.5">
              Each row is a population. Curves run from parents to descendants of every
              admixture event. Color of the curve = rupture kind.
            </p>
          </div>
          <button
            onClick={() => setOpen(false)}
            className="text-gray-400 hover:text-white text-xl leading-none"
            aria-label="Close"
          >
            ×
          </button>
        </div>

        {/* Legend strip */}
        <div className="px-4 py-1.5 border-b border-gray-800 flex flex-wrap gap-3 text-[10px] text-gray-400 shrink-0">
          <span>Curve color:</span>
          {Object.keys(RUPTURE_COLOR).map((k) => (
            <span key={k} className="flex items-center gap-1">
              <span className="inline-block w-3 h-1.5 rounded" style={{ background: RUPTURE_COLOR[k] }} />
              {RUPTURE_LABEL[k]}
            </span>
          ))}
        </div>

        {/* Body */}
        <div className="flex-1 overflow-auto">
          <svg
            width={innerWidth}
            height={totalHeight}
            style={{ background: '#020617' }}
          >
            {/* Time-axis ticks at the top */}
            {[
              { y: -10000, lbl: '10 kya' },
              { y: -3000, lbl: '3000 BCE' },
              { y: -1000, lbl: '1000 BCE' },
              { y: 0, lbl: '1 CE' },
              { y: 500, lbl: '500' },
              { y: 1000, lbl: '1000' },
              { y: 1500, lbl: '1500' },
              { y: 1900, lbl: '1900' },
            ].map((t) => (
              <g key={t.y}>
                <line
                  x1={xAt(t.y)} x2={xAt(t.y)}
                  y1={PADDING_TOP - 8} y2={totalHeight}
                  stroke="#1e293b" strokeWidth={1}
                />
                <text
                  x={xAt(t.y)} y={PADDING_TOP - 4}
                  fill="#64748b" fontSize={9} textAnchor="middle"
                >
                  {t.lbl}
                </text>
              </g>
            ))}

            {/* Current-year cursor */}
            <line
              x1={xAt(year)} x2={xAt(year)}
              y1={PADDING_TOP - 8} y2={totalHeight}
              stroke="#f59e0b" strokeWidth={1.5} strokeDasharray="4 3"
              opacity={0.8}
            />

            {/* Region section labels */}
            {layout.sectionStarts.map((s) => (
              <text
                key={s.region}
                x={LABEL_W - 8}
                y={PADDING_TOP + s.rowIndex * ROW_H + 14}
                fill="#94a3b8"
                fontSize={11}
                fontWeight="600"
                textAnchor="end"
                style={{ textTransform: 'uppercase', letterSpacing: 0.5 }}
              >
                {REGION_LABEL[s.region]}
              </text>
            ))}

            {/* Edges (connectors) — drawn before bars so the bars sit on top.
                Active edges (touching today's year cursor) render brighter. */}
            {edges.map((e, i) => {
              const parent = carriers[e.parentId]
              const result = carriers[e.resultId]
              if (!parent || !result) return null
              const px = xAt(parent.date_max_year)
              const py = PADDING_TOP + (layout.rowById[e.parentId] ?? 0) * ROW_H + ROW_H / 2
              const rx = xAt(result.date_min_year)
              const ry = PADDING_TOP + (layout.rowById[e.resultId] ?? 0) * ROW_H + ROW_H / 2
              const isHover = hoverEdge === `${e.eventId}|${e.parentId}|${e.resultId}`
              return (
                <g key={`edge-${i}`}>
                  <path
                    d={bezierPath(px, py, rx, ry)}
                    stroke={e.color}
                    strokeWidth={isHover ? 3 : 1 + e.severity * 0.4}
                    fill="none"
                    opacity={isHover ? 1 : 0.55}
                    style={{ cursor: 'pointer' }}
                    onMouseEnter={() => setHoverEdge(`${e.eventId}|${e.parentId}|${e.resultId}`)}
                    onMouseLeave={() => setHoverEdge((cur) => cur === `${e.eventId}|${e.parentId}|${e.resultId}` ? null : cur)}
                  >
                    <title>{e.label} · severity {e.severity}/5</title>
                  </path>
                </g>
              )
            })}

            {/* Carrier rows: label + bar */}
            {layout.rows.map(({ carrier: c, rowIndex }) => {
              const x1 = xAt(c.date_min_year)
              const x2 = xAt(c.date_max_year)
              const y = PADDING_TOP + rowIndex * ROW_H + (ROW_H - BAR_H) / 2
              const fill = c.dominant_trait
                ? colorForTraitId(c.dominant_trait)
                : '#475569'
              return (
                <g key={c.id}>
                  {/* Label (left gutter) */}
                  <text
                    x={LABEL_W - 8}
                    y={y + BAR_H / 2 + 3}
                    fill="#cbd5e1"
                    fontSize={10}
                    textAnchor="end"
                    style={{ cursor: 'pointer' }}
                    onClick={() => {
                      const mid = Math.round((c.date_min_year + c.date_max_year) / 2)
                      setYear(mid)
                      setSelectedCarrierId(c.id)
                      setOpen(false)
                    }}
                  >
                    <title>{c.id}</title>
                    {c.display_name.length > 40 ? c.display_name.slice(0, 38) + '…' : c.display_name}
                  </text>
                  {/* Bar */}
                  <rect
                    x={x1} y={y} width={Math.max(2, x2 - x1)} height={BAR_H}
                    fill={fill}
                    stroke="#0f172a"
                    strokeWidth={1}
                    rx={2}
                    style={{ cursor: 'pointer' }}
                    onClick={() => {
                      const mid = Math.round((c.date_min_year + c.date_max_year) / 2)
                      setYear(mid)
                      setSelectedCarrierId(c.id)
                      setOpen(false)
                    }}
                  >
                    <title>
                      {c.display_name} · {formatYear(c.date_min_year)} — {formatYear(c.date_max_year)}
                      {c.dominant_trait ? ` · dominant ${c.dominant_trait}` : ''}
                    </title>
                  </rect>
                </g>
              )
            })}
          </svg>
        </div>

        {/* Hover tooltip strip at bottom */}
        <div className="px-4 py-1.5 border-t border-gray-700 text-[10px] text-gray-400 h-7 flex items-center shrink-0">
          {hoverEdge ? (
            (() => {
              const [eventId, parentId, resultId] = hoverEdge.split('|')
              const e = events.find((x) => x.id === eventId)
              if (!e) return null
              return (
                <>
                  <span className="text-gray-200 font-medium">{e.display_name}</span>
                  <span className="mx-2">·</span>
                  <span style={{ color: RUPTURE_COLOR[e.rupture_kind] }}>
                    {RUPTURE_LABEL[e.rupture_kind]}
                  </span>
                  <span className="mx-2">·</span>
                  <span>severity {e.severity}/5</span>
                  <span className="mx-2">·</span>
                  <span>{carriers[parentId]?.display_name ?? parentId} → {carriers[resultId]?.display_name ?? resultId}</span>
                </>
              )
            })()
          ) : (
            <span>Hover a curve for the admixture event details. Click a bar to inspect that population on the map.</span>
          )}
        </div>
      </div>
    </div>
  )
}
