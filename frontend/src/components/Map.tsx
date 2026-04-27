import { useEffect, useRef, useCallback } from 'react'
import maplibregl from 'maplibre-gl'
import { WorldResponse, CarrierView } from '../api'
import { useStore } from '../state'
import { computeDiff } from './DiffOverlay'

const OSM_STYLE: maplibregl.StyleSpecification = {
  version: 8,
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
  perspectiveId: string
  diffCarrierIds?: Set<string>
  onCarrierClick: (carrierId: string) => void
  syncWith?: maplibregl.Map | null
}

function useMapInstance({
  containerId,
  carriers,
  diffCarrierIds,
  onCarrierClick,
  syncWith,
}: MapInstanceProps) {
  const mapRef = useRef<maplibregl.Map | null>(null)
  const syncingRef = useRef(false)

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
      // Add carrier source + layer
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
          'text-size': 11,
          'text-offset': [0, 1.5],
          'text-anchor': 'top',
        },
        paint: {
          'text-color': '#ffffff',
          'text-halo-color': '#000000',
          'text-halo-width': 1,
        },
      })

      map.on('click', 'carriers-circle', (e) => {
        const feature = e.features?.[0]
        if (feature?.properties?.id) {
          onCarrierClick(feature.properties.id)
        }
      })

      map.on('mouseenter', 'carriers-circle', () => {
        map.getCanvas().style.cursor = 'pointer'
      })
      map.on('mouseleave', 'carriers-circle', () => {
        map.getCanvas().style.cursor = ''
      })
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

  // Update carrier data
  useEffect(() => {
    const map = mapRef.current
    if (!map || !map.isStyleLoaded()) return

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
  }, [carriers, diffCarrierIds])

  return mapRef
}

// Single-perspective map
function SingleMap({
  carriers,
  perspectiveId,
  onCarrierClick,
}: {
  carriers: CarrierView[]
  perspectiveId: string
  onCarrierClick: (id: string) => void
}) {
  const containerId = `map-${perspectiveId}`
  useMapInstance({
    containerId,
    carriers,
    perspectiveId,
    onCarrierClick,
  })

  return <div id={containerId} className="w-full h-full" />
}

interface MapProps {
  worldData: WorldResponse | null
  loading: boolean
}

export function WorldMap({ worldData, loading }: MapProps) {
  const renderMode = useStore((s) => s.renderMode)
  const activePerspectives = useStore((s) => s.activePerspectives)
  const setSelectedCarrierId = useStore((s) => s.setSelectedCarrierId)
  const selectedCarrierId = useStore((s) => s.selectedCarrierId)

  const handleCarrierClick = useCallback(
    (id: string) => {
      setSelectedCarrierId(id === selectedCarrierId ? null : id)
    },
    [selectedCarrierId, setSelectedCarrierId]
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
    return <SideBySideMap worldData={worldData} perspIds={perspIds} onCarrierClick={handleCarrierClick} />
  }

  if (renderMode === 'diff-overlay') {
    const diffs = computeDiff(worldData)
    const diffIds = new Set(diffs.filter((d) => d.hasDisagreement).map((d) => d.carrierId))
    const allCarriers = Object.values(worldData.perspectives).flatMap((v) => v.carriers)
    const uniqueCarriers = Array.from(new globalThis.Map(allCarriers.map((c) => [c.id, c])).values())
    return (
      <div className="w-full h-full relative">
        <div id="map-diff" className="w-full h-full" />
        <DiffMapUpdater carriers={uniqueCarriers} diffIds={diffIds} onCarrierClick={handleCarrierClick} />
      </div>
    )
  }

  // Single perspective mode (use first active perspective)
  const pid = perspIds[0]
  const carriers = worldData.perspectives[pid]?.carriers ?? []
  return (
    <div className="w-full h-full">
      <SingleMap carriers={carriers} perspectiveId={pid} onCarrierClick={handleCarrierClick} />
    </div>
  )
}

function SideBySideMap({
  worldData,
  perspIds,
  onCarrierClick,
}: {
  worldData: WorldResponse
  perspIds: string[]
  onCarrierClick: (id: string) => void
}) {
  const diffs = computeDiff(worldData)
  const diffIds = new Set(diffs.filter((d) => d.hasDisagreement).map((d) => d.carrierId))

  const leftPid = perspIds[0]
  const rightPid = perspIds[1]

  const map1Ref = useMapInstance({
    containerId: `map-left`,
    carriers: worldData.perspectives[leftPid]?.carriers ?? [],
    perspectiveId: leftPid,
    diffCarrierIds: diffIds,
    onCarrierClick,
    syncWith: null,
  })

  const map2Ref = useMapInstance({
    containerId: `map-right`,
    carriers: worldData.perspectives[rightPid]?.carriers ?? [],
    perspectiveId: rightPid,
    diffCarrierIds: diffIds,
    onCarrierClick,
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
  diffIds,
  onCarrierClick,
}: {
  carriers: CarrierView[]
  diffIds: Set<string>
  onCarrierClick: (id: string) => void
}) {
  useMapInstance({
    containerId: 'map-diff',
    carriers,
    perspectiveId: 'diff',
    diffCarrierIds: diffIds,
    onCarrierClick,
    syncWith: null,
  })
  return null
}
