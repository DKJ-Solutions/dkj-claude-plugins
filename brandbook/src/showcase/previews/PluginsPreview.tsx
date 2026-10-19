import { useState } from 'react'
import { SegmentedChoice } from '../../components/Button'
import { Card, CardBody, CardHead } from '../../components/Card'
import { FooterNote, GroupHeading } from '../../components/Content'
import { Prose } from '../../components/Prose'
import { Banner, Disclosure, Message, TitleTag } from '../../components/Feedback'
import { Badge, BadgeRow } from '../../components/Metrics'
import { PageHeader } from '../../components/Navigation'
import { DataTable } from '../../components/Table'

type Issue = { n: number; title: string; labels: readonly string[]; detail: string; skip?: string }

/** Placeholder issues: invented titles, no real tracker content. */
const ISSUES: readonly Issue[] = [
  { n: 101, title: 'Example issue that is ready to be swept', labels: ['bug', 'prio-1'], detail: 'Assigned: nobody · Unblocks: #104' },
  { n: 102, title: 'Another example issue with a longer placeholder title', labels: ['feature'], detail: 'Assigned: someone · PR: #110' },
  { n: 103, title: 'Example issue that waits for another one', labels: ['docs'], detail: 'Blocked by: #101', skip: 'Blocked by an open issue' },
  { n: 104, title: 'Example follow-up issue', labels: ['bug', 'prio-2'], detail: 'Assigned: nobody' },
  { n: 105, title: 'Example issue claimed by somebody else', labels: ['feature'], detail: 'Assigned: someone else', skip: 'Assigned to another account' },
]

type Release = { version: string; title: string; date: string; sections: readonly { heading: string; items: readonly string[]; code?: boolean }[] }

/** Placeholder releases: invented versions and notes. */
const RELEASES: readonly Release[] = [
  {
    version: 'v2.1.0',
    title: 'Example release title',
    date: '12 October 2026',
    sections: [
      { heading: 'Added', items: ['A placeholder feature in one line', 'Another placeholder feature'] },
      { heading: 'Fixed', items: ['A placeholder fix'] },
      { heading: 'Scripts', items: ['example-script.ps1', 'another-script.ps1'], code: true },
    ],
  },
  { version: 'v2.0.0', title: 'Another example release', date: '1 October 2026', sections: [{ heading: 'Added', items: ['The first placeholder release'] }] },
  { version: 'v1.9.3', title: 'A small example fix release', date: '20 September 2026', sections: [{ heading: 'Fixed', items: ['A placeholder fix', 'Another placeholder fix'] }] },
]

function IssueDashboard() {
  const skipped = ISSUES.filter((i) => i.skip).length
  return (
    <>
      <Message>Generated 13 October 2026, 09:00 · {ISSUES.length} open issues</Message>
      <BadgeRow badge={<Badge tone="good" size="sm">✓</Badge>}>{`Sweepable ${ISSUES.length - skipped}`}</BadgeRow>
      <BadgeRow badge={<Badge tone="bad" size="sm">✗</Badge>}>{`Skip ${skipped}`}</BadgeRow>
      <Banner tone="warn" lead="Read with care">
        Placeholder warnings the page raises before the list:
        <ul>
          <li>One example issue has no label.</li>
          <li>One example issue was edited after it was claimed.</li>
        </ul>
      </Banner>
      <Card variant="data">
        <CardHead title="Open issues" />
        <CardBody>
          <DataTable
            label="Open issues"
            columns={[
              { key: 'issue', label: 'Issue' },
              { key: 'labels', label: 'Labels' },
            ]}
            rows={ISSUES.map((i) => ({
              id: String(i.n),
              sub: i.skip ? `Skipped: ${i.skip} · ${i.detail}` : i.detail,
              cells: {
                issue: (
                  <>
                    <strong>#{i.n}</strong> {i.title}
                  </>
                ),
                labels: i.labels.join(', '),
              },
              tones: i.skip ? { issue: 'negative' } : undefined,
            }))}
            empty="No open issues"
          />
        </CardBody>
      </Card>
    </>
  )
}

function ReleaseNotes() {
  return (
    <>
      <TitleTag>Example product</TitleTag>
      <Message>Every release is a row; open one to read it.</Message>
      <Card variant="data">
        <CardBody>
          {RELEASES.map((r) => (
            <Disclosure
              key={r.version}
              summary={
                <>
                  <span className="dkj-disclosure-version">{r.version}</span> {r.title}
                </>
              }
              meta={r.date}
              trailing={r === RELEASES[0] ? <TitleTag>Latest</TitleTag> : undefined}
            >
              {r.sections.map((sec) => (
                <div key={sec.heading}>
                  <GroupHeading level={2} count={sec.items.length}>{sec.heading}</GroupHeading>
                  <Prose size="sm">
                    <ul>
                      {sec.items.map((item) => (
                        <li key={item}>{sec.code ? <code>{item}</code> : item}</li>
                      ))}
                    </ul>
                  </Prose>
                </div>
              ))}
            </Disclosure>
          ))}
        </CardBody>
      </Card>
      <Message>Snapshot of 13 October 2026, built from the release documents.</Message>
    </>
  )
}

/** A recreation of the two generated pages of dkj-claude-plugins (src/apps/registry.ts, PLUGINS_VIEWS), with placeholder content. */
export function PluginsPreview() {
  const [view, setView] = useState<'issues' | 'releases'>('issues')
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title={view === 'issues' ? 'Issue dashboard — example-org/example-repo' : 'Release notes'}>
        <SegmentedChoice
          label="Page"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'issues', label: 'Issue dashboard' },
            { value: 'releases', label: 'Release notes' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column dkj-preview-column--wide">
        {view === 'issues' ? <IssueDashboard /> : <ReleaseNotes />}
        <FooterNote>
          A recreated preview with placeholder content. The real product of this repo is a plugin (policy, skills and scripts), not an app; these are its two generated pages.
        </FooterNote>
      </div>
    </div>
  )
}
