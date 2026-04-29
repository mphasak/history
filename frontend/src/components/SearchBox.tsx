/**
 * SearchBox — discover-by-name input for carriers.
 *
 * The map is great for browsing geographically, but to *find* a specific
 * population (Mali Empire, Han dynasty, Lapita) the user needed to
 * already know what year to scrub to. This box solves that: type a
 * substring, see matching carriers across all eras, click one to:
 *   1. snap the year slider to the carrier's mid-range,
 *   2. select the carrier (opens DetailPanel),
 *   3. pan the map to its centroid (handled implicitly by the user
 *      reading the dot they just selected).
 *
 * The dropdown is keyboard-navigable (↑ / ↓ / Enter / Esc).
 */
import { useEffect, useRef, useState } from 'react'
import { api, CarrierSearchResult } from '../api'
import { useStore } from '../state'

function formatYear(y: number): string {
  if (y < -10000) return `${(Math.abs(y) / 1000).toFixed(0)} kya`
  if (y < 0) return `${Math.abs(y).toLocaleString()} BCE`
  return `${y} CE`
}

export function SearchBox() {
  const [q, setQ] = useState('')
  const [results, setResults] = useState<CarrierSearchResult[]>([])
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const [loading, setLoading] = useState(false)
  const setYear = useStore((s) => s.setYear)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const setLineagePreview = useStore((s) => s.setLineagePreviewCarrierId)
  const inputRef = useRef<HTMLInputElement | null>(null)
  const containerRef = useRef<HTMLDivElement | null>(null)

  // Debounced fetch.
  useEffect(() => {
    const term = q.trim()
    if (term.length === 0) { setResults([]); setOpen(false); return }
    let cancelled = false
    setLoading(true)
    const t = window.setTimeout(() => {
      api.carriersSearch(term, 12)
        .then((r) => {
          if (cancelled) return
          setResults(r.results)
          setOpen(r.results.length > 0)
          setActive(0)
          setLoading(false)
        })
        .catch(() => { if (!cancelled) setLoading(false) })
    }, 200)
    return () => { cancelled = true; window.clearTimeout(t) }
  }, [q])

  // Close dropdown on outside click.
  useEffect(() => {
    function onDoc(e: MouseEvent) {
      if (!containerRef.current) return
      if (!containerRef.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [])

  // Keyboard shortcut: "/" focuses the box (matches GitHub / many apps).
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === '/' && document.activeElement?.tagName !== 'INPUT') {
        e.preventDefault()
        inputRef.current?.focus()
      }
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [])

  function pick(r: CarrierSearchResult) {
    // Snap to mid-range so the carrier is alive when the panel opens.
    const mid = Math.round((r.date_min_year + r.date_max_year) / 2)
    setYear(mid)
    setLineagePreview(null)
    setSelectedCarrierId(r.id)
    setQ('')
    setResults([])
    setOpen(false)
    inputRef.current?.blur()
  }

  function onKey(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActive((i) => Math.min(results.length - 1, i + 1))
      setOpen(true)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActive((i) => Math.max(0, i - 1))
    } else if (e.key === 'Enter' && open && results[active]) {
      e.preventDefault()
      pick(results[active])
    } else if (e.key === 'Escape') {
      setOpen(false)
      inputRef.current?.blur()
    }
  }

  return (
    <div ref={containerRef} className="relative">
      <input
        ref={inputRef}
        type="text"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onKeyDown={onKey}
        onFocus={() => results.length > 0 && setOpen(true)}
        placeholder="Search populations… (/)"
        className="bg-gray-800 text-white text-xs placeholder-gray-500 px-3 py-1.5 rounded border border-gray-700 focus:border-blue-500 focus:outline-none w-56"
      />
      {open && (
        <div className="absolute top-full left-0 mt-1 w-80 bg-gray-900 border border-gray-700 rounded shadow-xl z-50 max-h-80 overflow-y-auto">
          {loading && (
            <div className="px-3 py-2 text-xs text-gray-500">Searching…</div>
          )}
          {!loading && results.length === 0 && (
            <div className="px-3 py-2 text-xs text-gray-500">No matches.</div>
          )}
          {results.map((r, i) => (
            <button
              key={r.id}
              onMouseDown={(e) => { e.preventDefault(); pick(r) }}
              onMouseEnter={() => setActive(i)}
              className={`w-full text-left px-3 py-1.5 text-xs border-b border-gray-800 last:border-0 ${
                i === active ? 'bg-gray-800' : 'bg-gray-900'
              } hover:bg-gray-800`}
            >
              <div className="text-gray-200 font-medium truncate">{r.display_name}</div>
              <div className="text-[10px] text-gray-500 truncate flex items-center gap-2">
                <span>{formatYear(r.date_min_year)} — {formatYear(r.date_max_year)}</span>
                {r.dominant_trait && (
                  <span className="text-gray-600">· {r.dominant_trait}</span>
                )}
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
