import { useStore } from './state'
import { WorldMap } from './components/Map'
import { YearSlider } from './components/YearSlider'
import { PerspectivePicker } from './components/PerspectivePicker'
import { DetailPanel } from './components/DetailPanel'
import { ClickPointPanel } from './components/ClickPointPanel'
import { DiffLegend } from './components/DiffOverlay'
import { Legend } from './components/Legend'
import {
  useWorldQuery,
  usePaleoBasemap,
  useContinentalShelf,
  usePaleoCoastlines,
  useHistoricalPlaces,
} from './hooks/useWorldQuery'
import type { RenderMode, VizMode, LabelMode } from './state'

export default function App() {
  const renderMode = useStore((s) => s.renderMode)
  const setRenderMode = useStore((s) => s.setRenderMode)
  const vizMode = useStore((s) => s.vizMode)
  const setVizMode = useStore((s) => s.setVizMode)
  const labelMode = useStore((s) => s.labelMode)
  const setLabelMode = useStore((s) => s.setLabelMode)
  const selectedCarrierId = useStore((s) => s.selectedCarrierId)
  const clickPoint = useStore((s) => s.clickPoint)
  const { data: worldData, loading, error } = useWorldQuery()
  const { data: paleo } = usePaleoBasemap()
  const { data: shelfGeojson, band: shelfBandM } = useContinentalShelf(
    paleo?.sea_level_meters ?? null
  )
  const { data: paleoCoastlines } = usePaleoCoastlines()
  const { data: historicalPlaces } = useHistoricalPlaces(labelMode === 'historical')

  return (
    <div className="flex flex-col h-screen bg-gray-950 text-white">
      {/* Header */}
      <header className="flex items-center px-4 py-2 bg-gray-900 border-b border-gray-700 shrink-0 gap-4">
        <h1 className="font-bold text-sm text-white">Human History Simulator</h1>

        <div className="flex items-center gap-2">
          <span className="text-[10px] uppercase tracking-wide text-gray-500">Viz</span>
          <div className="flex gap-1">
            {(['pointwise', 'fill'] as VizMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setVizMode(mode)}
                className={`text-xs px-2 py-1 rounded transition-colors ${
                  vizMode === mode
                    ? 'bg-emerald-600 text-white'
                    : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                }`}
              >
                {mode === 'pointwise' ? 'Pointwise' : 'Fill'}
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
        />

        {/* Perspective picker — top-left overlay */}
        <div className="absolute top-3 left-3 z-10">
          <PerspectivePicker />
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

        {/* Click-point panel — right overlay when a map point was clicked */}
        {clickPoint && !selectedCarrierId && (
          <div className="absolute top-3 right-3 z-10 max-h-[calc(100vh-8rem)] overflow-y-auto">
            <ClickPointPanel />
          </div>
        )}
      </div>

      {/* Footer — year slider */}
      <footer className="shrink-0">
        <YearSlider />
      </footer>
    </div>
  )
}
