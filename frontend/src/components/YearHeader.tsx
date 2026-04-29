/**
 * YearHeader — a big, glanceable "where am I in time?" indicator that
 * sits at the top-center of the map. The slider at the bottom is fast
 * for scrubbing but small for reading; this header makes the year and
 * era unmistakable without taking up real estate.
 *
 * Era buckets are rough — chosen to give a useful chunked context
 * ("Mesolithic", "Iron Age", "Industrial") rather than precise
 * archaeological boundaries.
 */
function formatYear(y: number): string {
  if (y < -10000) return `${(Math.abs(y) / 1000).toFixed(0)} kya`
  if (y < 0) return `${Math.abs(y).toLocaleString()} BCE`
  return `${y} CE`
}

function era(y: number): string {
  if (y < -3_000_000) return 'Pliocene hominin radiation'
  if (y < -300_000) return 'Lower / Middle Paleolithic'
  if (y < -50_000) return 'Late Middle Paleolithic'
  if (y < -12_000) return 'Upper Paleolithic'
  if (y < -8_000) return 'Mesolithic / Epipaleolithic'
  if (y < -3_000) return 'Neolithic'
  if (y < -1_200) return 'Bronze Age'
  if (y < -500) return 'Iron Age'
  if (y < 500) return 'Classical Antiquity'
  if (y < 1500) return 'Medieval'
  if (y < 1800) return 'Early Modern'
  if (y < 1945) return 'Industrial / Imperial'
  if (y < 2000) return 'Late 20th c.'
  return 'Contemporary'
}

export function YearHeader({ year }: { year: number }) {
  return (
    <div className="bg-gray-900/85 text-white rounded-lg px-4 py-2 shadow-lg border border-gray-700 backdrop-blur-sm text-center">
      <div className="text-2xl font-bold tracking-tight tabular-nums">
        {formatYear(year)}
      </div>
      <div className="text-[10px] uppercase tracking-wide text-gray-400 mt-0.5">
        {era(year)}
      </div>
    </div>
  )
}
