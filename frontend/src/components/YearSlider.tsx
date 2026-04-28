import { useCallback, useMemo } from 'react'
import { useStore } from '../state'

// Aggressive piecewise-log scaling.
//
// The slider has two regions:
//   - Sapiens region: slider [200, 1000] ↔ year [-300_000, 2025] — gets 80% of the bar.
//   - Deep-time region: slider [0, 200] ↔ year [-10_000_000, -300_000] — gets 20%.
//
// Both regions are log-scaled in years-before-present, so recent history takes
// proportionally more space than antiquity.

const SLIDER_MIN = 0
const SLIDER_MAX = 1000
const SAPIENS_BREAK = 200 // slider position where deep-time ends and sapiens begins
const SAPIENS_BREAK_YEAR = -300_000
const DEEP_TIME_MIN_YEAR = -10_000_000
const PRESENT_YEAR = 2025

const SAPIENS_LOG_MAX = Math.log10(PRESENT_YEAR - SAPIENS_BREAK_YEAR + 1) // ≈ 5.48
const DEEP_LOG_MAX = Math.log10(PRESENT_YEAR - DEEP_TIME_MIN_YEAR + 1) // ≈ 7.0

function sliderToYearRaw(s: number): number {
  let logBp: number
  if (s >= SAPIENS_BREAK) {
    // Sapiens: as s goes from SAPIENS_BREAK → SLIDER_MAX, logBp goes SAPIENS_LOG_MAX → 0
    const t = (s - SAPIENS_BREAK) / (SLIDER_MAX - SAPIENS_BREAK)
    logBp = (1 - t) * SAPIENS_LOG_MAX
  } else {
    // Deep time: as s goes from 0 → SAPIENS_BREAK, logBp goes DEEP_LOG_MAX → SAPIENS_LOG_MAX
    const t = s / SAPIENS_BREAK
    logBp = DEEP_LOG_MAX - t * (DEEP_LOG_MAX - SAPIENS_LOG_MAX)
  }
  const bp = Math.pow(10, logBp) - 1
  return PRESENT_YEAR - bp
}

function sliderToYear(s: number): number {
  const raw = sliderToYearRaw(s)
  let y = Math.round(raw)
  // Skip year 0 (no year 0 in the system) — snap to the side the unrounded value was on
  if (y === 0) y = raw >= 0 ? 1 : -1
  return y
}

function yearToSliderPos(year: number): number {
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

function formatYear(year: number): string {
  const bp = PRESENT_YEAR - year
  if (bp >= 1_000_000) return `${(bp / 1_000_000).toFixed(2)} Mya`
  if (bp >= 10_000) return `${Math.round(bp / 1000).toLocaleString()} kya`
  if (year < 0) return `${Math.abs(year).toLocaleString()} BCE`
  return `${year.toLocaleString()} CE`
}

interface EpochMarker {
  year: number
  label: string
}

const EPOCH_MARKERS: EpochMarker[] = [
  { year: -10_000_000, label: '10 Mya' },
  { year: -3_000_000, label: '3 Mya' },
  { year: -1_000_000, label: '1 Mya' },
  { year: -300_000, label: 'sapiens' },
  { year: -70_000, label: '70 kya' },
  { year: -12_000, label: 'Holocene' },
  { year: -3000, label: '3000 BCE' },
  { year: 1, label: '1 CE' },
  { year: 2025, label: 'now' },
]

export function YearSlider() {
  const year = useStore((s) => s.year)
  const setYear = useStore((s) => s.setYear)

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      setYear(sliderToYear(parseInt(e.target.value, 10)))
    },
    [setYear]
  )

  const sliderPos = yearToSliderPos(year)

  const markerPositions = useMemo(
    () =>
      EPOCH_MARKERS.map((m) => ({
        ...m,
        leftPct: (yearToSliderPos(m.year) / SLIDER_MAX) * 100,
      })),
    []
  )

  return (
    <div className="px-4 pt-2 pb-3 bg-gray-900 text-white">
      <div className="flex items-center gap-3">
        <span className="text-xs text-gray-400 w-16 text-right shrink-0">10 Mya</span>
        <div className="flex-1 relative">
          <input
            type="range"
            min={SLIDER_MIN}
            max={SLIDER_MAX}
            value={sliderPos}
            onChange={handleChange}
            className="w-full accent-blue-400"
            aria-label="Year slider"
          />
          {/* Sapiens / deep-time boundary */}
          <div
            className="absolute top-1/2 -translate-y-1/2 h-3 w-px bg-amber-400/70 pointer-events-none"
            style={{ left: `${(SAPIENS_BREAK / SLIDER_MAX) * 100}%` }}
            title="Sapiens emergence (~300 kya) — deep-time / sapiens boundary"
          />
        </div>
        <span className="text-xs text-gray-400 w-12 shrink-0">2025 CE</span>
        <span className="font-mono font-bold text-blue-300 text-sm w-24 shrink-0 text-right">
          {formatYear(year)}
        </span>
      </div>
      {/* Epoch markers */}
      <div className="relative mx-[4.5rem] mt-1 h-4 select-none">
        {markerPositions.map((m) => (
          <button
            key={m.year}
            type="button"
            onClick={() => setYear(m.year === 0 ? 1 : m.year)}
            className="absolute top-0 -translate-x-1/2 text-[10px] text-gray-500 hover:text-blue-300 transition-colors whitespace-nowrap"
            style={{ left: `${m.leftPct}%` }}
            title={`Jump to ${m.label}`}
          >
            <span className="block text-center leading-none">|</span>
            <span className="block">{m.label}</span>
          </button>
        ))}
      </div>
    </div>
  )
}
