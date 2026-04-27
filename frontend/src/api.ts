const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:8000'

export interface GeoPoint {
  lat: number
  lon: number
}

export interface Perspective {
  id: string
  display_name: string
  domain_scope: string[]
  summary: string
  proponents: string | null
  methodology_notes: string
  parent_perspective_id: string | null
  default_active: boolean
  status: string
}

export interface TraitMixEntry {
  trait_id: string
  display_name: string | null
  domain: string
  fraction: number
  stderr: number | null
  endorsement: EndorsementSummary | null
}

export interface EndorsementSummary {
  stance: string
  override_statement: string | null
  override_quantitative_value: unknown
  source_weight_overrides: unknown
}

export interface CarrierView {
  id: string
  display_name: string
  type: string
  date_min_year: number
  date_max_year: number
  centroid: GeoPoint | null
  archaeological_culture: string | null
  linguistic_affiliation: string | null
  trait_mix: TraitMixEntry[]
  endorsement: EndorsementSummary | null
}

export interface PropagationEventView {
  id: string
  display_name: string
  domain: string
  date_min_year: number
  date_max_year: number
  mechanism: string | null
  source_point: GeoPoint | null
  destination_point: GeoPoint | null
  endorsement: EndorsementSummary | null
}

export interface PerspectiveWorldView {
  perspective_id: string
  carriers: CarrierView[]
  propagation_events: PropagationEventView[]
}

export interface WorldResponse {
  year: number
  bbox: number[]
  perspectives: Record<string, PerspectiveWorldView>
}

export interface ClaimSourceEntry {
  source_id: string
  citation: string
  stance: string
  weight_override: number | null
  default_weight: number
}

export interface ClaimPerspectiveView {
  perspective_id: string
  stance: string
  override_statement: string | null
  override_quantitative_value: unknown
  source_weight_overrides: unknown
  sources: ClaimSourceEntry[]
}

export interface ClaimResponse {
  id: number
  subject_type: string
  subject_id: string
  statement: string
  quantitative_value: unknown
  default_aggregated_confidence: number | null
  perspectives: Record<string, ClaimPerspectiveView>
}

export interface CarrierTimelineSnapshot {
  as_of_year: number
  domain: string
  traits: TraitMixEntry[]
}

export interface CarrierTimelineResponse {
  carrier_id: string
  display_name: string
  perspective_id: string
  timeline: CarrierTimelineSnapshot[]
}

async function get<T>(path: string, params: Record<string, string | number | undefined> = {}): Promise<T> {
  const url = new URL(`${BASE}${path}`)
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined) url.searchParams.set(k, String(v))
  }
  const res = await fetch(url.toString())
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} — ${path}`)
  return res.json() as T
}

export const api = {
  perspectives: (): Promise<Perspective[]> =>
    get('/perspectives'),

  world: (year: number, bbox: [number, number, number, number], perspectives: string[]): Promise<WorldResponse> =>
    get('/world', {
      year,
      bbox: bbox.join(','),
      perspectives: perspectives.join(',') || undefined,
    }),

  carrierTimeline: (carrierId: string, perspective: string): Promise<CarrierTimelineResponse> =>
    get(`/carrier/${carrierId}/timeline`, { perspective }),

  claim: (claimId: number, perspectives: string[]): Promise<ClaimResponse> =>
    get(`/claim/${claimId}`, {
      perspectives: perspectives.join(',') || undefined,
    }),

  traitLineage: (traitId: string, perspective: string) =>
    get(`/trait/${traitId}/lineage`, { perspective }),

  traitLineageDiff: (traitId: string, perspectives: string[]) =>
    get(`/trait/${traitId}/lineage-diff`, { perspectives: perspectives.join(',') }),

  paleoBasemap: (year: number, perspective?: string) =>
    get('/paleo-basemap', { year, perspective }),
}
