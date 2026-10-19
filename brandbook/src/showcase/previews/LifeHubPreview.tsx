import { useState } from 'react'
import { Button, SegmentedChoice } from '../../components/Button'
import { Card, CardBody } from '../../components/Card'
import { DateList, DateRow } from '../../components/DateRow'
import { Prose } from '../../components/Prose'
import { FooterNote, GroupHeading } from '../../components/Content'
import { Message, TitleTag } from '../../components/Feedback'
import { Badge, BadgeRow, Meter, StatTile, StatTiles, type StatusTone } from '../../components/Metrics'
import { PageHeader } from '../../components/Navigation'

type View = 'hub' | 'dossier'
type Phase = 'urgent' | 'running' | 'done'

type Doc = { intro: string; sections: readonly { heading: string; text: string; tasks: readonly { label: string; done: boolean }[] }[] }

type Dossier = {
  id: string
  parent?: string
  category: string
  slug: string
  title: string
  phase: Phase
  date: string
  summary: string
  open: number
  total: number
  doc: Doc
  /** A second document: only then does the detail page show its two-option toggle. */
  second?: string
}

const sample = (n: number): Doc => ({
  intro: 'An invented introduction: a short paragraph that says what this dossier is about.',
  sections: [
    {
      heading: 'Section one',
      text: 'Example text for the first section of the document.',
      tasks: Array.from({ length: n }, (_, i) => ({ label: `Example action ${i + 1}`, done: i % 2 === 0 })),
    },
    { heading: 'Section two', text: 'Example text for the second section of the document.', tasks: [] },
  ],
})

/** Placeholder dossiers: invented titles, categories and dates; nothing copied from a real archive. */
const DOSSIERS: readonly Dossier[] = [
  { id: 'a', category: 'Home', slug: 'dossier-a', title: 'Dossier A', phase: 'urgent', date: '2026-10-20', summary: 'An example summary of the first dossier.', open: 3, total: 4, doc: sample(4), second: 'Notes' },
  { id: 'a1', parent: 'a', category: 'Home', slug: 'dossier-a/part-1', title: 'Dossier A, part 1', phase: 'running', date: '2026-10-25', summary: 'An example subfolder of Dossier A.', open: 1, total: 2, doc: sample(2) },
  { id: 'a2', parent: 'a', category: 'Home', slug: 'dossier-a/part-2', title: 'Dossier A, part 2', phase: 'done', date: '2026-09-30', summary: 'A second example subfolder, already finished.', open: 0, total: 2, doc: sample(2) },
  { id: 'b', category: 'Home', slug: 'dossier-b', title: 'Dossier B', phase: 'running', date: '2026-11-15', summary: 'An example summary of the second dossier.', open: 2, total: 5, doc: sample(5) },
  { id: 'c', category: 'Admin', slug: 'dossier-c', title: 'Dossier C', phase: 'done', date: '2026-08-12', summary: 'An example summary of a finished dossier.', open: 0, total: 3, doc: sample(3) },
]

const TOP = DOSSIERS.filter((d) => !d.parent)
const CATEGORIES = [...new Set(TOP.map((d) => d.category))]

const PHASES: Record<Phase, { label: string; tone: StatusTone; glyph: string }> = {
  urgent: { label: 'Urgent', tone: 'bad', glyph: '!' },
  running: { label: 'Running', tone: 'info', glyph: '◷' },
  done: { label: 'Done', tone: 'good', glyph: '✓' },
}

/** Invented apps; the real hub links to its sibling local apps. */
const APPS_LIST = [
  { title: 'Example app one', tag: 'Tools', text: 'An invented app with a short description.', path: '/app-one' },
  { title: 'Example app two', tag: 'Planning', text: 'Another invented app with a short description.', path: '/app-two' },
  { title: 'Example app three', tag: 'Reference', text: 'A third invented app with a short description.', path: '/app-three' },
] as const

/** Invented calendar items: a distance label, a title and a muted date; one near, one invalid. */
const COMING_UP = [
  { distance: 'Tomorrow', title: 'Example appointment', date: '2026-10-14', near: true },
  { distance: 'In 6 days', title: 'Example deadline', date: '2026-10-19', near: false },
  { distance: 'In 3 weeks', title: 'Example renewal', date: '2026-11-03', near: false },
] as const

function DossierCards({ items, onOpen }: { items: readonly Dossier[]; onOpen: (id: string) => void }) {
  return (
    <div className="dkj-preview-tiles">
      {items.map((d) => {
        const p = PHASES[d.phase]
        return (
          <Card key={d.id}>
            <CardBody>
              <Message>{d.slug}</Message>
              <strong>{d.title}</strong>
              <BadgeRow
                badge={
                  <Badge tone={p.tone} size="sm">
                    {p.glyph}
                  </Badge>
                }
              >
                {p.label}
              </BadgeRow>
              <Message>Status: {d.date}</Message>
              <p>{d.summary}</p>
              <Meter value={d.total === 0 ? 0 : ((d.total - d.open) / d.total) * 100} tone={p.tone} label={`Progress: ${d.open} open of ${d.total}`} />
              <Message>{`${d.open} open of ${d.total}`}</Message>
              <div className="dkj-preview-gap">
                <Button variant="outline" size="compact" onClick={() => onOpen(d.id)}>
                  Open dossier
                  <span className="sr-only"> {d.title}</span>
                </Button>
              </div>
            </CardBody>
          </Card>
        )
      })}
    </div>
  )
}

function Hub({ onOpen }: { onOpen: (id: string) => void }) {
  const open = TOP.reduce((n, d) => n + d.open, 0)
  return (
    <>
      <StatTiles>
        <StatTile label="Apps" value={APPS_LIST.length} />
        <StatTile label="Dossiers" value={TOP.length} />
        <StatTile label="Open actions" value={open} />
      </StatTiles>

      <div>
        <GroupHeading level={2}>Coming up</GroupHeading>
        <DateList label="Coming up">
          {COMING_UP.map((c) => (
            <DateRow key={c.title} when={c.distance} date={c.date} title={c.title} sub={c.date} state={c.near ? 'near' : 'default'} />
          ))}
          <DateRow title="Example item with an unreadable date" state="invalid" reason="This item could not be placed: the date is not valid." />
        </DateList>
      </div>

      <div>
        <GroupHeading level={2}>Available apps</GroupHeading>
        <div className="dkj-preview-tiles">
          {APPS_LIST.map((a) => (
            <Card key={a.title}>
              <CardBody>
                <strong>{a.title}</strong> <TitleTag tone="info">{a.tag}</TitleTag>
                <p>{a.text}</p>
                <Message>Open {a.path}</Message>
              </CardBody>
            </Card>
          ))}
        </div>
      </div>

      <div>
        <GroupHeading level={2}>My dossiers</GroupHeading>
        <Message>Everything in one place, grouped by category.</Message>
      </div>
      {CATEGORIES.map((cat) => {
        const items = TOP.filter((d) => d.category === cat)
        return (
          <div key={cat}>
            <GroupHeading level={3} count={items.length}>{cat}</GroupHeading>
            <DossierCards items={items} onOpen={onOpen} />
          </div>
        )
      })}
    </>
  )
}

function DossierDetail({ dossier, onBack, onOpen }: { dossier: Dossier; onBack: () => void; onOpen: (id: string) => void }) {
  const [which, setWhich] = useState<'main' | 'second'>('main')
  const parent = DOSSIERS.find((d) => d.id === dossier.parent)
  const children = DOSSIERS.filter((d) => d.parent === dossier.id)
  const shown = which === 'main' || !dossier.second ? dossier.doc : sample(1)
  return (
    <>
      <div>
        <Button variant="outline" size="compact" onClick={onBack}>
          &larr; {parent ? parent.title : 'My dossiers'}
        </Button>
      </div>
      <Message>Dossier · {dossier.slug}</Message>
      {dossier.second && (
        <SegmentedChoice
          label="Document"
          layout="joined"
          value={which}
          onChange={setWhich}
          options={[
            { value: 'main', label: 'Overview' },
            { value: 'second', label: dossier.second },
          ]}
        />
      )}
      <div>
        <Button variant="outline" size="compact">
          Save as PDF
        </Button>
      </div>

      <Card variant="data">
        <CardBody>
          <Prose>
            <p>{shown.intro}</p>
          </Prose>
          {shown.sections.map((s) => (
            <div key={s.heading} className="dkj-preview-gap">
              <GroupHeading level={2}>{s.heading}</GroupHeading>
              <Prose>
                <p>{s.text}</p>
                {s.tasks.length > 0 && (
                  <ul>
                    {s.tasks.map((t) => {
                      const id = `task-${s.heading}-${t.label}`.replace(/\W+/g, '-')
                      return (
                        <li key={t.label}>
                          <input type="checkbox" checked={t.done} disabled aria-labelledby={id} />
                          <span id={id}>{t.label}</span>
                        </li>
                      )
                    })}
                  </ul>
                )}
              </Prose>
            </div>
          ))}
        </CardBody>
      </Card>

      {children.length > 0 && (
        <div>
          <GroupHeading level={2} count={children.length}>Subfolders</GroupHeading>
          <DossierCards items={children} onOpen={onOpen} />
        </div>
      )}
    </>
  )
}

/** A recreation of the two screens of dkj-lifehub (the hub and a dossier page), with placeholder content. */
export function LifeHubPreview() {
  const [view, setView] = useState<View>('hub')
  const [openId, setOpenId] = useState(DOSSIERS[0].id)
  const dossier = DOSSIERS.find((d) => d.id === openId) ?? DOSSIERS[0]
  const open = (id: string) => {
    setOpenId(id)
    setView('dossier')
  }
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title={view === 'hub' ? 'My hub' : dossier.title}>
        <SegmentedChoice
          label="Screen"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'hub', label: 'Hub' },
            { value: 'dossier', label: 'Dossier' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column">
        {view === 'hub' ? (
          <Hub onOpen={open} />
        ) : (
          <DossierDetail
            key={dossier.id}
            dossier={dossier}
            onBack={() => (dossier.parent ? open(dossier.parent) : setView('hub'))}
            onOpen={open}
          />
        )}
        <FooterNote>A recreated preview; every dossier, app, date and document is invented. The real app runs locally.</FooterNote>
      </div>
    </div>
  )
}
