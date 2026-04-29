import { create } from 'zustand'

export type RenderMode = 'single' | 'side-by-side' | 'diff-overlay'
/**
 * Map visualization mode.
 * - `pointwise`: each archaeological sample (trait_observation) is its own dot.
 * - `fill`: carrier extent polygons; dashed for buffered fallbacks, solid for
 *   authored extents (and territory snapshots).
 * - `flow`: migration / propagation arrows (source → destination), colored
 *   by the cultural domain of the event (genetic, technological, …).
 */
export type VizMode = 'pointwise' | 'fill' | 'flow'
/** Map label mode:
 *  - `modern`     : modern political map with present-day place names + borders (default).
 *  - `historical` : clean base + historical place names that match the current year
 *                   (Constantinople, Tenochtitlan, etc., from the historical_place table).
 *  - `none`       : clean base, no labels at all (best for paleo scrubs).
 */
export type LabelMode = 'modern' | 'historical' | 'none'

/** Lineage paths for the selected carrier — past (ancestors), future
 * (descendants), or both/off. Toggleable from the App header. */
export type LineageMode = 'off' | 'past' | 'future' | 'both'

/** How to color-code carriers on the map.
 *  - `cluster`: each carrier's dot/extent takes a color from its
 *    **dominant ancestry trait** (the trait_id with the largest fraction
 *    in its trait_mix). Two carriers that are mostly ANI take the same
 *    color, two carriers that are mostly EAST_ASIAN take the same color,
 *    etc. — surfaces ancestry clusters across the map.
 *  - `mono`: legacy single-color styling (blue dots, blue extents) — kept
 *    as an option for screenshots / minimalism.
 *  Disagreement-red still wins over either when in diff-overlay mode.
 */
export type CarrierColorMode = 'cluster' | 'mono'

export interface ClickPoint {
  lat: number
  lon: number
}

interface HistorySimState {
  year: number
  setYear: (year: number) => void

  activePerspectives: string[]
  setActivePerspectives: (ids: string[]) => void

  // [W, S, E, N]
  bbox: [number, number, number, number]
  setBbox: (bbox: [number, number, number, number]) => void

  selectedCarrierId: string | null
  setSelectedCarrierId: (id: string | null) => void

  clickPoint: ClickPoint | null
  setClickPoint: (p: ClickPoint | null) => void

  renderMode: RenderMode
  setRenderMode: (mode: RenderMode) => void

  vizMode: VizMode
  setVizMode: (mode: VizMode) => void

  labelMode: LabelMode
  setLabelMode: (mode: LabelMode) => void

  lineageMode: LineageMode
  setLineageMode: (mode: LineageMode) => void

  /** When true, the lineage view auto-advances the year slider so the user
   * sees ancestors fade in then out, the focal carrier light up, and
   * descendants appear in sequence. Stops automatically when the year
   * passes the latest descendant. */
  lineageAnimating: boolean
  setLineageAnimating: (v: boolean) => void

  /** While in lineage mode the focal carrier is locked — clicking other
   * carriers/nodes opens a non-destructive *preview* in the right panel
   * instead of replacing `selectedCarrierId`. Cleared when lineage mode
   * exits or the user clicks the focal again. */
  lineagePreviewCarrierId: string | null
  setLineagePreviewCarrierId: (id: string | null) => void

  carrierColorMode: CarrierColorMode
  setCarrierColorMode: (mode: CarrierColorMode) => void
}

// Read initial year + perspectives from URL params.
// Default perspective is the academic-mainstream Post-Reich consensus —
// users who want comparative perspectives can open the (collapsed) picker.
const DEFAULT_PERSPECTIVE = 'PERSP_POSTREICH_2025'

function getInitialState() {
  const params = new URLSearchParams(window.location.search)
  const year = params.has('year') ? parseInt(params.get('year')!, 10) : -2000
  const persp = params.get('perspectives')
  const perspectives = persp ? persp.split(',').filter(Boolean) : [DEFAULT_PERSPECTIVE]
  return { year, perspectives }
}

const { year: initYear, perspectives: initPerspectives } = getInitialState()

export const useStore = create<HistorySimState>((set) => ({
  year: initYear,
  setYear: (year) => {
    set({ year })
    updateUrl({ year })
  },

  activePerspectives: initPerspectives,
  setActivePerspectives: (ids) => {
    set({ activePerspectives: ids })
    updateUrl({ perspectives: ids })
  },

  bbox: [-180, -85, 180, 85],
  setBbox: (bbox) => set({ bbox }),

  selectedCarrierId: null,
  setSelectedCarrierId: (id) => set({ selectedCarrierId: id }),

  clickPoint: null,
  setClickPoint: (p) => set({ clickPoint: p }),

  renderMode: 'single',
  setRenderMode: (mode) => set({ renderMode: mode }),

  vizMode: 'fill',
  setVizMode: (mode) => set({ vizMode: mode }),

  labelMode: 'none',
  setLabelMode: (mode) => set({ labelMode: mode }),

  lineageMode: 'off',
  setLineageMode: (mode) => set({ lineageMode: mode }),

  lineageAnimating: false,
  setLineageAnimating: (v) => set({ lineageAnimating: v }),

  lineagePreviewCarrierId: null,
  setLineagePreviewCarrierId: (id) => set({ lineagePreviewCarrierId: id }),

  carrierColorMode: 'cluster',
  setCarrierColorMode: (mode) => set({ carrierColorMode: mode }),
}))

function updateUrl(changes: { year?: number; perspectives?: string[] }) {
  const params = new URLSearchParams(window.location.search)
  if (changes.year !== undefined) params.set('year', String(changes.year))
  if (changes.perspectives !== undefined) {
    if (changes.perspectives.length > 0) {
      params.set('perspectives', changes.perspectives.join(','))
    } else {
      params.delete('perspectives')
    }
  }
  const newUrl = `${window.location.pathname}?${params.toString()}`
  window.history.replaceState(null, '', newUrl)
}
