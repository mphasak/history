import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { api, WorldAtPointResponse, CarrierView } from '../api'

function formatYear(y: number) {
  return y < 0 ? `${Math.abs(y).toLocaleString()} BCE` : `${y} CE`
}

function formatLatLon(lat: number, lon: number) {
  const ns = lat >= 0 ? 'N' : 'S'
  const ew = lon >= 0 ? 'E' : 'W'
  return `${Math.abs(lat).toFixed(2)}°${ns}, ${Math.abs(lon).toFixed(2)}°${ew}`
}

export function ClickPointPanel() {
  const clickPoint = useStore((s) => s.clickPoint)
  const setClickPoint = useStore((s) => s.setClickPoint)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const year = useStore((s) => s.year)
  const activePerspectives = useStore((s) => s.activePerspectives)

  const [data, setData] = useState<WorldAtPointResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    if (!clickPoint) {
      setData(null)
      return
    }
    setLoading(true)
    setErr(null)
    api
      .worldAt(year, clickPoint.lat, clickPoint.lon, activePerspectives)
      .then((d) => {
        setData(d)
        // Auto-select if exactly one unique carrier across perspectives
        const ids = new Set<string>()
        for (const v of Object.values(d.perspectives)) {
          for (const c of v.carriers) ids.add(c.id)
        }
        if (ids.size === 1) {
          const only = ids.values().next().value as string
          setSelectedCarrierId(only)
          setClickPoint(null)
        }
      })
      .catch((e) => setErr(String(e)))
      .finally(() => setLoading(false))
  }, [clickPoint?.lat, clickPoint?.lon, year, activePerspectives.join(',')])

  if (!clickPoint) return null

  // Aggregate carriers by id with min distance across perspectives
  const aggregated = new Map<string, CarrierView>()
  if (data) {
    for (const v of Object.values(data.perspectives)) {
      for (const c of v.carriers) {
        const prev = aggregated.get(c.id)
        if (!prev || (c.distance_km ?? Infinity) < (prev.distance_km ?? Infinity)) {
          aggregated.set(c.id, c)
        }
      }
    }
  }
  const carriers = Array.from(aggregated.values()).sort(
    (a, b) => (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity)
  )

  return (
    <div className="bg-gray-900 text-white rounded-lg shadow-xl w-80 max-h-screen overflow-y-auto border border-gray-700">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
        <div>
          <div className="text-xs text-gray-400">Carriers near</div>
          <div className="font-mono text-sm">
            {formatLatLon(clickPoint.lat, clickPoint.lon)}
          </div>
          <div className="text-xs text-gray-400 mt-0.5">at {formatYear(year)}</div>
        </div>
        <button
          onClick={() => setClickPoint(null)}
          className="text-gray-400 hover:text-white ml-2 shrink-0"
          aria-label="Close"
        >
          ×
        </button>
      </div>

      <div className="p-3">
        {loading && <p className="text-xs text-gray-500">Searching…</p>}
        {err && <p className="text-xs text-red-400">{err}</p>}
        {!loading && !err && carriers.length === 0 && (
          <p className="text-xs text-gray-500">
            No carriers found within 3,000&nbsp;km of this point at this year.
          </p>
        )}
        <ul className="space-y-2">
          {carriers.map((c) => {
            const covers = c.covers_point
            const dist = c.distance_km ?? null
            return (
              <li key={c.id}>
                <button
                  className="w-full text-left rounded border border-gray-700 hover:border-blue-500 hover:bg-gray-800 px-3 py-2 transition-colors"
                  onClick={() => {
                    setSelectedCarrierId(c.id)
                    setClickPoint(null)
                  }}
                >
                  <div className="text-sm font-medium">{c.display_name}</div>
                  <div className="text-xs text-gray-400 mt-0.5">
                    {c.type.replace(/_/g, ' ')} · {formatYear(c.date_min_year)} —{' '}
                    {formatYear(c.date_max_year)}
                  </div>
                  <div className="text-xs mt-0.5">
                    {covers ? (
                      <span className="text-emerald-400">extent contains this point</span>
                    ) : dist !== null ? (
                      <span className="text-gray-500">{dist.toFixed(0)} km from centroid</span>
                    ) : null}
                  </div>
                </button>
              </li>
            )
          })}
        </ul>
      </div>
    </div>
  )
}
