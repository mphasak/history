/**
 * LineagePreviewPanel — small non-destructive panel that pops up when the
 * user clicks a non-focal node in the lineage subgraph.
 *
 * The focal carrier stays locked while lineage mode is on (so the BFS
 * doesn't reset every time the user clicks a node to inspect it). This
 * panel shows the previewed node's date range, hop depth, and the
 * shared traits that bridge it into the graph — enough to read what
 * the connection means without leaving lineage mode.
 *
 * Renders nothing when lineage mode is off or no preview is set.
 */
import { useEffect, useState } from 'react'
import { useStore } from '../state'
import { useCarrierLineage } from '../hooks/useWorldQuery'
import { fetchCarrierImage, WikipediaSummary } from '../lib/wikipedia'

function formatYear(y: number) {
  return y < 0 ? `${Math.abs(y).toLocaleString()} BCE` : `${y} CE`
}

export function LineagePreviewPanel() {
  const lineageMode = useStore((s) => s.lineageMode)
  const previewId = useStore((s) => s.lineagePreviewCarrierId)
  const setPreviewId = useStore((s) => s.setLineagePreviewCarrierId)
  const { data: lineage } = useCarrierLineage()
  const [wiki, setWiki] = useState<WikipediaSummary | null>(null)

  // Re-fetch the Wikipedia thumbnail per previewed node — cached on the
  // wikipedia helper, so flipping between nodes feels instant after the
  // first fetch.
  useEffect(() => {
    if (!previewId) { setWiki(null); return }
    let cancelled = false
    setWiki(null)
    const node = lineage?.nodes.find((n) => n.id === previewId)
    const displayName = node?.display_name ?? previewId
    fetchCarrierImage(previewId, displayName).then((res) => {
      if (!cancelled) setWiki(res)
    })
    return () => { cancelled = true }
  }, [previewId, lineage])

  if (lineageMode === 'off' || !previewId || !lineage) return null
  const node = lineage.nodes.find((n) => n.id === previewId)
  if (!node) return null

  const sideLabel =
    node.side === 'past' ? 'Ancestor' :
    node.side === 'future' ? 'Descendant' :
    'Focal carrier'

  return (
    <div className="bg-gray-900/95 text-white rounded-lg shadow-xl border border-gray-700 w-72 overflow-hidden">
      <div className="flex items-center justify-between px-3 py-2 border-b border-gray-700 bg-gray-800/60">
        <div>
          <div className="text-[10px] uppercase tracking-wide text-gray-500">
            {sideLabel} · hop {node.depth}
          </div>
          <div className="text-sm font-semibold truncate">
            {node.display_name}
          </div>
        </div>
        <button
          onClick={() => setPreviewId(null)}
          className="text-gray-400 hover:text-white ml-2 shrink-0"
          aria-label="Close preview"
        >
          ×
        </button>
      </div>
      {wiki?.thumbnail && (
        <a
          href={wiki.contentUrl ?? '#'}
          target="_blank"
          rel="noreferrer"
          className="block group"
          title={`From Wikipedia: ${wiki.title}`}
        >
          <img
            src={wiki.thumbnail.source}
            alt={wiki.title}
            className="w-full h-32 object-cover group-hover:opacity-90 transition-opacity"
            loading="lazy"
          />
        </a>
      )}
      <div className="px-3 py-2 space-y-2 text-xs">
        <div className="text-gray-400">
          <span className="text-gray-500">Active</span>{' '}
          {formatYear(node.date_min_year)} — {formatYear(node.date_max_year)}
        </div>
        {node.shared_trait_ids.length > 0 && (
          <div>
            <div className="text-[10px] uppercase tracking-wide text-gray-500 mb-1">
              Traits bridging into the graph
            </div>
            <div className="flex flex-wrap gap-1">
              {node.shared_trait_ids.map((t) => (
                <span
                  key={t}
                  className="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 border border-gray-700 text-gray-300"
                >
                  {t}
                </span>
              ))}
            </div>
          </div>
        )}
        {wiki?.extract && (
          <p className="text-[11px] text-gray-300 line-clamp-4 leading-snug">
            {wiki.extract}
          </p>
        )}
        <p className="text-[10px] text-gray-500 leading-snug pt-1 border-t border-gray-800">
          Click another node to preview it. Exit lineage mode (Lineage → Off)
          to change the focal carrier.
        </p>
      </div>
    </div>
  )
}
