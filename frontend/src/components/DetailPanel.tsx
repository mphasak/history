import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { api, CarrierView, CarrierTimelineResponse } from '../api'
import { useWorldQuery, usePerspectives } from '../hooks/useWorldQuery'

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
      </div>
    </div>
  )
}
