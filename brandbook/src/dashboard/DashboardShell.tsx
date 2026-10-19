import type { ReactNode } from 'react'
import { Card, CardBody, CardGroup, CardHead } from '../components/Card'
import { StatTile, StatTiles } from '../components/Metrics'
import { DataTable } from '../components/Table'
import { Toolbar } from '../showcase/Showcase'

/**
 * The shell every repo's Repo hub shares: the intro (eyebrow, title, lead, buttons), the in-flight tiles and the
 * three in-flight cards. RepoDashboard fills it with live GitHub data, the preview page with placeholder data.
 */
export type Pull = { number: number; title: string; html_url: string; draft: boolean; created_at: string; head: { ref: string } }
export type Issue = { number: number; title: string; html_url: string; updated_at: string; labels: { name: string }[]; assignees: { login: string }[]; pull_request?: unknown }
export type Branch = { name: string }
export type InFlight = { pulls: Pull[]; issues: Issue[]; branches: Branch[] }

const day = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' })
const date = (iso: string) => day.format(new Date(iso))

/** The issue's prio-N label as a number, or Infinity without one, so unprioritised issues sort last. */
function prio(issue: Issue) {
  const m = issue.labels.map((l) => /^prio-(\d+)$/.exec(l.name)).find(Boolean)
  return m ? Number(m[1]) : Infinity
}

/** A dashboard page's <main>: the preview settings over the page's blocks. The house style sizes it from the width in the
 * settings panel: the house column in fluid width, a 360px column in phone width, the whole width in full. */
export function DashboardMain({ children }: { children: ReactNode }) {
  return (
    <main className="dkj-dashboard">
      <Toolbar />
      {children}
    </main>
  )
}

/** The intro block. A div, not a header: the house style makes main > header the flex page-header row. */
export function DashboardIntro({ eyebrow, title, lead, actions }: { eyebrow: string; title: string; lead: ReactNode; actions?: ReactNode }) {
  return (
    <div className="dkj-intro">
      <p className="dkj-eyebrow">{eyebrow}</p>
      <h1>{title}</h1>
      <p className="dkj-lead">{lead}</p>
      {actions && <p className="dkj-dashboard-cta">{actions}</p>}
    </div>
  )
}

export function InFlightTiles({ data, trunk }: { data: InFlight | null; trunk: string }) {
  const count = (n: number | undefined) => (n === undefined ? '--' : String(n))
  return (
    <StatTiles>
      <StatTile label="Open pull requests" value={count(data?.pulls.length)} />
      <StatTile label="Open issues" value={count(data?.issues.length)} />
      <StatTile label={`Branches off ${trunk}`} value={count(data?.branches.length)} />
    </StatTiles>
  )
}

export function InFlightCards({ data, repo, trunk }: { data: InFlight; repo: string; trunk: string }) {
  return (
    <CardGroup title="In flight" subtitle="Every list this repo has open">
      <Card variant="data" className="grid__full">
        <CardHead title="Pull requests" subtitle="Open, newest first" />
        <CardBody>
          <DataTable
            label="Open pull requests"
            columns={[
              { key: 'title', label: 'Pull request' },
              { key: 'number', label: 'Number' },
              { key: 'opened', label: 'Opened' },
            ]}
            rows={data.pulls.map((p) => ({
              id: String(p.number),
              cells: { title: <a href={p.html_url}>{p.title}</a>, number: `#${p.number}`, opened: date(p.created_at) },
              sub: p.draft ? `${p.head.ref} (draft)` : p.head.ref,
            }))}
            empty="No open pull requests."
          />
        </CardBody>
      </Card>

      <Card variant="data" className="grid__full">
        <CardHead title="Issues" subtitle="Open, by priority" />
        <CardBody>
          <DataTable
            label="Open issues"
            columns={[
              { key: 'title', label: 'Issue' },
              { key: 'number', label: 'Number' },
              { key: 'prio', label: 'Priority' },
            ]}
            rows={[...data.issues]
              .sort((a, b) => prio(a) - prio(b) || b.number - a.number)
              .map((i) => ({
                id: String(i.number),
                cells: { title: <a href={i.html_url}>{i.title}</a>, number: `#${i.number}`, prio: Number.isFinite(prio(i)) ? String(prio(i)) : '--' },
                sub: i.assignees.length ? `Claimed by ${i.assignees.map((a) => a.login).join(', ')}` : 'Unclaimed',
              }))}
            empty="No open issues."
          />
        </CardBody>
      </Card>

      <Card variant="data" className="grid__full">
        <CardHead title="Branches" subtitle={`Every branch off ${trunk}, with its pull request where one is open`} />
        <CardBody>
          <DataTable
            label={`Branches off ${trunk}`}
            columns={[
              { key: 'name', label: 'Branch' },
              { key: 'pull', label: 'Pull request' },
            ]}
            rows={data.branches.map((b) => {
              const pull = data.pulls.find((p) => p.head.ref === b.name)
              return { id: b.name, cells: { name: <a href={`https://github.com/${repo}/tree/${b.name}`}>{b.name}</a>, pull: pull ? `#${pull.number}` : 'none yet' } }
            })}
            empty={`No branches off ${trunk}.`}
          />
        </CardBody>
      </Card>
    </CardGroup>
  )
}
