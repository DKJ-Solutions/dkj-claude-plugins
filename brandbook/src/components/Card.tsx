import { createContext, useContext, type ReactNode } from 'react'
import { cx } from './cx'
import { Icon, type IconName } from './Icon'
import './surfaces.css'

/** The card's variant, so CardHead picks the heading element whose token its title is set in. */
const CardVariant = createContext<'default' | 'data'>('default')

/**
 * Card -- the main surface. flush: no padding, the head and body bring their own.
 * invalid: a danger border. open: a stronger accent-tinted border while its dialog is open.
 * variant="data": for a data view -- 20px padding, the head left-aligned in the house serif with an optional subline,
 * and no rule between head and body. The other states stay.
 */
export function Card({
  children,
  flush,
  invalid,
  open,
  variant = 'default',
  className,
}: {
  children: ReactNode
  flush?: boolean
  invalid?: boolean
  open?: boolean
  variant?: 'default' | 'data'
  className?: string
}) {
  return (
    <section
      className={cx('dkj-card', flush && 'dkj-card--flush', variant === 'data' && 'dkj-card--data', invalid && 'dkj-card--invalid', open && 'dkj-card--open', className)}
    >
      <CardVariant.Provider value={variant}>{children}</CardVariant.Provider>
    </section>
  )
}

/**
 * CardHead -- a centred title (optionally with an accent icon), and below it the card's actions over the full width.
 * The title is an <h6> (--text-h6), or an <h2> (--text-h2) in a data card: a heading takes the token of its own level.
 * subtitle: a muted line under the title. info: a slot after the title text, for an inline RoundToggle.
 * badge: a status Badge before the title text (#153). The Badge is decorative, so say the status in the subtitle too.
 * level={3}: a plain <h3>, for a card whose <h2> stands above a group of cards in a CardGroup (#206).
 */
export function CardHead({
  title,
  icon,
  badge,
  subtitle,
  info,
  actions,
  level,
}: {
  title: ReactNode
  level?: 3
  icon?: IconName
  badge?: ReactNode
  subtitle?: ReactNode
  info?: ReactNode
  actions?: ReactNode
}) {
  const variant = useContext(CardVariant)
  const plainH3 = level === 3
  const Title = plainH3 ? 'h3' : variant === 'data' ? 'h2' : 'h6'
  return (
    <div className="dkj-card-head">
      <Title className={plainH3 ? undefined : cx('dkj-card-title', icon && 'dkj-card-title--icon')}>
        {icon && <Icon name={icon} className="dkj-card-icon" />}
        {badge}
        {title}
        {info}
      </Title>
      {subtitle && <p className="dkj-card-sub">{subtitle}</p>}
      {actions}
    </div>
  )
}

/**
 * CardGroup -- an <h2> with its sub line standing ABOVE the card(s) it heads, not inside them (#206): the house `.grid-2`
 * with a `.grid__head`. Put the cards inside: two sit side by side, one with className="grid__full" takes the whole row.
 */
export function CardGroup({ title, subtitle, children }: { title: ReactNode; subtitle: ReactNode; children: ReactNode }) {
  return (
    <div className="grid-2">
      <div className="grid__head">
        <h2>{title}</h2>
        <p className="card__sub">{subtitle}</p>
      </div>
      {children}
    </div>
  )
}

/** CardBody -- the card content, under a rule when a CardHead sits above it. */
export function CardBody({ children }: { children: ReactNode }) {
  return <div className="dkj-card-body">{children}</div>
}

/**
 * TintedPanel -- a bordered panel tinted from one colour token, so parts of one card read as separate:
 * neutral (muted), accent, or positive. As a button it becomes a large tappable tile.
 */
export function TintedPanel({
  tone = 'neutral',
  children,
  as = 'div',
  onClick,
}: {
  tone?: 'neutral' | 'accent' | 'positive'
  children: ReactNode
  as?: 'div' | 'button'
  onClick?: () => void
}) {
  const className = cx('dkj-panel', `dkj-panel--${tone}`, as === 'button' && 'dkj-panel--button')
  return as === 'button' ? (
    <button type="button" className={className} onClick={onClick}>
      {children}
    </button>
  ) : (
    <div className={className}>{children}</div>
  )
}
