import { useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent, type PointerEvent as ReactPointerEvent, type ReactNode, type RefObject } from 'react'
import { createPortal } from 'react-dom'
import { cx } from './cx'
import './charts.css'

/** One column: `label` names it in the tooltip and the table, `short` under the axis; `guide` draws a divider before it. */
export type ColumnDatum = {
  key: string
  label: string
  short: string
  value: number
  /** A muted line under the label in the tooltip, e.g. "up to 13 Oct" for a month still running. */
  detail?: string
  /** A vertical guide before this column, with this text at its top (e.g. "Q2 2026"). */
  guide?: string
}

const H = 240
const M = { top: 24, right: 8, bottom: 24, left: 56 }
const LABEL_GAP = 44 // the least room an axis label needs, in px
const GUIDE_GAP = 64 // the least room between two guide labels, in px

/** Round tick values for a range: 1, 2, 2.5 or 5 times a power of ten, about `count` of them, always including 0. */
function ticks(lo: number, hi: number, count: number) {
  const span = hi - lo || Math.abs(hi) || 1
  const raw = span / count
  const pow = 10 ** Math.floor(Math.log10(raw))
  const step = [1, 2, 2.5, 5, 10].map((f) => f * pow).find((s) => s >= raw) ?? 10 * pow
  const out: number[] = []
  for (let v = Math.floor(lo / step) * step; v <= hi + step * 1e-9; v += step) out.push(Math.round(v / step) * step)
  return out
}

/** A column with a 4px rounded data end and a square end on the zero line, up or down. */
function columnPath(x: number, w: number, y0: number, h: number, up: boolean) {
  const r = Math.min(4, h, w / 2)
  return up
    ? `M${x},${y0}V${y0 - h + r}a${r},${r} 0 0 1 ${r},${-r}H${x + w - r}a${r},${r} 0 0 1 ${r},${r}V${y0}z`
    : `M${x},${y0}V${y0 + h - r}a${r},${r} 0 0 0 ${r},${r}H${x + w - r}a${r},${r} 0 0 0 ${r},${-r}V${y0}z`
}

/** What both charts share: the measured width, the active mark, the roving focus stop and the tooltip placement. */
function useChartFrame(n: number) {
  const wrap = useRef<HTMLDivElement>(null)
  const tip = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(0)
  const [active, setActive] = useState<number | null>(null)
  const [focusStop, setFocusIndex] = useState(0)
  const [at, setAt] = useState<{ x: number; y: number } | null>(null)

  useLayoutEffect(() => {
    const el = wrap.current
    if (!el) return
    const ro = new ResizeObserver(([entry]) => setWidth(Math.floor(entry.contentRect.width)))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Place the tooltip next to the point it belongs to, inside the viewport.
  useLayoutEffect(() => {
    const t = tip.current
    if (!t || active === null || !at) return
    t.style.left = `${Math.max(8, Math.min(at.x + 14, window.innerWidth - t.offsetWidth - 8))}px`
    t.style.top = `${Math.max(8, Math.min(at.y + 14, window.innerHeight - t.offsetHeight - 8))}px`
  }, [active, at])

  useEffect(() => {
    if (active === null) return
    const hide = () => setActive(null)
    window.addEventListener('scroll', hide, true)
    return () => window.removeEventListener('scroll', hide, true)
  }, [active])

  const show = (i: number, point: { x: number; y: number }) => {
    setActive(i)
    setAt(point)
  }
  // Clamped, so a shrinking data set never leaves the chart without its one tab stop.
  const focusIndex = Math.min(focusStop, Math.max(0, n - 1))
  return { wrap, tip, width, active, setActive, focusIndex, setFocusIndex, show }
}

/** The guide lines of a chart, each with its text only where it clears the previous text by GUIDE_GAP and fits in `width`. */
function thinGuides(items: readonly { key: string; guide?: string }[], band: number, width: number) {
  let lastGuideX = -Infinity
  return items.flatMap((d, i) => {
    if (!d.guide || i === 0) return []
    const x = M.left + band * i
    const showText = x - lastGuideX >= GUIDE_GAP && x + GUIDE_GAP / 2 <= width
    if (showText) lastGuideX = x
    return [{ key: d.key, x, text: showText ? d.guide : null }]
  })
}

/** The roving-stop key handler of a chart: `prev`/`next` (arrows), Home and End move the focus over the .bar hit areas, Escape hides the tooltip. */
function rovingKeys(
  frame: Pick<ReturnType<typeof useChartFrame>, 'wrap' | 'focusIndex' | 'setFocusIndex' | 'setActive'>,
  n: number,
  prev: string,
  next: string,
) {
  const { wrap, focusIndex, setFocusIndex, setActive } = frame
  return (e: KeyboardEvent<SVGSVGElement>) => {
    const to = { [next]: focusIndex + 1, [prev]: focusIndex - 1, Home: 0, End: n - 1 }[e.key]
    if (e.key === 'Escape') return setActive(null)
    if (to === undefined) return
    e.preventDefault()
    const i = Math.max(0, Math.min(n - 1, to))
    setFocusIndex(i)
    wrap.current?.querySelectorAll<SVGRectElement>('.bar')[i]?.focus()
  }
}

/** A chart tooltip follows the pointer, so it stays click-through: shown inline, never .tooltip--open. */
function ChartTip({ tipRef, children }: { tipRef: RefObject<HTMLDivElement | null>; children: ReactNode }) {
  return createPortal(
    <div ref={tipRef} className="tooltip" style={{ display: 'block' }} aria-hidden="true">
      {children}
    </div>,
    document.body,
  )
}

/** The figures as a table in a house .more disclosure, so they are always reachable. */
function ChartTable({ summary, caption, headings, children }: { summary: string; caption: string; headings: string[]; children: ReactNode }) {
  return (
    <details className="more">
      <summary>{summary}</summary>
      <div className="table-wrap">
        <table className="table">
          <caption className="sr-only">{caption}</caption>
          <thead>
            <tr>
              {headings.map((h) => (
                <th key={h} scope="col">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>{children}</tbody>
        </table>
      </div>
    </details>
  )
}

/**
 * ColumnChart -- a result per period around a zero line, on the house .chart: gain columns up in --positive-3, loss columns
 * down in --negative-3, so direction reads from position as well as colour. It draws at the width it is given, so its 12px
 * labels stay 12px on a phone, and thins the axis labels to what fits. Hover or keyboard focus shows the house
 * .tooltip with the value; the columns are one tab stop, and the arrow keys, Home and End move through them. The same
 * figures are always reachable as a table under the chart. Put a Legend (gain, loss) above it.
 */
export function ColumnChart({
  label,
  data,
  format,
  tableLabel = 'Show as table',
  periodHeading = 'Period',
  valueHeading = 'Result',
}: {
  /** Names the chart for a screen reader and the table, e.g. "Result per month". */
  label: string
  data: readonly ColumnDatum[]
  format: (v: number) => string
  tableLabel?: string
  periodHeading?: string
  valueHeading?: string
}) {
  const frame = useChartFrame(data.length)
  const { wrap, tip, width, active, setActive, focusIndex, setFocusIndex, show } = frame

  const pw = Math.max(0, width - M.left - M.right)
  const ph = H - M.top - M.bottom
  const values = data.map((d) => d.value)
  const lo = Math.min(0, ...values)
  const hi = Math.max(0, ...values)
  const tk = ticks(lo, hi, 4)
  const yMin = Math.min(lo, tk[0])
  const yMax = Math.max(hi, tk[tk.length - 1])
  const y = (v: number) => M.top + ((yMax - v) / (yMax - yMin || 1)) * ph
  const y0 = y(0)
  const band = data.length ? pw / data.length : 0
  const bw = Math.max(2, Math.min(24, band - 2)) // at least a 2px gap between columns
  const every = Math.max(1, Math.ceil(LABEL_GAP / (band || 1)))

  const guides = thinGuides(data, band, width)

  const showAtColumn = (i: number) => {
    const svg = wrap.current?.querySelector('svg')
    if (!svg) return
    const b = svg.getBoundingClientRect()
    show(i, { x: b.left + M.left + band * (i + 0.5), y: b.top + Math.min(y(data[i].value), y0) - 8 })
  }
  const onKey = rovingKeys(frame, data.length, 'ArrowLeft', 'ArrowRight')

  const d = active === null ? null : data[active]
  return (
    <div className="dkj-chart">
      <div ref={wrap} className="chart">
        {width > 0 && (
          <svg width={width} height={H} viewBox={`0 0 ${width} ${H}`} role="group" aria-label={label} onKeyDown={onKey}>
            {tk.map((v) => (
              <g key={v}>
                <line x1={M.left} x2={M.left + pw} y1={y(v)} y2={y(v)} stroke={v === 0 ? 'var(--primary-9)' : 'var(--primary-4)'} strokeWidth={1} />
                <text x={M.left - 8} y={y(v) + 4} textAnchor="end">
                  {format(v)}
                </text>
              </g>
            ))}
            {guides.map((g) => (
              <g key={g.key}>
                <line x1={g.x} x2={g.x} y1={M.top} y2={M.top + ph} stroke="var(--primary-4)" strokeWidth={1} />
                {g.text && (
                  <text className="axis-note" x={g.x + 4} y={M.top - 8}>
                    {g.text}
                  </text>
                )}
              </g>
            ))}
            {data.map((c, i) => {
              const up = c.value >= 0
              const h = Math.max(Math.abs(y(c.value) - y0), 1)
              const cx0 = M.left + band * i + band / 2
              return (
                <path
                  key={c.key}
                  className={cx('dkj-chart-col', active === i && 'dkj-chart-col--active')}
                  d={columnPath(cx0 - bw / 2, bw, y0, h, up)}
                  fill={up ? 'var(--positive-3)' : 'var(--negative-3)'}
                  aria-hidden="true"
                />
              )
            })}
            {data.map((c, i) =>
              i % every === 0 ? (
                <text key={c.key} x={M.left + band * i + band / 2} y={H - 8} textAnchor="middle">
                  {c.short}
                </text>
              ) : null,
            )}
            {/* The hit areas: the full band, taller than the column, and the keyboard stops (one tab stop, arrows move). */}
            {data.map((c, i) => (
              <rect
                key={c.key}
                className="bar"
                x={M.left + band * i}
                y={M.top}
                width={band}
                height={ph}
                fill="transparent"
                role="img"
                aria-label={`${c.label}${c.detail ? ` (${c.detail})` : ''}: ${format(c.value)}`}
                tabIndex={i === focusIndex ? 0 : -1}
                onPointerMove={(e: ReactPointerEvent) => show(i, { x: e.clientX, y: e.clientY })}
                onPointerLeave={() => setActive(null)}
                onFocus={() => {
                  setFocusIndex(i)
                  showAtColumn(i)
                }}
                onBlur={() => setActive(null)}
              />
            ))}
          </svg>
        )}
      </div>
      {d && (
        <ChartTip tipRef={tip}>
          <b>{d.label}</b>
          {d.detail && <span className="dkj-chart-detail">{d.detail}</span>}
          <span className={cx('num', d.value >= 0 ? 'delta--up' : 'delta--down')}>{format(d.value)}</span>
        </ChartTip>
      )}
      <ChartTable summary={tableLabel} caption={label} headings={[periodHeading, valueHeading]}>
        {data.map((c) => (
          <tr key={c.key}>
            <td>
              {c.label}
              {c.detail && <span className="dkj-chart-detail">{c.detail}</span>}
            </td>
            <td className={c.value >= 0 ? 'delta--up' : 'delta--down'}>{format(c.value)}</td>
          </tr>
        ))}
      </ChartTable>
    </div>
  )
}

/** One bar: `label` is the full name (tooltip, table, accessible name), `short` is what the row shows. */
export type BarDatum = {
  key: string
  label: string
  /** The shorter name the row shows; defaults to `label`. */
  short?: string
  value: number
  /** Muted lines under the label in the tooltip and the table, e.g. "Fund · 120 units". */
  detail?: string
  /** For `colorBy="series"`: 1 to 3, the house --cat-N the bar takes. */
  series?: 1 | 2 | 3
}

const WIDE = 480 // from this width a row is one 30px line; below it the row is stacked at 48px
const LABEL_CHAR_PX = 6.5 // the estimated width of an average 12px text character, for cutting a label with an ellipsis
const VALUE_CHAR_PX = 7 // a figure is wider than average text (digits, currency sign), and a value is never cut, so it is measured generously
const BAR_H = 18

/** Cut a label with an ellipsis at what fits in `px`, on a character estimate. */
function fit(text: string, px: number) {
  const max = Math.max(1, Math.floor(px / LABEL_CHAR_PX))
  return text.length > max ? `${text.slice(0, max - 1)}\u2026` : text
}

/** A horizontal bar with a 4px rounded data end and a square end on the zero line, to the right or the left of it. */
function barPath(x0: number, w: number, y: number, right: boolean) {
  const r = Math.min(4, w, BAR_H / 2)
  const mid = BAR_H - 2 * r
  return right
    ? `M${x0},${y}h${w - r}a${r},${r} 0 0 1 ${r},${r}v${mid}a${r},${r} 0 0 1 ${-r},${r}h${r - w}z`
    : `M${x0},${y}h${r - w}a${r},${r} 0 0 0 ${-r},${r}v${mid}a${r},${r} 0 0 0 ${r},${r}h${w - r}z`
}

type BarColor = { colorBy: 'series' } | { colorBy: 'direction' }

/**
 * BarChart -- a value per row as a horizontal bar, on the house .chart. `colorBy="series"` colours each bar with the
 * house --cat-N of its `series` (put a Legend above it); `colorBy="direction"` draws gains to the right of the zero line
 * in --positive-3 and losses to the left in --negative-3, so the side says the same as the colour. The order of `data` is kept, so
 * sort it first. It draws at its real width: one 30px line per row from 480px, stacked rows (label and value over the
 * bar) below it, so 12px text stays 12px on a phone. Hover, or tab to it and use Up, Down, Home and End, for the house
 * .tooltip; the same figures, and with `share` each row's share of the total, are always a table away.
 */
export function BarChart({
  label,
  data,
  format,
  share,
  tableLabel = 'Show as table',
  itemHeading = 'Item',
  valueHeading = 'Value',
  shareHeading = 'Share',
  ...color
}: {
  /** Names the chart for a screen reader and the table, e.g. "Allocation". */
  label: string
  data: readonly BarDatum[]
  format: (v: number) => string
  /** Words a row's share of the sum of all bars, e.g. "12% of total"; only meaningful for parts of a whole, so it is ignored unless every value is 0 or more and their sum is above 0. */
  share?: (fraction: number) => string
  tableLabel?: string
  itemHeading?: string
  valueHeading?: string
  shareHeading?: string
} & BarColor) {
  const frame = useChartFrame(data.length)
  const { wrap, tip, width, active, setActive, focusIndex, setFocusIndex, show } = frame

  const wide = width >= WIDE
  const rowH = wide ? 30 : 48
  const barY = wide ? 6 : 24 // the top of a bar within its row
  const values = data.map((d) => d.value)
  const lo = Math.min(0, ...values)
  const hi = Math.max(0, ...values)
  const mixed = lo < 0 && hi > 0
  const tk = ticks(lo, hi, 4)
  const min = mixed ? Math.min(lo, tk[0]) : lo
  const max = mixed ? Math.max(hi, tk[tk.length - 1]) : hi
  const valW = Math.max(0, ...data.map((d) => format(d.value).length)) * VALUE_CHAR_PX + 8
  const labelW = wide ? Math.max(96, Math.min(168, Math.round(width * 0.3))) : 0
  // The plot runs from px0 to px1; a stacked row keeps 1px in from the edge where the zero line sits on it, so the full 1px shows.
  const px0 = wide ? labelW + 8 : lo === 0 ? 1 : 0
  const px1 = wide ? width - valW - 8 : hi === 0 ? width - 1 : width
  const x = (v: number) => px0 + ((v - min) / (max - min || 1)) * (px1 - px0)
  const x0 = x(0)
  const total = values.reduce((a, b) => a + b, 0)
  const showShare = !!share && lo >= 0 && total > 0 // a share is only meaningful for parts of a whole
  const fill = (d: BarDatum) => (color.colorBy === 'series' ? `var(--cat-${d.series ?? 1})` : d.value >= 0 ? 'var(--positive-3)' : 'var(--negative-3)')
  const sign = (v: number) => (color.colorBy === 'direction' ? (v >= 0 ? 'delta--up' : 'delta--down') : undefined)

  const showAtRow = (i: number) => {
    const svg = wrap.current?.querySelector('svg')
    if (!svg) return
    const b = svg.getBoundingClientRect()
    show(i, { x: b.left + x(data[i].value), y: b.top + i * rowH + barY })
  }
  const onKey = rovingKeys(frame, data.length, 'ArrowUp', 'ArrowDown')

  const h = data.length * rowH
  const d = active === null ? null : data[active]
  return (
    <div className="dkj-chart">
      <div ref={wrap} className="chart">
        {width > 0 && (
          <svg width={width} height={h} viewBox={`0 0 ${width} ${h}`} role="group" aria-label={label} onKeyDown={onKey}>
            {/* The zero line: through stacked rows it would cut their text, so those get a piece beside each bar. */}
            {wide ? (
              <line x1={x0} x2={x0} y1={0} y2={h} stroke="var(--primary-9)" strokeWidth={1} />
            ) : (
              data.map((c, i) => <line key={c.key} x1={x0} x2={x0} y1={i * rowH + barY - 2} y2={i * rowH + barY + BAR_H + 2} stroke="var(--primary-9)" strokeWidth={1} />)
            )}
            {data.map((c, i) => {
              const w = Math.max(Math.abs(x(c.value) - x0), 1) // a zero value stays a 1px bar
              const y = i * rowH + barY
              const textY = wide ? y + BAR_H / 2 + 4 : i * rowH + 16
              return (
                <g key={c.key}>
                  <text x={0} y={textY}>
                    {fit(c.short ?? c.label, (wide ? labelW : width - valW) - 8)}
                  </text>
                  <path className={cx('dkj-chart-bar', active === i && 'dkj-chart-bar--active')} d={barPath(x0, w, y, c.value >= 0)} fill={fill(c)} aria-hidden="true" />
                  <text className="val" x={width} y={textY} textAnchor="end">
                    {format(c.value)}
                  </text>
                </g>
              )
            })}
            {/* The hit areas: the full row, and the keyboard stops (one tab stop, arrows move). */}
            {data.map((c, i) => (
              <rect
                key={c.key}
                className="bar"
                x={0}
                y={i * rowH}
                width={width}
                height={rowH}
                fill="transparent"
                role="img"
                aria-label={`${c.label}${c.detail ? ` (${c.detail})` : ''}: ${format(c.value)}`}
                tabIndex={i === focusIndex ? 0 : -1}
                onPointerMove={(e: ReactPointerEvent) => show(i, { x: e.clientX, y: e.clientY })}
                onPointerLeave={() => setActive(null)}
                onFocus={() => {
                  setFocusIndex(i)
                  showAtRow(i)
                }}
                onBlur={() => setActive(null)}
              />
            ))}
          </svg>
        )}
      </div>
      {d && (
        <ChartTip tipRef={tip}>
          <b>{d.label}</b>
          {d.detail && <span className="dkj-chart-detail">{d.detail}</span>}
          <span className={cx('num', sign(d.value))}>{format(d.value)}</span>
          {showShare && <span className="dkj-chart-detail">{share(d.value / total)}</span>}
        </ChartTip>
      )}
      <ChartTable summary={tableLabel} caption={label} headings={showShare ? [itemHeading, valueHeading, shareHeading] : [itemHeading, valueHeading]}>
        {data.map((c) => (
          <tr key={c.key}>
            <td>
              {c.label}
              {c.detail && <span className="dkj-chart-detail">{c.detail}</span>}
            </td>
            <td className={sign(c.value)}>{format(c.value)}</td>
            {showShare && <td>{share(c.value / total)}</td>}
          </tr>
        ))}
      </ChartTable>
    </div>
  )
}

/** One point of a line chart: `label` is the full name (tooltip, table, accessible name), `short` goes under the axis. */
export type LinePoint = {
  key: string
  label: string
  short: string
  /** The figure of every series at this point, by `LineSeries.key`. */
  values: Record<string, number>
  /** A muted line under the label in the tooltip and the table. */
  detail?: string
  /** A vertical guide before this point, with this text at its top (e.g. "Q2 2026"). */
  guide?: string
}

/** One line: it takes the house --cat-<slot> and keeps it, so identity is never the colour alone (a `step` line is a different shape). */
export type LineSeries = {
  key: string
  label: string
  slot: 1 | 2 | 3
  /** Draw as a step: flat to the new point, then up or down, for a figure that changes on a date and stays (deposits). */
  step?: boolean
  /** The figure wears the up/down colour in the tooltip and the table; the line stays its slot colour. */
  signed?: boolean
}

const LINE_WIDE = 560 // from this width every line gets a direct end label; below it the right margin is the 8px of M
const END_W = 84 // the right margin that holds the end labels
const END_GAP = 14 // the least room between two end labels, in px
const DOT_R = 4

/**
 * LineChart -- several series over evenly spaced points (month ends), on the house .chart. Each series takes its
 * house --cat-<slot>; a `step` series is drawn as a step. The axis encloses 0 and every value, so a series can go
 * negative. It draws at its real width, so 12px stays 12px on a phone; from 560px each line is named at its end.
 * Hover, or tab to it and use Left, Right, Home and End, for a crosshair marking every series and the house .tooltip
 * with all figures; the same figures are always a table away. Put a Legend (line items) above it.
 */
export function LineChart({
  label,
  points,
  series,
  format,
  tableLabel = 'Show as table',
  periodHeading = 'Period',
}: {
  /** Names the chart for a screen reader and the table, e.g. "Value over time". */
  label: string
  points: readonly LinePoint[]
  series: readonly LineSeries[]
  format: (v: number) => string
  tableLabel?: string
  periodHeading?: string
}) {
  const frame = useChartFrame(points.length)
  const { wrap, tip, width, active, setActive, focusIndex, setFocusIndex, show } = frame

  const endLabels = width >= LINE_WIDE
  const right = endLabels ? END_W : M.right
  const pw = Math.max(0, width - M.left - right)
  const ph = H - M.top - M.bottom
  const all = points.flatMap((p) => series.map((s) => p.values[s.key]))
  const lo = Math.min(0, ...all)
  const hi = Math.max(0, ...all)
  const tk = ticks(lo, hi, 4)
  const yMin = Math.min(lo, tk[0])
  const yMax = Math.max(hi, tk[tk.length - 1])
  const y = (v: number) => M.top + ((yMax - v) / (yMax - yMin || 1)) * ph
  const band = points.length ? pw / points.length : 0
  const px = (i: number) => M.left + band * (i + 0.5)
  const every = Math.max(1, Math.ceil(LABEL_GAP / (band || 1)))
  const color = (s: LineSeries) => `var(--cat-${s.slot})`
  const tone = (s: LineSeries, v: number) => (s.signed ? (v >= 0 ? 'delta--up' : 'delta--down') : undefined)

  const guides = thinGuides(points, band, width)

  const path = (s: LineSeries) =>
    points
      .map((p, i) => {
        const v = p.values[s.key]
        return i === 0 ? `M${px(0)},${y(v)}` : s.step ? `H${px(i)}V${y(v)}` : `L${px(i)},${y(v)}`
      })
      .join('')
  // Draw order: the step lines first, then the plain ones, the first series on top.
  const drawn = [...series.filter((s) => s.step), ...series.filter((s) => !s.step).reverse()]

  // End labels, top to bottom, nudged apart by END_GAP and kept inside the plot: pushed down first, then walked back up from the bottom.
  const last = points[points.length - 1]
  const ends: { s: LineSeries; v: number; y: number }[] = []
  if (last && endLabels) {
    const sorted = series.map((s) => ({ s, v: last.values[s.key], y: y(last.values[s.key]) + 4 })).sort((p, q) => p.y - q.y)
    sorted.forEach((e, i) => (e.y = i ? Math.max(e.y, sorted[i - 1].y + END_GAP) : e.y))
    const floor = M.top + ph
    for (let i = sorted.length - 1; i >= 0; i--) sorted[i].y = Math.min(sorted[i].y, i === sorted.length - 1 ? floor : sorted[i + 1].y - END_GAP)
    ends.push(...sorted)
  }

  const showAtPoint = (i: number) => {
    const svg = wrap.current?.querySelector('svg')
    if (!svg) return
    const b = svg.getBoundingClientRect()
    show(i, { x: b.left + px(i), y: b.top + (series.length ? Math.min(...series.map((s) => y(points[i].values[s.key]))) : M.top) - 8 })
  }
  const onKey = rovingKeys(frame, points.length, 'ArrowLeft', 'ArrowRight')

  const a = active === null ? null : points[active]
  return (
    <div className="dkj-chart">
      <div ref={wrap} className="chart">
        {width > 0 && (
          <svg width={width} height={H} viewBox={`0 0 ${width} ${H}`} role="group" aria-label={label} onKeyDown={onKey}>
            {tk.map((v) => (
              <g key={v}>
                <line x1={M.left} x2={M.left + pw} y1={y(v)} y2={y(v)} stroke={v === 0 ? 'var(--primary-9)' : 'var(--primary-4)'} strokeWidth={1} />
                <text x={M.left - 8} y={y(v) + 4} textAnchor="end">
                  {format(v)}
                </text>
              </g>
            ))}
            {guides.map((g) => (
              <g key={g.key}>
                <line x1={g.x} x2={g.x} y1={M.top} y2={M.top + ph} stroke="var(--primary-4)" strokeWidth={1} />
                {g.text && (
                  <text className="axis-note" x={g.x + 4} y={M.top - 8}>
                    {g.text}
                  </text>
                )}
              </g>
            ))}
            {points.map((p, i) =>
              i % every === 0 ? (
                <text key={p.key} x={px(i)} y={H - 8} textAnchor="middle">
                  {p.short}
                </text>
              ) : null,
            )}
            {drawn.map((s) => (
              <path key={s.key} d={path(s)} fill="none" stroke={color(s)} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" aria-hidden="true" />
            ))}
            {last &&
              series.map((s) => (
                <circle key={s.key} cx={px(points.length - 1)} cy={y(last.values[s.key])} r={DOT_R} fill={color(s)} stroke="var(--primary-2)" strokeWidth={2} aria-hidden="true" />
              ))}
            {ends.map(({ s, v, y: ey }) => (
              <text key={s.key} className={cx(s === series[0] && 'val')} x={M.left + pw + 8} y={ey} aria-hidden="true">
                {format(v)}
              </text>
            ))}
            {a && active !== null && (
              <g aria-hidden="true" pointerEvents="none">
                <line x1={px(active)} x2={px(active)} y1={M.top} y2={M.top + ph} stroke="var(--primary-9)" strokeWidth={1} />
                {series.map((s) => (
                  <circle key={s.key} cx={px(active)} cy={y(a.values[s.key])} r={DOT_R} fill={color(s)} stroke="var(--primary-2)" strokeWidth={2} />
                ))}
              </g>
            )}
            {/* The hit areas: the full band, so the pointer snaps to the nearest point, and the keyboard stops (one tab stop, arrows move). */}
            {points.map((p, i) => (
              <rect
                key={p.key}
                className="bar"
                x={M.left + band * i}
                y={M.top}
                width={band}
                height={ph}
                fill="transparent"
                role="img"
                aria-label={`${p.label}${p.detail ? ` (${p.detail})` : ''}: ${series.map((s) => `${s.label} ${format(p.values[s.key])}`).join('; ')}`}
                tabIndex={i === focusIndex ? 0 : -1}
                onPointerMove={(e: ReactPointerEvent) => show(i, { x: e.clientX, y: e.clientY })}
                onPointerLeave={() => setActive(null)}
                onFocus={() => {
                  setFocusIndex(i)
                  showAtPoint(i)
                }}
                onBlur={() => setActive(null)}
              />
            ))}
          </svg>
        )}
      </div>
      {a && (
        <ChartTip tipRef={tip}>
          <b>{a.label}</b>
          {a.detail && <span className="dkj-chart-detail">{a.detail}</span>}
          {series.map((s) => (
            <span key={s.key} className="dkj-chart-row">
              <span className="dkj-chart-swatch" style={{ background: color(s) }} />
              {s.label}
              <span className={cx('num', 'dkj-chart-figure', tone(s, a.values[s.key]))}>{format(a.values[s.key])}</span>
            </span>
          ))}
        </ChartTip>
      )}
      <ChartTable summary={tableLabel} caption={label} headings={[periodHeading, ...series.map((s) => s.label)]}>
        {points.map((p) => (
          <tr key={p.key}>
            <td>
              {p.label}
              {p.detail && <span className="dkj-chart-detail">{p.detail}</span>}
            </td>
            {series.map((s) => (
              <td key={s.key} className={tone(s, p.values[s.key])}>
                {format(p.values[s.key])}
              </td>
            ))}
          </tr>
        ))}
      </ChartTable>
    </div>
  )
}
