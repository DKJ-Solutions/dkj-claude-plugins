import { useEffect, useId, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { cx } from './cx'
import { RoundToggle } from './Button'
import { Icon } from './Icon'
import './surfaces.css'

/**
 * Banner -- a callout.
 * accent: a tinted line (--primary-6) with a --primary-5 border; <strong> inside it turns accent.
 * warn: the house notice look (warn background, hairline border, radius lg): a bold lead line with a warning icon,
 * then the text and optionally a list.
 */
export function Banner({ tone = 'accent', lead, children }: { tone?: 'accent' | 'warn'; lead?: ReactNode; children?: ReactNode }) {
  if (tone === 'warn') {
    return (
      <div className="dkj-banner dkj-banner--warn">
        {lead && (
          <strong className="dkj-banner-lead">
            <Icon name="warning" size={16} />
            {lead}
          </strong>
        )}{' '}
        {children}
      </div>
    )
  }
  return <p className="dkj-banner dkj-banner--accent">{children}</p>
}

/**
 * Alert -- a generic danger callout: a danger border, a --negative-3-tinted background built from house tokens, a title
 * with a warning icon in the danger text colour, and the content below. No hazard stripes.
 */
export function Alert({ tone = 'danger', title, children }: { tone?: 'danger'; title: ReactNode; children?: ReactNode }) {
  const id = useId()
  return (
    <section className={cx('dkj-alert', `dkj-alert--${tone}`)} aria-labelledby={id}>
      <h5 className="dkj-alert-title" id={id}>
        <Icon name="warning" className="dkj-alert-icon" />
        {title}
      </h5>
      {children}
    </section>
  )
}

/**
 * Message -- a line of supporting text.
 * hint: muted help. note: a hint with more space above. warn: bold warning colour. error: danger.
 * debug: developer info, dashed danger outline, so it never reads as help for the user.
 * live: for a line that appears or changes after load, so a screen reader announces it -- 'status' for a loading or
 * neutral line, 'alert' for a warning or an error. A line that is there from the start leaves it out.
 */
export function Message({
  tone = 'hint',
  live,
  children,
}: {
  tone?: 'hint' | 'note' | 'warn' | 'error' | 'debug'
  live?: 'status' | 'alert'
  children: ReactNode
}) {
  return (
    <p className={cx('dkj-msg', `dkj-msg--${tone}`)} role={live}>
      {children}
    </p>
  )
}

/** Chip -- a verdict pill. yes: accent fill. no: page fill. todo / unknown: muted and dashed. */
export function Chip({ tone, children }: { tone: 'yes' | 'no' | 'todo' | 'unknown'; children: ReactNode }) {
  return <span className={cx('dkj-chip', `dkj-chip--${tone}`)}>{children}</span>
}

/**
 * TitleTag -- a small uppercase pill label on its own line above a title. info: the info-accent.
 * warn: the warning fill with --primary-12 text on it.
 */
export function TitleTag({ tone = 'accent', children }: { tone?: 'accent' | 'info' | 'warn'; children: ReactNode }) {
  return <span className={cx('dkj-tag', tone !== 'accent' && `dkj-tag--${tone}`)}>{children}</span>
}

/**
 * Help -- an explanation that stays closed until asked for: a round "?" on the right, the text below it.
 * The text stays in the page (hidden), so aria-controls holds.
 */
export function Help({ children, defaultOpen = false }: { children: ReactNode; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(defaultOpen)
  const id = useId()
  return (
    <div className="dkj-help">
      <RoundToggle expanded={open} aria-controls={id} onClick={() => setOpen(!open)} />
      <p className="dkj-msg dkj-msg--hint" id={id} hidden={!open}>
        {children}
      </p>
    </div>
  )
}

/**
 * Disclosure -- a native <details> with a bold summary and a ▾ / ▴ marker after it. `summary` is the title; a plain
 * string renders exactly as before. `meta` (a date, a count) and `trailing` (a Chip or TitleTag) are optional slots on
 * the right of the row: the component owns the wrapping and the marker stays last. Slots hold non-interactive content
 * only -- no button, link or input inside a <summary>. Keep the slots in DOM order equal to visual order; at narrow widths only the decorative marker may move before meta and trailing. A structured row is a size container (`width: 100%`), so it fills its parent and does not shrink to fit.
 */
export function Disclosure({
  summary,
  meta,
  trailing,
  children,
  defaultOpen,
}: {
  summary: ReactNode
  meta?: ReactNode
  trailing?: ReactNode
  children: ReactNode
  defaultOpen?: boolean
}) {
  const structured = meta != null || trailing != null
  return (
    <details className={cx('dkj-disclosure', structured && 'dkj-disclosure--structured')} open={defaultOpen}>
      {structured ? (
        <summary>
          <span className="dkj-disclosure-title">{summary}</span>
          {meta != null && <span className="dkj-disclosure-meta">{meta}</span>}
          {trailing != null && <span className="dkj-disclosure-trailing">{trailing}</span>}
        </summary>
      ) : (
        <summary>{summary}</summary>
      )}
      {children}
    </details>
  )
}

/**
 * ReadMoreToggle -- a full-width "read more" button under a block (the house .moretoggle). The extra text opens ABOVE
 * it, so the button moves down with what it reveals. It is controlled: the caller owns `expanded` and the region
 * (`controls` is that region's id). The ▾ / ▴ comes from the house class; a minimum height makes the tap area 44px.
 */
export function ReadMoreToggle({
  expanded,
  controls,
  onToggle,
  moreLabel = 'Read more',
  lessLabel = 'Read less',
}: {
  expanded: boolean
  controls: string
  onToggle: () => void
  moreLabel?: string
  lessLabel?: string
}) {
  return (
    <button type="button" className="moretoggle" aria-expanded={expanded} aria-controls={controls} onClick={onToggle}>
      {expanded ? lessLabel : moreLabel}
    </button>
  )
}

/**
 * Tooltip -- a non-modal explanation on the house .tooltip. `trigger` draws the element that opens it and receives the
 * aria-describedby that links it to the text. Hover or focus opens it; a click or tap pins it (so it works where there
 * is no hover); the pointer can move from the trigger onto the text without closing it (WCAG 1.4.13, hoverable);
 * Escape, a click elsewhere, a scroll or a resize close it. explain: the wider variant for paragraphs.
 * The text is always in the page, so the description is reachable while it is hidden. It is drawn in the page body
 * (or in the open <dialog> the trigger sits in), so no ancestor's font, clipping or stacking reaches it.
 */
export function Tooltip({
  trigger,
  title,
  paragraphs,
  explain,
}: {
  trigger: (a11y: { 'aria-describedby': string }) => ReactNode
  title?: string
  paragraphs?: readonly string[]
  explain?: boolean
}) {
  const id = useId()
  const anchor = useRef<HTMLSpanElement>(null)
  const tip = useRef<HTMLSpanElement>(null)
  const [host, setHost] = useState<Element | null>(null)
  const [hovered, setHovered] = useState(false) // pointer over the trigger or the text, or keyboard focus on the trigger
  const leave = useRef<number | undefined>(undefined)
  const [pinned, setPinned] = useState(false) // clicked or tapped
  const open = hovered || pinned
  // Leaving the trigger or the text closes after a beat, so the pointer can cross the gap between them.
  const enter = () => {
    window.clearTimeout(leave.current)
    setHovered(true)
  }
  const exit = () => {
    window.clearTimeout(leave.current)
    leave.current = window.setTimeout(() => setHovered(false), 150)
  }
  useEffect(() => () => window.clearTimeout(leave.current), [])

  useLayoutEffect(() => setHost(anchor.current?.closest('dialog') ?? document.body), [])

  // Under the trigger, kept inside the viewport; above it when there is no room below.
  useLayoutEffect(() => {
    if (!open || !anchor.current || !tip.current) return
    const a = anchor.current.getBoundingClientRect()
    const { offsetWidth: w, offsetHeight: h } = tip.current
    const below = a.bottom + 8
    tip.current.style.left = `${Math.max(8, Math.min(a.left, window.innerWidth - w - 8))}px`
    tip.current.style.top = `${below + h > window.innerHeight - 8 ? Math.max(8, a.top - h - 8) : below}px`
  }, [open])

  useEffect(() => {
    if (!open) return
    const close = () => {
      setHovered(false)
      setPinned(false)
    }
    // Escape closes the tooltip only: a surrounding <dialog> must not close on the same keypress.
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      e.preventDefault()
      e.stopPropagation()
      close()
    }
    const onPointer = (e: PointerEvent) =>
      !anchor.current?.contains(e.target as Node) && !tip.current?.contains(e.target as Node) && close()
    document.addEventListener('keydown', onKey, true)
    document.addEventListener('pointerdown', onPointer)
    window.addEventListener('scroll', close, true)
    window.addEventListener('resize', close)
    return () => {
      document.removeEventListener('keydown', onKey, true)
      document.removeEventListener('pointerdown', onPointer)
      window.removeEventListener('scroll', close, true)
      window.removeEventListener('resize', close)
    }
  }, [open])

  return (
    <span
      ref={anchor}
      className="dkj-tooltip-anchor"
      onMouseEnter={enter}
      onMouseLeave={exit}
      onFocus={() => setHovered(true)}
      onBlur={() => {
        setHovered(false)
        setPinned(false)
      }}
      onClick={() => {
        if (pinned) setHovered(false)
        setPinned(!pinned)
      }}
    >
      {trigger({ 'aria-describedby': id })}
      {host &&
        createPortal(
          <span
            ref={tip}
            id={id}
            role="tooltip"
            className={cx('tooltip', explain && 'tooltip--explain', open && 'tooltip--open')}
            onMouseEnter={enter}
            onMouseLeave={exit}
            onClick={(e) => e.stopPropagation()} // a portal still bubbles React events to the anchor, whose click would unpin it
          >
            {title && <b>{title}</b>}
            {paragraphs?.map((p, i) => (
              <span key={i} className="dkj-tooltip-p">
                {p}
              </span>
            ))}
          </span>,
          host,
        )}
    </span>
  )
}
