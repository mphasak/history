import { useState, useEffect } from 'react'
import { api, WorldResponse, Perspective, PaleoBasemapResponse } from '../api'
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

// Continental shelf — polygon of L_0 minus K_200 from Natural Earth bathymetry.
// Fetched once and cached for the session (~2MB).
let _shelfPromise: Promise<GeoJSON.FeatureCollection> | null = null
function loadShelf(): Promise<GeoJSON.FeatureCollection> {
  if (_shelfPromise) return _shelfPromise
  _shelfPromise = fetch('/paleo/continental_shelf.geojson').then((r) => {
    if (!r.ok) throw new Error(`shelf load failed: ${r.status}`)
    return r.json() as Promise<GeoJSON.FeatureCollection>
  })
  return _shelfPromise
}

export function useContinentalShelf(): {
  data: GeoJSON.FeatureCollection | null
  loading: boolean
} {
  const [data, setData] = useState<GeoJSON.FeatureCollection | null>(null)
  const [loading, setLoading] = useState(true)
  useEffect(() => {
    let cancelled = false
    loadShelf()
      .then((d) => {
        if (!cancelled) {
          setData(d)
          setLoading(false)
        }
      })
      .catch(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])
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
