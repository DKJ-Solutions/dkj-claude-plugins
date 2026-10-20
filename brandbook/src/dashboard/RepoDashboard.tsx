import { Message } from '../components/Feedback'
import { Breadcrumbs } from '../components/Navigation'
import { DASHBOARDS_PATH, HUB_PATH, SHOWCASE_PATH } from '../routes'
import { DashboardMain } from './DashboardShell'
import { PlaceholderDashboard, issue, pull, type PlaceholderRepo } from './PlaceholderDashboard'
import './dashboard.css'

/**
 * The Repo hub pattern: how a DKJ-Solutions repo's hub index is laid out (DKJ-Solutions/dkj-claude-plugins#3064),
 * drawn with the brand book's components. A specimen, not a hub (#3202): nothing is read from GitHub and it speaks
 * for no repo. This repo's own Repo hub is the one on the dev server's '/', and that is the page the pattern is for.
 */
const EXAMPLE: PlaceholderRepo = {
  slug: 'DKJ-Solutions/example-repo',
  lead: 'What the repo is for, in one or two sentences: the first thing somebody opening its dev server reads.',
  product: 'Open the product',
  inFlight: {
    pulls: [pull(42, 'Example feature', 'feat/41-example-feature', 14), pull(40, 'Example draft', 'docs/39-example-draft', 9, true)],
    issues: [
      issue(43, 'Example bug', ['bug', 'prio-3']),
      issue(41, 'Example feature', ['feature', 'prio-2'], 'example-user'),
      issue(38, 'Example decision', ['awaiting-decision-dev', 'prio-1']),
    ],
    branches: [{ name: 'feat/41-example-feature' }, { name: 'docs/39-example-draft' }],
  },
  facts: [
    { term: 'Stack', value: 'The repo’s stack' },
    { term: 'Gate', value: 'The command its gate runs' },
  ],
  source: 'The real page reads its in-flight lists from GitHub each time it opens.',
}

export function RepoDashboard() {
  return (
    <>
      <Breadcrumbs bar items={[{ label: 'Brand book', href: SHOWCASE_PATH }, { label: 'Repo hub pattern' }]} />
      <DashboardMain>
        <Message tone="note">
          A specimen of the Repo hub pattern, with placeholder data. This repo’s own hub is on the <a href={HUB_PATH}>dev server’s index</a>;
          other repos’ hubs drawn in this pattern are under <a href={DASHBOARDS_PATH}>Hub previews</a>.
        </Message>

        <PlaceholderDashboard repo={EXAMPLE} />
      </DashboardMain>
    </>
  )
}
