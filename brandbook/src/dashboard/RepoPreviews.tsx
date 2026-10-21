import { Card, CardBody, CardHead } from '../components/Card'
import { Badge, BadgeRow, StatTile, StatTiles, type StatusTone } from '../components/Metrics'
import { DataTable } from '../components/Table'
import { PlaceholderDashboard, issue, pull, type PlaceholderRepo } from './PlaceholderDashboard'

/**
 * The Repo hubs of the other DKJ-Solutions repos, as previews of their About this repo page (#3270): the shared shell,
 * then each repo's own cards. None of these repos has a Repo hub of its own yet, so the own cards are a proposal of
 * what its page would show. Every figure, title and name is invented placeholder data: three of these repos are private.
 */
const PUBLIC_SOURCE = 'The real page reads its in-flight lists live from the GitHub API, unauthenticated: the repo is public.'
const PRIVATE_SOURCE = 'The real page reads its in-flight lists through the gh CLI on this machine: the repo is private.'

type Check = 'good' | 'warn' | 'bad'
const CHECK: Record<Check, { tone: StatusTone; glyph: string; word: string }> = {
  good: { tone: 'good', glyph: '✓', word: 'ok' },
  warn: { tone: 'warn', glyph: '!', word: 'warn' },
  bad: { tone: 'bad', glyph: '!', word: 'failed' },
}

function CheckBadge({ check, word }: { check: Check; word?: string }) {
  const c = CHECK[check]
  return (
    <BadgeRow badge={<Badge tone={c.tone} size="sm">{c.glyph}</Badge>}>{word ?? c.word}</BadgeRow>
  )
}

const rowTone = (check: Check): 'negative' | 'warn' | undefined => (check === 'bad' ? 'negative' : check === 'warn' ? 'warn' : undefined)

// ETF tracker: a Python generator that turns a ledger into one static dashboard page.
const ETF: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-etf-tracker',
  lead: 'A personal investment dashboard, generated from a ledger into one static page with the holdings, the result and a market report.',
  product: 'Open the investment dashboard',
  inFlight: {
    pulls: [pull(48, 'Example chart change', 'feat/example-chart', 11)],
    issues: [issue(52, 'Example ledger check', ['bug', 'prio-1']), issue(50, 'Example report section', ['feature', 'prio-3'], 'example-user')],
    branches: [{ name: 'feat/example-chart' }],
  },
  facts: [
    { term: 'Stack', value: 'Python, generating static HTML' },
    { term: 'Gate', value: 'pytest' },
  ],
  source: PRIVATE_SOURCE,
}

const ETF_STEPS: readonly { step: string; ran: string; check: Check; note: string }[] = [
  { step: 'Read the ledger', ran: '12 Oct, 08:55', check: 'good', note: '412 rows' },
  { step: 'Check the ledger', ran: '12 Oct, 08:55', check: 'warn', note: '1 discrepancy' },
  { step: 'Fetch the prices', ran: '12 Oct, 08:56', check: 'good', note: '6 of 6 holdings' },
  { step: 'Write the market report', ran: '2 Oct, 09:10', check: 'warn', note: '10 days old' },
  { step: 'Generate the page', ran: '12 Oct, 08:57', check: 'good', note: 'dashboard.html' },
]

function EtfDashboardPreview() {
  return (
    <PlaceholderDashboard repo={ETF}>
      <Card variant="data">
        <CardHead title="Last run" subtitle="Each step from the ledger to the generated page" />
        <CardBody>
          <StatTiles>
            <StatTile label="Ledger rows" value="412" />
            <StatTile label="Discrepancies" value="1" tone="warn" />
            <StatTile label="Report age" value="10 days" tone="warn" />
          </StatTiles>
          <DataTable
            label="The steps of the last run"
            columns={[
              { key: 'step', label: 'Step' },
              { key: 'ran', label: 'Ran', align: 'start', priority: 'low' },
              { key: 'status', label: 'Status', align: 'start' },
              { key: 'note', label: 'Result', align: 'start' },
            ]}
            rows={ETF_STEPS.map((s) => ({
              id: s.step,
              cells: { step: s.step, ran: s.ran, status: <CheckBadge check={s.check} />, note: s.note },
              tone: rowTone(s.check),
            }))}
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

// Mesowise: a public PWA on GitHub Pages, built on a set of game-data tables.
const MESOWISE: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-maplestory-classic-mesowise',
  lead: 'A mobile-first web app that works out the cheapest way to level up a game character, level by level.',
  product: 'Open the app',
  inFlight: {
    pulls: [pull(91, 'Example card change', 'feat/example-card', 12), pull(89, 'Example data fix', 'fix/example-data', 8, true)],
    issues: [
      issue(95, 'Example question about a level', ['feature', 'prio-2'], 'example-user'),
      issue(94, 'Example wrong figure', ['bug', 'prio-1']),
      issue(90, 'Example idea', ['feature']),
    ],
    branches: [{ name: 'feat/example-card' }, { name: 'fix/example-data' }],
  },
  facts: [
    { term: 'Stack', value: 'Preact + TypeScript + Vite; installable PWA' },
    { term: 'Live', value: 'GitHub Pages' },
    { term: 'Gate', value: 'scripts/lint (eslint + tsc + build)' },
  ],
  source: PUBLIC_SOURCE,
}

const MESOWISE_DATA: readonly { table: string; rows: number; checked: string; check: Check }[] = [
  { table: 'Equipment', rows: 1240, checked: '11 Oct', check: 'good' },
  { table: 'Monsters', rows: 318, checked: '11 Oct', check: 'good' },
  { table: 'Training spots', rows: 64, checked: '4 Oct', check: 'warn' },
  { table: 'Potions', rows: 27, checked: '11 Oct', check: 'good' },
]

function MesowiseDashboardPreview() {
  return (
    <PlaceholderDashboard repo={MESOWISE}>
      <Card variant="data">
        <CardHead title="Live" subtitle="The last deploy to GitHub Pages" />
        <CardBody>
          <StatTiles>
            <StatTile label="Deployed commit" value="a1b2c3d" />
            <StatTile label="Deployed" value="12 Oct" />
            <StatTile label="Commits not live" value="2" tone="warn" />
          </StatTiles>
        </CardBody>
      </Card>
      <Card variant="data">
        <CardHead title="Game data" subtitle="The tables the cost of a level is worked out from" />
        <CardBody>
          <DataTable
            label="Game data tables"
            columns={[
              { key: 'table', label: 'Table' },
              { key: 'rows', label: 'Rows' },
              { key: 'checked', label: 'Last checked', align: 'start', priority: 'low' },
              { key: 'status', label: 'Status', align: 'start' },
            ]}
            rows={MESOWISE_DATA.map((d) => ({
              id: d.table,
              cells: { table: d.table, rows: d.rows.toLocaleString('en-GB'), checked: d.checked, status: <CheckBadge check={d.check} word={d.check === 'good' ? 'ok' : 'stale'} /> },
              tone: rowTone(d.check),
            }))}
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

// Music library: a local Next.js app that syncs playlists from a music service.
const MUSIC: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-music-library',
  lead: 'A local app for managing a music library: sync the playlists, sort them into worlds, filter and annotate them.',
  product: 'Open the music library',
  inFlight: {
    pulls: [pull(132, 'Example filter change', 'feat/example-filter', 10)],
    issues: [issue(140, 'Example sync problem', ['bug', 'prio-1'], 'example-user'), issue(137, 'Example new view', ['feature', 'prio-2'])],
    branches: [{ name: 'feat/example-filter' }, { name: 'docs/example-readme' }],
  },
  facts: [
    { term: 'Stack', value: 'Next.js (React) + TypeScript; runs locally' },
    { term: 'Data', value: 'data/ (the synced library)' },
    { term: 'Gate', value: 'eslint + vitest + next build' },
  ],
  source: PUBLIC_SOURCE,
}

const MUSIC_SYNCS: readonly { when: string; check: Check; playlists: number; tracks: number; note: string }[] = [
  { when: '12 Oct, 20:14', check: 'good', playlists: 86, tracks: 3412, note: '14 tracks added' },
  { when: '9 Oct, 19:02', check: 'bad', playlists: 0, tracks: 0, note: 'Sign-in expired' },
  { when: '5 Oct, 21:40', check: 'good', playlists: 84, tracks: 3398, note: '3 tracks added' },
]

function MusicDashboardPreview() {
  return (
    <PlaceholderDashboard repo={MUSIC}>
      <Card variant="data">
        <CardHead title="Library" subtitle="The library as the last sync left it" />
        <CardBody>
          <StatTiles>
            <StatTile label="Playlists" value="86" />
            <StatTile label="Tracks" value="3,412" />
            <StatTile label="Duplicates" value="7" tone="warn" />
            <StatTile label="Without a world" value="4" tone="warn" />
          </StatTiles>
        </CardBody>
      </Card>
      <Card variant="data">
        <CardHead title="Syncs" subtitle="The last syncs from the music service, newest first" />
        <CardBody>
          <DataTable
            label="Recent syncs"
            columns={[
              { key: 'when', label: 'Sync' },
              { key: 'status', label: 'Status', align: 'start' },
              { key: 'playlists', label: 'Playlists', priority: 'low' },
              { key: 'tracks', label: 'Tracks', priority: 'low' },
              { key: 'note', label: 'Result', align: 'start' },
            ]}
            rows={MUSIC_SYNCS.map((s) => ({
              id: s.when,
              cells: {
                when: s.when,
                status: <CheckBadge check={s.check} />,
                playlists: s.playlists ? String(s.playlists) : '--',
                tracks: s.tracks ? s.tracks.toLocaleString('en-GB') : '--',
                note: s.note,
              },
              tone: rowTone(s.check),
            }))}
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

// Recipes: a public Astro site on GitHub Pages; each recipe is a Markdown file in recipes/.
const RECIPES: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-recipes',
  lead: 'A mobile-first recipe collection to search by tag, scale to the number of portions and shop from.',
  product: 'Open the recipes',
  inFlight: {
    pulls: [pull(27, 'Example recipe', 'feat/example-recipe', 12)],
    issues: [issue(31, 'Example wish for the shopping list', ['feature', 'prio-2']), issue(29, 'Example recipe to add', ['feature'])],
    branches: [{ name: 'feat/example-recipe' }],
  },
  facts: [
    { term: 'Stack', value: 'Astro static site; installable PWA' },
    { term: 'Live', value: 'GitHub Pages' },
    { term: 'Recipes', value: 'One Markdown file each, from a template' },
  ],
  source: PUBLIC_SOURCE,
}

const RECIPE_CHECKS: readonly { file: string; check: Check; finding: string }[] = [
  { file: 'example-soup.md', check: 'warn', finding: 'No source line' },
  { file: 'example-curry.md', check: 'warn', finding: 'An ingredient without a department' },
  { file: 'example-salad.md', check: 'bad', finding: 'The front matter does not parse' },
]

function RecipesDashboardPreview() {
  return (
    <PlaceholderDashboard repo={RECIPES}>
      <Card variant="data">
        <CardHead title="Collection" subtitle="The recipes in recipes/ against the template" />
        <CardBody>
          <StatTiles>
            <StatTile label="Recipes" value="38" />
            <StatTile label="Tags" value="12" />
            <StatTile label="Findings" value={String(RECIPE_CHECKS.length)} tone="warn" />
          </StatTiles>
          <DataTable
            label="Recipes that do not follow the template"
            columns={[
              { key: 'file', label: 'Recipe file' },
              { key: 'status', label: 'Status', align: 'start' },
              { key: 'finding', label: 'Finding', align: 'start' },
            ]}
            rows={RECIPE_CHECKS.map((r) => ({
              id: r.file,
              cells: { file: r.file, status: <CheckBadge check={r.check} />, finding: r.finding },
              tone: rowTone(r.check),
            }))}
            empty="Every recipe follows the template."
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

// Thumbnail generator: local Node scripts that run a round at an image service; no product, so no product button.
const THUMBNAIL: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-thumbnail-generator',
  lead: 'Scripts that run a thumbnail round at an image-generation service, measure the result against a yardstick and place it in a design file.',
  inFlight: {
    pulls: [],
    issues: [issue(58, 'Example measurement to add', ['feature', 'prio-2'], 'example-user'), issue(55, 'Example script failure', ['bug'])],
    branches: [{ name: 'feat/example-measurement' }],
  },
  facts: [
    { term: 'Stack', value: 'Node scripts; local only' },
    { term: 'Output', value: 'A measurement report and a contact sheet per round' },
  ],
  source: PRIVATE_SOURCE,
}

const ROUNDS: readonly { round: string; date: string; candidates: number; retained: number; check: Check }[] = [
  { round: 'Round 14', date: '11 Oct', candidates: 4, retained: 1, check: 'good' },
  { round: 'Round 13', date: '6 Oct', candidates: 4, retained: 0, check: 'warn' },
  { round: 'Round 12', date: '2 Oct', candidates: 4, retained: 2, check: 'good' },
]

function ThumbnailDashboardPreview() {
  return (
    <PlaceholderDashboard repo={THUMBNAIL}>
      <Card variant="data">
        <CardHead title="Rounds" subtitle="The last rounds against the yardstick, newest first" />
        <CardBody>
          <StatTiles>
            <StatTile label="Rounds" value="14" />
            <StatTile label="Candidates retained" value="9" />
            <StatTile label="Paid calls this month" value="24" />
          </StatTiles>
          <DataTable
            label="Recent rounds"
            columns={[
              { key: 'round', label: 'Round' },
              { key: 'date', label: 'Date', align: 'start', priority: 'low' },
              { key: 'candidates', label: 'Candidates', priority: 'low' },
              { key: 'retained', label: 'Retained' },
              { key: 'status', label: 'Verdict', align: 'start' },
            ]}
            rows={ROUNDS.map((r) => ({
              id: r.round,
              cells: {
                round: r.round,
                date: r.date,
                candidates: String(r.candidates),
                retained: String(r.retained),
                status: <CheckBadge check={r.check} word={r.retained ? 'passed' : 'nothing retained'} />,
              },
              tone: rowTone(r.check),
            }))}
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

// Life hub: a private repo whose content is a set of folders, with a local read-only app over it.
const LIFE_HUB: PlaceholderRepo = {
  slug: 'DKJ-Solutions/dkj-lifehub',
  lead: 'A personal hub: the content lives in folders in the repo, and a local app shows it read-only as a start page with dossiers.',
  product: 'Open the hub',
  inFlight: {
    pulls: [pull(73, 'Example dossier update', 'docs/example-dossier', 12)],
    issues: [issue(80, 'Example app change', ['feature', 'prio-2'], 'example-user'), issue(77, 'Example broken link', ['bug', 'prio-1'])],
    branches: [{ name: 'docs/example-dossier' }, { name: 'feat/example-view' }],
  },
  facts: [
    { term: 'Stack', value: 'Next.js (React) + TypeScript; runs locally, read-only' },
    { term: 'Content', value: 'Markdown folders in the repo' },
    { term: 'Gate', value: 'eslint + vitest + next build' },
  ],
  source: PRIVATE_SOURCE,
}

const CONTENT_CHECKS: readonly { check: string; result: Check; note: string }[] = [
  { check: 'Every folder has its convention file', result: 'good', note: 'All folders' },
  { check: 'Internal links resolve', result: 'warn', note: '2 broken links' },
  { check: 'Dates in "Coming up" parse', result: 'bad', note: '1 invalid date' },
]

function LifeHubDashboardPreview() {
  return (
    <PlaceholderDashboard repo={LIFE_HUB}>
      <Card variant="data">
        <CardHead title="Content" subtitle="The content folders, and the checks the app relies on" />
        <CardBody>
          <StatTiles>
            <StatTile label="Dossiers" value="23" />
            <StatTile label="Open actions" value="11" />
            <StatTile label="Coming up" value="5" />
          </StatTiles>
          <DataTable
            label="Content checks"
            columns={[
              { key: 'check', label: 'Check' },
              { key: 'status', label: 'Status', align: 'start' },
              { key: 'note', label: 'Result', align: 'start' },
            ]}
            rows={CONTENT_CHECKS.map((c) => ({
              id: c.check,
              cells: { check: c.check, status: <CheckBadge check={c.result} />, note: c.note },
              tone: rowTone(c.result),
            }))}
          />
        </CardBody>
      </Card>
    </PlaceholderDashboard>
  )
}

export { EtfDashboardPreview, LifeHubDashboardPreview, MesowiseDashboardPreview, MusicDashboardPreview, RecipesDashboardPreview, ThumbnailDashboardPreview }
