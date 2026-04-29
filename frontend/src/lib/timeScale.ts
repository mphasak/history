/**
 * Shared piecewise-log time-scale helpers.
 *
 * Used by both the YearSlider (the canonical owner of these constants)
 * and any other component that needs to render in the same time scale —
 * notably the AdmixtureTimeline. Without sharing, the two would drift
 * out of alignment and the timeline tick under "1700 CE" wouldn't line
 * up with the slider thumb at the same year.
 *
 * Two regions:
 *   * Sapiens: slider [200, 1000] ↔ year [-300_000, 2026] — 80% of the bar.
 *   * Deep time: slider [0, 200] ↔ year [-10_000_000, -300_000] — 20%.
 */

export const SLIDER_MIN = 0
export const SLIDER_MAX = 1000
export const SAPIENS_BREAK = 200
export const SAPIENS_BREAK_YEAR = -300_000
export const DEEP_TIME_MIN_YEAR = -10_000_000
export const PRESENT_YEAR = 2026

const SAPIENS_LOG_MAX = Math.log10(PRESENT_YEAR - SAPIENS_BREAK_YEAR + 1)
const DEEP_LOG_MAX = Math.log10(PRESENT_YEAR - DEEP_TIME_MIN_YEAR + 1)

/** Slider position [0, 1000] → year. */
export function sliderToYearRaw(s: number): number {
  let logBp: number
  if (s >= SAPIENS_BREAK) {
    const t = (s - SAPIENS_BREAK) / (SLIDER_MAX - SAPIENS_BREAK)
    logBp = (1 - t) * SAPIENS_LOG_MAX
  } else {
    const t = s / SAPIENS_BREAK
    logBp = DEEP_LOG_MAX - t * (DEEP_LOG_MAX - SAPIENS_LOG_MAX)
  }
  const bp = Math.pow(10, logBp) - 1
  return PRESENT_YEAR - bp
}

export function sliderToYear(s: number): number {
  const raw = sliderToYearRaw(s)
  let y = Math.round(raw)
  if (y === 0) y = raw >= 0 ? 1 : -1
  return y
}

/** Year → slider position [0, 1000]. */
export function yearToSliderPos(year: number): number {
  const bp = Math.max(0, PRESENT_YEAR - year)
  const logBp = Math.log10(bp + 1)
  if (logBp <= SAPIENS_LOG_MAX) {
    const t = logBp / SAPIENS_LOG_MAX
    return Math.round(SLIDER_MAX - t * (SLIDER_MAX - SAPIENS_BREAK))
  } else {
    const t = (DEEP_LOG_MAX - logBp) / (DEEP_LOG_MAX - SAPIENS_LOG_MAX)
    return Math.round(t * SAPIENS_BREAK)
  }
}

/** Year → fractional position [0, 1] along the slider/timeline. */
export function yearToFraction(year: number): number {
  return yearToSliderPos(year) / SLIDER_MAX
}

export function formatYear(year: number): string {
  const bp = PRESENT_YEAR - year
  if (bp >= 1_000_000) return `${(bp / 1_000_000).toFixed(2)} Mya`
  if (bp >= 10_000) return `${Math.round(bp / 1000).toLocaleString()} kya`
  if (year < 0) return `${Math.abs(year).toLocaleString()} BCE`
  return `${year.toLocaleString()} CE`
}
