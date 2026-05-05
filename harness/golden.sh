#!/usr/bin/env bash
# Golden flows. Each block is a canonical demo from CLAUDE.md, exercised
# via curl + jq assertions. Add a new flow whenever a regression bites.
#
# The flows are deliberately phrased as "the thing the user expects to see
# on the UI"; if a flow ever fails, the failure message tells the agent
# both *what* broke and *which user-facing scenario* depends on it.
set -euo pipefail

API="${API_URL:-http://localhost:8000}"
fail() { echo "  FAIL: $*" >&2; exit 1; }
ok()   { echo "  ok: $*"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "[golden] jq not installed; skipping" >&2
  exit 0
fi

echo "[golden] Indo-Aryan disagreement (AMT + OOI at -1700)..."
got="$(curl -sf "$API/world?year=-1700&bbox=-180,-85,180,85&perspectives=PERSP_INDIAN_AMT,PERSP_INDIAN_OOI" \
  | jq -r '.disagreed_carrier_ids[]?' | grep -c CARR_NW_SOUTH_ASIA_LATE_BRONZE || true)"
[[ "$got" -ge 1 ]] || fail "AMT+OOI disagreement not surfaced for NW South Asia carrier"
ok "AMT+OOI disagreement surfaced"

echo "[golden] Multi-hop lineage Rural-South-US -> Neanderthal..."
n=$(curl -sf "$API/carrier/CARR_RURAL_SOUTH_US_2025/lineage?year=2000&direction=past&max_depth=6&max_per_hop=5" \
  | jq -r '.nodes[].id' | grep -c CARR_HOMININ_NEANDERTHAL || true)
[[ "$n" -ge 1 ]] || fail "Multi-hop trace from Rural South US doesn't reach Neanderthal"
ok "Rural South US traces back to Neanderthal"

echo "[golden] Future-of-First-Americans is Native-American only..."
desc=$(curl -sf "$API/carrier/CARR_PALEO_AMER_15K/lineage?year=-12000&direction=future&max_depth=5&max_per_hop=6" \
  | jq -r '.nodes[].id')
echo "$desc" | grep -qE '(CARR_HIST_FOR_SAAMI_ANCESTRAL|CARR_HIST_GAP_YAKUT|CARR_HIST_MODERN_HAN|CARR_HIST_VEDIC_ARYAN)' \
  && fail "Sibling populations leaked through future-of-First-Americans"
echo "$desc" | grep -qE '(CARR_HIST_AZTEC|CARR_HIST_INCA|CARR_HIST_MAYA_CLASSICAL|CARR_HIST_MODERN_NATIVE_AMER)' \
  || fail "No genuine Native American descendants of First Americans"
ok "Future of First Americans is Native-American only"

echo "[golden] No N-American temporal gap at 700 CE..."
n=$(curl -sf "$API/world?year=700&bbox=-130,25,-50,75&perspectives=PERSP_REICH_2018" \
  | jq '.perspectives.PERSP_REICH_2018.carriers | length')
[[ "$n" -ge 3 ]] || fail "N America at 700 CE has only $n carriers (expected >=3)"
ok "N America at 700 CE: $n carriers"

echo "[golden] Post-Columbian carriers present at 1700 CE..."
ids=$(curl -sf "$API/world?year=1700&bbox=-130,-55,-50,75&perspectives=PERSP_REICH_2018" \
  | jq -r '.perspectives.PERSP_REICH_2018.carriers[].id')
for need in CARR_HIST_POST1492_COLONIAL_NA CARR_HIST_POST1492_AFRICAN_AMERICAN CARR_HIST_POST1492_COLONIAL_ANDEAN; do
  echo "$ids" | grep -q "^$need\$" || fail "$need missing from Americas at 1700 CE"
done
ok "Post-Columbian carriers present at 1700 CE"

echo "[golden] Roman provenance cites ANTONIO_2019..."
got=$(curl -sf "$API/carrier/CARR_HIST_ROMAN/claims?perspectives=PERSP_REICH_2018" \
  | jq -r '.claims[].perspectives.PERSP_REICH_2018.sources[].source_id' | grep -c ANTONIO_2019 || true)
[[ "$got" -ge 1 ]] || fail "Roman [AUTO-PROVENANCE] doesn't cite ANTONIO_2019"
ok "Roman provenance cites ANTONIO_2019"

echo "[golden] Yamnaya admixture event lights up at -2500..."
got=$(curl -sf "$API/admixture-events?year=-2500" \
  | jq -r '.events[].id' | grep -c ADMIX_YAMNAYA_INTO_EUROPE || true)
[[ "$got" -ge 1 ]] || fail "Yamnaya admixture event not surfaced at -2500 BCE"
ok "Yamnaya admixture event surfaces at -2500 BCE"

echo "[golden] Atlantic slave trade event lights up at 1700..."
got=$(curl -sf "$API/admixture-events?year=1700" \
  | jq -r '.events[].id' | grep -c ADMIX_ATLANTIC_SLAVE_TRADE || true)
[[ "$got" -ge 1 ]] || fail "Atlantic slave trade not surfaced at 1700 CE"
ok "Atlantic slave trade event surfaces at 1700 CE"

echo "[golden] Antimeridian-crossing extent doesn't span the globe..."
ext=$(curl -sf "$API/world?year=1500&bbox=-180,-85,180,85&perspectives=PERSP_REICH_2018" \
  | jq -r '.perspectives.PERSP_REICH_2018.carriers[] | select(.id=="CARR_HIST_GAP_CHUKCHI") | .extent_geojson')
if [[ -n "$ext" && "$ext" != "null" ]]; then
  span=$(printf '%s' "$ext" | python3 -c '
import json, sys
g = json.loads(sys.stdin.read())
def lons(coords):
    out = []
    for r in coords:
        if isinstance(r[0], (int, float)):
            out.append(r[0])
        else:
            out.extend(lons(r))
    return out
ls = lons(g["coordinates"])
print(f"{max(ls) - min(ls):.1f}")
')
  if awk "BEGIN{exit !($span > 60.0)}"; then
    fail "Chukchi extent spans ${span}° of longitude (>60° = antimeridian wrap)"
  fi
  ok "Chukchi extent span: ${span}°"
else
  ok "Chukchi not in this year's view (skipping)"
fi

echo "[golden] No Chinese-heartland gap at 472 BCE (Zhou bridge present)..."
got=$(curl -sf "$API/world?year=-472&bbox=95,25,130,45&perspectives=PERSP_POSTREICH_2025" \
  | jq -r '.perspectives.PERSP_POSTREICH_2025.carriers[].id' | grep -c CARR_HIST_BRIDGE_ZHOU || true)
[[ "$got" -ge 1 ]] || fail "Zhou bridge missing at 472 BCE — Yellow River cell empty during Spring & Autumn / Warring States"
ok "Zhou bridge fills the Shang→Han gap at 472 BCE"

echo "[golden] No post-Han Chinese gap at 400 CE (Three Kingdoms / Jin bridge)..."
got=$(curl -sf "$API/world?year=400&bbox=95,25,130,45&perspectives=PERSP_POSTREICH_2025" \
  | jq -r '.perspectives.PERSP_POSTREICH_2025.carriers[].id' | grep -c CARR_HIST_BRIDGE_THREEKINGS_JIN || true)
[[ "$got" -ge 1 ]] || fail "Three-Kingdoms/Jin bridge missing at 400 CE"
ok "Three-Kingdoms/Jin bridge fills the Han→Tang gap"

echo "[golden] all green"
