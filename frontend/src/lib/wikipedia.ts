/**
 * Wikipedia image lookup for carriers.
 *
 * Hits the public Wikipedia REST API
 * (https://en.wikipedia.org/api/rest_v1/page/summary/<title>) which returns
 * a JSON summary including a thumbnail URL. CORS is allowed on this
 * endpoint so the browser can call it directly without a backend proxy.
 *
 * Title resolution:
 *   1. If the carrier_id is in `CARRIER_WIKIPEDIA_TITLES`, use that title.
 *   2. Otherwise fall back to the carrier's display_name (URL-encoded).
 *      Wikipedia's API will normalize/redirect on its end, so an
 *      approximate display_name often resolves to the right page.
 *
 * Many carriers have no Wikipedia entry at all (e.g. CARR_HOMININ_*,
 * gene-component-only carriers, regional gap-fillers); those simply
 * 404 and the panel shows no image.
 */

/** Hand-curated overrides where the display_name doesn't match a
 * Wikipedia page title cleanly. Keep this minimal — favor adding rows
 * here only for carriers whose UI labels deviate from the Wikipedia
 * convention (e.g. "Modern South Asians" → "South Asian people"). */
export const CARRIER_WIKIPEDIA_TITLES: Record<string, string> = {
  // Indo-Aryan demo carriers
  CARR_HIST_VEDIC_ARYAN: 'Indo-Aryan_migrations',
  CARR_NW_SOUTH_ASIA_LATE_BRONZE: 'History_of_South_Asia',
  CARR_HARAPPAN: 'Indus_Valley_Civilisation',
  CARR_HIST_MAURYAN: 'Maurya_Empire',
  CARR_HIST_MUGHAL_N_INDIAN: 'Mughal_Empire',
  CARR_HIST_MODERN_S_ASIAN: 'South_Asian_ethnic_groups',
  // Reich-style ancestry component carriers
  CARR_OOA_LEVANT_55K: 'Recent_African_origin_of_modern_humans',
  CARR_NATUFIAN_12K: 'Natufian_culture',
  CARR_MALTA_24K: 'Mal%27ta%E2%80%93Buret%27_culture',
  CARR_PALEO_AMER_15K: 'Settlement_of_the_Americas',
  CARR_AURIGNACIAN_EU: 'Aurignacian',
  CARR_GRAVETTIAN_EU: 'Gravettian',
  CARR_TIANYUAN_40K: 'Tianyuan_man',
  CARR_PAPUAN_45K: 'Papuans',
  CARR_AUS_ABORIGINAL: 'Aboriginal_Australians',
  CARR_WHG_MESO: 'Western_Hunter-Gatherer',
  CARR_EHG_MESO: 'Eastern_Hunter-Gatherer',
  CARR_CHG_MESO: 'Caucasus_hunter-gatherer',
  CARR_ANATOLIAN_FARMER: 'Early_European_Farmers',
  CARR_IRAN_NEOLITHIC: 'Iranian_Neolithic',
  // Historical empires
  CARR_HIST_ROMAN: 'Roman_Empire',
  CARR_HIST_GREEK: 'Ancient_Greece',
  CARR_HIST_BYZANTINE: 'Byzantine_Empire',
  CARR_HIST_OTTOMAN: 'Ottoman_Empire',
  CARR_HIST_HAN: 'Han_dynasty',
  CARR_HIST_TANG: 'Tang_dynasty',
  CARR_HIST_MONGOL: 'Mongol_Empire',
  CARR_HIST_MAYA_CLASSICAL: 'Maya_civilization',
  CARR_HIST_AZTEC: 'Aztec_Empire',
  CARR_HIST_INCA: 'Inca_Empire',
  CARR_HIST_KHMER: 'Khmer_Empire',
  CARR_HIST_AKSUMITE: 'Kingdom_of_Aksum',
  CARR_HIST_ABBASID: 'Abbasid_Caliphate',
  CARR_HIST_ACHAEMENID: 'Achaemenid_Empire',
  CARR_HIST_SASANIAN: 'Sasanian_Empire',
  CARR_HIST_BABYLONIAN: 'Babylonia',
  CARR_HIST_ASSYRIAN: 'Assyria',
  CARR_HIST_PHOENICIAN: 'Phoenicia',
  CARR_HIST_HITTITE: 'Hittites',
  CARR_HIST_SUMERIAN: 'Sumer',
  CARR_HIST_AKKADIAN: 'Akkadian_Empire',
  CARR_HIST_EGYPT_OK: 'Old_Kingdom_of_Egypt',
  CARR_HIST_EGYPT_MK_NK: 'New_Kingdom_of_Egypt',
  CARR_HIST_NUBIAN_KUSHITE: 'Kingdom_of_Kush',
  CARR_HIST_VIKING: 'Vikings',
  CARR_HIST_GERMANIC: 'Germanic_peoples',
  CARR_HIST_CELTIC: 'Celts',
  CARR_HIST_SCYTHIAN: 'Scythians',
  CARR_HIST_TURKIC_GOKTURK: 'Turkic_Khaganate',
  CARR_HIST_RASHIDUN_UMAYYAD: 'Umayyad_Caliphate',
  CARR_HIST_SOGDIAN: 'Sogdia',
  CARR_HIST_MODERN_ARAB: 'Arabs',

  // Gap-filler carriers (013 seed)
  CARR_HIST_GAP_MOCHE: 'Moche_culture',
  CARR_HIST_GAP_NAZCA: 'Nazca_culture',
  CARR_HIST_GAP_WARI: 'Wari_Empire',
  CARR_HIST_GAP_TIWANAKU: 'Tiwanaku',
  CARR_HIST_GAP_MARAJOARA: 'Marajoara_culture',
  CARR_HIST_GAP_MAPUCHE: 'Mapuche',
  CARR_HIST_GAP_TEOTIHUACAN: 'Teotihuacan',
  CARR_HIST_GAP_ZAPOTEC: 'Zapotec_civilization',
  CARR_HIST_GAP_MIXTEC: 'Mixtec',
  CARR_HIST_GAP_TOLTEC: 'Toltec',
  CARR_HIST_GAP_PUREPECHA: 'Tarascan_state',
  CARR_HIST_GAP_TAINO: 'Ta%C3%ADno',
  CARR_HIST_GAP_BANTU_EXPANSION: 'Bantu_expansion',
  CARR_HIST_GAP_GHANA_EMPIRE: 'Ghana_Empire',
  CARR_HIST_GAP_MALI_EMPIRE: 'Mali_Empire',
  CARR_HIST_GAP_SONGHAI: 'Songhai_Empire',
  CARR_HIST_GAP_GREAT_ZIMBABWE: 'Great_Zimbabwe',
  CARR_HIST_GAP_KONGO: 'Kingdom_of_Kongo',
  CARR_HIST_GAP_SWAHILI_COAST: 'Swahili_culture',
  CARR_HIST_GAP_ASANTE: 'Ashanti_Empire',
  CARR_HIST_GAP_ETHIOPIAN_HIGHLAND: 'Solomonic_dynasty',
  CARR_HIST_GAP_LAPITA: 'Lapita_culture',
  CARR_HIST_GAP_POLYNESIAN_EXP: 'Polynesians',
  CARR_HIST_GAP_MAORI: 'M%C4%81ori_people',
  CARR_HIST_GAP_HAWAIIAN: 'Native_Hawaiians',
  CARR_HIST_GAP_YAKUT: 'Yakuts',
  CARR_HIST_GAP_CHUKCHI: 'Chukchi_people',
  CARR_HIST_GAP_THULE_INUIT: 'Thule_people',
  CARR_HIST_GAP_MISSISSIPPIAN: 'Mississippian_culture',
  CARR_HIST_GAP_NAVAJO_APACHE: 'Athabaskan_languages',
  CARR_HIST_GAP_HAUDENOSAUNEE: 'Iroquois',
}

export interface WikipediaSummary {
  title: string
  extract?: string
  thumbnail?: { source: string; width: number; height: number }
  /** Direct Wikipedia URL — used for the "from Wikipedia" attribution link. */
  contentUrl?: string
}

const CACHE = new Map<string, Promise<WikipediaSummary | null>>()

/** Encode a Wikipedia title for the REST URL — preserves the canonical form
 * (don't double-encode entries that are already URL-encoded in the map). */
function urlForTitle(title: string): string {
  // If the title already contains percent-escapes, trust it as encoded.
  if (/%[0-9A-Fa-f]{2}/.test(title)) {
    return `https://en.wikipedia.org/api/rest_v1/page/summary/${title}`
  }
  return `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`
}

export async function fetchCarrierImage(
  carrierId: string,
  displayName: string,
): Promise<WikipediaSummary | null> {
  const explicit = CARRIER_WIKIPEDIA_TITLES[carrierId]
  // Fallback to the display_name with spaces → underscores so it lines up
  // with how Wikipedia titles are spelled.
  const fallback = displayName.replace(/\s+/g, '_')
  const title = explicit ?? fallback
  const cacheKey = title
  const cached = CACHE.get(cacheKey)
  if (cached) return cached

  const p = (async () => {
    try {
      const res = await fetch(urlForTitle(title), {
        headers: { Accept: 'application/json' },
      })
      if (!res.ok) return null
      const data = await res.json()
      if (!data?.thumbnail?.source) {
        // No thumbnail attached to the page — treat as a miss.
        return null
      }
      return {
        title: data.title ?? title,
        extract: data.extract,
        thumbnail: data.thumbnail,
        contentUrl: data.content_urls?.desktop?.page,
      } as WikipediaSummary
    } catch {
      return null
    }
  })()

  CACHE.set(cacheKey, p)
  return p
}
