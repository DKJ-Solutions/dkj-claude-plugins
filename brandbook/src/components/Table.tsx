import type { ReactNode } from 'react'
import { cx } from './cx'
import './tables.css'

type Tone = 'negative' | 'positive' | 'warn'
type DefinitionRow = { term: string; value: ReactNode; tone?: Tone; weight?: 'bold' | 'regular'; info?: ReactNode }

/**
 * DefinitionList -- label left, value right (bold, tabular), a rule between rows; a detail line small and muted under
 * the label; an optional total row in bold without a rule under it. variant="facts": the label is muted.
 * A value takes the ValueBox props: tone (negative red, positive green, warn the warning colour) and weight ("regular" for a secondary figure).
 * info: a slot right after the label, for an inline RoundToggle or a Tooltip. A value is a node, so it can be a link.
 */
export function DefinitionList({
  items,
  total,
  variant = 'breakdown',
}: {
  items: readonly (DefinitionRow & { detail?: string })[]
  total?: DefinitionRow
  variant?: 'breakdown' | 'facts'
}) {
  const row = (i: DefinitionRow, detail?: string) => (
    <>
      <dt>
        {i.term}
        {i.info}
        {detail && <span className="dkj-dl-detail">{detail}</span>}
      </dt>
      <dd className={cx(i.tone && `dkj-tone-${i.tone}`, i.weight === 'regular' && 'dkj-dl-regular')}>{i.value}</dd>
    </>
  )
  return (
    <dl className={cx('dkj-dl', variant === 'facts' && 'dkj-dl--facts')}>
      {items.map((i) => (
        <div key={i.term}>{row(i, i.detail)}</div>
      ))}
      {total && <div className="dkj-dl-total">{row(total)}</div>}
    </dl>
  )
}

export type BillLine = {
  slot: string
  name: string | null
  qty?: string
  price: string | null
  /** buy: the price in the accent. empty: a muted dash for the name. */
  tone?: 'buy' | 'empty'
  action?: ReactNode
}

/**
 * BillTable -- one table per invoice: small uppercase muted column heads, a row per line (slot, item name that
 * truncates, optional qty, price right-aligned), optional groups that close with a subtotal between stronger rules,
 * and a total under a rule in the accent.
 */
export function BillTable({
  columns,
  groups,
  total,
  withQty,
}: {
  columns: { slot: string; item: string; qty?: string; price: string }
  groups: readonly { name?: string; lines: readonly BillLine[]; subtotal?: string }[]
  total?: { label: string; value: string }
  withQty?: boolean
}) {
  return (
    <table className={cx('dkj-bill', withQty && 'dkj-bill--qty')}>
      <thead>
        <tr className="dkj-bill-head">
          <th scope="col">{columns.slot}</th>
          <th scope="col">{columns.item}</th>
          {withQty && <th scope="col" className="dkj-num">{columns.qty}</th>}
          <th scope="col" className="dkj-num">{columns.price}</th>
          <th scope="col" aria-label="Actions" />
        </tr>
      </thead>
      {groups.map((g, gi) => (
        <tbody key={gi} className={cx(g.subtotal && 'dkj-bill-group')}>
          {g.lines.map((l) => (
            <tr key={l.slot} className={cx('dkj-bill-row', l.tone && `dkj-bill-row--${l.tone}`)}>
              <th scope="row" className="dkj-bill-slot">{l.slot}</th>
              <td>
                <span className="dkj-bill-name">{l.name ?? '—'}</span>
              </td>
              {withQty && <td className="dkj-num dkj-bill-qty">{l.qty}</td>}
              <td className="dkj-num dkj-bill-price">{l.price ?? ''}</td>
              <td className="dkj-bill-action">{l.action}</td>
            </tr>
          ))}
          {g.subtotal && (
            <tr className="dkj-bill-subtotal">
              <th scope="row" colSpan={withQty ? 3 : 2}>
                {g.name}
              </th>
              <td className="dkj-num">
                <strong>{g.subtotal}</strong>
              </td>
              <td />
            </tr>
          )}
        </tbody>
      ))}
      {total && (
        <tfoot>
          <tr className="dkj-bill-total">
            <th scope="row" colSpan={withQty ? 3 : 2}>
              {total.label}
            </th>
            <td className="dkj-num">
              <strong>{total.value}</strong>
            </td>
            <td />
          </tr>
        </tfoot>
      )}
    </table>
  )
}

export type DataColumn = {
  key: string
  label: string
  sortable?: boolean
  /** low: the column drops out while the table is narrower than 760px, so a wide table fits a phone. The first column ignores it. */
  priority?: 'low'
  /** start: text on the left, for a text column. end: right-aligned. Left out, the first column is start and the rest end. */
  align?: 'start' | 'end'
}
export type DataRow = {
  id: string
  /** Column key -> cell content. */
  cells: Readonly<Record<string, ReactNode>>
  /** A muted line under the first cell, e.g. an ISIN. */
  sub?: ReactNode
  /** Column key -> tone: negative in red, positive in green, warn in the warning colour. */
  tones?: Readonly<Record<string, Tone | undefined>>
  /** The whole row's state: a tinted background (--negative-1, --positive-1 or --warning-1). The colour alone says nothing
   * to a screen reader, so a cell names the same state in text (a Status column). */
  tone?: Tone
}
export type DataSort = { key: string; direction: 'ascending' | 'descending' }

/**
 * DataTable -- the house .table in a horizontally scrolling wrapper. The first column is text on the left, every other
 * column is right-aligned tabular figures; a column's `align` overrides that, for a text column. A sortable header is a button inside its <th aria-sort> with the house
 * up/down arrow; the caller owns the sort (`sort`, `onSort`) and the order of `rows`. A row may carry a muted sub-line
 * under its first cell, cells a tone, the row itself a tone (a tinted background), and `total` closes the table with a bold row. `empty` is the one muted row for no data. A column with
 * priority="low" drops out while the table is narrower than 760px (a container query on the wrapper).
 */
export function DataTable({
  label,
  columns,
  rows,
  total,
  empty,
  sort,
  onSort,
}: {
  label: string
  columns: readonly DataColumn[]
  rows: readonly DataRow[]
  total?: Pick<DataRow, 'cells' | 'tones'> & { label: string }
  /** One muted line shown instead of the rows when there are none. */
  empty?: ReactNode
  sort?: DataSort
  onSort?: (key: string) => void
}) {
  if (columns.length === 0) return null
  const first = columns[0].key
  const low = (c: DataColumn) => c.key !== first && c.priority === 'low' && 'dkj-col-low' // the row labels always stay
  const align = (c: DataColumn) => c.align && `dkj-col-${c.align}`
  const cell = (c: DataColumn, r: Pick<DataRow, 'cells' | 'tones'>, content: ReactNode = r.cells[c.key]) => (
    <td key={c.key} className={cx(low(c), align(c), r.tones?.[c.key] && `dkj-tone-${r.tones[c.key]}`)}>
      {content}
    </td>
  )
  return (
    <div className="table-wrap dkj-table-wrap" role="region" aria-label={label} tabIndex={0}>
      <table className="table">
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} scope="col" className={cx(low(c), align(c)) || undefined} aria-sort={c.sortable ? (sort?.key === c.key ? sort.direction : 'none') : undefined}>
                {c.sortable ? (
                  <button type="button" className="sort" onClick={() => onSort?.(c.key)}>
                    {c.label}
                    <span className="arrow" aria-hidden="true">
                      <svg viewBox="0 0 8 12">
                        <path className="u" d="M1 4.5 4 1.5 7 4.5" />
                        <path className="d" d="M1 7.5 4 10.5 7 7.5" />
                      </svg>
                    </span>
                  </button>
                ) : (
                  c.label
                )}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && empty && (
            <tr>
              <td colSpan={columns.length} className="muted">
                {empty}
              </td>
            </tr>
          )}
          {rows.map((r) => (
            <tr key={r.id} className={r.tone && `dkj-row-${r.tone}`}>
              {columns.map((c) =>
                c.key === first && r.sub
                  ? cell(
                      c,
                      r,
                      <>
                        {r.cells[first]}
                        <div className="muted">{r.sub}</div>
                      </>,
                    )
                  : cell(c, r),
              )}
            </tr>
          ))}
          {total && <tr className="row-total">{columns.map((c) => cell(c, total, c.key === first ? total.label : total.cells[c.key]))}</tr>}
        </tbody>
      </table>
    </div>
  )
}

/**
 * ComparisonTable -- a label column and numeric columns with small right-aligned muted heads; the last column is the
 * difference, negative in red with a minus and positive in green with a plus; a bold total row under a strong rule.
 */
export function ComparisonTable({
  columns,
  rows,
  total,
}: {
  columns: readonly string[]
  rows: readonly { label: string; values: readonly string[]; tone?: 'negative' | 'positive' | 'none' }[]
  total?: { label: string; values: readonly string[]; tone?: 'negative' | 'positive' }
}) {
  const diff = (tone: 'negative' | 'positive' | 'none' | undefined) => cx('dkj-num', tone && tone !== 'none' && `dkj-tone-${tone}`, tone === 'none' && 'dkj-muted')
  return (
    <table className="dkj-compare">
      <thead>
        <tr>
          <td />
          {columns.map((c) => (
            <th key={c} scope="col">
              {c}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.label}>
            <th scope="row">{r.label}</th>
            {r.values.map((v, i) => (
              <td key={i} className={i === r.values.length - 1 ? diff(r.tone) : 'dkj-num'}>
                {v}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
      {total && (
        <tfoot>
          <tr>
            <th scope="row">{total.label}</th>
            {total.values.map((v, i) => (
              <td key={i} className={i === total.values.length - 1 ? diff(total.tone) : 'dkj-num'}>
                {v}
              </td>
            ))}
          </tr>
        </tfoot>
      )}
    </table>
  )
}

export type CalcItem =
  | { kind: 'row'; what: string; sub?: string; op?: string; num: string }
  | { kind: 'box'; items: readonly CalcItem[] }

/**
 * CalcTable -- a calculation written downwards: what it is left, the operator and the number right-aligned so the
 * digits line up, a thin rule between factors. Boxes (a --primary-5 border) group the factors that belong together
 * and share the outer columns via subgrid. The result sits below without a label, large and in the accent.
 */
export function CalcTable({ items, result }: { items: readonly CalcItem[]; result: string }) {
  const boxed = items.some((i) => i.kind === 'box')
  const render = (list: readonly CalcItem[]): ReactNode =>
    list.map((i, n) =>
      i.kind === 'box' ? (
        <div key={n} className="dkj-calc-box">
          {render(i.items)}
        </div>
      ) : (
        <div key={n} className="dkj-calc-row">
          <span className="dkj-calc-what">
            {i.what}
            {i.sub && <span className="dkj-calc-sub">{i.sub}</span>}
          </span>
          <span className="dkj-calc-op">{i.op ?? ''}</span>
          <span className="dkj-calc-num">{i.num}</span>
        </div>
      ),
    )
  return (
    <div className={cx('dkj-calc', boxed && 'dkj-calc--boxed')}>
      {render(items)}
      <div className="dkj-calc-row dkj-calc-result">
        <span className="dkj-calc-what" />
        <span className="dkj-calc-op">=</span>
        <span className="dkj-calc-num">{result}</span>
      </div>
    </div>
  )
}

/** AnswerBox -- the answer of a block: a rounded accent-tinted box, the label left and the number right in the accent. */
export function AnswerBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="dkj-answer">
      <span className="dkj-answer-label">{label}</span>
      <span className="dkj-answer-value">{value}</span>
    </div>
  )
}

/** CalcSection -- a block of a calculation with a bold question as its heading; space between blocks. */
export function CalcSection({ question, children }: { question: string; children: ReactNode }) {
  return (
    <section className="dkj-calc-section">
      <h6 className="dkj-calc-question">{question}</h6>
      {children}
    </section>
  )
}
