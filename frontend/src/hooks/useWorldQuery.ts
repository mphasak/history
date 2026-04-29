import { useState, useEffect } from 'react'
import {
  api,
  WorldResponse,
  Perspective,
  PaleoBasemapResponse,
  HistoricalPlace,
  CarrierLineageResponse,
} from '../api'
import { useStore } from '../state'

interface WorldQueryResult {
  data: WorldResponse | null
  loading: boolean
  error: string | null
}

export function useWorldQuery(): WorldQueryResult {
  const year = useStore((s) => s.year)
  const bbox = useStore((s) => s.bbox)
  const activePerspectives = useStore((s) => s.activePerspectives)

  const [data, setData] = useState<WorldResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)

    api
      .world(year, bbox, activePerspectives)
      .then((res) => {
        if (!cancelled) {
          setData(res)
          setLoading(false)
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(String(err))
          setLoading(false)
        }
      })

    return () => {
      cancelled = true
    }
  }, [year, bbox[0], bbox[1], bbox[2], bbox[3], activePerspectives.join(',')])

  return { data, loading, error }
}

interface PerspectivesResult {
  perspectives: Perspective[]
  loading: boolean
  error: string | null
}

interface PaleoResult {
  data: PaleoBasemapResponse | null
  loading: boolean
  error: string | null
}

export function usePaleoBasemap(): PaleoResult {
  const year = useStore((s) => s.year)
  const [data, setData] = useState<PaleoBasemapResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    api
      .paleoBasemap(year)
      .then((res) => {
        if (!cancelled) {
          setData(res)
          setLoading(false)
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(String(err))
          setLoading(false)
        }
      })
    return () => { cancelled = true }
  }, [year])

  return { data, loading, error }
}

// GPlates paleo-coastlines for deep time (year < -3 Mya). Cached client-side
// keyed by year (rounded server-side to 0.5 Ma).
const DEEP_TIME_THRESHOLD = -3_000_000

export function usePaleoCoastlines(): {
  data: GeoJSON.FeatureCollection | null
  loading: boolean
  error: string | null
} {
  const year = useStore((s) => s.year)
  const [data, setData] = useState<GeoJSON.FeatureCollection | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (year > DEEP_TIME_THRESHOLD) {
      setData(null)
      setError(null)
      return
    }
    let cancelled = false
    setLoading(true)
    setError(null)
    api
      .paleoCoastlines(year)
      .then((d) => {
        if (!cancelled) {
          setData(d)
          setLoading(false)
        }
      })
      .catch((e) => {
        if (!cancelled) {
          setError(String(e))
          setData(null)
          setLoading(false)
        }
      })
    return () => { cancelled = true }
  }, [year])

  return { data, loading, error }
}

// Continental-shelf depth bands (m). Each entry is a polygon eroded from the
// full L_0 minus K_200 shelf to approximate land exposure at that sea level.
// Picked by sea-level proximity at runtime; loaded lazily and cached.
const SHELF_BANDS_M = [-150, -90, -50, -25] as const
type ShelfBandM = (typeof SHELF_BANDS_M)[number]

const _shelfPromises: Partial<Record<ShelfBandM, Promise<GeoJSON.FeatureCollection>>> = {}
function loadShelfBand(band: ShelfBandM): Promise<GeoJSON.FeatureCollection> {
  const cached = _shelfPromises[band]
  if (cached) return cached
  const p = fetch(`/paleo/shelf_${band}m.geojson`).then((r) => {
    if (!r.ok) throw new Error(`shelf band ${band} load failed: ${r.status}`)
    return r.json() as Promise<GeoJSON.FeatureCollection>
  })
  _shelfPromises[band] = p
  return p
}

// Pick the band whose depth is closest to the current sea level (clamped to
// the shallowest band when sea level is between -25 and 0 m).
function pickShelfBand(seaLevelMeters: number): ShelfBandM {
  let best: ShelfBandM = SHELF_BANDS_M[0]
  let bestDiff = Math.abs(best - seaLevelMeters)
  for (const b of SHELF_BANDS_M) {
    const d = Math.abs(b - seaLevelMeters)
    if (d < bestDiff) {
      best = b
      bestDiff = d
    }
  }
  return best
}

export function useContinentalShelf(seaLevelMeters: number | null | undefined): {
  data: GeoJSON.FeatureCollection | null
  band: ShelfBandM | null
  loading: boolean
} {
  const [data, setData] = useState<GeoJSON.FeatureCollection | null>(null)
  const [band, setBand] = useState<ShelfBandM | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (seaLevelMeters == null || seaLevelMeters > -25) {
      // Above the shallowest band: nothing to show.
      setData(null)
      setBand(null)
      setLoading(false)
      return
    }
    const target = pickShelfBand(seaLevelMeters)
    let cancelled = false
    setLoading(true)
    loadShelfBand(target)
      .then((d) => {
        if (!cancelled) {
          setData(d)
          setBand(target)
          setLoading(false)
        }
      })
      .catch(() => {
        if (!cancelled) {
          setData(null)
          setBand(null)
          setLoading(false)
        }
      })
    return () => { cancelled = true }
  }, [seaLevelMeters])

  return { data, band, loading }
}

// Historical place labels (Constantinople, Tenochtitlan, etc.) filtered to
// the carriers/year window. Only fired when label mode is "historical" so
// the modern-label fallback path doesn't pay for the fetch.
export function useHistoricalPlaces(enabled: boolean): {
  data: HistoricalPlace[]
  loading: boolean
} {
  const year = useStore((s) => s.year)
  const [data, setData] = useState<HistoricalPlace[]>([])
  const [loading, setLoading] = useState(false)
  useEffect(() => {
    if (!enabled) {
      setData([])
      setLoading(false)
      return
    }
    let cancelled = false
    setLoading(true)
    api
      .historicalPlaces(year)
      .then((res) => {
        if (!cancelled) {
          setData(res.places)
          setLoading(false)
        }
      })
      .catch(() => {
        if (!cancelled) {
          setData([])
          setLoading(false)
        }
      })
    return () => { cancelled = true }
  }, [year, enabled])
  return { data, loading }
}

/**
 * Past/future lineage for the currently selected carrier.
 *
 * The lineage is anchored on the year *when the user activates lineage mode*
 * (or selects a different carrier), and stays stable as the slider scrubs —
 * otherwise animation mode would re-fetch on every year tick, causing the
 * edge set itself to flicker as "post-current-year" carriers drop out of
 * range. A static anchor lets the animation just fade nodes in/out based on
 * whether they're "alive" at the current year.
 */
export function useCarrierLineage(): {
  data: CarrierLineageResponse | null
  loading: boolean
} {
  const lineageMode = useStore((s) => s.lineageMode)
  const carrierId = useStore((s) => s.selectedCarrierId)
  const year = useStore((s) => s.year)
  const [data, setData] = useState<CarrierLineageResponse | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (lineageMode === 'off' || !carrierId) {
      setData(null)
      setLoading(false)
      return
    }
    let cancelled = false
    setLoading(true)
    // Capture the year at activation as the anchor; it does not refetch on
    // subsequent year changes.
    const anchorYear = year
    api
      .carrierLineage(carrierId, anchorYear, lineageMode, {
        // Multi-hop default — lets the user trace e.g. modern-US back
        // through European Bronze Age and OOA to Neanderthal.
        maxDepth: 5,
        maxPerHop: 5,
      })
      .then((res) => {
        if (!cancelled) {
          setData(res)
          setLoading(false)
        }
      })
      .catch(() => {
        if (!cancelled) {
          setData(null)
          setLoading(false)
        }
      })
    return () => { cancelled = true }
    // Intentionally exclude `year` so the anchor stays put while the slider
    // (and animation) move it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lineageMode, carrierId])

  return { data, loading }
}

export function usePerspectives(): PerspectivesResult {
  const [perspectives, setPerspectives] = useState<Perspective[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api
      .perspectives()
      .then((data) => {
        setPerspectives(data)
        setLoading(false)
      })
      .catch((err) => {
        setError(String(err))
        setLoading(false)
      })
  }, [])

  return { perspectives, loading, error }
}
