import { RoundToggle } from '../../components/Button'
import { Card, CardHead } from '../../components/Card'
import { Badge, BadgeList, BadgeRow, Delta, HeroRow, HeroValue, Legend, LegendItem, Meter, MiniCard, MiniCards, StatTile, StatTiles } from '../../components/Metrics'
import { Demo, Section } from '../Showcase'
import { BarChart, ColumnChart, LineChart, type BarDatum, type ColumnDatum, type LinePoint, type LineSeries } from '../../components/Chart'

const eur = (v: number) => new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0, signDisplay: 'exceptZero' }).format(v)
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const RESULTS = [120, -80, 310, -420, 180, 260, 90, -150, 340, 410, -60, 220, 150, -310, 280, 190, -90, 130]
/** Eighteen months from January 2025, a quarter guide before every January, April, July and October; the last one still running. */
const MONTHS: ColumnDatum[] = RESULTS.map((value, i) => {
  const m = i % 12
  const year = 2025 + Math.floor(i / 12)
  return {
    key: `${year}-${m + 1}`,
    label: `${MONTH_NAMES[m]} ${year}`,
    short: m === 0 || i === 0 ? `${MONTH_NAMES[m]} ${year}` : MONTH_NAMES[m],
    value,
    detail: i === RESULTS.length - 1 ? 'up to 13 Jun' : undefined,
    guide: m % 3 === 0 ? `Q${m / 3 + 1} ${year}` : undefined,
  }
})

const eur0 = (v: number) => new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(v)
const share = (f: number) => `${Math.round(f * 100)}% of total`
/** Placeholder holdings, already sorted by value, as the app would; the series is the holding type: 1 fund, 2 share, 3 cash. */
const ALLOCATION: BarDatum[] = [
  { key: 'world', label: 'World fund', value: 8240, detail: 'Fund · 210 units', series: 1 },
  { key: 'em', label: 'Emerging markets fund', short: 'Emerging markets', value: 3120, detail: 'Fund · 95 units', series: 1 },
  { key: 'bond', label: 'Bond fund', value: 1480, detail: 'Fund · 30 units', series: 1 },
  { key: 'corp', label: 'Example Corp', value: 940, detail: 'Share · 12 units', series: 2 },
  { key: 'cash', label: 'Cash', value: 320, series: 3 },
]
const UNREALISED: BarDatum[] = [
  { key: 'world', label: 'World fund', value: 910, detail: 'Cost € 7,330 · Value € 8,240' },
  { key: 'em', label: 'Emerging markets fund', short: 'Emerging markets', value: 260, detail: 'Cost € 2,860 · Value € 3,120' },
  { key: 'bond', label: 'Bond fund', value: -45, detail: 'Cost € 1,525 · Value € 1,480' },
  { key: 'small', label: 'Small caps fund', value: -120, detail: 'Cost € 2,090 · Value € 1,970' },
]

const DEPOSITS = Array.from({ length: 18 }, (_, i) => 4000 + 500 * i)
const GAINS = [60, 120, -80, -210, -340, -120, 40, 210, 380, 260, 150, 420, 610, 520, 780, 990, 880, 1150]
/** The same eighteen month ends: money in as a step, the result going below zero for a few months, the value their sum; the last month still running. */
const TIMELINE: LinePoint[] = MONTHS.map((c, i) => ({
  key: c.key,
  label: c.label,
  short: c.short,
  detail: c.detail,
  guide: c.guide,
  values: { value: DEPOSITS[i] + GAINS[i], deposits: DEPOSITS[i], result: GAINS[i] },
}))
const TIMELINE_SERIES: LineSeries[] = [
  { key: 'value', label: 'Total value', slot: 1 },
  { key: 'deposits', label: 'Deposits', slot: 2, step: true },
  { key: 'result', label: 'Result', slot: 3, signed: true },
]
const timelineLegend = (
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
)

const info = (what: string) => <RoundToggle size="inline" label={`Explain: ${what}`} />

export function Metrics() {
  return (
    <>
      <Section id="StatTile" title="StatTile" intro="A bordered tile: a small muted label, with an optional info mark after it, and one figure. The grid fits as many 160px columns as the width allows.">
        <Demo label="Grid of tiles" wide surface={false}>
          <StatTiles>
            <StatTile label="Label one" value="€ 12,400.00" info={info("Label one")} />
            <StatTile label="Label two" value="€ 1,250.00" info={info("Label two")} />
            <StatTile label="A gain" value="+€ 340.50" tone="positive" info={info("A gain")} />
            <StatTile label="A loss" value="−€ 42.10" tone="negative" info={info("A loss")} />
            <StatTile label="Warnings" value="3" tone="warn" info={info("Warnings")} />
            <StatTile label="Label six" value="€ 9.00" />
          </StatTiles>
        </Demo>
      </Section>

      <Section id="HeroValue" title="HeroValue" intro="The one big figure of a page: a muted label over a value in the house display size, h0. The secondary figure beside it is the lg size, usually a Delta.">
        <Demo label="Total and result" wide surface={false}>
          <Card variant="data">
            <HeroRow>
              <HeroValue label="Total value" info={info("Total value")}>
                € 13,650.00
              </HeroValue>
              <HeroValue label="Result against deposits" info={info("Result against deposits")} size="lg">
                <Delta tone="up">+€ 1,150.00 (+9.2%)</Delta>
              </HeroValue>
            </HeroRow>
          </Card>
        </Demo>
      </Section>

      <Section id="Delta" title="Delta" intro="A change in direction: a ▲ or ▼, then the figure with its sign. Green is up and red is down, in the text versions of the colours; the sign is in the text, so the colour is never the only signal.">
        <Demo label="Up / down">
          <div className="dkj-demo-row">
            <Delta tone="up">+€ 1,150.00 (+9.2%)</Delta>
            <Delta tone="down">−€ 320.00 (−2.4%)</Delta>
          </div>
        </Demo>
      </Section>

      <Section id="Legend" title="Legend" intro="A row of swatches above a chart. Each series takes one of --cat-1 .. --cat-3 and keeps it in the whole view; gain uses --positive-3 and loss uses --negative-3. A line series gets a short line instead of a square.">
        <Demo label="Squares -- series, with info marks">
          <Legend>
            <LegendItem color="cat-1">
              Series one
              {info("Series one")}
            </LegendItem>
            <LegendItem color="cat-2">
              Series two
              {info("Series two")}
            </LegendItem>
            <LegendItem color="cat-3">
              Series three
              {info("Series three")}
            </LegendItem>
          </Legend>
        </Demo>
        <Demo label="Squares -- gain and loss">
          <Legend>
            <LegendItem color="positive-3">Gain</LegendItem>
            <LegendItem color="negative-3">Loss</LegendItem>
          </Legend>
        </Demo>
        <Demo label="Lines">
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
        </Demo>
      </Section>

      <Section id="ColumnChart" title="ColumnChart" intro="A result per period around a zero line: gain up in --positive-3, loss down in --negative-3, quarter guides, a legend above. It draws at its real width, so its labels stay 12px on a phone and thin out to what fits. Hover, or tab to it and use the arrow keys, for a value; the same figures are always a table away.">
        <Demo label="Result per month, with quarter guides" wide>
          <Legend>
            <LegendItem color="positive-3">Gain</LegendItem>
            <LegendItem color="negative-3">Loss</LegendItem>
          </Legend>
          <ColumnChart label="Result per month" data={MONTHS} format={eur} periodHeading="Month" />
        </Demo>
        <Demo label="At phone width (360px)">
          <div style={{ maxWidth: '360px' }}>
            <Legend>
              <LegendItem color="positive-3">Gain</LegendItem>
              <LegendItem color="negative-3">Loss</LegendItem>
            </Legend>
            <ColumnChart label="Result per month" data={MONTHS} format={eur} periodHeading="Month" />
          </div>
        </Demo>
      </Section>

      <Section id="BarChart" title="BarChart" intro="A value per row as a horizontal bar, in the order you give it. Coloured by series, each bar takes its --cat colour and a legend above is the key; coloured by direction, a gain runs right in --positive-3 and a loss left in --negative-3 from the zero line. It draws at its real width, so on a phone the rows stack and the labels stay 12px. Hover, or tab to it and use the arrow keys, for a value; the same figures are always a table away.">
        <Demo label="Allocation, by series, with share of the total" wide>
          <Legend>
            <LegendItem color="cat-1">Fund</LegendItem>
            <LegendItem color="cat-2">Share</LegendItem>
            <LegendItem color="cat-3">Cash</LegendItem>
          </Legend>
          <BarChart colorBy="series" label="Allocation" data={ALLOCATION} format={eur0} share={share} itemHeading="Holding" />
        </Demo>
        <Demo label="Unrealised result, by direction" wide>
          <BarChart colorBy="direction" label="Unrealised result per holding" data={UNREALISED} format={eur} itemHeading="Holding" valueHeading="Result" />
        </Demo>
        <Demo label="At phone width (360px)">
          <div style={{ maxWidth: '360px' }}>
            <Legend>
              <LegendItem color="cat-1">Fund</LegendItem>
              <LegendItem color="cat-2">Share</LegendItem>
              <LegendItem color="cat-3">Cash</LegendItem>
            </Legend>
            <BarChart colorBy="series" label="Allocation" data={ALLOCATION} format={eur0} share={share} itemHeading="Holding" />
            <BarChart colorBy="direction" label="Unrealised result per holding" data={UNREALISED} format={eur} itemHeading="Holding" valueHeading="Result" />
          </div>
        </Demo>
      </Section>

      <Section id="LineChart" title="LineChart" intro="Several series over evenly spaced points, each in its own --cat colour; a step series, like deposits, changes on a date and stays. The axis always takes in zero, so a series can go below it. It draws at its real width, so its labels stay 12px on a phone, and from 560px each line is named at its end. Hover, or tab to it and use the arrow keys, for a crosshair marking every series; the same figures are always a table away.">
        <Demo label="Value, deposits and result per month end, with quarter guides" wide>
          {timelineLegend}
          <LineChart label="Value over time" points={TIMELINE} series={TIMELINE_SERIES} format={eur0} periodHeading="Month" />
        </Demo>
        <Demo label="At phone width (360px)">
          <div style={{ maxWidth: '360px' }}>
            {timelineLegend}
            <LineChart label="Value over time" points={TIMELINE} series={TIMELINE_SERIES} format={eur0} periodHeading="Month" />
          </div>
        </Demo>
      </Section>

      <Section id="MiniCard" title="MiniCard" intro="A small bordered card: a muted label, a figure, then what you put under it. The grid fits as many 104px columns as the width allows; the highlighted one has a warning border.">
        <Demo label="Quarter cards" wide surface={false}>
          <Card variant="data">
            <CardHead title="Quarterly goals" subtitle="Target: € 1,500 per quarter" />
            <MiniCards>
              <MiniCard label="Q1 2026" value="€ 1,500">
                <Meter value={100} tone="good" label="100% of the target" />
                <BadgeRow badge={<Badge tone="good" size="sm">✓</Badge>}>Met</BadgeRow>
                <div className="note">€ 120 more than the target</div>
              </MiniCard>
              <MiniCard label="Q2 2026" value="€ 600">
                <Meter value={40} tone="bad" label="40% of the target" />
                <BadgeRow badge={<Badge tone="bad" size="sm">✗</Badge>}>Missed</BadgeRow>
                <div className="note">€ 900 behind schedule</div>
              </MiniCard>
              <MiniCard label="Q3 2026" value="€ 1,500">
                <Meter value={100} tone="series" label="100% of the target" />
                <BadgeRow badge={<Badge tone="series" size="sm">=</Badge>}>Covered</BadgeRow>
                <div className="note">On schedule</div>
              </MiniCard>
              <MiniCard label="Q4 2026" value="€ 300" highlight>
                <Meter value={20} tone="warn" label="20% of the target" />
                <BadgeRow badge={<Badge tone="warn" size="sm">◷</Badge>}>Still open</BadgeRow>
                <div className="note">€ 1,200 to go · 46 days left</div>
              </MiniCard>
            </MiniCards>
          </Card>
        </Demo>
      </Section>

      <Section id="Meter" title="Meter" intro="A thin progress bar, an image with a text alternative. Its colour is a status token: good, warn, bad, info (the theme's primary) or series (--cat-1).">
        <Demo label="Tones">
          <Meter value={100} tone="good" label="Good, 100%" />
          <Meter value={60} tone="warn" label="Warn, 60%" />
          <Meter value={30} tone="bad" label="Bad, 30%" />
          <Meter value={75} tone="info" label="Info, 75%" />
          <Meter value={50} tone="series" label="Series, 50%" />
        </Demo>
      </Section>

      <Section id="Badge" title="Badge" intro="A small round status mark with a glyph. The colour is a status token (--positive-3, --warning-3, --negative-3, the primary, --cat-1), the glyph is --primary-1, and the status is also written next to it: the glyph alone is decorative.">
        <Demo label="Tones, 20px">
          <div className="dkj-demo-row">
            <Badge tone="good">✓</Badge>
            <Badge tone="warn">!</Badge>
            <Badge tone="bad">✗</Badge>
            <Badge tone="info">i</Badge>
            <Badge tone="series">=</Badge>
            <Badge tone="neutral">?</Badge>
          </div>
        </Demo>
        <Demo label="Small, 18px, with its text">
          <BadgeRow badge={<Badge tone="good" size="sm">✓</Badge>}>Doing well (3)</BadgeRow>
          <BadgeRow badge={<Badge tone="warn" size="sm">!</Badge>}>Pay attention (2)</BadgeRow>
        </Demo>
        <Demo label="BadgeList -- several badged items as a list; a long item wraps with its badge on the first line">
          <BadgeList
            label="Checks"
            items={[
              { id: 'e', badge: <Badge tone="bad" size="sm">!</Badge>, text: 'Error: the lens for specialist 05-05 is missing.' },
              { id: 'i', badge: <Badge tone="info" size="sm">i</Badge>, text: 'Info: a newer release is available; this checkout runs the one before it, which still works but no longer receives fixes.' },
              { id: 's', badge: <Badge tone="neutral" size="sm">-</Badge>, text: 'Skip: no CI workflow to check.' },
            ]}
          />
        </Demo>
      </Section>
    </>
  )
}
