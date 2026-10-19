import type { ReactNode } from 'react'
import { cx } from './cx'
import { IconButton } from './Button'
import './forms.css'

/**
 * ValueBox -- a read-only number: no border, no fill, a bold tabular figure, optionally a muted unit after it.
 * changed: a 2px accent border on an accent tint, with the expected value small and struck through.
 * tone: negative (red, a cost) or positive (green, a gain). weight="regular" for secondary figures.
 * The transparent 1px border keeps the size identical in every state.
 */
export function ValueBox({
  value,
  unit,
  changed,
  expected,
  tone,
  weight = 'bold',
  size = 'md',
  className,
}: {
  value: ReactNode
  unit?: string
  changed?: boolean
  expected?: string
  tone?: 'negative' | 'positive'
  weight?: 'bold' | 'regular'
  size?: 'md' | 'lg'
  className?: string
}) {
  return (
    <span className={cx('dkj-value', changed && 'dkj-value--changed', className)}>
      <strong
        className={cx(
          'dkj-value-num',
          tone && `dkj-value-num--${tone}`,
          weight === 'regular' && 'dkj-value-num--regular',
          size === 'lg' && 'dkj-value-num--lg',
        )}
      >
        {value}
        {changed && expected && <s className="dkj-value-was">{expected}</s>}
      </strong>
      {unit && <span className="dkj-value-unit">{unit}</span>}
    </span>
  )
}

/**
 * StatRow -- a name, a value box and an outline pencil on one row; a rule between rows.
 * help: an extra column for a round "?" that every row in the list keeps free (so values stay aligned).
 * readOnly: no pencil, its column stays.
 */
export function StatRow({
  name,
  sub,
  children,
  onEdit,
  help,
  readOnly,
}: {
  name: ReactNode
  sub?: ReactNode
  children: ReactNode
  onEdit?: () => void
  help?: ReactNode
  readOnly?: boolean
}) {
  return (
    <div className={cx('dkj-row', help !== undefined && 'dkj-row--help')}>
      <span className="dkj-row-name">
        {name}
        {sub && <span className="dkj-row-sub">{sub}</span>}
      </span>
      {children}
      {help !== undefined && <span className="dkj-row-help">{help}</span>}
      {readOnly ? <span /> : <IconButton icon="pencil" label={`Edit ${typeof name === 'string' ? name : ''}`.trim()} onClick={onEdit} />}
    </div>
  )
}

/** RowList -- groups StatRows; with `withHelp` every row reserves the "?" column. */
export function RowList({ children, withHelp }: { children: ReactNode; withHelp?: boolean }) {
  return <div className={cx('dkj-rows', withHelp && 'dkj-rows--help')}>{children}</div>
}

/**
 * FormulaRow -- a name, then base + extra = total in fixed narrow columns, and the pencil. Base and extra are
 * regular weight; only the total is bold and larger. FormulaHead puts small muted column heads above.
 */
export function FormulaRow({ name, a, b, total, onEdit }: { name: string; a: string; b: string; total: string; onEdit?: () => void }) {
  return (
    <div className="dkj-row dkj-row--formula">
      <span className="dkj-row-name">{name}</span>
      <ValueBox value={a} weight="regular" />
      <span className="dkj-row-op">+</span>
      <ValueBox value={b} weight="regular" />
      <span className="dkj-row-op">=</span>
      <ValueBox value={total} size="lg" className="dkj-value--flush" />
      <IconButton icon="pencil" label={`Edit ${name}`} onClick={onEdit} />
    </div>
  )
}

export function FormulaHead({ a, b, total }: { a: string; b: string; total: string }) {
  return (
    <div className="dkj-row dkj-row--formula dkj-row--head" aria-hidden="true">
      <span />
      <span>{a}</span>
      <span />
      <span>{b}</span>
      <span />
      <span>{total}</span>
      <span />
    </div>
  )
}
