import { useEffect, useRef, useCallback } from 'react'
import maplibregl from 'maplibre-gl'
import { WorldResponse, CarrierView, TraitObservationView, PaleoFeature, CarrierLineageResponse, PropagationEventView } from '../api'
import { useStore } from '../state'
import { computeDiff } from './DiffOverlay'
import { clusterColor } from '../lib/clusters'

// Domain → hex color (kept in sync with the legend and DetailPanel TraitBar).
export const DOMAIN_COLORS: Record<string, string> = {
  genetic: '#10b981',
  linguistic: '#8b5cf6',
  ideological: '#f59e0b',
  religious: '#f43f5e',
  technological: '#0ea5e9',
  artistic: '#ec4899',
  institutional: '#a16207',
  material_culture: '#65a30d',
  other: '#9ca3af',
}

// CartoDB Voyager tiles let us split the base layer from the labels raster,
// so the user can swap modern labels off (e.g. for "Historical" or "None"
// label modes). Both tiles are public, no API key required, with
// attribution to OSM + CARTO.
const CARTODB_ATTRIBUTION =
  '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors ' +
  '© <a href="https://carto.com/attributions">CARTO</a>'

const OSM_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  // Required so symbol layers using `text-field` (e.g. carrier labels and
  // the historical-places layer) can resolve glyphs. MapLibre's demo glyph
  // endpoint covers basic Latin and is sufficient for our display names.
  glyphs: 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
  sources: {
    'osm-base': {
      type: 'raster',
      tiles: [
        'https://a.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
        'https://b.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
        'https://c.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
        'https://d.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
      ],
      tileSize: 256,
      attribution: CARTODB_ATTRIBUTION,
    },
    'osm-labels': {
      type: 'raster',
      tiles: [
        'https://a.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
        'https://b.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
        'https://c.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
        'https://d.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
      ],
      tileSize: 256,
      attribution: CARTODB_ATTRIBUTION,
    },
  },
  layers: [
    { id: 'osm-base-tiles',   type: 'raster', source: 'osm-base',   minzoom: 0, maxzoom: 19 },
    // `osm-labels-tiles` is added after our paleo / carrier layers below so
    // it draws on top — but its visibility is driven by labelMode and it's
    // hidden in 'historical' / 'none' modes.
    { id: 'osm-labels-tiles', type: 'raster', source: 'osm-labels', minzoom: 0, maxzoom: 19 },
  ],
}

interface MapInstanceProps {
  containerId: string
  carriers: CarrierView[]
  /** Propagation events (migration / spread / influence flows) for the
   * current perspective. Rendered only in flow viz mode. */
  propagationEvents?: PropagationEventView[]
  observations?: TraitObservationView[]
  paleoFeatures?: PaleoFeature[]
  shelfGeojson?: GeoJSON.FeatureCollection | null
  /** When true, render the continental-shelf polygon as exposed land. */
  shelfVisible?: boolean
  /** Optional GeoJSON of paleo-coastlines from GPlates for deep time. */
  paleoCoastlines?: GeoJSON.FeatureCollection | null
  /** Era-appropriate place labels — fed in by the parent so all map instances
   * (single, side-by-side, diff) share one fetch. Undefined when labelMode
   * isn't "historical". */
  historicalPlaces?: { id: string; display_name: string; centroid: { lat: number; lon: number }; kind: string | null }[]
  /** Past/future lineage for the selected carrier — drawn as connector lines
   * + amber (past) / cyan (future) endpoint dots. Null when lineage mode is off. */
  lineage?: CarrierLineageResponse | null
  perspectiveId: string
  diffCarrierIds?: Set<string>
  onCarrierClick: (carrierId: string) => void
  onMapClick?: (lat: number, lon: number) => void
  syncWith?: maplibregl.Map | null
}

function useMapInstance({
  containerId,
  carriers,
  propagationEvents,
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  historicalPlaces,
  lineage,
  diffCarrierIds,
  onCarrierClick,
  onMapClick,
  syncWith,
}: MapInstanceProps) {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const syncingRef = useRef(false)
  const onMapClickRef = useRef(onMapClick)
  useEffect(() => { onMapClickRef.current = onMapClick }, [onMapClick])
  const clickPoint = useStore((s) => s.clickPoint)
  const clickMarkerRef = useRef<maplibregl.Marker | null>(null)
  const vizMode = useStore((s) => s.vizMode)
  const vizModeRef = useRef(vizMode)
  useEffect(() => { vizModeRef.current = vizMode }, [vizMode])
  const labelMode = useStore((s) => s.labelMode)
  const year = useStore((s) => s.year)
  const carrierColorMode = useStore((s) => s.carrierColorMode)

  useEffect(() => {
    const container = document.getElementById(containerId)
    if (!container) return

    const map = new maplibregl.Map({
      container,
      style: OSM_STYLE,
      center: [20, 30],
      zoom: 2,
    })
    mapRef.current = map

    map.addControl(new maplibregl.NavigationControl(), 'top-right')

    map.on('load', () => {
      // Deep-time paleo coastlines (from GPlates) — bottom-most paleo layer.
      // Renders only when in deep-time year range.
      map.addSource('paleo-coastlines', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'paleo-coastlines-fill',
        type: 'fill',
        source: 'paleo-coastlines',
        layout: { visibility: 'none' },
        paint: {
          // Earthy brown — distinct from the sandy continental-shelf fill so
          // deep-time GPlates reconstructions don't read as "the same poly."
          'fill-color': '#8b5e34',
          'fill-opacity': 0.55,
        },
      })

      map.addLayer({
        id: 'paleo-coastlines-outline',
        type: 'line',
        source: 'paleo-coastlines',
        layout: { visibility: 'none' },
        paint: {
          'line-color': '#3a2812',
          'line-width': 1.4,
          'line-opacity': 0.9,
        },
      })

      // Continental-shelf overlay — exposed during glacial low-stands.
      map.addSource('continental-shelf', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'continental-shelf-fill',
        type: 'fill',
        source: 'continental-shelf',
        layout: { visibility: 'none' },
        paint: {
          'fill-color': '#c2b280', // sandy
          'fill-opacity': 0.5,
        },
      })

      map.addLayer({
        id: 'continental-shelf-outline',
        type: 'line',
        source: 'continental-shelf',
        layout: { visibility: 'none' },
        paint: {
          'line-color': '#8b7355',
          'line-width': 0.4,
          'line-opacity': 0.8,
        },
      })

      // Paleo features (land bridges, ice sheets) — rendered BELOW everything
      // else so carriers and observations remain on top.
      map.addSource('paleo-features', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'paleo-features-fill',
        type: 'fill',
        source: 'paleo-features',
        paint: {
          'fill-color': [
            'match',
            ['get', 'type'],
            'land_bridge', '#a16207', // amber-700 — exposed earth
            'ice_sheet',   '#e0f2fe', // sky-100 — pale ice
            'lake',        '#1e3a8a',
            'inland_sea',  '#1e40af',
            'sea',         '#1e40af',
            '#9ca3af', // fallback
          ],
          'fill-opacity': 0.45,
        },
      })

      map.addLayer({
        id: 'paleo-features-outline',
        type: 'line',
        source: 'paleo-features',
        paint: {
          'line-color': [
            'match',
            ['get', 'type'],
            'land_bridge', '#92400e',
            'ice_sheet',   '#bae6fd',
            '#9ca3af',
          ],
          'line-width': 1,
        },
      })

      // Carrier extents (fill mode) — added BEFORE circle layer so extents render below
      map.addSource('carrier-extents', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'carrier-extents-fill',
        type: 'fill',
        source: 'carrier-extents',
        layout: { visibility: 'none' },
        paint: {
          'fill-color': [
            'case',
            ['get', 'disagreed'], '#ef4444',
            ['get', 'color'],
          ],
          'fill-opacity': [
            'case',
            ['get', 'extent_is_real'],
            0.25,
            0.12,
          ],
        },
      })

      // Outline layers are split in two because MapLibre rejects data-driven
      // expressions for `line-dasharray`. Authored extents render solid; buffered
      // (synthetic) extents render dashed. Both styles share the same color
      // expression, so the disagreement cue still applies in either case.
      map.addLayer({
        id: 'carrier-extents-outline-solid',
        type: 'line',
        source: 'carrier-extents',
        filter: ['==', ['get', 'extent_is_real'], true],
        layout: { visibility: 'none' },
        paint: {
          'line-color': [
            'case',
            ['get', 'disagreed'], '#ef4444',
            ['get', 'color'],
          ],
          'line-width': 1.5,
        },
      })

      map.addLayer({
        id: 'carrier-extents-outline-dashed',
        type: 'line',
        source: 'carrier-extents',
        filter: ['!=', ['get', 'extent_is_real'], true],
        layout: { visibility: 'none' },
        paint: {
          'line-color': [
            'case',
            ['get', 'disagreed'], '#ef4444',
            ['get', 'color'],
          ],
          'line-width': 1.5,
          'line-dasharray': [3, 2],
        },
      })

      // Trait observations (pointwise mode)
      map.addSource('observations', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'observations-circle',
        type: 'circle',
        source: 'observations',
        layout: { visibility: 'none' },
        paint: {
          'circle-radius': 4,
          'circle-color': ['get', 'color'],
          'circle-stroke-width': 1,
          'circle-stroke-color': '#0f172a',
          'circle-opacity': 0.95,
        },
      })

      // Add carrier source + layer (centroid markers, always visible)
      map.addSource('carriers', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      // Carrier color expression: disagreement-red wins when in diff overlay,
      // otherwise the dot takes its `color` property which is computed per-
      // feature from carrierColorMode + region (see the carriers data effect).
      // This way the legend, dot, and extent fill stay in sync without a
      // global match expression on every layer.
      map.addLayer({
        id: 'carriers-circle',
        type: 'circle',
        source: 'carriers',
        paint: {
          'circle-radius': 10,
          'circle-color': [
            'case',
            ['get', 'disagreed'], '#ef4444',
            ['get', 'color'],
          ],
          'circle-stroke-width': [
            'case',
            ['get', 'disagreed'],
            3,
            1,
          ],
          'circle-stroke-color': [
            'case',
            ['get', 'disagreed'],
            '#ffffff',
            '#1e40af',
          ],
          'circle-opacity': 0.85,
        },
      })

      map.addLayer({
        id: 'carriers-label',
        type: 'symbol',
        source: 'carriers',
        layout: {
          'text-field': ['get', 'display_name'],
          'text-font': ['Noto Sans Regular'],
          'text-size': 11,
          'text-offset': [0, 1.5],
          'text-anchor': 'top',
          // Cap label rendering at zoomed-out levels to avoid the world map turning
          // into a wall of overlapping text — labels appear once you zoom in.
          'text-allow-overlap': false,
          'text-optional': true,
          'text-padding': 4,
        },
        paint: {
          'text-color': '#ffffff',
          'text-halo-color': '#000000',
          'text-halo-width': 1,
        },
        minzoom: 3,
      })

      map.on('click', (e) => {
        const hits = map.queryRenderedFeatures(e.point, {
          layers: ['carriers-circle'],
        })
        if (hits.length > 0 && hits[0].properties?.id) {
          onCarrierClick(hits[0].properties.id as string)
          return
        }
        onMapClickRef.current?.(e.lngLat.lat, e.lngLat.lng)
      })

      map.on('mouseenter', 'carriers-circle', () => {
        map.getCanvas().style.cursor = 'pointer'
      })
      map.on('mouseleave', 'carriers-circle', () => {
        map.getCanvas().style.cursor = ''
      })

      // Propagation / migration flows — rendered only in `flow` viz mode.
      // Lines run source → destination, colored by domain (genetic =
      // emerald, linguistic = violet, …) using the same DOMAIN_COLORS the
      // observations layer uses.
      map.addSource('propagation-edges', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })
      map.addLayer({
        id: 'propagation-edges-line',
        type: 'line',
        source: 'propagation-edges',
        layout: { visibility: 'none' },
        paint: {
          'line-color': ['get', 'color'],
          'line-width': 2.5,
          'line-opacity': 0.85,
        },
      })

      // A second source provides destination points only, so we can render
      // a small disk + a unicode arrow oriented along the line. MapLibre
      // doesn't draw arrowheads on lines natively; this is the canonical
      // workaround.
      map.addSource('propagation-arrowheads', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })
      map.addLayer({
        id: 'propagation-arrowhead-circle',
        type: 'circle',
        source: 'propagation-arrowheads',
        layout: { visibility: 'none' },
        paint: {
          'circle-radius': 5,
          'circle-color': ['get', 'color'],
          'circle-stroke-color': '#0f172a',
          'circle-stroke-width': 1,
        },
      })
      map.addLayer({
        id: 'propagation-arrowhead-arrow',
        type: 'symbol',
        source: 'propagation-arrowheads',
        layout: {
          visibility: 'none',
          'text-field': '▶',
          'text-font': ['Noto Sans Regular'],
          'text-size': 14,
          'text-rotate': ['get', 'bearing'],
          'text-rotation-alignment': 'map',
          'text-allow-overlap': true,
          'text-ignore-placement': true,
          'text-offset': [0.6, 0],
        },
        paint: {
          'text-color': ['get', 'color'],
          'text-halo-color': '#0f172a',
          'text-halo-width': 1.5,
        },
      })

      // Lineage connector lines + endpoint nodes for the selected carrier.
      // Past edges render amber (looking back), future edges cyan (looking
      // forward). Drawn ABOVE the carrier circles so the connectors don't
      // get hidden behind the dots.
      map.addSource('lineage-edges', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })
      // Two-layer connector style: a thick translucent halo behind a thin
      // solid core, so edges read as glowing connectors against the
      // basemap (the prior single 2-px dashed line was too thin to see at
      // continent scale, especially when the focal carrier sits on top of
      // the raster). MapLibre rejects data-driven `line-blur`, so the halo
      // gets fixed blur per layer.
      map.addLayer({
        id: 'lineage-edges-halo',
        type: 'line',
        source: 'lineage-edges',
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: {
          'line-color': [
            'match', ['get', 'side'],
            'past', '#fbbf24',     // amber
            'future', '#22d3ee',   // cyan
            '#9ca3af',
          ],
          'line-width': 9,
          'line-blur': 4,
          'line-opacity': [
            'case', ['==', ['get', 'active'], true], 0.45, 0.10,
          ],
        },
      })
      map.addLayer({
        id: 'lineage-edges-line',
        type: 'line',
        source: 'lineage-edges',
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: {
          'line-color': [
            'match', ['get', 'side'],
            'past', '#fde68a',     // amber-200, brighter than the halo
            'future', '#a5f3fc',   // cyan-200
            '#e5e7eb',
          ],
          'line-width': 3.5,
          'line-opacity': [
            'case', ['==', ['get', 'active'], true], 0.95, 0.30,
          ],
        },
      })

      // Pulse dots: a single bright marker per edge that travels along the
      // line in proportion to how far through the lineage span we are. The
      // position is recomputed on every year change (which fires both
      // during normal scrubbing and during animation), so the dots
      // visibly slide along the connectors when the user hits Play.
      map.addSource('lineage-pulse', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })
      map.addLayer({
        id: 'lineage-pulse-dot',
        type: 'circle',
        source: 'lineage-pulse',
        paint: {
          'circle-radius': 6,
          'circle-color': [
            'match', ['get', 'side'],
            'past', '#fde047',
            'future', '#67e8f9',
            '#ffffff',
          ],
          'circle-stroke-color': '#0f172a',
          'circle-stroke-width': 2,
          'circle-opacity': 1,
        },
      })

      map.addSource('lineage-nodes', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })
      map.addLayer({
        id: 'lineage-nodes-circle',
        type: 'circle',
        source: 'lineage-nodes',
        paint: {
          'circle-radius': [
            'case', ['==', ['get', 'role'], 'focal'], 11, 7,
          ],
          'circle-color': [
            'match', ['get', 'role'],
            'focal', '#facc15',
            'past', '#fbbf24',
            'future', '#22d3ee',
            '#9ca3af',
          ],
          'circle-stroke-color': '#0f172a',
          'circle-stroke-width': 2,
          // Active nodes (alive at the current year) glow at full opacity;
          // inactive nodes ghost out so the user can watch them light up in
          // sequence as the year animates forward.
          'circle-opacity': [
            'case', ['==', ['get', 'active'], true], 0.95, 0.25,
          ],
        },
      })
      map.addLayer({
        id: 'lineage-nodes-label',
        type: 'symbol',
        source: 'lineage-nodes',
        layout: {
          'text-field': ['get', 'display_name'],
          'text-font': ['Noto Sans Regular'],
          'text-size': 10,
          'text-offset': [0, 1.3],
          'text-anchor': 'top',
          'text-allow-overlap': false,
          'text-optional': true,
          'text-padding': 4,
        },
        paint: {
          'text-color': '#fde68a',
          'text-halo-color': '#0f172a',
          'text-halo-width': 1.4,
        },
        minzoom: 2,
      })

      // Historical place labels (city / region names that match the queried
      // year — e.g. Constantinople from 330 to 1453). Rendered as a symbol
      // layer fed by /historical-places. Visibility tracks labelMode.
      map.addSource('historical-places', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      map.addLayer({
        id: 'historical-places-label',
        type: 'symbol',
        source: 'historical-places',
        layout: {
          'text-field': ['get', 'display_name'],
          'text-font': ['Noto Sans Regular'],
          'text-size': [
            'case',
            ['==', ['get', 'kind'], 'region'],
            14,
            12,
          ],
          'text-letter-spacing': [
            'case',
            ['==', ['get', 'kind'], 'region'],
            0.15,
            0,
          ],
          'text-transform': [
            'case',
            ['==', ['get', 'kind'], 'region'],
            'uppercase',
            'none',
          ],
          'text-allow-overlap': false,
          'text-padding': 4,
          visibility: 'none',
        },
        paint: {
          'text-color': '#fde68a',  // amber-200, distinct from carrier-name white
          'text-halo-color': '#0f172a',
          'text-halo-width': 1.5,
        },
      })

      // Apply initial viz mode visibility once layers exist
      const v = vizModeRef.current
      const fillVis = v === 'fill' ? 'visible' : 'none'
      const pointVis = v === 'pointwise' ? 'visible' : 'none'
      const flowVis = v === 'flow' ? 'visible' : 'none'
      for (const id of [
        'carrier-extents-fill',
        'carrier-extents-outline-solid',
        'carrier-extents-outline-dashed',
      ]) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', fillVis)
      }
      if (map.getLayer('observations-circle')) {
        map.setLayoutProperty('observations-circle', 'visibility', pointVis)
      }
      for (const id of [
        'propagation-edges-line',
        'propagation-arrowhead-circle',
        'propagation-arrowhead-arrow',
      ]) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', flowVis)
      }
    })

    return () => {
      map.remove()
      mapRef.current = null
    }
  }, [containerId])

  // Sync camera with another map
  useEffect(() => {
    const map = mapRef.current
    if (!map || !syncWith) return

    const onMove = () => {
      if (syncingRef.current) return
      syncingRef.current = true
      syncWith.setCenter(map.getCenter())
      syncWith.setZoom(map.getZoom())
      syncWith.setBearing(map.getBearing())
      syncWith.setPitch(map.getPitch())
      syncingRef.current = false
    }

    map.on('move', onMove)
    return () => { map.off('move', onMove) }
  }, [syncWith])

  // Show/hide click-point marker
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    if (clickMarkerRef.current) {
      clickMarkerRef.current.remove()
      clickMarkerRef.current = null
    }
    if (clickPoint) {
      const el = document.createElement('div')
      el.className = 'click-point-marker'
      el.style.cssText = [
        'width:14px',
        'height:14px',
        'border-radius:50%',
        'background:rgba(250,204,21,0.9)',
        'border:2px solid #fff',
        'box-shadow:0 0 0 4px rgba(250,204,21,0.25)',
        'pointer-events:none',
      ].join(';')
      clickMarkerRef.current = new maplibregl.Marker({ element: el })
        .setLngLat([clickPoint.lon, clickPoint.lat])
        .addTo(map)
    }
    return () => {
      if (clickMarkerRef.current) {
        clickMarkerRef.current.remove()
        clickMarkerRef.current = null
      }
    }
  }, [clickPoint?.lat, clickPoint?.lon])

  // Per-carrier color resolution. Cluster mode uses the carrier's dominant
  // ancestry trait — see lib/clusters.ts. Mono mode keeps the legacy single
  // blue. The map's paint expressions read the resulting `color` property
  // directly, so we don't need to enumerate the whole palette as a MapLibre
  // match expression.
  const colorFor = useCallback(
    (c: CarrierView): string => {
      if (carrierColorMode === 'mono') return '#3b82f6'
      return clusterColor(c)
    },
    [carrierColorMode],
  )

  // Update carrier data
  useEffect(() => {
    const map = mapRef.current
    if (!map) return

    const apply = () => {
      const source = map.getSource('carriers') as maplibregl.GeoJSONSource | undefined
      if (!source) return

      const features: GeoJSON.Feature[] = carriers
        .filter((c) => c.centroid)
        .map((c) => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [c.centroid!.lon, c.centroid!.lat],
          },
          properties: {
            id: c.id,
            display_name: c.display_name,
            type: c.type,
            color: colorFor(c),
            disagreed: diffCarrierIds?.has(c.id) ?? false,
            has_endorsement: !!c.endorsement,
            endorsement_stance: c.endorsement?.stance ?? null,
          },
        }))

      source.setData({ type: 'FeatureCollection', features })
    }

    // Gate on source existence rather than `isStyleLoaded()`. The latter flips
    // back to false transiently while OSM raster tiles fetch, and falling into
    // the `else` branch registers a `'load'` listener for an event that has
    // already fired once at init — so the data update would be silently
    // dropped. Sources, once added during init's `'load'` callback, persist
    // for the lifetime of the map.
    if (map.getSource('carriers')) apply()
    else map.once('load', apply)
  }, [carriers, diffCarrierIds, colorFor])

  // Update carrier-extents source (fill mode polygons)
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('carrier-extents') as maplibregl.GeoJSONSource | undefined
      if (!source) return

      const features: GeoJSON.Feature[] = []
      for (const c of carriers) {
        if (!c.extent_geojson) continue
        try {
          const geom = JSON.parse(c.extent_geojson) as GeoJSON.Geometry
          features.push({
            type: 'Feature',
            geometry: geom,
            properties: {
              id: c.id,
              display_name: c.display_name,
              type: c.type,
              color: colorFor(c),
              extent_is_real: !!c.extent_is_real,
              disagreed: diffCarrierIds?.has(c.id) ?? false,
            },
          })
        } catch {
          // skip malformed geometry
        }
      }
      source.setData({ type: 'FeatureCollection', features })
    }
    if (map.getSource('carrier-extents')) apply()
    else map.once('load', apply)
  }, [carriers, diffCarrierIds, colorFor])

  // Update propagation flow lines + arrowheads (flow viz mode).
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const lineSrc = map.getSource('propagation-edges') as maplibregl.GeoJSONSource | undefined
      const arrowSrc = map.getSource('propagation-arrowheads') as maplibregl.GeoJSONSource | undefined
      if (!lineSrc || !arrowSrc) return

      const lines: GeoJSON.Feature[] = []
      const arrows: GeoJSON.Feature[] = []
      for (const p of propagationEvents ?? []) {
        if (!p.source_point || !p.destination_point) continue
        const src: [number, number] = [p.source_point.lon, p.source_point.lat]
        const dst: [number, number] = [p.destination_point.lon, p.destination_point.lat]
        const color = DOMAIN_COLORS[p.domain] ?? DOMAIN_COLORS.other
        lines.push({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: [src, dst] },
          properties: {
            id: p.id,
            display_name: p.display_name,
            domain: p.domain,
            color,
          },
        })
        // Bearing in degrees from source to destination, used to rotate the
        // unicode arrow at the destination so it points along the line.
        const dLon = dst[0] - src[0]
        const dLat = dst[1] - src[1]
        const bearing = (Math.atan2(dLon, dLat) * 180) / Math.PI
        arrows.push({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: dst },
          properties: {
            id: p.id,
            domain: p.domain,
            color,
            bearing,
          },
        })
      }
      lineSrc.setData({ type: 'FeatureCollection', features: lines })
      arrowSrc.setData({ type: 'FeatureCollection', features: arrows })
    }
    if (map.getSource('propagation-edges')) apply()
    else map.once('load', apply)
  }, [propagationEvents])

  // Update observations source (pointwise mode)
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('observations') as maplibregl.GeoJSONSource | undefined
      if (!source) return

      const features: GeoJSON.Feature[] = (observations ?? [])
        .filter((o) => o.location)
        .map((o) => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [o.location!.lon, o.location!.lat],
          },
          properties: {
            id: o.id,
            domain: o.domain,
            color: DOMAIN_COLORS[o.domain] ?? DOMAIN_COLORS.other,
            sample_label: o.sample_label,
            trait_id: o.trait_id,
            trait_display_name: o.trait_display_name,
            fraction: o.fraction,
            method: o.method,
          },
        }))
      source.setData({ type: 'FeatureCollection', features })
    }
    if (map.getSource('observations')) apply()
    else map.once('load', apply)
  }, [observations])

  // Update continental-shelf source data + visibility together. Combined into
  // a single effect so the two can never desync (e.g. data set without
  // visibility flipping back on, leaving an invisible loaded source).
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('continental-shelf') as maplibregl.GeoJSONSource | undefined
      if (!source) return
      const fc = shelfGeojson ?? { type: 'FeatureCollection' as const, features: [] }
      source.setData(fc)
      const v = shelfVisible ? 'visible' : 'none'
      for (const id of ['continental-shelf-fill', 'continental-shelf-outline']) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', v)
      }
    }
    if (map.getSource('continental-shelf')) apply()
    else map.once('load', apply)
  }, [shelfGeojson, shelfVisible])

  // Update paleo-coastlines (GPlates) source + visibility
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('paleo-coastlines') as maplibregl.GeoJSONSource | undefined
      if (!source) return
      const fc = paleoCoastlines ?? { type: 'FeatureCollection' as const, features: [] }
      source.setData(fc)
      const has = (paleoCoastlines?.features?.length ?? 0) > 0
      const v = has ? 'visible' : 'none'
      for (const id of ['paleo-coastlines-fill', 'paleo-coastlines-outline']) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', v)
      }
    }
    if (map.getSource('paleo-coastlines')) apply()
    else map.once('load', apply)
  }, [paleoCoastlines])

  // Update paleo-features source
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('paleo-features') as maplibregl.GeoJSONSource | undefined
      if (!source) return

      const features: GeoJSON.Feature[] = []
      for (const f of paleoFeatures ?? []) {
        if (!f.geometry_geojson) continue
        try {
          const geom = JSON.parse(f.geometry_geojson) as GeoJSON.Geometry
          features.push({
            type: 'Feature',
            geometry: geom,
            properties: {
              id: f.id,
              type: f.type,
              display_name: f.display_name,
              as_of_year: f.as_of_year,
            },
          })
        } catch {
          // skip malformed geometry
        }
      }
      source.setData({ type: 'FeatureCollection', features })
    }
    if (map.getSource('paleo-features')) apply()
    else map.once('load', apply)
  }, [paleoFeatures])

  // Update lineage edges + nodes. Edges are LineString features connecting
  // the focal carrier centroid to each ancestor (side='past') and descendant
  // (side='future'). Nodes include the focal point (role='focal') so the user
  // can see which carrier the lineage anchors on.
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const edgeSrc = map.getSource('lineage-edges') as maplibregl.GeoJSONSource | undefined
      const nodeSrc = map.getSource('lineage-nodes') as maplibregl.GeoJSONSource | undefined
      const pulseSrc = map.getSource('lineage-pulse') as maplibregl.GeoJSONSource | undefined
      if (!edgeSrc || !nodeSrc || !pulseSrc) return

      const edges: GeoJSON.Feature[] = []
      const nodes: GeoJSON.Feature[] = []
      const pulses: GeoJSON.Feature[] = []
      // A node/edge is "active" when its carrier's date range covers the
      // current year. The lineage anchor itself stays fixed (see
      // useCarrierLineage), so toggling animation just changes which
      // ancestors/descendants light up — the cast of nodes is stable.
      const isActive = (minY: number, maxY: number) => year >= minY && year <= maxY

      // Linear interpolation between two lng/lat points by t ∈ [0, 1].
      // For continent-scale connectors plain linear is fine (the visual
      // is "a particle is moving along this edge", not great-circle
      // navigation precision).
      const lerp = (
        a: [number, number],
        b: [number, number],
        t: number,
      ): [number, number] => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]

      if (lineage?.focal?.centroid) {
        const f = lineage.focal
        const focalActive = isActive(f.date_min_year, f.date_max_year)
        nodes.push({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [f.centroid!.lon, f.centroid!.lat] },
          properties: {
            id: f.id,
            display_name: f.display_name,
            role: 'focal',
            active: focalActive,
          },
        })
        const focalLngLat: [number, number] = [f.centroid!.lon, f.centroid!.lat]
        for (const a of lineage.ancestors) {
          if (!a.centroid) continue
          const active = isActive(a.date_min_year, a.date_max_year)
          const ancestorLngLat: [number, number] = [a.centroid.lon, a.centroid.lat]
          edges.push({
            type: 'Feature',
            geometry: { type: 'LineString', coordinates: [ancestorLngLat, focalLngLat] },
            properties: {
              side: 'past',
              id: a.id,
              shared: a.shared_trait_ids.join(','),
              active,
            },
          })
          nodes.push({
            type: 'Feature',
            geometry: { type: 'Point', coordinates: ancestorLngLat },
            properties: {
              id: a.id,
              display_name: a.display_name,
              role: 'past',
              date_max_year: a.date_max_year,
              active,
            },
          })
          // Past-edge pulse: travels from ancestor → focal as years progress
          // from a.date_max_year (ancestor's end) to f.date_min_year (focal's
          // start). Outside that interval, clamp to one of the endpoints.
          const t0 = a.date_max_year
          const t1 = Math.max(t0 + 1, f.date_min_year)
          const tNorm = Math.min(1, Math.max(0, (year - t0) / (t1 - t0)))
          pulses.push({
            type: 'Feature',
            geometry: { type: 'Point', coordinates: lerp(ancestorLngLat, focalLngLat, tNorm) },
            properties: { side: 'past', edge_id: `past:${a.id}` },
          })
        }
        for (const d of lineage.descendants) {
          if (!d.centroid) continue
          const active = isActive(d.date_min_year, d.date_max_year)
          const descendantLngLat: [number, number] = [d.centroid.lon, d.centroid.lat]
          edges.push({
            type: 'Feature',
            geometry: { type: 'LineString', coordinates: [focalLngLat, descendantLngLat] },
            properties: {
              side: 'future',
              id: d.id,
              shared: d.shared_trait_ids.join(','),
              active,
            },
          })
          nodes.push({
            type: 'Feature',
            geometry: { type: 'Point', coordinates: descendantLngLat },
            properties: {
              id: d.id,
              display_name: d.display_name,
              role: 'future',
              date_min_year: d.date_min_year,
              active,
            },
          })
          // Future-edge pulse: focal → descendant as years progress from
          // focal.date_max_year to d.date_min_year.
          const t0 = f.date_max_year
          const t1 = Math.max(t0 + 1, d.date_min_year)
          const tNorm = Math.min(1, Math.max(0, (year - t0) / (t1 - t0)))
          pulses.push({
            type: 'Feature',
            geometry: { type: 'Point', coordinates: lerp(focalLngLat, descendantLngLat, tNorm) },
            properties: { side: 'future', edge_id: `future:${d.id}` },
          })
        }
      }
      edgeSrc.setData({ type: 'FeatureCollection', features: edges })
      nodeSrc.setData({ type: 'FeatureCollection', features: nodes })
      pulseSrc.setData({ type: 'FeatureCollection', features: pulses })
    }
    if (map.getSource('lineage-edges')) apply()
    else map.once('load', apply)
  }, [lineage, year])

  // Update historical-places source + visibility together. Same combined
  // pattern as the shelf effect: data and visibility flip in lockstep so
  // toggling the label mode never leaves stale labels on screen.
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const source = map.getSource('historical-places') as maplibregl.GeoJSONSource | undefined
      if (!source) return
      const places = labelMode === 'historical' ? (historicalPlaces ?? []) : []
      const features: GeoJSON.Feature[] = places.map((p) => ({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [p.centroid.lon, p.centroid.lat] },
        properties: {
          id: p.id,
          display_name: p.display_name,
          kind: p.kind ?? 'city',
        },
      }))
      source.setData({ type: 'FeatureCollection', features })
      const vis = labelMode === 'historical' && features.length > 0 ? 'visible' : 'none'
      if (map.getLayer('historical-places-label')) {
        map.setLayoutProperty('historical-places-label', 'visibility', vis)
      }
    }
    if (map.getSource('historical-places')) apply()
    else map.once('load', apply)
  }, [historicalPlaces, labelMode])

  // Toggle the modern OSM label raster. Hidden in 'historical' / 'none'
  // modes so the user can read the carrier and historical-place labels
  // without modern names crowding them out.
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      if (!map.getLayer('osm-labels-tiles')) return
      map.setLayoutProperty(
        'osm-labels-tiles',
        'visibility',
        labelMode === 'modern' ? 'visible' : 'none',
      )
    }
    if (map.getLayer('osm-labels-tiles')) apply()
    else map.once('load', apply)
  }, [labelMode])

  // Toggle layer visibility based on viz mode. Each mode has its own
  // dominant set of layers; the others hide so the map stays uncluttered.
  // Flow mode hides extents and observations and shows propagation arrows;
  // it's the only mode that surfaces propagation_event geometry on the map.
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const fillVis = vizMode === 'fill' ? 'visible' : 'none'
      const pointVis = vizMode === 'pointwise' ? 'visible' : 'none'
      const flowVis = vizMode === 'flow' ? 'visible' : 'none'
      for (const id of [
        'carrier-extents-fill',
        'carrier-extents-outline-solid',
        'carrier-extents-outline-dashed',
      ]) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', fillVis)
      }
      if (map.getLayer('observations-circle')) {
        map.setLayoutProperty('observations-circle', 'visibility', pointVis)
      }
      for (const id of [
        'propagation-edges-line',
        'propagation-arrowhead-circle',
        'propagation-arrowhead-arrow',
      ]) {
        if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', flowVis)
      }
    }
    if (map.getLayer('carrier-extents-fill')) apply()
    else map.once('load', apply)
  }, [vizMode])

  return mapRef
}

// Single-perspective map
function SingleMap({
  carriers,
  propagationEvents,
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  historicalPlaces,
  lineage,
  perspectiveId,
  onCarrierClick,
  onMapClick,
}: {
  carriers: CarrierView[]
  propagationEvents: PropagationEventView[]
  observations: TraitObservationView[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
  historicalPlaces: MapInstanceProps['historicalPlaces']
  lineage: CarrierLineageResponse | null
  perspectiveId: string
  onCarrierClick: (id: string) => void
  onMapClick: (lat: number, lon: number) => void
}) {
  const containerId = `map-${perspectiveId}`
  useMapInstance({
    containerId,
    carriers,
    propagationEvents,
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    historicalPlaces,
    lineage,
    perspectiveId,
    onCarrierClick,
    onMapClick,
  })

  return <div id={containerId} className="w-full h-full" />
}

interface MapProps {
  worldData: WorldResponse | null
  loading: boolean
  paleoFeatures?: PaleoFeature[]
  shelfGeojson?: GeoJSON.FeatureCollection | null
  /** Sea level in meters relative to present. Currently informational; shelf
   *  visibility is driven by whether shelfGeojson has features. */
  seaLevelMeters?: number | null
  /** Deep-time paleo coastlines from GPlates. */
  paleoCoastlines?: GeoJSON.FeatureCollection | null
  /** Era-appropriate place labels — only populated when labelMode='historical'. */
  historicalPlaces?: MapInstanceProps['historicalPlaces']
  /** Past/future lineage for the selected carrier — null when off. */
  lineage?: CarrierLineageResponse | null
}

export function WorldMap({
  worldData,
  loading,
  paleoFeatures = [],
  shelfGeojson = null,
  paleoCoastlines = null,
  historicalPlaces = [],
  lineage = null,
}: MapProps) {
  const shelfVisible = (shelfGeojson?.features?.length ?? 0) > 0
  const renderMode = useStore((s) => s.renderMode)
  const activePerspectives = useStore((s) => s.activePerspectives)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const selectedCarrierId = useStore((s) => s.selectedCarrierId)
  const setClickPoint = useStore((s) => s.setClickPoint)

  const handleCarrierClick = useCallback(
    (id: string) => {
      setClickPoint(null)
      setSelectedCarrierId(id === selectedCarrierId ? null : id)
    },
    [selectedCarrierId, setSelectedCarrierId, setClickPoint]
  )

  const handleMapClick = useCallback(
    (lat: number, lon: number) => {
      setSelectedCarrierId(null)
      setClickPoint({ lat, lon })
    },
    [setSelectedCarrierId, setClickPoint]
  )

  if (!worldData || activePerspectives.length === 0) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-gray-800 text-gray-400 text-sm">
        {loading ? 'Loading world data…' : 'Select at least one Perspective to begin.'}
      </div>
    )
  }

  const perspIds = activePerspectives.filter((pid) => pid in worldData.perspectives)

  if (renderMode === 'side-by-side' && perspIds.length >= 2) {
    return (
      <SideBySideMap
        worldData={worldData}
        perspIds={perspIds}
        paleoFeatures={paleoFeatures}
        shelfGeojson={shelfGeojson}
        shelfVisible={shelfVisible}
        paleoCoastlines={paleoCoastlines}
        historicalPlaces={historicalPlaces}
        lineage={lineage}
        onCarrierClick={handleCarrierClick}
        onMapClick={handleMapClick}
      />
    )
  }

  if (renderMode === 'diff-overlay') {
    const diffs = computeDiff(worldData)
    const diffIds = new Set(diffs.filter((d) => d.hasDisagreement).map((d) => d.carrierId))
    const allCarriers = Object.values(worldData.perspectives).flatMap((v) => v.carriers)
    const uniqueCarriers = Array.from(new globalThis.Map(allCarriers.map((c) => [c.id, c])).values())
    const allProps = Object.values(worldData.perspectives).flatMap((v) => v.propagation_events)
    const uniqueProps = Array.from(new globalThis.Map(allProps.map((p) => [p.id, p])).values())
    return (
      <div className="w-full h-full relative">
        <div id="map-diff" className="w-full h-full" />
        <DiffMapUpdater
          carriers={uniqueCarriers}
          propagationEvents={uniqueProps}
          observations={worldData.observations ?? []}
          paleoFeatures={paleoFeatures}
          shelfGeojson={shelfGeojson}
          shelfVisible={shelfVisible}
          paleoCoastlines={paleoCoastlines}
          historicalPlaces={historicalPlaces}
          lineage={lineage}
          diffIds={diffIds}
          onCarrierClick={handleCarrierClick}
          onMapClick={handleMapClick}
        />
      </div>
    )
  }

  // Single perspective mode (use first active perspective)
  const pid = perspIds[0]
  const carriers = worldData.perspectives[pid]?.carriers ?? []
  const propagationEvents = worldData.perspectives[pid]?.propagation_events ?? []
  const observations = worldData.observations ?? []
  return (
    <div className="w-full h-full">
      <SingleMap
        carriers={carriers}
        propagationEvents={propagationEvents}
        observations={observations}
        paleoFeatures={paleoFeatures}
        shelfGeojson={shelfGeojson}
        shelfVisible={shelfVisible}
        paleoCoastlines={paleoCoastlines}
        historicalPlaces={historicalPlaces}
        lineage={lineage}
        perspectiveId={pid}
        onCarrierClick={handleCarrierClick}
        onMapClick={handleMapClick}
      />
    </div>
  )
}

function SideBySideMap({
  worldData,
  perspIds,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  historicalPlaces,
  lineage,
  onCarrierClick,
  onMapClick,
}: {
  worldData: WorldResponse
  perspIds: string[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
  historicalPlaces: MapInstanceProps['historicalPlaces']
  lineage: CarrierLineageResponse | null
  onCarrierClick: (id: string) => void
  onMapClick: (lat: number, lon: number) => void
}) {
  const diffs = computeDiff(worldData)
  const diffIds = new Set(diffs.filter((d) => d.hasDisagreement).map((d) => d.carrierId))

  const leftPid = perspIds[0]
  const rightPid = perspIds[1]

  const observations = worldData.observations ?? []

  const map1Ref = useMapInstance({
    containerId: `map-left`,
    carriers: worldData.perspectives[leftPid]?.carriers ?? [],
    propagationEvents: worldData.perspectives[leftPid]?.propagation_events ?? [],
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    historicalPlaces,
    lineage,
    perspectiveId: leftPid,
    diffCarrierIds: diffIds,
    onCarrierClick,
    onMapClick,
    syncWith: null,
  })

  const map2Ref = useMapInstance({
    containerId: `map-right`,
    carriers: worldData.perspectives[rightPid]?.carriers ?? [],
    propagationEvents: worldData.perspectives[rightPid]?.propagation_events ?? [],
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    historicalPlaces,
    lineage,
    perspectiveId: rightPid,
    diffCarrierIds: diffIds,
    onCarrierClick,
    onMapClick,
    syncWith: null,
  })

  return (
    <div className="flex w-full h-full">
      <div className="flex-1 h-full relative">
        <div
          className="absolute top-2 left-2 z-10 bg-black/70 text-white text-xs px-2 py-1 rounded"
        >
          {leftPid.replace('PERSP_', '').replace(/_/g, ' ')}
        </div>
        <div id="map-left" className="w-full h-full" />
      </div>
      <div className="w-px bg-gray-600" />
      <div className="flex-1 h-full relative">
        <div
          className="absolute top-2 left-2 z-10 bg-black/70 text-white text-xs px-2 py-1 rounded"
        >
          {rightPid.replace('PERSP_', '').replace(/_/g, ' ')}
        </div>
        <div id="map-right" className="w-full h-full" />
      </div>
    </div>
  )
}

// Separate component to update diff-overlay map (uses a standalone map instance)
function DiffMapUpdater({
  carriers,
  propagationEvents,
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  historicalPlaces,
  lineage,
  diffIds,
  onCarrierClick,
  onMapClick,
}: {
  carriers: CarrierView[]
  propagationEvents: PropagationEventView[]
  observations: TraitObservationView[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
  historicalPlaces: MapInstanceProps['historicalPlaces']
  lineage: CarrierLineageResponse | null
  diffIds: Set<string>
  onCarrierClick: (id: string) => void
  onMapClick: (lat: number, lon: number) => void
}) {
  useMapInstance({
    containerId: 'map-diff',
    carriers,
    propagationEvents,
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    historicalPlaces,
    lineage,
    perspectiveId: 'diff',
    diffCarrierIds: diffIds,
    onCarrierClick,
    onMapClick,
    syncWith: null,
  })
  return null
}
