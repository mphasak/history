import { create } from 'zustand'

export type RenderMode = 'single' | 'side-by-side' | 'diff-overlay'
export type VizMode = 'pointwise' | 'fill'

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
}

// Read initial year + perspectives from URL params
function getInitialState() {
  const params = new URLSearchParams(window.location.search)
  const year = params.has('year') ? parseInt(params.get('year')!, 10) : -2000
  const persp = params.get('perspectives')
  const perspectives = persp ? persp.split(',').filter(Boolean) : []
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

  vizMode: 'pointwise',
  setVizMode: (mode) => set({ vizMode: mode }),
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
