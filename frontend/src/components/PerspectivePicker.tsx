import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { usePerspectives } from '../hooks/useWorldQuery'

const DEFAULT_PERSPECTIVE = 'PERSP_POSTREICH_2025'

/**
 * Perspective picker.
 *
 * The default state is *collapsed* — most users land on the academic-mainstream
 * (Post-Reich consensus, 2025) view and don't need to think about
 * perspectives at all. A small "Perspectives" pill at the top-left expands
 * the multi-select for users who want to compare schools (e.g. AMT vs OOI
 * for the Indo-Aryan demo). Once expanded, the prior multi-select UI is
 * unchanged.
 *
 * On first load with no `?perspectives=` URL param, we seed the active set
 * to just `PERSP_POSTREICH_2025` (the academic mainstream) instead of the
 * DB's `default_active=true` set. The DB column is preserved so the
 * Indo-Aryan demo URL (`?perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI`)
 * still works.
 */
export function PerspectivePicker() {
  const { perspectives, loading } = usePerspectives()
  const activePerspectives = useStore((s) => s.activePerspectives)
  const setActivePerspectives = useStore((s) => s.setActivePerspectives)
  const [open, setOpen] = useState(false)

  // If no perspective ever got selected (URL param empty AND state seed
  // didn't apply), fall back to the academic-mainstream default.
  useEffect(() => {
    if (perspectives.length > 0 && activePerspectives.length === 0) {
      setActivePerspectives([DEFAULT_PERSPECTIVE])
    }
  }, [perspectives])

  const admittedPerspectives = perspectives.filter(
    (p) => p.status === 'admitted' || p.status === 'provisional'
  )

  function toggle(id: string) {
    if (activePerspectives.includes(id)) {
      // Don't let the user end up with zero perspectives selected — leaving
      // the default in place makes the empty-state recoverable.
      if (activePerspectives.length === 1) return
      setActivePerspectives(activePerspectives.filter((x) => x !== id))
    } else {
      setActivePerspectives([...activePerspectives, id])
    }
  }

  const activeNames = activePerspectives
    .map((id) => perspectives.find((p) => p.id === id)?.display_name ?? id)
    .join(' · ')

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="bg-gray-900/90 hover:bg-gray-800 text-white text-xs px-3 py-1.5 rounded-full shadow-lg border border-gray-700 flex items-center gap-2 max-w-xs"
        title="Open the Perspective picker. Currently active: more than one perspective lets you compare scholarly schools."
      >
        <span className="text-[10px] uppercase tracking-wide text-gray-400">
          Perspective
        </span>
        <span className="truncate text-gray-200">
          {activePerspectives.length === 0
            ? 'none'
            : activePerspectives.length === 1
              ? activeNames
              : `${activePerspectives.length} active`}
        </span>
        <span className="text-gray-500">▾</span>
      </button>
    )
  }

  return (
    <div className="bg-gray-900 text-white p-3 rounded-lg shadow-lg min-w-64 max-w-xs">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-xs font-semibold uppercase text-gray-400">
          Active Perspectives
        </h3>
        <button
          onClick={() => setOpen(false)}
          className="text-gray-400 hover:text-white text-sm leading-none"
          aria-label="Close perspective picker"
        >
          ×
        </button>
      </div>
      {loading && <p className="text-xs text-gray-500">Loading…</p>}
      <div className="space-y-1 max-h-72 overflow-y-auto">
        {admittedPerspectives.map((p) => {
          const active = activePerspectives.includes(p.id)
          return (
            <button
              key={p.id}
              onClick={() => toggle(p.id)}
              className={`w-full text-left px-2 py-1.5 rounded text-xs transition-colors ${
                active
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800 text-gray-300 hover:bg-gray-700'
              }`}
              title={p.methodology_notes}
            >
              <div className="font-medium truncate">{p.display_name}</div>
              {p.domain_scope.length > 0 && (
                <div className="text-gray-400 text-[10px] truncate">
                  {p.domain_scope.join(', ')}
                </div>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}
