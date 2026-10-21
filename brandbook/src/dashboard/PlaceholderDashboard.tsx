import type { ReactNode } from 'react'
import { Card, CardBody, CardGroup } from '../components/Card'
import { FooterNote } from '../components/Content'
import { PageLinks } from '../components/Navigation'
import { DefinitionList } from '../components/Table'
import { DashboardIntro, InFlightCards, InFlightTiles, type InFlight, type Issue, type Pull } from './DashboardShell'

/**
 * A repo's Repo hub in the form the house-style README lays down ("The Repo hub"), filled with placeholder data. The
 * hub is two pages (DKJ-Solutions/dkj-claude-plugins#3270): PlaceholderHome, the home page on '/' (the repo's name, its
 * products, one link to About this repo, the Brand book), and PlaceholderDashboard, About this repo on '/about' (the
 * in-flight tiles and cards, the repo's own cards, the facts and the footer note). A preview only: nothing is fetched
 * and no link goes anywhere.
 */
export type PlaceholderRepo = {
  /** GitHub "owner/name": About's eyebrow; the name after the slash is the home page's h1. */
  slug: string
  lead: string
  /** The product's label on the home page; left out for a repo without a product. */
  product?: string
  trunk?: string
  inFlight: InFlight
  facts: readonly { term: string; value: ReactNode }[]
  /** Where the real page would read its in-flight lists, for the footer note. */
  source: string
}

/** One open pull request, opened on the given day of October 2026. */
export const pull = (number: number, title: string, ref: string, day: number, draft = false): Pull => ({
  number,
  title,
  html_url: '#',
  draft,
  created_at: `2026-10-${String(day).padStart(2, '0')}T09:00:00Z`,
  head: { ref },
})

/** One open issue, with its labels and, where claimed, who claimed it. */
export const issue = (number: number, title: string, labels: readonly string[], claimedBy?: string): Issue => ({
  number,
  title,
  html_url: '#',
  updated_at: '2026-10-12T09:00:00Z',
  labels: labels.map((name) => ({ name })),
  assignees: claimedBy ? [{ login: claimedBy }] : [],
})

/** The home page: a portal, as little as possible. -aboutHref is where its About this repo row goes. */
export function PlaceholderHome({ repo, aboutHref }: { repo: PlaceholderRepo; aboutHref: string }) {
  const name = repo.slug.split('/').pop() ?? repo.slug
  return (
    <>
      <DashboardIntro title={name} lead={repo.lead} />

      {repo.product && (
        <PageLinks title="Products" subtitle="What this repo offers, each on a route of its own" pages={[{ label: repo.product, href: '#' }]} />
      )}

      <PageLinks
        title="About this repo"
        subtitle="The repo itself rather than what it offers"
        pages={[{ label: 'About this repo', href: aboutHref, description: 'Its pages, what is in flight, and its facts' }]}
      />

      <PageLinks
        title="Brand book"
        subtitle="Shared by every DKJ-Solutions repo: the house style they are all built from"
        pages={[{ label: 'Brandbook', href: '#', description: 'The house style: its tokens, its twelve themes and its components' }]}
      />
    </>
  )
}

/** About this repo: everything about the repo itself. -children are the repo's own cards, between In flight and Facts. */
export function PlaceholderDashboard({ repo, children }: { repo: PlaceholderRepo; children?: ReactNode }) {
  const trunk = repo.trunk ?? 'main'
  return (
    <>
      <DashboardIntro eyebrow={repo.slug} title="About this repo" lead={repo.lead} />

      <InFlightTiles data={repo.inFlight} trunk={trunk} />

      <InFlightCards data={repo.inFlight} repo={repo.slug} trunk={trunk} />

      {children}

      <CardGroup title="Facts" subtitle="What this repo is">
        <Card variant="data" className="grid__full">
          <CardBody>
            <DefinitionList variant="facts" items={[...repo.facts, { term: 'Trunk', value: trunk }]} />
          </CardBody>
        </Card>
      </CardGroup>

      <FooterNote>{repo.source} Placeholder data only.</FooterNote>
    </>
  )
}
