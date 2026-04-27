import { useState, useEffect } from 'react'
import { api, WorldResponse, Perspective } from '../api'
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
