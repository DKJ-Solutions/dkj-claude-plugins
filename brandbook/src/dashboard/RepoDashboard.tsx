import { useEffect, useState } from 'react'
import { Button } from '../components/Button'
import { Card, CardBody, CardGroup, CardHead } from '../components/Card'
import { FooterNote } from '../components/Content'
import { Message } from '../components/Feedback'
import { Breadcrumbs, PageLinks } from '../components/Navigation'
import { DataTable, DefinitionList } from '../components/Table'
import { ORG, REPOS, DEFAULT_THEMES, appPreviewPath } from '../repos'
import { DASHBOARDS_PATH, SHOWCASE_PATH, dashboardPreviewPath } from '../routes'
import { DashboardIntro, DashboardMain, InFlightCards, InFlightTiles, type Branch, type InFlight, type Issue, type Pull } from './DashboardShell'
import { PREVIEWS } from './previews'
import { ThemeLabel } from './ThemeLabel'
import './dashboard.css'

/**
 * The Repo hub: the index of this repo's dev server (DKJ-Solutions/dkj-claude-plugins#3064, #137). A welcome page
 * with what this repo is for and what is in flight -- open pull requests, open issues and the branches off the trunk --
 * and a button to the product, the brand book showcase, which has a route of its own.
 * In-flight data is read live from the GitHub API: the repo is public, so no token is needed (60 requests an hour).
 */
const REPO = 'DKJ-Solutions/dkj-brandbook'
const TRUNK = 'main'
const API = `https://api.github.com/repos/${REPO}`

type Load = { status: 'loading' } | { status: 'error'; reason: string } | { status: 'ready'; data: InFlight }

async function get<T>(path: string, signal: AbortSignal): Promise<T> {
  const res = await fetch(`${API}/${path}`, { signal, headers: { Accept: 'application/vnd.github+json' } })
  if (!res.ok) throw new Error(res.status === 403 || res.status === 429 ? 'the GitHub API rate limit is reached; try again within the hour' : `GitHub answered ${res.status}`)
  return res.json() as Promise<T>
}

function useInFlight() {
  const [load, setLoad] = useState<Load>({ status: 'loading' })
  useEffect(() => {
    const abort = new AbortController()
    Promise.all([
      get<Pull[]>('pulls?state=open&per_page=100', abort.signal),
      // The issues endpoint lists pull requests too; those are counted under pulls.
      get<Issue[]>('issues?state=open&per_page=100', abort.signal).then((all) => all.filter((i) => !i.pull_request)),
      get<Branch[]>('branches?per_page=100', abort.signal).then((all) => all.filter((b) => b.name !== TRUNK)),
    ])
      .then(([pulls, issues, branches]) => setLoad({ status: 'ready', data: { pulls, issues, branches } }))
      .catch((e: unknown) => {
        if (!abort.signal.aborted) setLoad({ status: 'error', reason: e instanceof Error ? e.message : String(e) })
      })
    return () => abort.abort()
  }, [])
  return load
}

export function RepoDashboard() {
  const load = useInFlight()
  const data = load.status === 'ready' ? load.data : null

  return (
    <>
      <Breadcrumbs bar items={[{ label: 'Repo hub' }]} />
      <DashboardMain>
        <DashboardIntro
          eyebrow={REPO}
          title="Repo hub"
          lead="The single source of the DKJ-Solutions brand: the design principles, the tokens, the twelve themes and every component the DKJ-Solutions apps share, in one place."
          actions={
            <Button variant="primary" href={SHOWCASE_PATH}>
              Open the brand book
            </Button>
          }
        />

        <PageLinks
          pages={[{ label: 'Preview other repo hubs', href: DASHBOARDS_PATH, description: 'How the other DKJ-Solutions repos’ hubs look in this form' }]}
          generalPages={[
            { label: 'Issues', href: `https://github.com/${REPO}/issues`, description: 'Open and closed, on GitHub' },
            { label: 'Release notes', href: `https://github.com/${REPO}/releases`, description: 'What each release changed' },
          ]}
        />

        <InFlightTiles data={data} trunk={TRUNK} />

        {load.status === 'loading' && <Message live="status">Reading what is in flight from GitHub...</Message>}
        {load.status === 'error' && (
          <Message tone="warn" live="alert">
            What is in flight could not be read: {load.reason}.
          </Message>
        )}

        {data && <InFlightCards data={data} repo={REPO} trunk={TRUNK} />}

        <Card variant="data">
          <CardHead title="DKJ-Solutions repos" subtitle="Every repo that follows the brand book, with its app preview and, where one exists, its dashboard preview." />
          <CardBody>
            <DataTable
              label="DKJ-Solutions repos"
              columns={[
                { key: 'repo', label: 'Repo' },
                { key: 'theme', label: 'Default theme' },
                { key: 'app', label: 'App preview' },
                { key: 'dashboard', label: 'Dashboard preview' },
              ]}
              rows={REPOS.map((r) => ({
                id: r,
                cells: {
                  repo: <a href={`https://github.com/${ORG}/${r}`}>{r}</a>,
                  theme: <ThemeLabel id={DEFAULT_THEMES[r]} />,
                  app: <a href={appPreviewPath(r)}>Open</a>,
                  dashboard: PREVIEWS.some((p) => p.id === r) ? <a href={dashboardPreviewPath(r)}>Open</a> : '--',
                },
              }))}
            />
          </CardBody>
        </Card>

        <CardGroup title="About this repo" subtitle="What this repo is">
          <Card variant="data" className="grid__full">
            <CardBody>
              <DefinitionList
                variant="facts"
                items={[
                  { term: 'Stack', value: 'React 19 + TypeScript + Vite' },
                  { term: 'Trunk', value: TRUNK },
                  { term: 'Gate', value: 'scripts/lint/lint-web.ps1' },
                  { term: 'Showcase', value: SHOWCASE_PATH },
                ]}
              />
            </CardBody>
          </Card>
        </CardGroup>

        <FooterNote>
          In flight is read live from the GitHub API for <a href={`https://github.com/${REPO}`}>{REPO}</a> each time this page opens.
        </FooterNote>
      </DashboardMain>
    </>
  )
}
