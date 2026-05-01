import { useEffect, useState } from 'react'
import { useStore } from '../state'
import {
  api,
  CarrierView,
  CarrierTimelineResponse,
  CarrierClaim,
  CarrierThreat,
  CarrierPlight,
} from '../api'
import { useWorldQuery, usePerspectives } from '../hooks/useWorldQuery'
import { fetchCarrierImage, wikipediaSearchUrl, WikipediaSummary } from '../lib/wikipedia'

const THREAT_TYPE_LABEL: Record<string, string> = {
  climate: 'Climate',
  disease: 'Disease',
  war: 'War',
  raids: 'Raids',
  displacement: 'Displacement',
  resource_scarcity: 'Resource scarcity',
  resource_competition: 'Resource competition',
  megafauna_loss: 'Megafauna loss',
  natural_disaster: 'Natural disaster',
  colonization: 'Colonization',
  genocide: 'Genocide',
  assimilation_pressure: 'Assimilation pressure',
  other: 'Other',
}

function severityStyle(sev: number): string {
  // 1-2: gray; 3: amber; 4: orange; 5: rose. Color codes existential vs stressor.
  if (sev >= 5) return 'border-rose-700 bg-rose-950/30 text-rose-200'
  if (sev >= 4) return 'border-orange-700 bg-orange-950/30 text-orange-200'
  if (sev >= 3) return 'border-amber-700 bg-amber-950/30 text-amber-200'
  return 'border-gray-700 bg-gray-800/40 text-gray-200'
}

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
  const [threats, setThreats] = useState<CarrierThreat[]>([])
  const [loadingThreats, setLoadingThreats] = useState(false)
  // Wikipedia thumbnail + brief extract for the selected carrier — fetched
  // directly from Wikipedia's REST API (CORS-allowed), cached client-side
  // by title. Many carriers have no Wikipedia page; in that case we silently
  // skip rendering the image.
  const [wiki, setWiki] = useState<WikipediaSummary | null>(null)
  const [plight, setPlight] = useState<CarrierPlight | null>(null)

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

  useEffect(() => {
    if (!selectedCarrierId) { setThreats([]); return }
    setLoadingThreats(true)
    api
      .carrierThreats(selectedCarrierId, year)
      .then((res) => { setThreats(res.threats); setLoadingThreats(false) })
      .catch(() => { setThreats([]); setLoadingThreats(false) })
  }, [selectedCarrierId, year])

  // Plight narrative — editorial 1-2 paragraphs about everyday life,
  // origin, ending. Many carriers don't have one yet; the section just
  // hides when the API returns null.
  useEffect(() => {
    if (!selectedCarrierId) { setPlight(null); return }
    let cancelled = false
    setPlight(null)
    api.carrierPlight(selectedCarrierId).then((res) => {
      if (!cancelled) setPlight(res)
    })
    return () => { cancelled = true }
  }, [selectedCarrierId])

  // Wikipedia image lookup. Resets per carrier so we don't briefly show the
  // previous carrier's photo while the new fetch is in-flight.
  useEffect(() => {
    if (!selectedCarrierId) { setWiki(null); return }
    setWiki(null)
    let cancelled = false
    const carrier = worldData
      ? Object.values(worldData.perspectives)
          .flatMap((v) => v.carriers)
          .find((c) => c.id === selectedCarrierId)
      : null
    const displayName = carrier?.display_name ?? selectedCarrierId
    fetchCarrierImage(selectedCarrierId, displayName).then((res) => {
      if (!cancelled) setWiki(res)
    })
    return () => { cancelled = true }
  }, [selectedCarrierId])

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

  /** Compact form for the header date range. Switches to "kya" past 10000
   * BCE so the deep-paleolithic carriers (Jebel Irhoud, Homo erectus,
   * Neanderthal) read cleanly instead of showing "300,000 BCE". */
  function formatYearCompact(y: number): string {
    if (y < -10000) return `${(Math.abs(y) / 1000).toFixed(0)} kya`
    if (y < 0) return `${Math.abs(y).toLocaleString()} BCE`
    return `${y} CE`
  }

  // Carrier date range for the header subtitle. Pull from the first active
  // perspective's view (carriers are uniform across perspectives — only the
  // endorsement and stance differ).
  const headerCarrier =
    carriersByPersp[activePerspectives[0]] ??
    Object.values(carriersByPersp).find((c) => c) ??
    null

  return (
    <div className="bg-gray-900 text-white rounded-lg shadow-xl w-80 max-h-screen overflow-y-auto">
      <div className="flex items-start justify-between px-4 py-3 border-b border-gray-700 gap-2">
        <div className="min-w-0 flex-1">
          <h2 className="font-semibold text-sm truncate">
            {headerCarrier?.display_name ?? selectedCarrierId}
          </h2>
          {headerCarrier && (
            <p
              className="text-[11px] text-gray-400 mt-0.5"
              title="Active period — the date range during which this carrier is treated as existing on the map."
            >
              {formatYearCompact(headerCarrier.date_min_year)}
              {' – '}
              {formatYearCompact(headerCarrier.date_max_year)}
            </p>
          )}
        </div>
        <button
          onClick={() => setSelectedCarrierId(null)}
          className="text-gray-400 hover:text-white shrink-0"
          aria-label="Close"
        >
          ×
        </button>
      </div>

      {/* Wikipedia thumbnail + extract — only renders when a thumbnail came
          back. Many carriers (gene-component populations, gap-fillers
          without dedicated articles) have no Wikipedia entry, in which
          case this section is silently omitted. */}
      {/* Wikipedia thumbnail + extract + Read-more link.
          ALWAYS shows a "Read on Wikipedia" link — when no canonical
          page summary is found we fall back to a Wikipedia *search*
          URL with the carrier's display_name. So every carrier has
          *some* path to further reading; only the thumbnail + extract
          are gated on the API returning a real summary. */}
      {(() => {
        const focal = headerCarrier
        const dn = focal?.display_name ?? selectedCarrierId
        const linkUrl = wiki?.contentUrl ?? wikipediaSearchUrl(dn)
        const linkText = wiki?.title
          ? `Read on Wikipedia → ${wiki.title}`
          : `Search Wikipedia for "${dn}"`
        return (
          <div className="border-b border-gray-700">
            {wiki?.thumbnail && (
              <a
                href={linkUrl}
                target="_blank"
                rel="noreferrer"
                className="block group"
                title={`From Wikipedia: ${wiki.title ?? dn}`}
              >
                <img
                  src={wiki.thumbnail.source}
                  alt={wiki.title ?? dn}
                  className="w-full h-40 object-cover group-hover:opacity-90 transition-opacity"
                  loading="lazy"
                />
              </a>
            )}
            <div className="px-4 py-2 text-[10px] leading-snug">
              {wiki?.extract && (
                <p className="text-[11px] text-gray-300 line-clamp-3 mb-1.5">
                  {wiki.extract}
                </p>
              )}
              <a
                href={linkUrl}
                target="_blank"
                rel="noreferrer"
                className="text-blue-400 hover:text-blue-300 underline decoration-dotted"
              >
                {linkText}
              </a>
            </div>
          </div>
        )
      })()}

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

        {/* Plight narrative — editorial 1-2 paragraphs on everyday
            life, origin, and ending. Pairs with the Threats list:
            Threats is *itemized event-window* records; Plight is the
            *narrative gestalt* of what it meant to live as one of these
            people. Hidden when no narrative is seeded for the carrier. */}
        {plight && (
          <div>
            <div className="text-xs uppercase tracking-wide text-gray-500 mb-2">
              Plight
            </div>
            <div className="space-y-2 text-[12px] leading-relaxed text-gray-200">
              <p>{plight.everyday_life}</p>
              {plight.origin && (
                <p>
                  <span className="text-gray-500 italic">Origin. </span>
                  {plight.origin}
                </p>
              )}
              {plight.ending && (
                <p>
                  <span className="text-gray-500 italic">Ending. </span>
                  {plight.ending}
                </p>
              )}
            </div>
          </div>
        )}

        {/* Threats faced by this population at the current year. Backend
            filters carrier_threat rows whose [date_min_year, date_max_year]
            window contains `year`, so the section auto-updates as the user
            scrubs the slider. */}
        {(loadingThreats || threats.length > 0) && (
          <div>
            <div className="text-xs uppercase tracking-wide text-gray-500 mb-2">
              Threats at {formatYear(year)}
            </div>

            {loadingThreats && (
              <p className="text-xs text-gray-500">Loading threats…</p>
            )}

            <ul className="space-y-2">
              {threats.map((t) => (
                <li key={t.id} className={`border rounded-lg p-2 ${severityStyle(t.severity)}`}>
                  <div className="flex items-baseline justify-between gap-2 mb-1">
                    <span className="text-[10px] uppercase tracking-wide font-semibold opacity-80">
                      {THREAT_TYPE_LABEL[t.threat_type] ?? t.threat_type}
                    </span>
                    <span className="text-[10px] opacity-70">
                      severity {t.severity}/5
                    </span>
                  </div>
                  <div className="text-xs font-medium mb-0.5">{t.display_name}</div>
                  {t.description && (
                    <p className="text-[11px] leading-snug opacity-90">{t.description}</p>
                  )}
                  {t.sources.length > 0 && (
                    <ul className="mt-1 text-[10px] opacity-70 space-y-0.5">
                      {t.sources.map((s) => (
                        <li key={s.source_id} className="leading-snug">{s.citation}</li>
                      ))}
                    </ul>
                  )}
                </li>
              ))}
            </ul>
          </div>
        )}

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
