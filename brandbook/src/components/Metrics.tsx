import type { CSSProperties, ReactNode } from 'react'
import { cx } from './cx'
import './metrics.css'

/** The series colours: --cat-1 .. --cat-3 (one meaning per slot in a view); a gain in a direction chart is --positive-3, a loss --negative-3. */
export type SeriesColor = 'cat-1' | 'cat-2' | 'cat-3' | 'positive-3' | 'negative-3'
const seriesStyle = (color: SeriesColor) => ({ '--c': `var(--${color})` }) as CSSProperties

/** StatTiles -- the grid of StatTiles (the house .tiles): as many 160px columns as fit. */
export function StatTiles({ children }: { children: ReactNode }) {
  return <div className="tiles">{children}</div>
}

/**
 * StatTile -- a bordered tile: a small muted label (with an optional info slot after it, e.g. an inline RoundToggle)
 * and one figure under it. tone colours the figure: negative red, positive green, warn the warning colour (a count of
 * notes or warnings).
 */
export function StatTile({ label, value, info, tone }: { label: string; value: ReactNode; info?: ReactNode; tone?: 'negative' | 'positive' | 'warn' }) {
  return (
    <div className="tile">
      <div className="label">
        {label}
        {info}
      </div>
      <div className={cx('v', tone === 'negative' && 'neg', tone === 'positive' && 'pos', tone === 'warn' && 'dkj-v--warn')}>{value}</div>
    </div>
  )
}

/** HeroRow -- a row of HeroValues that wraps (the house .hero). */
export function HeroRow({ children }: { children: ReactNode }) {
  return <div className="hero">{children}</div>
}

/**
 * HeroValue -- the one big figure of a page: a small muted label (with an optional info slot) over a value in the
 * house display size (--text-h1). size="lg" is the secondary figure beside it
 * (--text-h3), usually a Delta.
 */
export function HeroValue({ label, info, size = 'display', children }: { label: string; info?: ReactNode; size?: 'display' | 'lg'; children: ReactNode }) {
  return (
    <div>
      <div className="muted">
        {label}
        {info}
      </div>
      <div className={cx('dkj-hero-value', size === 'lg' && 'dkj-hero-value--lg')}>{children}</div>
    </div>
  )
}

/**
 * Delta -- a change in direction: a ▲ or ▼, then the figure with its sign (the caller formats it, e.g. "+€ 1.200,00").
 * tone up is green, down is red (--positive-5 / --negative-5, the text versions). The arrow repeats what the sign says, so it is
 * hidden from a screen reader.
 */
export function Delta({ tone, children }: { tone: 'up' | 'down'; children: ReactNode }) {
  return (
    <span className={cx('delta', `delta--${tone}`)}>
      <span aria-hidden="true">{tone === 'up' ? '▲' : '▼'}</span> {children}
    </span>
  )
}

/** Legend -- a wrapping row of LegendItems above a chart (the house .legend). */
export function Legend({ children }: { children: ReactNode }) {
  return <div className="legend">{children}</div>
}

/**
 * LegendItem -- a swatch in a series colour and its label; `line` draws a short line instead of a square, for a line
 * series. An info slot can follow the label.
 */
export function LegendItem({ color, line, children }: { color: SeriesColor; line?: boolean; children: ReactNode }) {
  return (
    <span className={cx('legend__item', line && 'legend__item--line')} style={seriesStyle(color)}>
      {children}
    </span>
  )
}

/** MiniCards -- the grid of MiniCards (the house .mini-cards). */
export function MiniCards({ children }: { children: ReactNode }) {
  return <div className="mini-cards">{children}</div>
}

/**
 * MiniCard -- a small bordered card: a muted label, a figure, then what the caller puts under it (a Meter, a
 * BadgeRow, a note). highlight: a warning-coloured border, for the one that is still open.
 */
export function MiniCard({ label, value, highlight, children }: { label: string; value: string; highlight?: boolean; children?: ReactNode }) {
  return (
    <div className={cx('mini-card', highlight && 'mini-card--highlight')}>
      <div className="mini-card__label">{label}</div>
      <div className="mini-card__value">{value}</div>
      {children}
    </div>
  )
}

/** The status colours of a Meter and a Badge. series is --cat-1; info is the theme's primary. */
export type StatusTone = 'good' | 'warn' | 'bad' | 'info' | 'series'

/**
 * Meter -- a thin progress bar, filled to `value` percent (clamped to 0-100). It is an image with a text
 * alternative, `label`, because the fill alone says nothing to a screen reader.
 */
export function Meter({ value, tone, label }: { value: number; tone: StatusTone; label: string }) {
  return (
    <div className={cx('meter', tone === 'series' ? 'dkj-meter--series' : `meter--${tone}`)} role="img" aria-label={label}>
      <span style={{ width: `${Math.min(100, Math.max(0, value))}%` }} />
    </div>
  )
}

/**
 * Badge -- a small round status mark with a glyph in it (✓, ✗, !, ?, i). The colour is a status token, never a hex; the
 * glyph is --primary-1 (near-white on light, near-black on dark, in the theme's own tint). neutral is a grey disc. The glyph is decorative: say the
 * status in text beside it (BadgeRow). size="sm" is 18px.
 */
export function Badge({ tone, size = 'md', children }: { tone: StatusTone | 'neutral'; size?: 'md' | 'sm'; children: string }) {
  return (
    <span className={cx('badge', tone === 'series' ? 'dkj-badge--series' : `badge--${tone}`, size === 'sm' && 'badge--sm')} aria-hidden="true">
      {children}
    </span>
  )
}

/** BadgeRow -- a Badge and its status text on one line (the house .badge-row). */
export function BadgeRow({ badge, children }: { badge: ReactNode; children: ReactNode }) {
  return (
    <div className="badge-row">
      {badge}
      {children}
    </div>
  )
}

/**
 * BadgeList -- several badged items as a list (the house .badge-list): a <ul> of .badge-row items, so a screen reader
 * hears a list and how long it is. A wrapped text keeps its badge on the first line.
 */
export function BadgeList({ label, items }: { label?: string; items: readonly { id: string; badge: ReactNode; text: ReactNode }[] }) {
  return (
    <ul className="badge-list" aria-label={label}>
      {items.map((i) => (
        <li key={i.id} className="badge-row">
          {i.badge}
          <span>{i.text}</span>
        </li>
      ))}
    </ul>
  )
}
