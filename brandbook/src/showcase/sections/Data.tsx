import { useState } from 'react'
import { IconButton, RoundToggle } from '../../components/Button'
import { AnswerBox, BillTable, CalcSection, CalcTable, ComparisonTable, DataTable, DefinitionList, type DataColumn, type DataSort } from '../../components/Table'
import { Demo, Section } from '../Showcase'

const COLUMNS: readonly DataColumn[] = [
  { key: 'name', label: 'Product', sortable: true },
  { key: 'type', label: 'Type', sortable: true, align: 'start' },
  { key: 'qty', label: 'Quantity', sortable: true, priority: 'low' },
  { key: 'value', label: 'Value', sortable: true },
  { key: 'result', label: 'Result', sortable: true },
]

/** Placeholder rows; result is the number the sort uses, and the tone follows its sign. */
const HOLDINGS = [
  { id: 'a', name: 'Product alpha', code: 'XX0000000001', type: 'Fund', qty: 12, value: 1234.5, result: 120.25 },
  { id: 'b', name: 'Product bravo', code: 'XX0000000002', type: 'Share', qty: 3, value: 560, result: -42.1 },
  { id: 'c', name: 'Product charlie with a longer name', code: 'XX0000000003', type: 'Fund', qty: 40.5, value: 2210.8, result: 0 },
] as const

const money = (v: number) => v.toLocaleString('en', { style: 'currency', currency: 'EUR' })
const signed = (v: number) => (v > 0 ? '+' : '') + money(v)
const tone = (v: number) => (v > 0 ? 'positive' : v < 0 ? 'negative' : undefined)

function DataTableDemo() {
  const [sort, setSort] = useState<DataSort>({ key: 'value', direction: 'descending' })
  // A new column starts ascending for text and descending for figures; the same column flips.
  const onSort = (key: string) =>
    setSort((s) =>
      s.key === key
        ? { key, direction: s.direction === 'ascending' ? 'descending' : 'ascending' }
        : { key, direction: key === 'name' || key === 'type' ? 'ascending' : 'descending' },
    )
  const sorted = [...HOLDINGS].sort((a, b) => {
    const x = a[sort.key as keyof typeof a]
    const y = b[sort.key as keyof typeof b]
    const d = typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y))
    return sort.direction === 'ascending' ? d : -d
  })
  const sum = (k: 'value' | 'result') => HOLDINGS.reduce((t, h) => t + h[k], 0)
  return (
    <DataTable
      label="Holdings"
      columns={COLUMNS}
      sort={sort}
      onSort={onSort}
      rows={sorted.map((h) => ({
        id: h.id,
        sub: h.code,
        cells: { name: h.name, type: h.type, qty: h.qty, value: money(h.value), result: signed(h.result) },
        tones: { result: tone(h.result) },
      }))}
      total={{ label: 'Total', cells: { value: money(sum('value')), result: signed(sum('result')) }, tones: { result: tone(sum('result')) } }}
    />
  )
}

export function Data() {
  return (
    <>
      <Section id="DefinitionList" title="DefinitionList" intro="Label left, a bold tabular value right, a rule between; a detail line under a label; a bold total. The facts variant mutes the labels. A value can take a tone and a weight (the ValueBox props), and a label an info slot. A value can be a link.">
        <Demo label="Breakdown with total">
          <DefinitionList
            items={[
              { term: 'Part one', detail: '12 × 3', value: '36' },
              { term: 'Part two', value: '14' },
              { term: 'Part three', detail: 'base + bonus', value: '50' },
            ]}
            total={{ term: 'Total', value: '100' }}
          />
        </Demo>
        <Demo label="Tone, weight and info slot">
          <DefinitionList
            items={[
              { term: 'A gain', value: '+120.00', tone: 'positive', info: <RoundToggle size="inline" label="Explain: A gain" /> },
              { term: 'A loss', value: '−42.10', tone: 'negative', info: <RoundToggle size="inline" label="Explain: A loss" /> },
              { term: 'A secondary figure', value: '8.00', weight: 'regular' },
            ]}
            total={{ term: 'Total result', value: '+85.90', tone: 'positive' }}
          />
        </Demo>
        <Demo label="Facts">
          <DefinitionList
            variant="facts"
            items={[
              { term: 'Label', value: 'Value' },
              { term: 'Another label', value: '1,234' },
              { term: 'Third', value: 'Yes' },
              { term: 'A warning', value: '3 notes', tone: 'warn' },
              { term: 'A link', value: <a href="#DefinitionList">connectors/example.json</a> },
            ]}
          />
        </Demo>
      </Section>

      <Section id="DataTable" title="DataTable" intro="The house table in a sideways-scrolling wrapper: text first column, right-aligned tabular figures (a text column such as Type takes align start), sortable headers (tap one: aria-sort and the arrow follow), a muted sub-line under the first cell, toned figures and a bold total row. A low-priority column (Quantity here) drops out while the table is narrower than 760px. ComparisonTable stays the comparison variant.">
        <Demo label="Sortable, with sub-line, tones and total" wide>
          <DataTableDemo />
        </Demo>
        <Demo label="Plain headers, empty state" wide>
          <DataTable
            label="Closed positions"
            columns={[
              { key: 'name', label: 'Product' },
              { key: 'bought', label: 'Bought' },
              { key: 'sold', label: 'Sold' },
            ]}
            rows={[]}
            empty="No closed positions"
          />
        </Demo>
        <Demo label="Row and cell tones" wide>
          <DataTable
            label="Checks"
            columns={[
              { key: 'name', label: 'Check' },
              { key: 'errors', label: 'Errors' },
              { key: 'notes', label: 'Notes' },
            ]}
            rows={[
              { id: 'a', cells: { name: 'A failing check', errors: '2', notes: '0' }, tone: 'negative', tones: { errors: 'negative' } },
              { id: 'b', cells: { name: 'A check with notes', errors: '0', notes: '3' }, tone: 'warn', tones: { notes: 'warn' } },
              { id: 'c', cells: { name: 'A passing check', errors: '0', notes: '0' } },
            ]}
          />
        </Demo>
      </Section>

      <Section id="BillTable" title="BillTable" intro="One table per invoice. Long names truncate on a 360px phone; empty slots show a muted dash; what you buy has its price in the accent. Groups close with a subtotal between stronger rules; the total sits under a rule in the accent.">
        <Demo label="Simple, with info / help / edit actions" wide>
          <BillTable
            columns={{ slot: 'Slot', item: 'Item', price: 'Price' }}
            groups={[
              {
                lines: [
                  { slot: 'Slot A', name: 'Item alpha with a rather long name', price: '1,200', tone: 'buy', action: <RoundToggle /> },
                  { slot: 'Slot B', name: 'Item bravo', price: '0', action: <RoundToggle kind="info" /> },
                  { slot: 'Slot C', name: null, price: null, tone: 'empty', action: <IconButton icon="pencil" label="Edit slot C" /> },
                ],
              },
            ]}
            total={{ label: 'Total', value: '1,200' }}
          />
        </Demo>
        <Demo label="With quantity, grouped with subtotals" wide>
          <BillTable
            withQty
            columns={{ slot: 'Slot', item: 'Item', qty: 'Qty', price: 'Price' }}
            groups={[
              {
                name: 'Group one',
                subtotal: '2,450',
                lines: [
                  { slot: 'Line 1', name: 'Item charlie', qty: '120', price: '1,800', tone: 'buy' },
                  { slot: 'Line 2', name: 'Item delta', qty: '30', price: '650', tone: 'buy' },
                ],
              },
              {
                name: 'Group two',
                subtotal: '300',
                lines: [{ slot: 'Line 3', name: 'Item echo', qty: '5', price: '300', tone: 'buy' }],
              },
            ]}
            total={{ label: 'Total', value: '2,750' }}
          />
        </Demo>
      </Section>

      <Section id="ComparisonTable" title="ComparisonTable" intro="Several numeric columns with small right-aligned heads; the difference column is red with a minus or green with a plus.">
        <Demo label="Comparison" wide>
          <ComparisonTable
            columns={['Option A', 'Option B', 'Difference']}
            rows={[
              { label: 'Category one', values: ['1,500', '1,200', '−300'], tone: 'negative' },
              { label: 'Category two', values: ['800', '950', '+150'], tone: 'positive' },
              { label: 'Category three', values: ['400', '400', '—'], tone: 'none' },
            ]}
            total={{ label: 'Total', values: ['2,700', '2,550', '−150'], tone: 'negative' }}
          />
        </Demo>
      </Section>

      <Section id="CalcTable" title="CalcTable" intro="A calculation written downwards, digits right-aligned so they line up; boxes group what belongs together and share the outer columns; the result is large and in the accent.">
        <Demo label="Plain">
          <CalcTable
            items={[
              { kind: 'row', what: 'Factor one', num: '1,234' },
              { kind: 'row', what: 'Factor two', sub: '12 + 3', op: '×', num: '15' },
              { kind: 'row', what: 'Divider', op: '÷', num: '100' },
            ]}
            result="185.1"
          />
        </Demo>
        <Demo label="Boxed">
          <CalcTable
            items={[
              {
                kind: 'box',
                items: [
                  { kind: 'row', what: 'Factor one', num: '250' },
                  { kind: 'row', what: 'Factor two', op: '+', num: '50' },
                ],
              },
              { kind: 'row', what: 'Multiplier', op: '×', num: '1.5' },
            ]}
            result="450"
          />
        </Demo>
      </Section>

      <Section id="AnswerBox" title="AnswerBox" intro="The answer of a calculation block, in an accent-tinted rounded box; blocks carry a bold question as their heading.">
        <Demo label="Sections with answers">
          <CalcSection question="How many are needed?">
            <DefinitionList items={[{ term: 'Per step', value: '12' }, { term: 'Steps', value: '10' }]} />
            <AnswerBox label="Needed" value="120" />
          </CalcSection>
          <CalcSection question="What does it cost?">
            <AnswerBox label="Cost" value="1,800" />
          </CalcSection>
        </Demo>
      </Section>
    </>
  )
}
