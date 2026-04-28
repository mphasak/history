import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { api, CarrierView, CarrierTimelineResponse, CarrierClaim } from '../api'
import { useWorldQuery, usePerspectives } from '../hooks/useWorldQuery'

const STANCE_STYLE: Record<string, { label: string; bg: string; border: string; text: string }> = {
  endorses: {
    label: 'endorses',
    bg: 'bg-emerald-900/40',
    border: 'border-emerald-700',
    text: 'text-emerald-200',
  },
  nuances: {
    label: 'nuances',
    bg: 'bg-amber-900/40',
    border: 'border-amber-700',
    text: 'text-amber-200',
  },
  rejects: {
    label: 'rejects',
    bg: 'bg-rose-900/40',
    border: 'border-rose-700',
    text: 'text-rose-200',
  },
  asserts: {
    label: 'asserts',
    bg: 'bg-sky-900/40',
    border: 'border-sky-700',
    text: 'text-sky-200',
  },
}

function StanceBadge({ stance }: { stance: string }) {
  const style = STANCE_STYLE[stance] ?? STANCE_STYLE.endorses
  return (
    <span
      className={`inline-block uppercase tracking-wide text-[10px] font-semibold px-1.5 py-0.5 rounded ${style.bg} ${style.border} border ${style.text}`}
    >
      {style.label}
    </span>
  )
}

function subjectKindLabel(kind: string): string {
  if (kind === 'carrier_trait_mix') return 'Trait mix'
  if (kind === 'propagation_event') return 'Migration / propagation'
  if (kind === 'carrier') return 'This population'
  return kind.replace(/_/g, ' ')
}

function TraitBar({ label, fraction, domain }: { label: string; fraction: number; domain: string }) {
  const colors: Record<string, string> = {
    genetic: 'bg-emerald-500',
    linguistic: 'bg-violet-500',
    ideological: 'bg-amber-500',
    religious: 'bg-rose-500',
    technological: 'bg-sky-500',
  }
  const color = colors[domain] ?? 'bg-gray-500'
  return (
    <div className="mb-1">
      <div className="flex justify-between text-xs mb-0.5">
        <span className="text-gray-300 truncate">{label}</span>
        <span className="text-gray-400 ml-1">{(fraction * 100).toFixed(1)}%</span>
      </div>
      <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full`} style={{ width: `${fraction * 100}%` }} />
      </div>
    </div>
  )
}

export function DetailPanel() {
  const selectedCarrierId = useStore((s) => s.selectedCarrierId)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const activePerspectives = useStore((s) => s.activePerspectives)
  const year = useStore((s) => s.year)
  const { data: worldData } = useWorldQuery()
  const { perspectives } = usePerspectives()

  const [timelines, setTimelines] = useState<Record<string, CarrierTimelineResponse>>({})
  const [loadingTimelines, setLoadingTimelines] = useState(false)
  const [claims, setClaims] = useState<CarrierClaim[]>([])
  const [loadingClaims, setLoadingClaims] = useState(false)

  useEffect(() => {
    if (!selectedCarrierId || activePerspectives.length === 0) return
    setLoadingTimelines(true)
    Promise.all(
      activePerspectives.map((pid) =>
        api.carrierTimeline(selectedCarrierId, pid).then((data) => ({ pid, data }))
      )
    )
      .then((results) => {
        const map: Record<string, CarrierTimelineResponse> = {}
        results.forEach(({ pid, data }) => { map[pid] = data })
        setTimelines(map)
        setLoadingTimelines(false)
      })
      .catch(() => setLoadingTimelines(false))
  }, [selectedCarrierId, activePerspectives.join(',')])

  useEffect(() => {
    if (!selectedCarrierId) { setClaims([]); return }
    setLoadingClaims(true)
    api
      .carrierClaims(selectedCarrierId, activePerspectives)
      .then((res) => { setClaims(res.claims); setLoadingClaims(false) })
      .catch(() => { setClaims([]); setLoadingClaims(false) })
  }, [selectedCarrierId, activePerspectives.join(',')])

  if (!selectedCarrierId) return null

  // Get carrier views from world data for each perspective
  const carriersByPersp: Record<string, CarrierView | undefined> = {}
  if (worldData) {
    for (const [pid, view] of Object.entries(worldData.perspectives)) {
      carriersByPersp[pid] = view.carriers.find((c) => c.id === selectedCarrierId)
    }
  }

  function getPerspDisplayName(pid: string) {
    return perspectives.find((p) => p.id === pid)?.display_name ?? pid
  }

  function formatYear(y: number) {
    return y < 0 ? `${Math.abs(y).toLocaleString()} BCE` : `${y} CE`
  }

  return (
    <div className="bg-gray-900 text-white rounded-lg shadow-xl w-80 max-h-screen overflow-y-auto">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
        <h2 className="font-semibold text-sm truncate">
          {carriersByPersp[activePerspectives[0]]?.display_name ?? selectedCarrierId}
        </h2>
        <button
          onClick={() => setSelectedCarrierId(null)}
          className="text-gray-400 hover:text-white ml-2 shrink-0"
          aria-label="Close"
        >
          ×
        </button>
      </div>

      <div className="p-4 space-y-5">
        {activePerspectives.map((pid) => {
          const carrier = carriersByPersp[pid]
          const timeline = timelines[pid]
          const perspName = getPerspDisplayName(pid)
          const perspMeta = perspectives.find((p) => p.id === pid)

          // Get the mix at the current year from timeline
          const snapshot = timeline?.timeline
            .filter((s) => s.as_of_year <= year)
            .sort((a, b) => b.as_of_year - a.as_of_year)[0]

          const groupedMix: Record<string, typeof snapshot> = {}
          if (snapshot) groupedMix[snapshot.domain] = snapshot

          return (
            <div key={pid} className="border border-gray-700 rounded-lg p-3">
              <div className="font-medium text-blue-300 text-xs mb-1">{perspName}</div>

              {carrier?.endorsement && (
                <div className="text-xs bg-amber-900/40 border border-amber-700 rounded p-2 mb-2">
                  <span className="font-semibold capitalize text-amber-300">
                    {carrier.endorsement.stance}:{' '}
                  </span>
                  {carrier.endorsement.override_statement && (
                    <span className="text-amber-200">{carrier.endorsement.override_statement}</span>
                  )}
                </div>
              )}

              {loadingTimelines ? (
                <p className="text-xs text-gray-500">Loading trait mix…</p>
              ) : timeline ? (
                <div>
                  <div className="text-xs text-gray-400 mb-2">
                    Trait mix (at {formatYear(snapshot?.as_of_year ?? year)}):
                  </div>
                  {timeline.timeline
                    .filter((s) => s.as_of_year <= year)
                    .sort((a, b) => b.as_of_year - a.as_of_year)
                    .slice(0, 1)
                    .flatMap((s) =>
                      s.traits.map((t) => (
                        <TraitBar
                          key={`${pid}-${t.trait_id}`}
                          label={t.display_name ?? t.trait_id}
                          fraction={t.fraction ?? 0}
                          domain={t.domain}
                        />
                      ))
                    )}
                </div>
              ) : carrier?.trait_mix && carrier.trait_mix.length > 0 ? (
                <div>
                  <div className="text-xs text-gray-400 mb-2">Trait mix:</div>
                  {carrier.trait_mix.map((t) => (
                    <TraitBar
                      key={`${pid}-${t.trait_id}`}
                      label={t.display_name ?? t.trait_id}
                      fraction={t.fraction ?? 0}
                      domain={t.domain}
                    />
                  ))}
                </div>
              ) : (
                <p className="text-xs text-gray-500">No trait mix data at this year.</p>
              )}

              {perspMeta && (
                <details className="mt-2">
                  <summary className="text-xs text-gray-400 cursor-pointer hover:text-gray-200">
                    Methodology notes
                  </summary>
                  <p className="text-xs text-gray-400 mt-1 leading-relaxed">
                    {perspMeta.methodology_notes}
                  </p>
                </details>
              )}
            </div>
          )
        })}

        {/* Claims about this carrier (its trait mixes, propagation events).
            Stance differences across active perspectives are surfaced here —
            this is where the contested-knowledge story actually lands. */}
        {(loadingClaims || claims.length > 0) && (
          <div>
            <div className="text-xs uppercase tracking-wide text-gray-500 mb-2">
              Claims about this population
              {claims.some((c) => c.has_disagreement) && (
                <span className="ml-2 normal-case tracking-normal text-rose-400">
                  · perspectives disagree
                </span>
              )}
            </div>

            {loadingClaims && (
              <p className="text-xs text-gray-500">Loading claims…</p>
            )}

            <div className="space-y-3">
              {claims.map((claim) => (
                <div
                  key={claim.id}
                  className={`border rounded-lg p-3 ${
                    claim.has_disagreement
                      ? 'border-rose-700 bg-rose-950/30'
                      : 'border-gray-700 bg-gray-800/40'
                  }`}
                >
                  <div className="flex items-baseline justify-between gap-2 mb-1">
                    <span className="text-[10px] uppercase tracking-wide text-gray-500">
                      {subjectKindLabel(claim.subject_kind)}
                    </span>
                  </div>
                  <p className="text-xs text-gray-200 leading-snug mb-2">
                    {/* Strip the internal [AUTO-PROVENANCE] tag used as an idempotency
                        key on seeded ancestry claims — the user doesn't need to see it. */}
                    {claim.statement.replace(/^\[AUTO-PROVENANCE\]\s*/, '')}
                  </p>

                  {/* Per-perspective stance + override + sources */}
                  <div className="space-y-2">
                    {Object.entries(claim.perspectives).map(([pid, pv]) => {
                      const perspName = getPerspDisplayName(pid)
                      return (
                        <div key={pid} className="text-xs">
                          <div className="flex items-center gap-2 mb-1">
                            <StanceBadge stance={pv.stance} />
                            <span className="text-gray-300 truncate">{perspName}</span>
                          </div>
                          {pv.override_statement && (
                            <p className="text-[11px] text-gray-300 leading-snug pl-1 mb-1 italic">
                              “{pv.override_statement}”
                            </p>
                          )}
                          {pv.sources.length > 0 && (
                            <ul className="text-[10px] text-gray-500 space-y-0.5 pl-1">
                              {pv.sources.map((s) => {
                                const w = s.weight_override ?? s.default_weight
                                return (
                                  <li key={s.source_id} className="leading-snug">
                                    <span className="text-gray-400">
                                      {s.citation}
                                    </span>
                                    <span className="text-gray-600">
                                      {' '}· weight {w.toFixed(2)}
                                      {s.weight_override != null && s.weight_override !== s.default_weight
                                        ? ` (override; default ${s.default_weight.toFixed(2)})`
                                        : ''}
                                    </span>
                                  </li>
                                )
                              })}
                            </ul>
                          )}
                        </div>
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
