import { useState } from 'react'
import { SegmentedChoice } from '../../components/Button'
import { Card, CardBody, TintedPanel } from '../../components/Card'
import { FooterNote, GroupHeading } from '../../components/Content'
import { Prose } from '../../components/Prose'
import { Chip, Disclosure, Message } from '../../components/Feedback'
import { Figure } from '../../components/Figure'
import { StatTile, StatTiles } from '../../components/Metrics'
import { PageHeader } from '../../components/Navigation'
import { DataTable, DefinitionList, type DataColumn, type DataRow } from '../../components/Table'

type View = 'report' | 'sheet'

const DASH = '—'
const ROUNDS = ['Round A', 'Round B', 'Round C', 'Round D'] as const

/** One report section: a table with one row per round; a cell is text, DASH meaning "not measured". */
type Section = {
  title: string
  columns: readonly DataColumn[]
  /** Per round, the cells after the round name, with a tone for a verdict that can be read as good or bad. */
  rows: readonly (readonly { text: string; tone?: 'positive' | 'negative' }[])[]
}

/** Placeholder sections and values: invented, neutral figures; nothing measured in a real series. */
const SECTIONS: readonly Section[] = [
  {
    title: '1. Position',
    columns: [
      { key: 'round', label: 'Round' },
      { key: 'offset', label: 'Offset' },
      { key: 'verdict', label: 'Within the margin' },
    ],
    rows: [
      [{ text: '2 px' }, { text: 'yes', tone: 'positive' }],
      [{ text: '12 px' }, { text: 'outside the margin', tone: 'negative' }],
      [{ text: '5 px' }, { text: 'yes', tone: 'positive' }],
      [{ text: DASH }, { text: DASH }],
    ],
  },
  {
    title: '2. Options',
    columns: [
      { key: 'round', label: 'Round' },
      { key: 'made', label: 'Made' },
      { key: 'kept', label: 'Kept' },
    ],
    rows: [[{ text: '4' }, { text: '1' }], [{ text: '4' }, { text: '0' }], [{ text: '4' }, { text: '2' }], [{ text: '4' }, { text: DASH }]],
  },
  {
    title: '3. Isolation',
    columns: [
      { key: 'round', label: 'Round' },
      { key: 'edge', label: 'Clean edge' },
    ],
    rows: [[{ text: 'yes', tone: 'positive' }], [{ text: 'no', tone: 'negative' }], [{ text: 'no verdict — example reason' }], [{ text: DASH }]],
  },
  {
    title: '4. Guide check',
    columns: [
      { key: 'round', label: 'Round' },
      { key: 'fit', label: 'Matches the guide' },
    ],
    rows: [[{ text: 'yes', tone: 'positive' }], [{ text: 'yes', tone: 'positive' }], [{ text: 'no', tone: 'negative' }], [{ text: DASH }]],
  },
  {
    title: '5. Usage',
    columns: [
      { key: 'round', label: 'Round' },
      { key: 'units', label: 'Units used' },
    ],
    rows: [[{ text: '4' }], [{ text: '4' }], [{ text: '4' }], [{ text: DASH }]],
  },
]

const tableRows = (s: Section): DataRow[] =>
  ROUNDS.map((round, i) => {
    const cells: Record<string, string> = { [s.columns[0].key]: round }
    const tones: Record<string, 'positive' | 'negative' | undefined> = {}
    s.rows[i].forEach((c, j) => {
      cells[s.columns[j + 1].key] = c.text
      tones[s.columns[j + 1].key] = c.tone
    })
    return { id: round, cells, tones }
  })

const NOTES: readonly { round: string; date: string; verdict: 'yes' | 'no' | 'unknown' | 'todo'; text: string }[] = [
  { round: 'Round A', date: '1 Jan 2026', verdict: 'yes', text: 'Example note: one candidate kept, placed inside the margin.' },
  { round: 'Round B', date: '8 Jan 2026', verdict: 'no', text: 'Example note: every candidate discarded; the placement was outside the margin.' },
  { round: 'Round C', date: '15 Jan 2026', verdict: 'unknown', text: 'Example note: two candidates kept; the cutout has no verdict, for an example reason.' },
  { round: 'Round D', date: '22 Jan 2026', verdict: 'todo', text: 'Example note: planned, nothing measured yet.' },
]

const VERDICT_LABEL = { yes: 'Within the margin', no: 'Outside the margin', unknown: 'No verdict', todo: 'Planned' } as const

function YardstickReport() {
  return (
    <>
      <Message>Generated on 2026-01-01</Message>
      <Message tone="note">Generated report; edit the data, not this page.</Message>
      <Prose>
        <p>A short introduction: each round below is measured against the same yardstick, and a dash means the value was not measured.</p>
      </Prose>

      <GroupHeading level={2}>Series summary</GroupHeading>
      <StatTiles>
        <StatTile label="Rounds" value="4" />
        <StatTile label="Measured" value="3" />
        <StatTile label="Within the margin" value="2" tone="positive" />
        <StatTile label="Outside the margin" value="1" tone="negative" />
      </StatTiles>

      {SECTIONS.map((s) => (
        <Card key={s.title} variant="data">
          <CardBody>
            <GroupHeading level={2}>{s.title}</GroupHeading>
            <DataTable label={s.title} columns={s.columns} rows={tableRows(s)} />
          </CardBody>
        </Card>
      ))}

      <Card variant="data">
        <CardBody>
          <GroupHeading level={2}>Notes per round</GroupHeading>
          {NOTES.map((n) => (
            <Disclosure
              key={n.round}
              summary={n.round}
              meta={n.date}
              trailing={<Chip tone={n.verdict}>{VERDICT_LABEL[n.verdict]}</Chip>}
            >
              <Prose size="sm">
                <p>{n.text}</p>
              </Prose>
            </Disclosure>
          ))}
        </CardBody>
      </Card>
    </>
  )
}

const CANDIDATES = [
  { label: 'Candidate 1', verdict: 'yes' as const, text: 'Within the margin' },
  { label: 'Candidate 2', verdict: 'no' as const, text: 'Outside the margin' },
  { label: 'Candidate 3', verdict: 'yes' as const, text: 'Within the margin' },
  { label: 'Candidate 4', verdict: 'no' as const, text: 'Outside the margin' },
]

function ContactSheet() {
  return (
    <>
      <Message>A generated image: four candidates side by side, then the ones to discard and to retain. The images below are placeholders.</Message>
      <TintedPanel>
        <div className="dkj-preview-candidates">
          {CANDIDATES.map((c) => (
            <Figure
              key={c.label}
              placeholder
              ratio="16/9"
              placeholderLabel={c.label}
              caption={
                <>
                  {c.label} <Chip tone={c.verdict}>{c.text}</Chip>
                </>
              }
            />
          ))}
        </div>
      </TintedPanel>
      <Card variant="data">
        <CardBody>
          <DefinitionList
            variant="facts"
            items={[
              { term: 'Discard', value: 'Candidates 2 and 4' },
              { term: 'Retain', value: 'Candidates 1 and 3' },
            ]}
          />
        </CardBody>
      </Card>
    </>
  )
}

/** A recreation of the two outputs of dkj-thumbnail-generator (the measurement report and the contact sheet), with placeholder content. */
export function ThumbnailPreview() {
  const [view, setView] = useState<View>('report')
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title={view === 'report' ? 'Yardstick report' : 'Contact sheet'}>
        <SegmentedChoice
          label="Output"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'report', label: 'Yardstick report' },
            { value: 'sheet', label: 'Contact sheet' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column">
        {view === 'report' ? <YardstickReport /> : <ContactSheet />}
        <FooterNote>A recreated preview; every round, value and image is invented. The real repo has no interface: these are its two generated outputs.</FooterNote>
      </div>
    </div>
  )
}
