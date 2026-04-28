/**
 * DiffOverlay computes which carriers have disagreement across active perspectives
 * and exposes that information for the map to render appropriately.
 */
import { useMemo } from 'react'
import { WorldResponse } from '../api'

export interface CarrierDiffStatus {
  carrierId: string
  agreed: boolean
  perspectives: string[]
  // true if at least one perspective rejects/nuances differently than others
  hasDisagreement: boolean
}

export function computeDiff(worldData: WorldResponse): CarrierDiffStatus[] {
  const perspIds = Object.keys(worldData.perspectives)
  if (perspIds.length < 2) return []

  // Collect all carrier IDs across all perspectives
  const allCarrierIds = new Set<string>()
  for (const view of Object.values(worldData.perspectives)) {
    for (const c of view.carriers) {
      allCarrierIds.add(c.id)
    }
  }

  // Backend-computed: carriers whose related claims (carrier-level,
  // carrier_trait_mix, or nearby propagation_event) receive different stances
  // under different active perspectives. Most real disagreements live there
  // rather than on the carrier row itself, so honoring this set is what makes
  // diff-overlay actually mark contested carriers.
  const claimDisagreed = new Set(worldData.disagreed_carrier_ids ?? [])

  const result: CarrierDiffStatus[] = []

  for (const carrierId of allCarrierIds) {
    const presences: boolean[] = []
    const stances: (string | null)[] = []

    for (const pid of perspIds) {
      const view = worldData.perspectives[pid]
      const carrier = view.carriers.find((c) => c.id === carrierId)
      presences.push(!!carrier)
      stances.push(carrier?.endorsement?.stance ?? null)
    }

    const allPresent = presences.every(Boolean)
    const allSameStance = stances.every((s) => s === stances[0])
    const hasDisagreement = !allPresent || !allSameStance || claimDisagreed.has(carrierId)

    result.push({
      carrierId,
      agreed: !hasDisagreement,
      perspectives: perspIds.filter((_, i) => presences[i]),
      hasDisagreement,
    })
  }

  return result
}

interface DiffLegendProps {
  worldData: WorldResponse | null
}

export function DiffLegend({ worldData }: DiffLegendProps) {
  const diffs = useMemo(
    () => (worldData ? computeDiff(worldData) : []),
    [worldData]
  )

  const disagreed = diffs.filter((d) => d.hasDisagreement)
  if (disagreed.length === 0) return null

  return (
    <div className="bg-gray-900 text-white rounded-lg shadow-lg p-3 text-xs">
      <div className="font-semibold text-gray-300 mb-2">Perspective Disagreements</div>
      <div className="flex items-center gap-2 mb-1">
        <div className="w-4 h-4 rounded-full bg-blue-500 shrink-0" />
        <span className="text-gray-300">All perspectives agree</span>
      </div>
      <div className="flex items-center gap-2">
        <div className="w-4 h-4 rounded-full bg-red-500 border-2 border-white shrink-0" />
        <span className="text-gray-300">Perspectives disagree ({disagreed.length})</span>
      </div>
    </div>
  )
}
