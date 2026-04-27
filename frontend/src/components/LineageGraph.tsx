/**
 * LineageGraph — stretch goal for Phase 0.
 * Renders a trait's ancestry tree using SVG.
 * Simple recursive tree layout (no d3-sankey dependency).
 */
import { useEffect, useState } from 'react'
import { api } from '../api'

interface Node {
  trait_id: string
  display_name: string
  relation_type: string
  weight: number | null
  endorsement: { stance: string } | null
  parents: Node[]
}

interface LineageGraphProps {
  traitId: string
  perspectiveId: string
}

const STANCE_COLORS: Record<string, string> = {
  endorses: '#3b82f6',
  nuances: '#f59e0b',
  asserts: '#22c55e',
  rejects: '#ef4444',
}

function TreeNode({
  node,
  depth = 0,
  x,
  y,
  onHover,
}: {
  node: Node
  depth?: number
  x: number
  y: number
  onHover: (text: string | null) => void
}) {
  const color = STANCE_COLORS[node.endorsement?.stance ?? 'endorses'] ?? '#6b7280'

  return (
    <g>
      <circle
        cx={x}
        cy={y}
        r={8}
        fill={color}
        stroke="#1f2937"
        strokeWidth={2}
        className="cursor-pointer"
        onMouseEnter={() => onHover(`${node.display_name} (${node.relation_type})`)}
        onMouseLeave={() => onHover(null)}
      />
      <text x={x + 12} y={y + 4} fill="white" fontSize={10} className="pointer-events-none">
        {node.display_name.length > 20
          ? node.display_name.slice(0, 18) + '…'
          : node.display_name}
      </text>
      {node.parents.map((parent, i) => {
        const py = y - 60
        const px = x - 80 + i * 160
        return (
          <g key={parent.trait_id}>
            <line
              x1={x}
              y1={y - 8}
              x2={px}
              y2={py + 8}
              stroke={color}
              strokeWidth={1.5}
              strokeOpacity={0.6}
            />
            <TreeNode node={parent} depth={depth + 1} x={px} y={py} onHover={onHover} />
          </g>
        )
      })}
    </g>
  )
}

export function LineageGraph({ traitId, perspectiveId }: LineageGraphProps) {
  const [lineage, setLineage] = useState<Node[]>([])
  const [loading, setLoading] = useState(false)
  const [tooltip, setTooltip] = useState<string | null>(null)

  useEffect(() => {
    if (!traitId || !perspectiveId) return
    setLoading(true)
    api
      .traitLineage(traitId, perspectiveId)
      .then((data) => {
        const typed = data as { lineage: Node[] }
        setLineage(typed.lineage ?? [])
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [traitId, perspectiveId])

  if (loading) {
    return <div className="text-xs text-gray-400 p-2">Loading lineage…</div>
  }

  if (lineage.length === 0) {
    return <div className="text-xs text-gray-500 p-2">No known ancestry for this trait.</div>
  }

  return (
    <div className="relative">
      {tooltip && (
        <div className="absolute top-0 right-0 text-xs bg-gray-800 text-gray-200 px-2 py-1 rounded z-10">
          {tooltip}
        </div>
      )}
      <svg
        width="100%"
        viewBox="0 0 400 200"
        className="overflow-visible"
      >
        {lineage.map((node, i) => (
          <TreeNode
            key={node.trait_id}
            node={node}
            x={200 + (i - lineage.length / 2) * 120}
            y={160}
            onHover={setTooltip}
          />
        ))}
      </svg>
    </div>
  )
}
