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
/**
 * Picking Wikipedia article titles is a quiet design choice. Articles
 * about empires / dynasties / cultures often lead with a *map* or a
 * coat-of-arms in the infobox, which makes for an unhelpful inspector
 * thumbnail. Where a "<People> people" / "<Foo> language" / "<Bar> art"
 * article exists with a representative *human* image, we prefer it.
 *
 * E.g. "Han_dynasty" → leads with a dynastic-territory map → so we use
 * "Han_Chinese" instead, which leads with a portrait. "Polynesians" →
 * leads with a map of the Polynesian Triangle → so we use "Polynesian_culture"
 * or a more specific "Native_Hawaiians" / "Maori_people" entry.
 */
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
  // Historical empires — prefer "<X> people" articles where they exist
  // and have a portrait / human image in the lead.
  CARR_HIST_ROMAN: 'Romans',                     // "Roman Empire" leads with a map
  CARR_HIST_GREEK: 'Ancient_Greeks',
  CARR_HIST_GREEK_CLASSICAL: 'Ancient_Greeks',
  CARR_HIST_BYZANTINE: 'Byzantine_people',
  CARR_HIST_OTTOMAN: 'Ottomans',                 // people
  CARR_HIST_HAN: 'Han_Chinese',                  // not Han_dynasty (map)
  CARR_HIST_TANG: 'Tang_dynasty',
  CARR_HIST_MONGOL: 'Mongols',
  CARR_HIST_MAYA_CLASSICAL: 'Maya_peoples',      // not Maya_civilization (map)
  CARR_HIST_AZTEC: 'Aztecs',                     // not Aztec_Empire
  CARR_HIST_INCA: 'Inca_people',                 // not Inca_Empire
  CARR_HIST_KHMER: 'Khmer_people',
  CARR_HIST_AKSUMITE: 'Aksumites',
  CARR_HIST_ABBASID: 'Abbasid_Caliphate',
  CARR_HIST_ACHAEMENID: 'Persians',              // people, not "Achaemenid Empire" (map)
  CARR_HIST_SASANIAN: 'Sasanian_people',
  CARR_HIST_BABYLONIAN: 'Babylonians',
  CARR_HIST_ASSYRIAN: 'Assyrian_people',
  CARR_HIST_PHOENICIAN: 'Phoenicians',
  CARR_HIST_HITTITE: 'Hittites',
  CARR_HIST_SUMERIAN: 'Sumer',
  CARR_HIST_AKKADIAN: 'Akkadian_people',
  CARR_HIST_EGYPT_OK: 'Ancient_Egyptians',       // not "Old Kingdom" (map)
  CARR_HIST_EGYPT_MK_NK: 'Ancient_Egyptians',
  CARR_HIST_NUBIAN_KUSHITE: 'Nubians',
  CARR_HIST_VIKING: 'Vikings',
  CARR_HIST_GERMANIC: 'Germanic_peoples',
  CARR_HIST_CELTIC: 'Celts',
  CARR_HIST_SCYTHIAN: 'Scythians',
  CARR_HIST_TURKIC_GOKTURK: 'G%C3%B6kturks',     // people, not "Khaganate"
  CARR_HIST_RASHIDUN_UMAYYAD: 'Arabs',
  CARR_HIST_SOGDIAN: 'Sogdians',                 // people
  CARR_HIST_MODERN_ARAB: 'Arabs',

  // Gap-filler carriers (013 seed) — prefer "people" articles for human imagery
  CARR_HIST_GAP_MOCHE: 'Moche_culture',
  CARR_HIST_GAP_NAZCA: 'Nazca_culture',
  CARR_HIST_GAP_WARI: 'Wari_culture',             // not Wari_Empire (map)
  CARR_HIST_GAP_TIWANAKU: 'Tiwanaku',
  CARR_HIST_GAP_MARAJOARA: 'Marajoara_culture',
  CARR_HIST_GAP_MAPUCHE: 'Mapuche',
  CARR_HIST_GAP_TEOTIHUACAN: 'Teotihuacan',
  CARR_HIST_GAP_ZAPOTEC: 'Zapotec_peoples',       // not Zapotec_civilization (map)
  CARR_HIST_GAP_MIXTEC: 'Mixtec',
  CARR_HIST_GAP_TOLTEC: 'Toltec',
  CARR_HIST_GAP_PUREPECHA: 'Pur%C3%A9pecha',      // people, not Tarascan_state (map)
  CARR_HIST_GAP_TAINO: 'Ta%C3%ADno',
  CARR_HIST_GAP_BANTU_EXPANSION: 'Bantu_peoples', // not Bantu_expansion (map)
  CARR_HIST_GAP_GHANA_EMPIRE: 'Ghana_Empire',
  CARR_HIST_GAP_MALI_EMPIRE: 'Mali_Empire',
  CARR_HIST_GAP_SONGHAI: 'Songhai_people',         // not Songhai_Empire (map)
  CARR_HIST_GAP_GREAT_ZIMBABWE: 'Great_Zimbabwe',
  CARR_HIST_GAP_KONGO: 'Kongo_people',             // not Kingdom_of_Kongo (map)
  CARR_HIST_GAP_SWAHILI_COAST: 'Swahili_people',   // not Swahili_culture
  CARR_HIST_GAP_ASANTE: 'Ashanti_people',          // not Ashanti_Empire (map)
  CARR_HIST_GAP_ETHIOPIAN_HIGHLAND: 'Habesha_peoples',
  CARR_HIST_GAP_LAPITA: 'Lapita_culture',
  CARR_HIST_GAP_POLYNESIAN_EXP: 'Polynesian_culture',
  CARR_HIST_GAP_MAORI: 'M%C4%81ori_people',
  CARR_HIST_GAP_HAWAIIAN: 'Native_Hawaiians',
  CARR_HIST_GAP_YAKUT: 'Yakuts',
  CARR_HIST_GAP_CHUKCHI: 'Chukchi_people',
  CARR_HIST_GAP_THULE_INUIT: 'Inuit',              // Thule_people leads with a map
  CARR_HIST_GAP_MISSISSIPPIAN: 'Mississippian_culture',
  CARR_HIST_GAP_NAVAJO_APACHE: 'Navajo',           // not Athabaskan_languages
  CARR_HIST_GAP_HAUDENOSAUNEE: 'Iroquois',

  // Hominin carriers (added in db/020).
  CARR_HOMININ_HOMO_HABILIS: 'Homo_habilis',
  CARR_HOMININ_AFRICAN_ERECTUS: 'Homo_ergaster',
  CARR_HOMININ_ASIAN_ERECTUS_JAVA: 'Java_Man',
  CARR_HOMININ_ASIAN_ERECTUS_CHINA: 'Peking_Man',
  CARR_HOMININ_ANTECESSOR: 'Homo_antecessor',
  CARR_HOMININ_HEIDELBERGENSIS: 'Homo_heidelbergensis',
  CARR_HOMININ_NALEDI: 'Homo_naledi',
  CARR_HOMININ_RHODESIENSIS: 'Homo_rhodesiensis',
  CARR_HOMININ_FLORESIENSIS: 'Homo_floresiensis',
  CARR_HOMININ_LUZONENSIS: 'Homo_luzonensis',
  CARR_HOMININ_NEANDERTHAL: 'Neanderthal',
  CARR_HOMININ_DENISOVAN: 'Denisovan',
  CARR_HIST_JEBEL_IRHOUD: 'Jebel_Irhoud',
  CARR_HIST_OMO_HERTO: 'Omo_remains',

  // Temporal bridge carriers (db/016).
  CARR_HIST_BRIDGE_LATE_WOODLAND: 'Late_Woodland_period',
  CARR_HIST_BRIDGE_ANASAZI: 'Ancestral_Puebloans',
  CARR_HIST_BRIDGE_HOHOKAM: 'Hohokam',
  CARR_HIST_BRIDGE_FREMONT: 'Fremont_culture',
  CARR_HIST_BRIDGE_CUPISNIQUE: 'Cupisnique_culture',
  CARR_HIST_BRIDGE_PARACAS: 'Paracas_culture',
  CARR_HIST_BRIDGE_AMAZON_FORMATIVE: 'History_of_the_Amazon_basin',
  CARR_HIST_BRIDGE_AFANASIEVO: 'Afanasievo_culture',
  CARR_HIST_BRIDGE_OKUNEV: 'Okunev_culture',
  CARR_HIST_BRIDGE_BOTAI: 'Botai_culture',
  CARR_HIST_BRIDGE_ANDRONOVO: 'Andronovo_culture',
  CARR_HIST_BRIDGE_KARASUK: 'Karasuk_culture',
  CARR_HIST_BRIDGE_TAGAR: 'Tagar_culture',
  CARR_HIST_BRIDGE_COLONIAL_MESO: 'New_Spain',
  CARR_HIST_BRIDGE_GARAMANTES: 'Garamantes',
  CARR_HIST_BRIDGE_ZAGWE: 'Zagwe_dynasty',

  // Post-Columbian / colonial carriers (db/017, db/019).
  CARR_HIST_POST1492_COLONIAL_NA: 'Pilgrims_(Plymouth_Colony)',  // people, not the colonial-history article (which is text-heavy)
  CARR_HIST_POST1492_REPUBLIC_US_WHITE: 'European_Americans',
  CARR_HIST_POST1492_GILDED_AGE_US: 'Immigration_to_the_United_States',
  CARR_HIST_POST1492_AFRICAN_AMERICAN: 'African_Americans',
  CARR_HIST_POST1492_AFRO_CARIBBEAN: 'Afro-Caribbean_people',
  CARR_HIST_POST1492_COLONIAL_BR: 'Bandeirantes',  // people-image article instead of Colonial_Brazil (map)
  CARR_HIST_POST1492_MODERN_BRAZILIAN: 'Brazilians',
  CARR_HIST_POST1492_COLONIAL_ANDEAN: 'Mestizo',
  CARR_HIST_POST1492_COLONIAL_AUS: 'Australians',  // colonial-history article is text-heavy
  CARR_HIST_POST1492_MODERN_AUS: 'Australians',
  CARR_HIST_POST1492_PAKEHA_NZ: 'P%C4%81keh%C4%81',
  CARR_HIST_POST1492_AFRIKANER: 'Afrikaners',
  CARR_HIST_POST1492_MODERN_ISRAELI: 'Israelis',
  CARR_HIST_POST1492_MODERN_USA: 'Americans',
  CARR_HIST_POST1492_MODERN_CANADA: 'Canadians',
  CARR_HIST_POST1492_MODERN_MEXICO: 'Mexicans',
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
