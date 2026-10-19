import { useState } from 'react'
import { RoundToggle, SegmentedChoice } from '../../components/Button'
import { Card, CardBody, CardHead } from '../../components/Card'
import { BarChart, ColumnChart, LineChart, type BarDatum, type ColumnDatum, type LinePoint, type LineSeries } from '../../components/Chart'
import { FooterNote } from '../../components/Content'
import { Banner } from '../../components/Feedback'
import { Badge, BadgeRow, Delta, HeroRow, HeroValue, Legend, LegendItem, Meter, MiniCard, MiniCards, StatTile, StatTiles } from '../../components/Metrics'
import { PageHeader } from '../../components/Navigation'
import { DataTable } from '../../components/Table'

const info = (what: string) => <RoundToggle size="inline" label={`Explain: ${what}`} />
const eur = (v: number) => new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0, signDisplay: 'exceptZero' }).format(v)

const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
/** Placeholder figures: twelve months from January 2026. */
const MONTHS: ColumnDatum[] = [140, -60, 220, -310, 180, 90, 260, -120, 310, 150, -40, 200].map((value, m) => ({
  key: `2026-${m + 1}`,
  label: `${MONTH_NAMES[m]} 2026`,
  short: m === 0 ? `${MONTH_NAMES[m]} 2026` : MONTH_NAMES[m],
  value,
  guide: m % 3 === 0 ? `Q${m / 3 + 1} 2026` : undefined,
}))

const eur0 = (v: number) => new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(v)
/** Placeholder holdings as in the Positions table below (series is the holding type: 1 fund, 3 cash; this portfolio holds no share). */
const ALLOCATION: BarDatum[] = [
  { key: 'world', label: 'World fund', value: 8240, detail: 'Fund · 210 units', series: 1 },
  { key: 'em', label: 'Emerging markets fund', short: 'Emerging markets', value: 3120, detail: 'Fund · 95 units', series: 1 },
  { key: 'small', label: 'Small caps fund', value: 1970, detail: 'Fund · 40 units', series: 1 },
  { key: 'cash', label: 'Cash', value: 320, series: 3 },
]
const UNREALISED: BarDatum[] = [
  { key: 'world', label: 'World fund', value: 910, detail: 'Cost € 7,330 · Value € 8,240' },
  { key: 'em', label: 'Emerging markets fund', short: 'Emerging markets', value: 260, detail: 'Cost € 2,860 · Value € 3,120' },
  { key: 'small', label: 'Small caps fund', value: -20, detail: 'Cost € 1,990 · Value € 1,970' },
]

/** Placeholder month ends, November 2025 to October 2026: deposits step up, the result dips below zero for a few months and ends at +€ 1,150 on € 12,500 deposited. */
const DEPOSITS = Array.from({ length: 12 }, (_, i) => 7000 + 500 * i)
const GAINS = [90, 160, -60, -180, -90, 120, 260, 410, 380, 640, 890, 1150]
const TIMELINE: LinePoint[] = GAINS.map((gain, i) => {
  const m = (10 + i) % 12
  const year = 2025 + Math.floor((10 + i) / 12)
  return {
    key: `${year}-${m + 1}`,
    label: `${MONTH_NAMES[m]} ${year}`,
    short: m === 0 || i === 0 ? `${MONTH_NAMES[m]} ${year}` : MONTH_NAMES[m],
    detail: i === GAINS.length - 1 ? 'up to 13 Oct' : undefined,
    guide: m % 3 === 0 ? `Q${m / 3 + 1} ${year}` : undefined,
    values: { value: DEPOSITS[i] + gain, deposits: DEPOSITS[i], result: gain },
  }
})
const TIMELINE_SERIES: LineSeries[] = [
  { key: 'value', label: 'Total value', slot: 1 },
  { key: 'deposits', label: 'Deposits', slot: 2, step: true },
  { key: 'result', label: 'Result', slot: 3, signed: true },
]

/** A recreation of the ETF tracker's dashboard (src/apps/registry.ts, ETF_VIEWS), with placeholder figures. */
export function EtfPreview() {
  const [view, setView] = useState<'primary' | 'secondary'>('primary')
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title="Portfolio" asOf="As of 13 October 2026">
        <SegmentedChoice
          label="View"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'primary', label: 'Overview' },
            { value: 'secondary', label: 'Details' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column dkj-preview-column--wide">
        <Banner tone="warn" lead="The ledger does not match the export">
          -- one figure may differ.
        </Banner>
        <Card variant="data">
          <CardHead title="Summary" subtitle="In euro, at the last closing prices" />
          <CardBody>
            <StatTiles>
              <StatTile label="Deposited" value="€ 12,500" info={info('Deposited')} />
              <StatTile label="Invested" value="€ 12,180" info={info('Invested')} />
              <StatTile label="Cash" value="€ 320" info={info('Cash')} />
              <StatTile label="Dividend" value="+€ 86" tone="positive" info={info('Dividend')} />
            </StatTiles>
            <HeroRow>
              <HeroValue label="Total value" info={info('Total value')}>
                € 13,650
              </HeroValue>
              <HeroValue label="Result against deposits" info={info('Result against deposits')} size="lg">
                <Delta tone="up">+€ 1,150 (+9.2%)</Delta>
              </HeroValue>
            </HeroRow>
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Monthly result" info={info('Monthly result')} />
          <CardBody>
            <Legend>
              <LegendItem color="positive-3">Gain</LegendItem>
              <LegendItem color="negative-3">Loss</LegendItem>
            </Legend>
            <ColumnChart label="Result per month" data={MONTHS} format={eur} periodHeading="Month" />
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Value over time" info={info('Value over time')} />
          <CardBody>
            <Legend>
              <LegendItem color="cat-1" line>
                Total value
              </LegendItem>
              <LegendItem color="cat-2" line>
                Deposits
              </LegendItem>
              <LegendItem color="cat-3" line>
                Result
              </LegendItem>
            </Legend>
            <LineChart label="Value over time" points={TIMELINE} series={TIMELINE_SERIES} format={eur0} periodHeading="Month" />
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Positions" info={info('Positions')} />
          <CardBody>
            <DataTable
              label="Positions"
              columns={[
                { key: 'name', label: 'Product' },
                { key: 'value', label: 'Value' },
                { key: 'result', label: 'Result' },
              ]}
              rows={[
                { id: 'a', sub: 'XX0000000001', cells: { name: 'World fund', value: '€ 8,240', result: '+€ 910' }, tones: { result: 'positive' } },
                { id: 'b', sub: 'XX0000000002', cells: { name: 'Emerging markets fund', value: '€ 3,120', result: '+€ 260' }, tones: { result: 'positive' } },
                { id: 'c', sub: 'XX0000000003', cells: { name: 'Small caps fund', value: '€ 1,970', result: '−€ 20' }, tones: { result: 'negative' } },
              ]}
              total={{ label: 'Total', cells: { value: '€ 13,330', result: '+€ 1,150' }, tones: { result: 'positive' } }}
            />
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Allocation" info={info('Allocation')} />
          <CardBody>
            <Legend>
              <LegendItem color="cat-1">
                Fund
                {info('Fund')}
              </LegendItem>
              <LegendItem color="cat-3">
                Cash
                {info('Cash')}
              </LegendItem>
            </Legend>
            <BarChart
              colorBy="series"
              label="Allocation of the portfolio"
              data={ALLOCATION}
              format={eur0}
              share={(f) => `${Math.round(f * 100)}% of total`}
              itemHeading="Holding"
            />
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Unrealised result" info={info('Unrealised result')} />
          <CardBody>
            <BarChart colorBy="direction" label="Unrealised result per holding" data={UNREALISED} format={eur} itemHeading="Holding" valueHeading="Result" />
          </CardBody>
        </Card>
        <Card variant="data">
          <CardHead title="Quarterly deposits" subtitle="Target: € 1,500 per quarter" info={info('Quarterly deposits')} />
          <MiniCards>
            <MiniCard label="Q1 2026" value="€ 1,500">
              <Meter value={100} tone="good" label="100% of the target" />
              <BadgeRow badge={<Badge tone="good" size="sm">✓</Badge>}>Met</BadgeRow>
            </MiniCard>
            <MiniCard label="Q2 2026" value="€ 1,500">
              <Meter value={100} tone="good" label="100% of the target" />
              <BadgeRow badge={<Badge tone="good" size="sm">✓</Badge>}>Met</BadgeRow>
            </MiniCard>
            <MiniCard label="Q3 2026" value="€ 900">
              <Meter value={60} tone="bad" label="60% of the target" />
              <BadgeRow badge={<Badge tone="bad" size="sm">✗</Badge>}>Missed</BadgeRow>
            </MiniCard>
            <MiniCard label="Q4 2026" value="€ 300" highlight>
              <Meter value={20} tone="warn" label="20% of the target" />
              <BadgeRow badge={<Badge tone="warn" size="sm">◷</Badge>}>Still open</BadgeRow>
            </MiniCard>
          </MiniCards>
        </Card>
        <FooterNote>A recreated preview with placeholder figures. The explanations are general information to help read the figures.</FooterNote>
      </div>
    </div>
  )
}
