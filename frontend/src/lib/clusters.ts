/**
 * Population-cluster coloring.
 *
 * A carrier's "cluster" is its **dominant ancestry trait** — the trait_id
 * with the largest fraction in its trait_mix. Two carriers that share the
 * same dominant trait (e.g. two populations that are mostly ANI) get the
 * same color, which surfaces ancestry-based clusters at a glance — the
 * Indo-European-related Steppe ancestry sweep across Eurasia, the
 * Anatolian-Farmer wash through Neolithic Europe, the East-Asian core,
 * and so on.
 *
 * When a carrier has no trait_mix data, its cluster is `unknown` and
 * renders as a neutral gray.
 *
 * Colors are assigned deterministically: a carefully-chosen palette covers
 * the most common ancestry components from the seed data (so the demo
 * carriers always get distinct, on-brand colors), and any unrecognized
 * trait_id falls through to a stable hash-derived palette slot.
 */
import type { CarrierView } from '../api'

/** Hand-tuned colors for the most-cited ancestry components in the seed
 * data. The choices loosely follow the "color of the dominant population"
 * convention you'd see in admixture plots. */
const CLUSTER_COLORS_BY_TRAIT: Record<string, string> = {
  // Genetic ancestry components (from db/004 + the spreadsheet)
  AFR_BASAL: '#fbbf24',        // amber  — Sub-Saharan African
  AFR_WEST: '#f59e0b',          // amber-darker — West African
  AFR_KHOISAN: '#ca8a04',       // mustard — Khoisan
  ANATOLIAN_FARMER: '#84cc16',  // lime  — EEF / Anatolian Neolithic
  IRN_N: '#a3e635',             // pale lime — Iranian Neolithic
  NATUFIAN: '#bef264',          // pale yellow-green — Natufian / Levantine
  EHG: '#22d3ee',               // cyan — Eastern HG
  WHG: '#06b6d4',               // teal — Western HG
  ANE: '#0ea5e9',               // sky — Ancient North Eurasian
  STEPPE_MLBA: '#3b82f6',       // blue — Steppe MLBA (Indo-European core)
  YAMNAYA: '#1d4ed8',           // deep blue — Yamnaya
  ANI: '#8b5cf6',               // violet — Ancestral North Indian
  ASI: '#a855f7',               // purple — Ancestral South Indian
  EAST_ASIAN: '#ec4899',        // pink — East Asian
  JOMON: '#f472b6',             // light pink — Jomon
  AMER_NA: '#ef4444',           // red — First Americans
  AUS_PNG: '#dc2626',           // dark red — Australasian
  NEANDERTHAL: '#6b7280',       // gray — archaic
  DENISOVAN: '#4b5563',         // dark gray — archaic
}

/** Fallback palette for trait_ids we don't have a hand-tuned color for —
 * indexed by a simple hash of the trait_id so colors stay consistent
 * across reloads. */
const FALLBACK_PALETTE = [
  '#16a34a', // green
  '#0891b2', // teal
  '#7c3aed', // purple
  '#db2777', // pink-rose
  '#d97706', // dark amber
  '#65a30d', // darker lime
  '#0d9488', // dark teal
  '#9333ea', // dark purple
  '#be185d', // dark rose
  '#b45309', // brown-amber
]

const UNKNOWN_COLOR = '#9ca3af' // neutral gray

function hashTrait(traitId: string): number {
  let h = 0
  for (let i = 0; i < traitId.length; i++) {
    h = (h * 31 + traitId.charCodeAt(i)) | 0
  }
  return Math.abs(h) % FALLBACK_PALETTE.length
}

/** Returns the dominant trait_id for a carrier (largest fraction wins; ties
 * resolve to lexically smallest trait_id for determinism). Returns null
 * when the trait_mix is empty. */
export function dominantTrait(c: CarrierView): string | null {
  if (!c.trait_mix || c.trait_mix.length === 0) return null
  let best = c.trait_mix[0]
  for (const t of c.trait_mix) {
    const f = t.fraction ?? 0
    const bf = best.fraction ?? 0
    if (f > bf) best = t
    else if (f === bf && t.trait_id < best.trait_id) best = t
  }
  return best.trait_id
}

/** Color assigned to a carrier by its population cluster (dominant trait). */
export function clusterColor(c: CarrierView): string {
  const t = dominantTrait(c)
  if (!t) return UNKNOWN_COLOR
  return CLUSTER_COLORS_BY_TRAIT[t] ?? FALLBACK_PALETTE[hashTrait(t)]
}

/** A carrier's cluster identifier (the dominant trait_id, or "unknown"). */
export function clusterId(c: CarrierView): string {
  return dominantTrait(c) ?? 'unknown'
}

/** Pretty-print a cluster id for the legend. */
export function clusterLabel(traitId: string, displayName?: string | null): string {
  if (traitId === 'unknown') return 'Unknown / no trait mix'
  return displayName ?? traitId
}

/** Color lookup by raw trait_id (used by the legend, which already has the
 * trait id and display name from the world payload). */
export function colorForTraitId(traitId: string): string {
  if (traitId === 'unknown') return UNKNOWN_COLOR
  return CLUSTER_COLORS_BY_TRAIT[traitId] ?? FALLBACK_PALETTE[hashTrait(traitId)]
}
