/**
 * AdmixtureTimeline — the headline "drama" feature.
 *
 * A horizontal lane of glowing markers rendered along the same
 * piecewise-log scale as the year slider. Each marker corresponds to a
 * major fusion moment seeded in `db/025_seed_admixture_events.sql`:
 * Out-of-Africa × Neanderthal, Yamnaya into Europe, Steppe into South
 * Asia, Bantu, Atlantic slave trade, etc.
 *
 * Visual encoding:
 *   - Marker SIZE ∝ severity (cultural rupture, 1-5).
 *   - Marker COLOR ∝ rupture_kind (gradual_blend / elite_dominance /
 *     demographic_swamp / violent_replacement / forced_diaspora /
 *     island_settlement) — gives the timeline a glanceable rhythm
 *     ("the red ones are the violent replacements").
 *   - Marker SPAN ∝ year_max - year_min — events with longer windows
 *     render as wider lozenges, instantaneous-feeling events as dots.
 *
 * Interactions:
 *   - Hover: tooltip with name, year range, severity, kind.
 *   - Click: jump-cuts the year slider to the event mid-range and
 *     opens the AdmixtureCard panel for that event.
 */
import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { api, AdmixtureEvent } from '../api'
import { yearToFraction, formatYear } from '../lib/timeScale'

const RUPTURE_COLOR: Record<string, string> = {
  gradual_blend: '#22c55e',           // green
  elite_dominance: '#fbbf24',         // amber
  demographic_swamp: '#f97316',       // orange
  violent_replacement: '#ef4444',     // red
  forced_diaspora: '#a855f7',         // violet
  island_settlement: '#06b6d4',       // cyan
}

const RUPTURE_LABEL: Record<string, string> = {
  gradual_blend: 'gradual blend',
  elite_dominance: 'elite dominance',
  demographic_swamp: 'demographic swamp',
  violent_replacement: 'violent replacement',
  forced_diaspora: 'forced diaspora',
  island_settlement: 'island settlement',
}

export function AdmixtureTimeline() {
  const [events, setEvents] = useState<AdmixtureEvent[]>([])
  const [hover, setHover] = useState<AdmixtureEvent | null>(null)
  const setYear = useStore((s) => s.setYear)
  const setSelectedAdmixtureEventId = useStore((s) => s.setSelectedAdmixtureEventId)
  const setAdmixtureAtlasOpen = useStore((s) => s.setAdmixtureAtlasOpen)
  const year = useStore((s) => s.year)

  useEffect(() => {
    let cancelled = false
    api.admixtureEvents().then((res) => {
      if (!cancelled) setEvents(res.events)
    }).catch(() => {})
    return () => { cancelled = true }
  }, [])

  function clickEvent(e: AdmixtureEvent) {
    const mid = Math.round((e.year_min + e.year_max) / 2)
    setYear(mid)
    setSelectedAdmixtureEventId(e.id)
  }

  return (
    <div className="relative bg-gray-950/95 border-t border-b border-gray-800 px-4 py-1.5">
      <div className="flex items-center justify-between mb-1">
        <div className="flex items-center gap-3">
          <span className="text-[10px] uppercase tracking-wide text-gray-500">
            Admixture events — populations meeting and fusing
          </span>
          <button
            onClick={() => setAdmixtureAtlasOpen(true)}
            className="text-[10px] px-2 py-0.5 rounded bg-gray-800 hover:bg-gray-700 border border-gray-700 text-gray-300"
            title="Open the expanded Admixture Atlas — every population on its own row, with curves connecting parents to descendants."
          >
            ⤢ Expand atlas
          </button>
        </div>
        {hover && (
          <span className="text-[10px] text-gray-400">
            {hover.display_name} · {formatYear(hover.year_min)}–{formatYear(hover.year_max)} ·{' '}
            <span style={{ color: RUPTURE_COLOR[hover.rupture_kind] }}>
              {RUPTURE_LABEL[hover.rupture_kind]}
            </span>{' '}
            · severity {hover.severity}/5
          </span>
        )}
      </div>
      <div className="relative h-7">
        {/* Backbone */}
        <div className="absolute top-1/2 left-0 right-0 h-px bg-gray-700" />

        {/* Current-year marker */}
        <div
          className="absolute top-0 bottom-0 w-px bg-amber-400/70"
          style={{ left: `${yearToFraction(year) * 100}%` }}
        />

        {/* Event markers */}
        {events.map((e) => {
          const left = yearToFraction(e.year_min)
          const right = yearToFraction(e.year_max)
          const widthPct = Math.max(0.6, (right - left) * 100)
          const color = RUPTURE_COLOR[e.rupture_kind] ?? '#9ca3af'
          const height = 6 + e.severity * 3 // 9 - 21px
          const isHover = hover?.id === e.id
          const yearActive = year >= e.year_min && year <= e.year_max
          return (
            <button
              key={e.id}
              onMouseEnter={() => setHover(e)}
              onMouseLeave={() => setHover((cur) => (cur?.id === e.id ? null : cur))}
              onClick={() => clickEvent(e)}
              title={`${e.display_name} · ${formatYear(e.year_min)}–${formatYear(e.year_max)} · ${RUPTURE_LABEL[e.rupture_kind]} · severity ${e.severity}/5`}
              className="absolute top-1/2 rounded-full hover:z-10 transition-all"
              style={{
                left: `calc(${left * 100}% - ${height / 2}px)`,
                width: `calc(${widthPct}% + ${height}px)`,
                height: `${height}px`,
                transform: 'translateY(-50%)',
                background: color,
                opacity: isHover ? 1 : (yearActive ? 0.95 : 0.65),
                boxShadow: yearActive
                  ? `0 0 8px 2px ${color}aa`
                  : isHover
                    ? `0 0 6px 1px ${color}88`
                    : 'none',
                border: yearActive ? '1px solid white' : '1px solid rgba(15,23,42,0.6)',
              }}
            />
          )
        })}
      </div>
    </div>
  )
}
