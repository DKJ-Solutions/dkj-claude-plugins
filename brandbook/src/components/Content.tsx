import type { ReactNode } from 'react'
import { cx } from './cx'
import { Chip } from './Feedback'
import './surfaces.css'

/**
 * GroupHeading -- an uppercase, muted section label at --text-base, optionally with a counter on the right
 * that turns danger when it is over its limit.
 *
 * `level` is the heading element (2, 3 or 4; default 3) and only sets the document outline, never the
 * look: pick the level below the page or section heading it sits under (h2 under a page h1, h3 under an h2).
 * Section labels are the one exemption from "a heading takes the token of its own level" (#90).
 */
export function GroupHeading({
  children,
  count,
  over,
  level = 3,
}: {
  children: ReactNode
  count?: ReactNode
  over?: boolean
  level?: 2 | 3 | 4
}) {
  const Tag = `h${level}` as const
  return (
    <Tag className="dkj-group-heading">
      <span>{children}</span>
      {count !== undefined && <span className={cx('dkj-group-count', over && 'dkj-group-count--over')}>{count}</span>}
    </Tag>
  )
}

/**
 * QuestionBlock -- a heading (h3) with a verdict chip on the same line (the chip shrinks or wraps below),
 * then a verdict line (body size) and supporting text.
 */
export function QuestionBlock({
  title,
  chip,
  chipText,
  verdict,
  children,
}: {
  title: ReactNode
  chip: 'yes' | 'no' | 'todo' | 'unknown'
  chipText: string
  verdict?: ReactNode
  children?: ReactNode
}) {
  return (
    <div className="dkj-question">
      <div className="dkj-question-head">
        <h3>{title}</h3>
        <Chip tone={chip}>{chipText}</Chip>
      </div>
      {verdict && <p className="dkj-verdict">{verdict}</p>}
      {children}
    </div>
  )
}

/** Amount -- a tabular number with a small icon after it, at the height of the digits. */
export function Amount({ value, icon }: { value: string; icon?: ReactNode }) {
  return (
    <span className="dkj-amount">
      {value}
      {icon}
    </span>
  )
}

/** FooterNote -- the small muted note at the foot of a page: what the figures are and are not (the house .footer-note). */
export function FooterNote({ children }: { children: ReactNode }) {
  return <p className="footer-note">{children}</p>
}
