import { useStore } from '../state'
import { DOMAIN_COLORS } from './Map'
import type { WorldResponse, PaleoFeature } from '../api'

const DOMAIN_ORDER = [
  'genetic',
  'linguistic',
  'ideological',
  'religious',
  'technological',
  'artistic',
  'institutional',
  'material_culture',
  'other',
] as const

function prettyDomain(d: string) {
  return d.replace(/_/g, ' ')
}

interface LegendProps {
  worldData: WorldResponse | null
  paleoFeatures?: PaleoFeature[]
  seaLevelMeters?: number | null
  /** True when the continental-shelf overlay is currently rendered. */
  shelfVisible?: boolean
  /** True when GPlates deep-time coastlines are currently rendered. */
  deepTimeActive?: boolean
}

const PALEO_TYPE_COLORS: Record<string, string> = {
  land_bridge: '#a16207',
  ice_sheet: '#e0f2fe',
  lake: '#1e3a8a',
  inland_sea: '#1e40af',
  sea: '#1e40af',
}

export function Legend({
  worldData,
  paleoFeatures = [],
  seaLevelMeters,
  shelfVisible = false,
  deepTimeActive = false,
}: LegendProps) {
  const vizMode = useStore((s) => s.vizMode)
  const presentPaleoTypes = new Set(paleoFeatures.filter((p) => p.geometry_geojson).map((p) => p.type))

  // Only show legend rows for domains that actually appear in the current data,
  // so the legend doesn't lie about what's on screen.
  const presentDomains = new Set<string>()
  if (worldData) {
    if (vizMode === 'pointwise') {
      for (const o of worldData.observations ?? []) presentDomains.add(o.domain)
    } else {
      for (const v of Object.values(worldData.perspectives)) {
        for (const c of v.carriers) {
          for (const m of c.trait_mix) presentDomains.add(m.domain)
        }
      }
    }
  }
  const rows = DOMAIN_ORDER.filter((d) => presentDomains.has(d))

  return (
    <div className="bg-gray-900/95 text-white text-xs rounded-lg shadow-xl border border-gray-700 px-3 py-2 w-56">
      <div className="font-semibold text-gray-200 mb-2">
        Legend — {vizMode === 'pointwise' ? 'pointwise' : 'fill'} mode
      </div>

      {vizMode === 'pointwise' ? (
        <div className="text-gray-400 mb-2 leading-snug">
          Dots are <span className="text-gray-200">archaeological samples</span>;
          large blue circles are carrier centroids.
        </div>
      ) : (
        <div className="text-gray-400 mb-2 leading-snug">
          Filled regions are{' '}
          <span className="text-gray-200">carrier extents</span>. Dashed
          outlines mark approximate (buffered) extents.
        </div>
      )}

      {rows.length > 0 && (
        <>
          <div className="text-gray-500 uppercase tracking-wide text-[10px] mb-1">
            Domains in view
          </div>
          <ul className="space-y-1">
            {rows.map((d) => (
              <li key={d} className="flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 rounded-full border border-gray-700"
                  style={{ background: DOMAIN_COLORS[d] }}
                />
                <span className="capitalize text-gray-300">{prettyDomain(d)}</span>
              </li>
            ))}
          </ul>
        </>
      )}

      {vizMode === 'fill' && (
        <div className="mt-2 pt-2 border-t border-gray-700 space-y-1">
          <div className="flex items-center gap-2">
            <span className="inline-block w-6 h-3 bg-blue-500/40 border border-blue-400" />
            <span className="text-gray-300">authored extent</span>
          </div>
          <div className="flex items-center gap-2">
            <span
              className="inline-block w-6 h-3 bg-blue-500/15"
              style={{ borderTop: '1.5px dashed #60a5fa', borderBottom: '1.5px dashed #60a5fa' }}
            />
            <span className="text-gray-300">buffered (no extent on file)</span>
          </div>
        </div>
      )}

      {(presentPaleoTypes.size > 0 || shelfVisible || deepTimeActive || seaLevelMeters != null) && (
        <div className="mt-2 pt-2 border-t border-gray-700">
          <div className="text-gray-500 uppercase tracking-wide text-[10px] mb-1">
            Paleogeography
            {seaLevelMeters != null && (
              <span className="ml-1 text-gray-400 normal-case tracking-normal">
                · sea level {seaLevelMeters > 0 ? '+' : ''}
                {seaLevelMeters.toFixed(0)} m
              </span>
            )}
          </div>
          <ul className="space-y-1">
            {deepTimeActive && (
              <li className="flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 border border-gray-700"
                  style={{ background: '#d6c79a', opacity: 0.7 }}
                />
                <span className="text-gray-300">paleo coastline (GPlates)</span>
              </li>
            )}
            {shelfVisible && (
              <li className="flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 border border-gray-700"
                  style={{ background: '#c2b280', opacity: 0.7 }}
                />
                <span className="text-gray-300">exposed continental shelf</span>
              </li>
            )}
            {Array.from(presentPaleoTypes).map((t) => (
              <li key={t} className="flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 border border-gray-700"
                  style={{ background: PALEO_TYPE_COLORS[t] ?? '#9ca3af', opacity: 0.6 }}
                />
                <span className="capitalize text-gray-300">{t.replace(/_/g, ' ')}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
