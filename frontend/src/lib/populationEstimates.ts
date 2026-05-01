/**
 * Hand-curated peak-population estimates (in individuals) for the
 * carriers that show up in the AdmixtureAtlas. Used to scale bar
 * height in the atlas so tiny island bands (Floresiensis ~5,000) read
 * thin and continent-scale modern populations (Han Chinese ~1.4 B)
 * read thick.
 *
 * Numbers are intentionally rough, often order-of-magnitude. Sources
 * are a mix of paleo-demographic estimates from the literature
 * (Roman / Han / Aztec / Inca peak populations are reasonably
 * documented; Pleistocene foragers are guesses bounded by carrying-
 * capacity arguments). Treat as "what scale of bar should this
 * carrier render at?" not "how many people lived here."
 *
 * Carriers without an entry default to MIN_POP and render as the
 * thinnest bars — which is the correct visual for "unknown / very
 * small."
 */
export const POPULATION_ESTIMATES: Record<string, number> = {
  // ── Hominins ────────────────────────────────────────────
  CARR_HOMININ_HOMO_HABILIS:        20_000,
  CARR_HOMININ_AFRICAN_ERECTUS:    100_000,
  CARR_HOMININ_ASIAN_ERECTUS_JAVA:  50_000,
  CARR_HOMININ_ASIAN_ERECTUS_CHINA: 50_000,
  CARR_HOMININ_ANTECESSOR:          10_000,
  CARR_HOMININ_HEIDELBERGENSIS:    200_000,
  CARR_HOMININ_NALEDI:               5_000,
  CARR_HOMININ_RHODESIENSIS:        50_000,
  CARR_HOMININ_FLORESIENSIS:         5_000,
  CARR_HOMININ_LUZONENSIS:           5_000,
  CARR_HOMININ_NEANDERTHAL:         70_000,
  CARR_HOMININ_DENISOVAN:           50_000,

  // ── Earliest sapiens ────────────────────────────────────
  CARR_HIST_JEBEL_IRHOUD:            5_000,
  CARR_HIST_OMO_HERTO:              10_000,
  CARR_HIST_KHOE_SAN_ANCESTRAL:    100_000,
  CARR_HIST_AFR_EARLY_OOA_SOURCE:   10_000,
  CARR_OOA_LEVANT_55K:               2_000,

  // ── Upper-Paleolithic / Mesolithic ──────────────────────
  CARR_AUS_ABORIGINAL:             750_000,
  CARR_PAPUAN_45K:                 300_000,
  CARR_HIST_ANDAMANESE:              5_000,
  CARR_TIANYUAN_40K:                 5_000,
  CARR_AURIGNACIAN_EU:              30_000,
  CARR_GRAVETTIAN_EU:               30_000,
  CARR_MALTA_24K:                    1_000,
  CARR_PALEO_AMER_15K:              50_000,
  CARR_NATUFIAN_12K:                30_000,
  CARR_HIST_NATUFIAN_12K:           30_000,
  CARR_WHG_MESO:                    50_000,
  CARR_EHG_MESO:                    30_000,
  CARR_CHG_MESO:                    20_000,

  // ── Neolithic ───────────────────────────────────────────
  CARR_ANATOLIAN_FARMER:           500_000,
  CARR_IRAN_NEOLITHIC:             200_000,
  CARR_HIST_HOL_MEHRGARH:          100_000,
  CARR_HARAPPAN:                 5_000_000,
  CARR_HIST_HOL_PREDYNASTIC_EGYPT:  500_000,
  CARR_HIST_HOL_C_GROUP_NUBIAN:    100_000,
  CARR_HIST_HOL_NOK:               300_000,
  CARR_HIST_HOL_KINTAMPO:          100_000,
  CARR_HIST_HOL_CARDIAL:           500_000,
  CARR_HIST_HOL_VINCA:             300_000,
  CARR_HIST_HOL_FUNNELBEAKER:      500_000,
  CARR_HIST_HOL_CUCUTENI_TRYP:   1_000_000,
  CARR_HIST_HOL_HONGSHAN:          100_000,
  CARR_HIST_HOL_LONGSHAN:        1_000_000,
  CARR_HIST_HOL_LIANGZHU:        1_000_000,
  CARR_HIST_HOL_HEMUDU:            100_000,
  CARR_HIST_HOL_YANGSHAO:        2_000_000,

  // ── Bronze Age ──────────────────────────────────────────
  CARR_YAMNAYA:                    100_000,
  CARR_HIST_BRIDGE_AFANASIEVO:      30_000,
  CARR_HIST_BRIDGE_BOTAI:           30_000,
  CARR_HIST_BRIDGE_OKUNEV:          30_000,
  CARR_HIST_BRIDGE_ANDRONOVO:    1_000_000,
  CARR_HIST_BRIDGE_KARASUK:        100_000,
  CARR_HIST_BRIDGE_TAGAR:          100_000,
  CARR_CORDED_WARE:                500_000,
  CARR_BELL_BEAKER:              1_000_000,
  CARR_NW_SOUTH_ASIA_LATE_BRONZE: 2_000_000,
  CARR_HIST_VEDIC_ARYAN:         5_000_000,
  CARR_HIST_HITTITE:             1_500_000,
  CARR_HIST_BRIDGE_CUPISNIQUE:     100_000,
  CARR_HIST_BRIDGE_PARACAS:        100_000,
  CARR_HIST_HOL_OLMEC:             200_000,
  CARR_HIST_HOL_NORTE_CHICO:        50_000,

  // ── Iron Age / Classical ────────────────────────────────
  CARR_HIST_SUMERIAN:            1_000_000,
  CARR_HIST_AKKADIAN:            1_000_000,
  CARR_HIST_BABYLONIAN:          2_000_000,
  CARR_HIST_ASSYRIAN:            5_000_000,
  CARR_HIST_PHOENICIAN:          1_000_000,
  CARR_HIST_EGYPT_OK:            2_000_000,
  CARR_HIST_EGYPT_MK_NK:         3_000_000,
  CARR_HIST_NUBIAN_KUSHITE:        500_000,
  CARR_HIST_AKSUMITE:            1_000_000,
  CARR_HIST_GREEK_CLASSICAL:     3_000_000,
  CARR_HIST_GREEK:               3_000_000,
  CARR_HIST_ROMAN:              70_000_000,
  CARR_HIST_BYZANTINE:          25_000_000,
  CARR_HIST_CELTS:               5_000_000,
  CARR_HIST_GERMANIC_IRON_AGE:   3_000_000,
  CARR_HIST_SCYTHIAN:            1_000_000,
  CARR_HIST_ACHAEMENID:         50_000_000,
  CARR_HIST_PARTHIAN:           20_000_000,
  CARR_HIST_SASANIAN:           25_000_000,
  CARR_HIST_HAN_CHINESE_EMPIRE: 60_000_000,
  CARR_HIST_TANG:               80_000_000,
  CARR_HIST_TANG_CHINESE:       80_000_000,
  CARR_HIST_MAURYAN:            50_000_000,
  CARR_HIST_HOL_CHAVIN:            500_000,
  CARR_HIST_HOL_PRECLASSIC_MAYA: 1_000_000,
  CARR_HIST_HOL_HOPEWELL:           50_000,
  CARR_HIST_HOL_ADENA:              20_000,

  // ── Late Antique / Medieval ─────────────────────────────
  CARR_HIST_RASHIDUN_UMAYYAD:   30_000_000,
  CARR_HIST_ABBASID:            50_000_000,
  CARR_HIST_OTTOMAN:            30_000_000,
  CARR_HIST_TURKIC_GOKTURK:      2_000_000,
  CARR_HIST_SOGDIAN:             1_000_000,
  CARR_HIST_NORSE:               1_000_000,
  CARR_HIST_MONGOL:             10_000_000,
  CARR_HIST_KHMER:               5_000_000,
  CARR_HIST_GAP_GHANA_EMPIRE:    5_000_000,
  CARR_HIST_GAP_MALI_EMPIRE:    20_000_000,
  CARR_HIST_MALI_EMPIRE:        20_000_000,
  CARR_HIST_GAP_SONGHAI:        15_000_000,
  CARR_HIST_GAP_GREAT_ZIMBABWE:  1_000_000,
  CARR_HIST_GAP_KONGO:           5_000_000,
  CARR_HIST_GAP_SWAHILI_COAST:   1_500_000,
  CARR_HIST_GAP_ASANTE:          3_000_000,
  CARR_HIST_GAP_ETHIOPIAN_HIGHLAND: 8_000_000,
  CARR_HIST_BRIDGE_ZAGWE:        4_000_000,
  CARR_HIST_BRIDGE_GARAMANTES:     200_000,
  CARR_HIST_GAP_BANTU_EXPANSION: 5_000_000,
  CARR_BANTU_EXPANSION:          5_000_000,
  CARR_HIST_FOR_KHOISAN_HOL:       300_000,
  CARR_HIST_KHOISAN_MODERN:        200_000,
  CARR_HIST_BERBER:              5_000_000,
  CARR_HIST_GAP_LAPITA:            100_000,
  CARR_HIST_GAP_POLYNESIAN_EXP:    500_000,
  CARR_HIST_LAPITA:                100_000,
  CARR_HIST_GAP_HAWAIIAN:          400_000,
  CARR_HIST_GAP_MAORI:             100_000,
  CARR_HIST_MAORI:                 850_000,
  CARR_HIST_GAP_YAKUT:             450_000,
  CARR_HIST_GAP_CHUKCHI:            16_000,
  CARR_HIST_GAP_THULE_INUIT:        50_000,
  CARR_HIST_GAP_NAVAJO_APACHE:     400_000,
  CARR_HIST_GAP_HAUDENOSAUNEE:     200_000,
  CARR_HIST_GAP_MISSISSIPPIAN:   2_000_000,
  CARR_HIST_MISSISSIPPIAN:       2_000_000,
  CARR_HIST_BRIDGE_MISSISSIPPIAN: 2_000_000,
  CARR_HIST_BRIDGE_LATE_WOODLAND: 1_000_000,
  CARR_HIST_BRIDGE_ANASAZI:        100_000,
  CARR_HIST_BRIDGE_HOHOKAM:         50_000,
  CARR_HIST_BRIDGE_FREMONT:         30_000,
  CARR_HIST_GAP_TEOTIHUACAN:     1_000_000,
  CARR_HIST_GAP_ZAPOTEC:         1_000_000,
  CARR_HIST_GAP_MIXTEC:            500_000,
  CARR_HIST_GAP_TOLTEC:          1_000_000,
  CARR_HIST_GAP_PUREPECHA:       1_500_000,
  CARR_HIST_GAP_TAINO:           1_500_000,
  CARR_HIST_GAP_MOCHE:             500_000,
  CARR_HIST_GAP_NAZCA:             100_000,
  CARR_HIST_GAP_WARI:            1_500_000,
  CARR_HIST_GAP_TIWANAKU:        1_000_000,
  CARR_HIST_GAP_MARAJOARA:         300_000,
  CARR_HIST_GAP_MAPUCHE:         1_000_000,
  CARR_HIST_AZTEC:               6_000_000,
  CARR_HIST_INCA:               12_000_000,
  CARR_HIST_MAYA_CLASSICAL:      2_000_000,

  // ── Early-modern / globalization era ────────────────────
  CARR_HIST_MUGHAL_N_INDIAN:   150_000_000,
  CARR_HIST_BRIDGE_COLONIAL_MESO: 7_000_000,
  CARR_HIST_POST1492_COLONIAL_NA: 2_000_000,
  CARR_HIST_POST1492_REPUBLIC_US_WHITE: 60_000_000,
  CARR_HIST_POST1492_GILDED_AGE_US: 100_000_000,
  CARR_HIST_POST1492_AFRICAN_AMERICAN: 47_000_000,
  CARR_HIST_POST1492_AFRO_CARIBBEAN: 20_000_000,
  CARR_HIST_POST1492_COLONIAL_BR:  3_000_000,
  CARR_HIST_POST1492_MODERN_BRAZILIAN: 220_000_000,
  CARR_HIST_POST1492_COLONIAL_ANDEAN: 5_000_000,
  CARR_HIST_POST1492_COLONIAL_AUS:  4_000_000,
  CARR_HIST_POST1492_MODERN_AUS: 26_000_000,
  CARR_HIST_POST1492_PAKEHA_NZ:  3_500_000,
  CARR_HIST_POST1492_AFRIKANER:  2_700_000,
  CARR_HIST_POST1492_MODERN_ISRAELI: 9_000_000,
  CARR_HIST_POST1492_MODERN_USA: 330_000_000,
  CARR_HIST_POST1492_MODERN_CANADA: 39_000_000,
  CARR_HIST_POST1492_MODERN_MEXICO: 130_000_000,
  CARR_HIST_MODERN_EUROPEAN:   750_000_000,
  CARR_HIST_MODERN_HAN:      1_400_000_000,
  CARR_HIST_MODERN_E_ASIAN:  1_700_000_000,
  CARR_HIST_MODERN_S_ASIAN:  1_900_000_000,
  CARR_HIST_MODERN_SE_ASIAN:   650_000_000,
  CARR_HIST_MODERN_W_AFRICAN:  400_000_000,
  CARR_HIST_MODERN_E_AFRICAN:  450_000_000,
  CARR_HIST_MODERN_ARAB:       450_000_000,
  CARR_HIST_MODERN_NATIVE_AMER:  6_500_000,
  CARR_HIST_MODERN_LATIN_AMER_MESTIZO: 450_000_000,
  CARR_RURAL_SOUTH_US_2025:     50_000_000,
  CARR_SF_BAY_AREA_2025:         8_000_000,
}

// Log-scale bar height. Sets the visual span — we want the difference
// between 1,000 (founder bottlenecks) and 1,500,000,000 (modern Han)
// to *show* without making the small bands invisible.
const MIN_POP = 1_000
const MAX_POP = 2_000_000_000
const MIN_BAR_H = 3
const MAX_BAR_H = 22

const LOG_RANGE = Math.log10(MAX_POP) - Math.log10(MIN_POP)

/**
 * Bar height in pixels for a carrier, log-scaled by population
 * estimate. Carriers without an entry default to MIN_BAR_H (the visual
 * equivalent of "small / unknown population, render as a thin line").
 */
export function barHeightForCarrier(carrierId: string): number {
  const pop = POPULATION_ESTIMATES[carrierId]
  if (!pop || pop <= MIN_POP) return MIN_BAR_H
  const t = (Math.log10(Math.min(pop, MAX_POP)) - Math.log10(MIN_POP)) / LOG_RANGE
  return MIN_BAR_H + (MAX_BAR_H - MIN_BAR_H) * t
}

/** Pretty-format population for tooltips: "5 M", "12,000", "1.4 B". */
export function formatPopulation(pop: number | undefined): string {
  if (pop == null) return '—'
  if (pop >= 1_000_000_000) return `${(pop / 1_000_000_000).toFixed(1)} B`
  if (pop >= 1_000_000) return `${(pop / 1_000_000).toFixed(0)} M`
  if (pop >= 1_000) return `${(pop / 1_000).toFixed(0)} K`
  return pop.toLocaleString()
}
