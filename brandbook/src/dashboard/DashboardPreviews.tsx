import { Card, CardBody } from '../components/Card'
import { Message } from '../components/Feedback'
import { Breadcrumbs } from '../components/Navigation'
import { DataTable } from '../components/Table'
import { useRepoDefaultTheme } from '../showcase/theme'
import { DASHBOARD_PATH, DASHBOARDS_PATH, SHOWCASE_PATH, dashboardPreviewPath } from '../routes'
import { DashboardMain } from './DashboardShell'
import { PREVIEWS } from './previews'
import './dashboard.css'

/**
 * The menu of every repo hub, one table row per repo, that can be previewed in this brand book's hub shape, to see whether what
 * those repos will put in theirs fits. The data is invented placeholder data (the repo is public) and nothing is fetched.
 */
export function DashboardIndex() {
  return (
    <>
      <Breadcrumbs bar items={[{ label: 'Brand book', href: SHOWCASE_PATH }, { label: 'Repo hub pattern', href: DASHBOARD_PATH }, { label: 'Hub previews' }]} />
      <DashboardMain>
        <div className="dkj-intro">
          <h1>Repo hub previews</h1>
          <p className="dkj-lead">
            Other repos' About this repo pages drawn in the Repo hub pattern, with their own cards, to see where the pattern does not fit yet. Placeholder data only.
          </p>
        </div>
        <Card variant="data">
          <CardBody>
            <DataTable
              label="Hub previews"
              columns={[
                { key: 'repo', label: 'Repo' },
                { key: 'shows', label: 'What it shows', align: 'start' },
              ]}
              rows={PREVIEWS.map((p) => ({
                id: p.id,
                cells: { repo: <a href={dashboardPreviewPath(p.id)}>{p.label}</a>, shows: p.description },
              }))}
            />
          </CardBody>
        </Card>
      </DashboardMain>
    </>
  )
}

/** One repo's dashboard preview; an unknown id says so, and the breadcrumbs lead back to the menu. */
export function DashboardPreviewPage({ id }: { id: string }) {
  const preview = PREVIEWS.find((p) => p.id === id)
  useRepoDefaultTheme(id)

  return (
    <>
      <Breadcrumbs
        bar
        items={[{ label: 'Brand book', href: SHOWCASE_PATH }, { label: 'Repo hub pattern', href: DASHBOARD_PATH }, { label: 'Hub previews', href: DASHBOARDS_PATH }, { label: preview?.label ?? id }]}
      />
      <DashboardMain>
        {preview ? (
          <preview.Component />
        ) : (
          <Message>There is no dashboard preview for this repo.</Message>
        )}
      </DashboardMain>
    </>
  )
}
