import type { ReactNode } from 'react'
import { cx } from './cx'
import { Icon } from './Icon'
import { TitleTag } from './Feedback'
import './daterow.css'

export type DateRowState = 'default' | 'near' | 'today' | 'invalid'

const FLAG: Partial<Record<DateRowState, string>> = { near: 'Soon', today: 'Today' }

/** DateList -- the semantic list for DateRows: a `ul` without bullets, named by `label` for screen readers. */
export function DateList({ label, children }: { label?: string; children: ReactNode }) {
  return (
    <ul className="dkj-datelist" aria-label={label}>
      {children}
    </ul>
  )
}

/**
 * DateRow -- one dated item: a fixed left column (`when`: a date, a time range, a distance), a title with a muted
 * second line, and an optional right-aligned `trailing` label. The caller decides the state; DateRow does no date maths.
 * near / today: a theme-coloured left bar, a tint, a bold `when` and a word ("Soon" / "Today"), so never colour alone.
 * invalid: a red bar, a warning icon, `when` defaulting to "Invalid", and `reason` under the title (linked by aria-describedby).
 * date: an ISO string, passed through to <time> unvalidated (no date maths). href: the title becomes a full-row link.
 * href and date are ignored in the invalid state. The stretched link covers the row, so links inside `trailing` are
 * unreachable. `when` does not wrap: keep it short. flag: the word beside `when` (default "Today" / "Soon" per state; false hides it).
 */
export function DateRow({
  when,
  date,
  title,
  sub,
  trailing,
  state = 'default',
  reason,
  href,
  flag,
}: {
  when?: string
  date?: string
  title: ReactNode
  sub?: ReactNode
  trailing?: ReactNode
  state?: DateRowState
  reason?: ReactNode
  href?: string
  flag?: string | false
}) {
  const invalid = state === 'invalid'
  const text = when ?? (invalid ? 'Invalid' : '')
  const flagText = flag === undefined ? FLAG[state] : flag
  return (
    <li
      className={cx('dkj-daterow', state !== 'default' && `dkj-daterow--${state}`, href && !invalid && 'dkj-daterow--link')}
    >
      <span className="dkj-daterow-when">
        {invalid && <Icon name="warning" size={16} className="dkj-daterow-icon" aria-hidden="true" />}
        {date && !invalid ? <time dateTime={date}>{text}</time> : <span>{text}</span>}
        {flagText && <TitleTag tone="accent">{flagText}</TitleTag>}
      </span>
      <span className="dkj-daterow-main">
        <span className="dkj-daterow-body">
          <span className="dkj-daterow-title">{href && !invalid ? <a href={href}>{title}</a> : title}</span>
          {sub && <span className="dkj-daterow-sub">{sub}</span>}
          {invalid && reason && <span className="dkj-daterow-reason">{reason}</span>}
        </span>
        {trailing && <span className="dkj-daterow-trailing">{trailing}</span>}
      </span>
    </li>
  )
}
