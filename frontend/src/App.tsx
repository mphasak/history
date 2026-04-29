import { useEffect, useRef } from 'react'
import { useStore } from './state'
import { WorldMap } from './components/Map'
import { YearSlider } from './components/YearSlider'
import { PerspectivePicker } from './components/PerspectivePicker'
import { DetailPanel } from './components/DetailPanel'
import { LineagePreviewPanel } from './components/LineagePreviewPanel'
import { ClickPointPanel } from './components/ClickPointPanel'
import { SearchBox } from './components/SearchBox'
import { YearHeader } from './components/YearHeader'
import { AdmixtureTimeline } from './components/AdmixtureTimeline'
import { AdmixtureCard } from './components/AdmixtureCard'
import { DiffLegend } from './components/DiffOverlay'
import { Legend } from './components/Legend'
import {
  useWorldQuery,
  usePaleoBasemap,
  useContinentalShelf,
  usePaleoCoastlines,
  useHistoricalPlaces,
  useCarrierLineage,
  useAdmixtureEvents,
} from './hooks/useWorldQuery'
import type { RenderMode, VizMode, LabelMode, LineageMode, CarrierColorMode } from './state'

export default function App() {
  const renderMode = useStore((s) => s.renderMode)
  const setRenderMode = useStore((s) => s.setRenderMode)
  const vizMode = useStore((s) => s.vizMode)
  const setVizMode = useStore((s) => s.setVizMode)
  const labelMode = useStore((s) => s.labelMode)
  const setLabelMode = useStore((s) => s.setLabelMode)
  const carrierColorMode = useStore((s) => s.carrierColorMode)
  const setCarrierColorMode = useStore((s) => s.setCarrierColorMode)
  const lineageMode = useStore((s) => s.lineageMode)
  const setLineageMode = useStore((s) => s.setLineageMode)
  const lineageAnimating = useStore((s) => s.lineageAnimating)
  const setLineageAnimating = useStore((s) => s.setLineageAnimating)
  const setLineagePreviewCarrierId = useStore((s) => s.setLineagePreviewCarrierId)
  const year = useStore((s) => s.year)
  const setYear = useStore((s) => s.setYear)
  const selectedCarrierId = useStore((s) => s.selectedCarrierId)
  const clickPoint = useStore((s) => s.clickPoint)
  const { data: worldData, loading, error } = useWorldQuery()
  const { data: paleo } = usePaleoBasemap()
  const { data: shelfGeojson, band: shelfBandM } = useContinentalShelf(
    paleo?.sea_level_meters ?? null
  )
  const { data: paleoCoastlines } = usePaleoCoastlines()
  const { data: historicalPlaces } = useHistoricalPlaces(labelMode === 'historical')
  const { data: lineage } = useCarrierLineage()
  const { active: activeAdmixtureEvents } = useAdmixtureEvents()

  // Exiting lineage mode (back to 'off') clears any preview node so the
  // DetailPanel returns to the focal carrier cleanly.
  useEffect(() => {
    if (lineageMode === 'off') setLineagePreviewCarrierId(null)
  }, [lineageMode, setLineagePreviewCarrierId])

  // Lineage animation: when toggled on, advance the year slider so the user
  // sees ancestors fade in then out, the focal carrier light up, and
  // descendants emerge in turn. The visible range is computed from the
  // lineage payload so the playback covers exactly the relevant span.
  // Auto-stops at the end (no looping — that just disorients).
  const animationStartRef = useRef<number | null>(null)
  useEffect(() => {
    if (!lineageAnimating || !lineage) return
    const minY = Math.min(
      lineage.focal?.date_min_year ?? lineage.year,
      ...lineage.ancestors.map((a) => a.date_min_year),
    )
    const maxY = Math.max(
      lineage.focal?.date_max_year ?? lineage.year,
      ...lineage.descendants.map((d) => d.date_max_year),
    )
    if (!Number.isFinite(minY) || !Number.isFinite(maxY) || minY >= maxY) {
      setLineageAnimating(false)
      return
    }
    const span = maxY - minY
    // Aim for ~10 s playback regardless of lineage span. Tick at 50 ms.
    const tickMs = 50
    const totalTicks = 10000 / tickMs
    const stepYears = Math.max(1, Math.ceil(span / totalTicks))
    if (animationStartRef.current === null || year < minY || year > maxY) {
      setYear(minY)
      animationStartRef.current = minY
    }
    const id = window.setInterval(() => {
      const cur = useStore.getState().year
      const next = cur + stepYears
      if (next > maxY) {
        setYear(maxY)
        setLineageAnimating(false)
        animationStartRef.current = null
        window.clearInterval(id)
        return
      }
      setYear(next)
    }, tickMs)
    return () => window.clearInterval(id)
    // Year is intentionally excluded so the interval isn't torn down on every
    // tick — we read the latest year via useStore.getState() inside.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lineageAnimating, lineage])

  return (
    <div className="flex flex-col h-screen bg-gray-950 text-white">
      {/* Header */}
      <header className="flex items-center px-4 py-2 bg-gray-900 border-b border-gray-700 shrink-0 gap-4">
        <h1 className="font-bold text-sm text-white">Human History Simulator</h1>
        <SearchBox />

        <div className="flex items-center gap-2">
          <span className="text-[10px] uppercase tracking-wide text-gray-500">Viz</span>
          <div className="flex gap-1">
            {(['pointwise', 'fill', 'flow'] as VizMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setVizMode(mode)}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  vizMode === mode
                    ? 'bg-emerald-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
                title={
                  mode === 'pointwise'
                    ? 'Each archaeological sample (trait_observation) as a colored dot'
                    : mode === 'fill'
                      ? 'Carrier extent polygons — solid for authored extents, dashed for buffered fallbacks'
                      : 'Migration / propagation arrows: source → destination, colored by domain'
                }
              >
                {mode === 'pointwise' ? 'Pointwise' : mode === 'fill' ? 'Fill' : 'Flow'}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-[10px] uppercase tracking-wide text-gray-500">Compare</span>
          <div className="flex gap-1">
            {(['single', 'side-by-side', 'diff-overlay'] as RenderMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setRenderMode(mode)}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  renderMode === mode
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {mode === 'single' ? 'Single' : mode === 'side-by-side' ? 'Side by Side' : 'Diff Overlay'}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span
            className="text-[10px] uppercase tracking-wide text-gray-500"
            title="Cluster: each carrier dot/extent takes a color from its dominant ancestry trait so populations sharing that ancestry visually group. Mono: legacy single blue."
          >
            Color
          </span>
          <div className="flex gap-1">
            {(['cluster', 'mono'] as CarrierColorMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setCarrierColorMode(mode)}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  carrierColorMode === mode
                    ? 'bg-pink-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {mode === 'cluster' ? 'Cluster' : 'Mono'}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-[10px] uppercase tracking-wide text-gray-500">Labels</span>
          <div className="flex gap-1">
            {(['modern', 'historical', 'none'] as LabelMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setLabelMode(mode)}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  labelMode === mode
                    ? 'bg-amber-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
                title={
                  mode === 'modern'
                    ? 'Show modern OSM place names + borders'
                    : mode === 'historical'
                      ? 'Show era-appropriate place names (Constantinople, Tenochtitlan, etc.)'
                      : 'Hide all labels — clean basemap'
                }
              >
                {mode === 'modern' ? 'Modern' : mode === 'historical' ? 'Historical' : 'None'}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span
            className="text-[10px] uppercase tracking-wide text-gray-500"
            title="Show ancestor / descendant populations of the selected carrier as connector lines on the map. Requires a selected carrier."
          >
            Lineage
          </span>
          <div className="flex gap-1">
            {(['off', 'past', 'future', 'both'] as LineageMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setLineageMode(mode)}
                disabled={mode !== 'off' && !selectedCarrierId}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  lineageMode === mode
                    ? 'bg-cyan-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                } disabled:opacity-50 disabled:cursor-not-allowed`}
                title={
                  mode === 'off'
                    ? 'Hide lineage'
                    : mode === 'past'
                      ? 'Show ancestor populations only'
                      : mode === 'future'
                        ? 'Show descendant populations only'
                        : 'Show both ancestors and descendants'
                }
              >
                {mode === 'off' ? 'Off' : mode.charAt(0).toUpperCase() + mode.slice(1)}
              </button>
            ))}
            <button
              onClick={() => setLineageAnimating(!lineageAnimating)}
              disabled={lineageMode === 'off' || !lineage}
              className={`text-xs px-2 py-1 rounded transition-colors ml-1 ${
                lineageAnimating
                  ? 'bg-rose-600 text-white'
                  : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              } disabled:opacity-50 disabled:cursor-not-allowed`}
              title={
                lineageAnimating
                  ? 'Pause animation'
                  : 'Animate the lineage forward in time so ancestors fade in/out and descendants light up in sequence.'
              }
            >
              {lineageAnimating ? '⏸ Pause' : '▶ Play'}
            </button>
          </div>
        </div>

        {loading && (
          <span className="text-xs text-gray-400 ml-auto">Fetching world…</span>
        )}
        {error && (
          <span className="text-xs text-red-400 ml-auto" title={error}>
            API error
          </span>
        )}
      </header>

      {/* Main area */}
      <div className="flex-1 relative overflow-hidden">
        {/* Map fills the whole area */}
        <WorldMap
          worldData={worldData}
          loading={loading}
          paleoFeatures={paleo?.physical_features ?? []}
          shelfGeojson={shelfGeojson}
          seaLevelMeters={paleo?.sea_level_meters ?? null}
          paleoCoastlines={paleoCoastlines}
          historicalPlaces={historicalPlaces}
          lineage={lineage}
          activeAdmixtureEvents={activeAdmixtureEvents}
        />

        {/* Perspective picker — top-left overlay */}
        <div className="absolute top-3 left-3 z-10">
          <PerspectivePicker />
        </div>

        {/* Year + era header — top-center overlay. Big, glanceable
            "where am I in time?" indicator that doesn't require reading
            the slider tick. */}
        <div className="absolute top-3 left-1/2 -translate-x-1/2 z-10 pointer-events-none">
          <YearHeader year={year} />
        </div>

        {/* Viz legend — always visible bottom-left */}
        <div className="absolute bottom-12 left-3 z-10">
          <Legend
            worldData={worldData}
            paleoFeatures={paleo?.physical_features ?? []}
            seaLevelMeters={paleo?.sea_level_meters}
            shelfVisible={shelfBandM != null && (shelfGeojson?.features?.length ?? 0) > 0}
            shelfBandM={shelfBandM}
            deepTimeActive={(paleoCoastlines?.features?.length ?? 0) > 0}
            paleoCoastlines={paleoCoastlines}
          />
        </div>

        {/* Diff legend — bottom-left, stacked above the viz legend */}
        {renderMode === 'diff-overlay' && (
          <div className="absolute bottom-12 left-64 z-10">
            <DiffLegend worldData={worldData} />
          </div>
        )}

        {/* Detail panel — right overlay when carrier selected */}
        {selectedCarrierId && (
          <div className="absolute top-3 right-3 z-10 max-h-[calc(100vh-8rem)] overflow-y-auto">
            <DetailPanel />
          </div>
        )}

        {/* Lineage preview — second column on the right when the user
            inspects a non-focal node. Renders nothing when lineage is off
            or no preview is set, so it doesn't compete for space normally. */}
        {selectedCarrierId && lineageMode !== 'off' && (
          <div className="absolute top-3 right-[22rem] z-10 max-h-[calc(100vh-8rem)] overflow-y-auto">
            <LineagePreviewPanel />
          </div>
        )}

        {/* Click-point panel — right overlay when a map point was clicked */}
        {clickPoint && !selectedCarrierId && (
          <div className="absolute top-3 right-3 z-10 max-h-[calc(100vh-8rem)] overflow-y-auto">
            <ClickPointPanel />
          </div>
        )}

        {/* Admixture event card — opens when the user clicks a marker
            on the AdmixtureTimeline. Renders nothing otherwise. */}
        <div className="absolute top-3 right-3 z-20">
          <AdmixtureCard />
        </div>
      </div>

      {/* Footer — admixture timeline + year slider. Timeline goes ABOVE
          the slider so the markers visually align with the slider thumb
          (both share the piecewise-log scale via lib/timeScale.ts). */}
      <footer className="shrink-0">
        <AdmixtureTimeline />
        <YearSlider />
      </footer>
    </div>
  )
}
