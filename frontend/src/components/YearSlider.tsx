import { useCallback } from 'react'
import { scaleSymlog } from 'd3-scale'
import { useStore } from '../state'

// Map slider integer positions [0, 1000] to years [-70000, 2025]
const SLIDER_MIN = 0
const SLIDER_MAX = 1000

const yearToSlider = scaleSymlog<number>()
  .domain([-70000, 2025])
  .range([SLIDER_MIN, SLIDER_MAX])
  .constant(1)

const sliderToYear = (pos: number): number =>
  Math.round(yearToSlider.invert(pos))

const yearToSliderPos = (year: number): number =>
  Math.round(yearToSlider(year))

function formatYear(year: number): string {
  if (year === 0) return '1 CE'
  if (year < 0) return `${Math.abs(year).toLocaleString()} BCE`
  return `${year.toLocaleString()} CE`
}

export function YearSlider() {
  const year = useStore((s) => s.year)
  const setYear = useStore((s) => s.setYear)

  const handleChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const pos = parseInt(e.target.value, 10)
      let y = sliderToYear(pos)
      // Skip year 0 (no year 0 in the system)
      if (y === 0) y = pos > 500 ? 1 : -1
      setYear(y)
    },
    [setYear]
  )

  const sliderPos = yearToSliderPos(year)

  return (
    <div className="flex items-center gap-3 px-4 py-2 bg-gray-900 text-white">
      <span className="text-xs text-gray-400 w-20 text-right shrink-0">70,000 BCE</span>
      <input
        type="range"
        min={SLIDER_MIN}
        max={SLIDER_MAX}
        value={sliderPos}
        onChange={handleChange}
        className="flex-1 accent-blue-400"
        aria-label="Year slider"
      />
      <span className="text-xs text-gray-400 w-16 shrink-0">2025 CE</span>
      <span className="font-mono font-bold text-blue-300 text-sm w-32 shrink-0">
        {formatYear(year)}
      </span>
    </div>
  )
}
