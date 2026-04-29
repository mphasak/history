/**
 * AdmixtureCard — the right-side panel that opens when an event in the
 * AdmixtureTimeline is clicked.
 *
 * Shows the full story of one fusion moment: parent ghost-traits and
 * carriers, result ghost-traits and carriers, severity, rupture kind,
 * the editorial description. Each parent / result carrier is a button
 * that selects it on the map (so the user can immediately see who was
 * involved).
 */
import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { api, AdmixtureEvent } from '../api'
import { formatYear } from '../lib/timeScale'

const RUPTURE_LABEL: Record<string, string> = {
  gradual_blend: 'Gradual blend',
  elite_dominance: 'Elite dominance',
  demographic_swamp: 'Demographic swamp',
  violent_replacement: 'Violent replacement',
  forced_diaspora: 'Forced diaspora',
  island_settlement: 'Island settlement',
}

const RUPTURE_COLOR: Record<string, string> = {
  gradual_blend: 'text-emerald-400',
  elite_dominance: 'text-amber-400',
  demographic_swamp: 'text-orange-400',
  violent_replacement: 'text-rose-500',
  forced_diaspora: 'text-violet-400',
  island_settlement: 'text-cyan-400',
}

export function AdmixtureCard() {
  const id = useStore((s) => s.selectedAdmixtureEventId)
  const setId = useStore((s) => s.setSelectedAdmixtureEventId)
  const setSelectedCarrier = useStore((s) => s.setSelectedCarrierId)
  const [event, setEvent] = useState<AdmixtureEvent | null>(null)

  useEffect(() => {
    if (!id) { setEvent(null); return }
    let cancelled = false
    // Cache-busting fetch — the events list is small and the API is
    // local, so re-fetching is cheap.
    api.admixtureEvents().then((res) => {
      if (cancelled) return
      const e = res.events.find((x) => x.id === id) ?? null
      setEvent(e)
    })
    return () => { cancelled = true }
  }, [id])

  if (!id || !event) return null

  const renderCarrier = (cid: string) => (
    <button
      key={cid}
      onClick={() => { setSelectedCarrier(cid); setId(null) }}
      className="text-[11px] text-blue-300 hover:text-blue-200 underline decoration-dotted"
    >
      {cid}
    </button>
  )

  return (
    <div className="bg-gray-900/95 text-white rounded-lg shadow-xl border border-gray-700 w-96 max-h-[calc(100vh-9rem)] overflow-y-auto backdrop-blur-sm">
      <div className="flex items-start justify-between px-4 py-3 border-b border-gray-700">
        <div>
          <div className="text-[10px] uppercase tracking-wide text-gray-500">
            Admixture event ·{' '}
            <span className={RUPTURE_COLOR[event.rupture_kind]}>
              {RUPTURE_LABEL[event.rupture_kind]}
            </span>{' '}
            · severity {event.severity}/5
          </div>
          <h2 className="font-semibold text-sm mt-0.5">{event.display_name}</h2>
          <div className="text-[11px] text-gray-400 mt-0.5 tabular-nums">
            {formatYear(event.year_min)} — {formatYear(event.year_max)}
          </div>
        </div>
        <button
          onClick={() => setId(null)}
          className="text-gray-400 hover:text-white shrink-0 text-lg leading-none"
          aria-label="Close"
        >
          ×
        </button>
      </div>
      <div className="px-4 py-3 space-y-4">
        {event.description && (
          <p className="text-[12px] leading-relaxed text-gray-200">
            {event.description}
          </p>
        )}

        {(event.parent_traits.length > 0 || event.parent_carriers.length > 0) && (
          <div>
            <div className="text-[10px] uppercase tracking-wide text-gray-500 mb-1">
              Parent populations / ancestries
            </div>
            {event.parent_traits.length > 0 && (
              <div className="flex flex-wrap gap-1 mb-1">
                {event.parent_traits.map((t) => (
                  <span key={t} className="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 border border-gray-700 text-gray-300">
                    {t}
                  </span>
                ))}
              </div>
            )}
            {event.parent_carriers.length > 0 && (
              <div className="flex flex-wrap gap-x-2 gap-y-0.5">
                {event.parent_carriers.map(renderCarrier)}
              </div>
            )}
          </div>
        )}

        <div className="text-center text-gray-500 text-xs">▼ fused into ▼</div>

        {(event.result_traits.length > 0 || event.result_carriers.length > 0) && (
          <div>
            <div className="text-[10px] uppercase tracking-wide text-gray-500 mb-1">
              Resulting populations / ancestries
            </div>
            {event.result_traits.length > 0 && (
              <div className="flex flex-wrap gap-1 mb-1">
                {event.result_traits.map((t) => (
                  <span key={t} className="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 border border-gray-700 text-gray-300">
                    {t}
                  </span>
                ))}
              </div>
            )}
            {event.result_carriers.length > 0 && (
              <div className="flex flex-wrap gap-x-2 gap-y-0.5">
                {event.result_carriers.map(renderCarrier)}
              </div>
            )}
          </div>
        )}

        <p className="text-[10px] text-gray-500 leading-snug pt-2 border-t border-gray-800">
          Click a carrier id to inspect it on the map. Drag the year slider
          to scrub through the event window — the parent and result
          carriers glow on the map while you're inside the year range.
        </p>
      </div>
    </div>
  )
}
