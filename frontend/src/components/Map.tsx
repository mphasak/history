import { useEffect, useRef, useCallback } from 'react'
import maplibregl from 'maplibre-gl'
import { WorldResponse, CarrierView, TraitObservationView, PaleoFeature } from '../api'
import { useStore } from '../state'
import { computeDiff } from './DiffOverlay'

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

const OSM_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  // Required so symbol layers using `text-field` (e.g. carrier labels) can resolve
  // glyphs. MapLibre's free demo glyph endpoint covers basic Latin and is
  // sufficient for carrier display names.
  glyphs: 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
  sources: {
    osm: {
      type: 'raster',
      tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      tileSize: 256,
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    },
  },
  layers: [{ id: 'osm-tiles', type: 'raster', source: 'osm', minzoom: 0, maxzoom: 19 }],
}

interface MapInstanceProps {
  containerId: string
  carriers: CarrierView[]
  observations?: TraitObservationView[]
  paleoFeatures?: PaleoFeature[]
  shelfGeojson?: GeoJSON.FeatureCollection | null
  /** When true, render the continental-shelf polygon as exposed land. */
  shelfVisible?: boolean
  /** Optional GeoJSON of paleo-coastlines from GPlates for deep time. */
  paleoCoastlines?: GeoJSON.FeatureCollection | null
  perspectiveId: string
  diffCarrierIds?: Set<string>
  onCarrierClick: (carrierId: string) => void
  onMapClick?: (lat: number, lon: number) => void
  syncWith?: maplibregl.Map | null
}

function useMapInstance({
  containerId,
  carriers,
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
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
            ['get', 'disagreed'],
            '#ef4444',
            '#3b82f6',
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
            ['get', 'disagreed'],
            '#ef4444',
            '#60a5fa',
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
            ['get', 'disagreed'],
            '#ef4444',
            '#60a5fa',
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

      map.addLayer({
        id: 'carriers-circle',
        type: 'circle',
        source: 'carriers',
        paint: {
          'circle-radius': 10,
          'circle-color': [
            'case',
            ['get', 'disagreed'],
            '#ef4444',
            '#3b82f6',
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

      // Apply initial viz mode visibility once layers exist
      const v = vizModeRef.current
      const fillVis = v === 'fill' ? 'visible' : 'none'
      const pointVis = v === 'pointwise' ? 'visible' : 'none'
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
  }, [carriers, diffCarrierIds])

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
  }, [carriers, diffCarrierIds])

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

  // Toggle layer visibility based on viz mode
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    const apply = () => {
      const fillVis = vizMode === 'fill' ? 'visible' : 'none'
      const pointVis = vizMode === 'pointwise' ? 'visible' : 'none'
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
    }
    if (map.getLayer('carrier-extents-fill')) apply()
    else map.once('load', apply)
  }, [vizMode])

  return mapRef
}

// Single-perspective map
function SingleMap({
  carriers,
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  perspectiveId,
  onCarrierClick,
  onMapClick,
}: {
  carriers: CarrierView[]
  observations: TraitObservationView[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
  perspectiveId: string
  onCarrierClick: (id: string) => void
  onMapClick: (lat: number, lon: number) => void
}) {
  const containerId = `map-${perspectiveId}`
  useMapInstance({
    containerId,
    carriers,
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
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
}

export function WorldMap({
  worldData,
  loading,
  paleoFeatures = [],
  shelfGeojson = null,
  paleoCoastlines = null,
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
    return (
      <div className="w-full h-full relative">
        <div id="map-diff" className="w-full h-full" />
        <DiffMapUpdater
          carriers={uniqueCarriers}
          observations={worldData.observations ?? []}
          paleoFeatures={paleoFeatures}
          shelfGeojson={shelfGeojson}
          shelfVisible={shelfVisible}
          paleoCoastlines={paleoCoastlines}
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
  const observations = worldData.observations ?? []
  return (
    <div className="w-full h-full">
      <SingleMap
        carriers={carriers}
        observations={observations}
        paleoFeatures={paleoFeatures}
        shelfGeojson={shelfGeojson}
        shelfVisible={shelfVisible}
        paleoCoastlines={paleoCoastlines}
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
  onCarrierClick,
  onMapClick,
}: {
  worldData: WorldResponse
  perspIds: string[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
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
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    perspectiveId: leftPid,
    diffCarrierIds: diffIds,
    onCarrierClick,
    onMapClick,
    syncWith: null,
  })

  const map2Ref = useMapInstance({
    containerId: `map-right`,
    carriers: worldData.perspectives[rightPid]?.carriers ?? [],
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
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
  observations,
  paleoFeatures,
  shelfGeojson,
  shelfVisible,
  paleoCoastlines,
  diffIds,
  onCarrierClick,
  onMapClick,
}: {
  carriers: CarrierView[]
  observations: TraitObservationView[]
  paleoFeatures: PaleoFeature[]
  shelfGeojson: GeoJSON.FeatureCollection | null
  shelfVisible: boolean
  paleoCoastlines: GeoJSON.FeatureCollection | null
  diffIds: Set<string>
  onCarrierClick: (id: string) => void
  onMapClick: (lat: number, lon: number) => void
}) {
  useMapInstance({
    containerId: 'map-diff',
    carriers,
    observations,
    paleoFeatures,
    shelfGeojson,
    shelfVisible,
    paleoCoastlines,
    perspectiveId: 'diff',
    diffCarrierIds: diffIds,
    onCarrierClick,
    onMapClick,
    syncWith: null,
  })
  return null
}
