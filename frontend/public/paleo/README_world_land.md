# World land + ocean mask (Natural Earth 110m)

`world_land_110m.geojson` — Natural Earth 1:110m land polygons, 127 features
(continents + major islands), ~230 KB. Source:
[`martynafford/natural-earth-geojson`](https://github.com/martynafford/natural-earth-geojson)
which mirrors `nvkelso/natural-earth-vector` as GeoJSON.

`world_ocean_mask_110m.geojson` — derived: a single Polygon whose outer ring
is the world rect (`-180,-90 → 180,90`) and whose interior holes are each
landmass's outer ring. Painted on the map *above* `carrier-extents-fill`,
this re-paints the ocean back over any buffer that bled past the coastline,
without server-side per-carrier clipping.

Regenerate the mask after replacing the source land file:

```python
python3 - <<'PY'
import json
land = json.load(open('frontend/public/paleo/world_land_110m.geojson'))
world_rect_ccw = [[-180,-90],[180,-90],[180,90],[-180,90],[-180,-90]]
holes = []
for feat in land['features']:
    g = feat['geometry']
    polys = [g['coordinates']] if g['type']=='Polygon' else g['coordinates']
    for poly in polys:
        outer = poly[0]
        if len(outer) >= 4: holes.append(outer)
ocean = {"type":"FeatureCollection","features":[{
    "type":"Feature","properties":{"role":"ocean_mask"},
    "geometry":{"type":"Polygon","coordinates":[world_rect_ccw] + holes}}]}
json.dump(ocean, open('frontend/public/paleo/world_ocean_mask_110m.geojson','w'))
PY
```

The 110m resolution is intentionally coarse — a higher-res mask just
makes the file bigger without visibly improving carrier clipping at the
zoom levels this app uses.
