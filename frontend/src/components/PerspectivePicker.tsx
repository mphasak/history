import { useEffect } from 'react'
import { useStore } from '../state'
import { usePerspectives } from '../hooks/useWorldQuery'

export function PerspectivePicker() {
  const { perspectives, loading } = usePerspectives()
  const activePerspectives = useStore((s) => s.activePerspectives)
  const setActivePerspectives = useStore((s) => s.setActivePerspectives)

  // On first load, default to the default_active perspectives if none are set
  useEffect(() => {
    if (perspectives.length > 0 && activePerspectives.length === 0) {
      const defaults = perspectives
        .filter((p) => p.default_active && p.status === 'admitted')
        .map((p) => p.id)
      if (defaults.length > 0) setActivePerspectives(defaults)
    }
  }, [perspectives])

  const admittedPerspectives = perspectives.filter(
    (p) => p.status === 'admitted' || p.status === 'provisional'
  )

  function toggle(id: string) {
    if (activePerspectives.includes(id)) {
      setActivePerspectives(activePerspectives.filter((x) => x !== id))
    } else {
      setActivePerspectives([...activePerspectives, id])
    }
  }

  return (
    <div className="bg-gray-900 text-white p-3 rounded-lg shadow-lg min-w-64 max-w-xs">
      <h3 className="text-xs font-semibold uppercase text-gray-400 mb-2">
        Active Perspectives
      </h3>
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
