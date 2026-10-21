import { Button } from '../components/Button'
import { Card, CardBody, CardGroup, CardHead } from '../components/Card'
import { FooterNote } from '../components/Content'
import { Disclosure, Message } from '../components/Feedback'
import { PageLinks } from '../components/Navigation'
import { Badge, BadgeList, BadgeRow, StatTile, StatTiles, type StatusTone } from '../components/Metrics'
import { DataTable, DefinitionList } from '../components/Table'
import { DashboardIntro, InFlightCards, InFlightTiles, type InFlight } from './DashboardShell'

/**
 * Preview of the "Connected repos" dashboard of a plugin-source repo, rendered in the Repo hub's shape: the shared
 * shell first, then the repo-specific sections, then "About this repo" and the footer note. Placeholder data only: invented repos, plugins and notes.
 */
const REPO = 'example-org/example-plugins'
const TRUNK = 'main'
const SOURCE_COMMIT = 'f0e1d2c'

const IN_FLIGHT: InFlight = {
  pulls: [
    { number: 212, title: 'Example change to a shared skill', html_url: '#', draft: false, created_at: '2026-10-12T09:00:00Z', head: { ref: 'feat/example-skill' } },
    { number: 211, title: 'Example fix for a script', html_url: '#', draft: true, created_at: '2026-10-09T09:00:00Z', head: { ref: 'fix/example-script' } },
  ],
  issues: [
    { number: 305, title: 'Example issue with a priority', html_url: '#', updated_at: '2026-10-12T09:00:00Z', labels: [{ name: 'bug' }, { name: 'prio-1' }], assignees: [] },
    { number: 301, title: 'Another example issue, claimed', html_url: '#', updated_at: '2026-10-10T09:00:00Z', labels: [{ name: 'feature' }], assignees: [{ login: 'example-user' }] },
  ],
  branches: [{ name: 'feat/example-skill' }, { name: 'fix/example-script' }, { name: 'docs/example-page' }],
}

/** The repo's own pages, as inert placeholder links (the preview has no routes). */
const PAGES = [
  { label: 'Connected repos', href: '#', description: 'Every registered repo and its checks, worst first' },
  { label: 'SessionStart measurements', href: '#', description: 'What a session loads before the first assignment' },
  { label: 'Test-gate measurements', href: '#', description: 'How long the test gate runs, over time' },
] as const

/** The pages every DKJ-Solutions repo serves: the General group of the Pages block (#206). */
const GENERAL_PAGES = [
  { label: 'Issues', href: '#', description: 'Open and closed, on GitHub' },
  { label: 'Release notes', href: '#', description: 'What each plugin release changed' },
] as const

type Status = 'bad' | 'warn' | 'good' | 'skip'
type Signal = { kind: 'error' | 'info' | 'skip'; plugin?: string; text: string }
type Repo = {
  name: string
  status: Status
  visibility: 'public' | 'private'
  plugins: readonly { id: string; lenses: number }[]
  installed: string
  git: { branch: string; uncommitted: number; ahead: number; behind: number } | null
  lastCommit: string
  drift: string | null
  signals: readonly Signal[]
  notes: readonly string[]
}

/** Sorted worst first, as the real dashboard sorts them. */
const REPOS: readonly Repo[] = [
  {
    name: 'example-org/repo-a',
    status: 'bad',
    visibility: 'private',
    plugins: [{ id: 'example-policy', lenses: 4 }, { id: 'example-team', lenses: 9 }],
    installed: '2.1.0',
    git: { branch: 'main', uncommitted: 2, ahead: 0, behind: 1 },
    lastCommit: 'a1b2c3d Example commit subject',
    drift: 'Agent definition of example-team differs from the source.',
    signals: [
      { kind: 'error', plugin: 'example-team', text: 'A lens refers to a persona that no longer exists.' },
      { kind: 'info', text: 'The checkout is one commit behind its remote.' },
    ],
    notes: ['Registered on 1 October 2026.', 'Placeholder note about how this repo was connected.'],
  },
  {
    name: 'example-org/repo-b',
    status: 'warn',
    visibility: 'public',
    plugins: [{ id: 'example-policy', lenses: 2 }],
    installed: '2.0.4',
    git: { branch: 'feat/example', uncommitted: 0, ahead: 3, behind: 0 },
    lastCommit: 'e4f5a6b Another example commit subject',
    drift: null,
    signals: [{ kind: 'info', plugin: 'example-policy', text: 'A newer plugin version is available.' }],
    notes: ['Registered on 20 September 2026.'],
  },
  {
    name: 'example-org/repo-c',
    status: 'good',
    visibility: 'public',
    plugins: [{ id: 'example-policy', lenses: 3 }, { id: 'example-team', lenses: 7 }],
    installed: '2.1.0',
    git: { branch: 'main', uncommitted: 0, ahead: 0, behind: 0 },
    lastCommit: '7c8d9e0 Third example commit subject',
    drift: null,
    signals: [],
    notes: [],
  },
  {
    name: 'example-org/repo-d',
    status: 'skip',
    visibility: 'private',
    plugins: [],
    installed: '--',
    git: null,
    lastCommit: '',
    drift: null,
    signals: [{ kind: 'skip', text: 'Not checked out on this machine.' }],
    notes: ['Registered on 5 August 2026.'],
  },
]

const STATUS: Record<Status, { tone: StatusTone | 'neutral'; glyph: string; word: string }> = {
  bad: { tone: 'bad', glyph: '!', word: 'bad' },
  warn: { tone: 'warn', glyph: '!', word: 'warn' },
  good: { tone: 'good', glyph: '✓', word: 'good' },
  skip: { tone: 'neutral', glyph: '-', word: 'skip' },
}
const SIGNAL = { error: { tone: 'bad', glyph: '!' }, info: { tone: 'info', glyph: 'i' }, skip: { tone: 'neutral', glyph: '-' } } as const

const slug = (name: string) => name.replace(/[^a-z0-9]+/gi, '-')
const gitLine = (g: Repo['git']) => (g ? `${g.branch}, ${g.uncommitted} uncommitted, ${g.ahead} ahead / ${g.behind} behind` : 'not checked out')
const errorCount = (r: Repo) => r.signals.filter((s) => s.kind === 'error').length

function StatusBadge({ status }: { status: Status }) {
  const s = STATUS[status]
  return (
    <BadgeRow badge={<Badge tone={s.tone} size="sm">{s.glyph}</Badge>}>{s.word}</BadgeRow>
  )
}

function RepoCard({ repo }: { repo: Repo }) {
  const s = STATUS[repo.status]
  return (
    <div id={slug(repo.name)}>
      <Card variant="data">
        <CardHead
          title={repo.name}
          badge={<Badge tone={s.tone}>{s.glyph}</Badge>}
          subtitle={`${s.word} · ${repo.visibility}`}
          actions={
            <Button href="#overview" variant="outline" size="compact">
              Back to overview
            </Button>
          }
        />
        <CardBody>
          <DefinitionList
            variant="facts"
            items={[
              { term: 'Checkout', value: gitLine(repo.git) },
              { term: 'Last commit', value: repo.lastCommit || '--' },
              { term: 'Register file', value: <a href={`https://github.com/${REPO}/blob/main/connectors/${slug(repo.name)}.json`}>connectors/{slug(repo.name)}.json</a> },
              { term: 'Plugins', value: repo.plugins.length ? repo.plugins.map((p) => `${p.id} · ${p.lenses} lenses`).join('; ') : 'none' },
              ...(repo.drift ? [{ term: 'Drift', value: repo.drift }] : []),
            ]}
          />
          {repo.signals.length === 0 ? (
            <Message>All checks pass.</Message>
          ) : (
            <BadgeList
              label={`Checks for ${repo.name}`}
              items={repo.signals.map((sig, i) => ({
                id: String(i),
                badge: (
                  <Badge tone={SIGNAL[sig.kind].tone} size="sm">
                    {SIGNAL[sig.kind].glyph}
                  </Badge>
                ),
                text: sig.plugin ? `${sig.plugin}: ${sig.text}` : sig.text,
              }))}
            />
          )}
          {repo.notes.length > 0 && (
            <Disclosure summary="Register notes">
              {repo.notes.map((n) => (
                <Message key={n}>{n}</Message>
              ))}
            </Disclosure>
          )}
        </CardBody>
      </Card>
    </div>
  )
}

export function ConnectedReposPreview() {
  return (
    <>
      <DashboardIntro
        eyebrow={REPO}
        title="About this repo"
        lead="The source of the shared plugins, and the check of every repo that has them installed."
        actions={
          <Button variant="primary" aria-disabled="true">
            Re-run the check
          </Button>
        }
      />

      <PageLinks pages={PAGES} generalPages={GENERAL_PAGES} subtitle="This repo's own pages, and the general ones beside them" />

      <InFlightTiles data={IN_FLIGHT} trunk={TRUNK} />

      <InFlightCards data={IN_FLIGHT} repo={REPO} trunk={TRUNK} />

      {/* The repo's own figures are grouped in their own data card, its head the group label, not in the shell (#158). */}
      <Card variant="data">
        <CardHead title="Register" subtitle="The connected repos at a glance" />
        <CardBody>
          <StatTiles>
            <StatTile label="Registered repos" value={String(REPOS.length)} />
            <StatTile label="Checked out here" value={String(REPOS.filter((r) => r.git).length)} />
            <StatTile label="Errors" value={String(REPOS.reduce((n, r) => n + errorCount(r), 0))} tone="negative" />
            <StatTile label="Notes" value={String(REPOS.reduce((n, r) => n + r.notes.length, 0))} tone="warn" />
          </StatTiles>
        </CardBody>
      </Card>

      <div id="overview">
        <Card variant="data">
          {/* The repo's own title and source-commit line live in a data card's head, not in the shell (#148). */}
          <CardHead title="Connected repos" subtitle={`Source commit ${SOURCE_COMMIT} · every registered repo, worst first`} />
          <CardBody>
            <DataTable
              label="Overview of the connected repos"
              columns={[
                { key: 'repo', label: 'Repo' },
                { key: 'status', label: 'Status', align: 'start' },
                { key: 'visibility', label: 'Visibility', align: 'start', priority: 'low' },
                { key: 'plugins', label: 'Plugins', priority: 'low' },
                { key: 'installed', label: 'Installed', align: 'start', priority: 'low' },
                { key: 'errors', label: 'Errors' },
                { key: 'notes', label: 'Notes' },
                { key: 'checkout', label: 'Checkout', align: 'start', priority: 'low' },
              ]}
              rows={REPOS.map((r) => ({
                id: r.name,
                cells: {
                  repo: <a href={`#${slug(r.name)}`}>{r.name}</a>,
                  status: <StatusBadge status={r.status} />,
                  visibility: r.visibility,
                  plugins: String(r.plugins.length),
                  installed: r.installed,
                  errors: String(errorCount(r)),
                  notes: String(r.notes.length),
                  checkout: gitLine(r.git),
                },
                tones: { errors: errorCount(r) > 0 ? 'negative' : undefined },
                tone: r.status === 'bad' ? 'negative' : r.status === 'warn' ? 'warn' : undefined,
              }))}
            />
          </CardBody>
        </Card>
      </div>

      {REPOS.map((r) => (
        <RepoCard key={r.name} repo={r} />
      ))}

      <CardGroup title="About this repo" subtitle="What this repo is">
        <Card variant="data" className="grid__full">
          <CardBody>
            <DefinitionList
              variant="facts"
              items={[
                { term: 'Stack', value: 'Claude Code plugins: skills, hooks and PowerShell scripts' },
                { term: 'Gate', value: 'Pester' },
                { term: 'Trunk', value: TRUNK },
              ]}
            />
          </CardBody>
        </Card>
      </CardGroup>

      <FooterNote>Checked 13 October 2026, 09:00 (placeholder).</FooterNote>
    </>
  )
}

