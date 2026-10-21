import { useRef, useState, type ReactNode } from 'react'
import { cx } from './cx'
import { Button, IconButton, RoundToggle } from './Button'
import { Card, CardBody, CardGroup, CardHead } from './Card'
import { Dialog } from './Dialog'
import { Icon } from './Icon'
import './navigation.css'

/**
 * TopBar -- sticky, the surface colour, full width with a hairline shadow; the content aligns with the app column.
 * Brand name and a muted tagline on the left, a menu button on the right that opens a Drawer.
 */
export function TopBar({ name, tagline, menuTitle = 'Settings', menu }: { name: string; tagline?: string; menuTitle?: string; menu: ReactNode }) {
  const [open, setOpen] = useState(false)
  const button = useRef<HTMLButtonElement>(null)
  return (
    <header className="dkj-topbar">
      <div className="dkj-topbar-inner">
        <div className="dkj-topbar-brand">
          <span className="dkj-topbar-name">{name}</span>
          {tagline && <span className="dkj-topbar-tagline">{tagline}</span>}
        </div>
        <IconButton
          ref={button}
          variant="ghost"
          icon="menu"
          label={menuTitle}
          aria-haspopup="dialog"
          aria-expanded={open}
          onClick={() => setOpen(true)}
        />
      </div>
      <Dialog
        open={open}
        variant="drawer"
        heading="plain"
        title={menuTitle}
        onClose={() => {
          setOpen(false)
          button.current?.focus()
        }}
      >
        <div className="dkj-drawer-content">{menu}</div>
      </Dialog>
    </header>
  )
}

/** MenuList / MenuRow -- a label, the chosen value right-aligned against a pencil; a rule between rows only. */
export function MenuList({ children }: { children: ReactNode }) {
  return <ul className="dkj-menu-list">{children}</ul>
}

export function MenuRow({ label, value, onEdit }: { label: string; value: ReactNode; onEdit?: () => void }) {
  return (
    <li className="dkj-menu-row">
      <span className="dkj-menu-label">{label}:</span>
      <span className="dkj-menu-value">{value}</span>
      <IconButton icon="pencil" label={`Edit ${label}`} onClick={onEdit} />
    </li>
  )
}

/** DrawerFooter -- pinned to the bottom of a drawer, with free space above it. */
export function DrawerFooter({ children }: { children: ReactNode }) {
  return <div className="dkj-drawer-footer">{children}</div>
}

/**
 * StepHeader -- back, a large value exactly centred, forward. Two equal side columns keep the value in the middle of
 * the screen however wide the buttons are. Both buttons are compact and identical in size; back is outline, forward
 * is the positive gradient.
 */
export function StepHeader({
  value,
  backLabel = 'Back',
  forwardLabel = 'Next',
  onBack,
  onForward,
  canBack = true,
  canForward = true,
}: {
  value: ReactNode
  backLabel?: string
  forwardLabel?: string
  onBack?: () => void
  onForward?: () => void
  canBack?: boolean
  canForward?: boolean
}) {
  return (
    <div className="dkj-stephead">
      <Button variant="outline" size="compact" onClick={onBack} disabled={!canBack}>
        {backLabel}
      </Button>
      <p className="dkj-stephead-value">{value}</p>
      <Button variant="positive" size="compact" onClick={onForward} disabled={!canForward}>
        {forwardLabel}
      </Button>
    </div>
  )
}

/**
 * InfoRow ("based on") -- a small muted head, then one tinted box per row: the value (or a muted placeholder), an
 * info button that fills the box so the name is tappable too, and optionally a pencil outside the box.
 */
export function InfoRows({ head, tone = 'accent', children }: { head: string; tone?: 'accent' | 'info'; children: ReactNode }) {
  return (
    <section className={cx('dkj-inforows', tone === 'info' && 'dkj-inforows--info')}>
      <p className="dkj-inforows-head">{head}</p>
      <div className="dkj-inforows-list">{children}</div>
    </section>
  )
}

export function InfoRow({
  value,
  placeholder = 'Nothing chosen',
  onInfo,
  onHelp,
  onEdit,
}: {
  value: string | null
  placeholder?: string
  onInfo?: () => void
  onHelp?: () => void
  onEdit?: () => void
}) {
  return (
    <div className="dkj-inforow">
      <div className="dkj-inforow-box">
        {value ? (
          <button type="button" className="dkj-inforow-named" onClick={onInfo}>
            <Icon name="info" />
            <span className="dkj-inforow-value">{value}</span>
          </button>
        ) : (
          <span className="dkj-inforow-value dkj-inforow-value--placeholder">{placeholder}</span>
        )}
        {onHelp && <RoundToggle onClick={onHelp} />}
      </div>
      {onEdit && <IconButton icon="pencil" label="Edit" onClick={onEdit} />}
    </div>
  )
}

/**
 * PageHeader -- the page title as the house serif h1, and on its right a controls row: a muted "as of" line, then
 * whatever controls the page has (a joined SegmentedChoice, buttons). The row wraps under the title on a narrow screen.
 * It carries its own flex layout, so it also works where the header is not a direct child of <main>.
 */
export function PageHeader({ title, asOf, children }: { title: string; asOf?: string; children?: ReactNode }) {
  return (
    <header className="dkj-page-header">
      <h1>{title}</h1>
      <div className="controls">
        {asOf && <span className="muted">{asOf}</span>}
        {children}
      </div>
    </header>
  )
}

/**
 * Breadcrumbs -- where this page sits: each ancestor a link, the current page last and unlinked (aria-current), a muted
 * chevron between them, on one line. As a `bar` it spans the full screen width on a tinted background and sticks to the top.
 */
export function Breadcrumbs({ items, bar = false }: { items: readonly { label: string; href?: string }[]; bar?: boolean }) {
  const trail = (
    <nav className="dkj-breadcrumbs" aria-label="Breadcrumb">
      <ol>
        {items.map((item, i) => {
          const current = i === items.length - 1
          return (
            <li key={i}>
              {i > 0 && (
                <span className="dkj-breadcrumbs-sep" aria-hidden="true">
                  <svg viewBox="0 0 24 24">
                    <path
                      fill="currentColor"
                      fillRule="evenodd"
                      d="M9.793 16.707a1 1 0 0 1 0-1.414L13.086 12 9.793 8.707a1 1 0 0 1 1.414-1.414l4 4a1 1 0 0 1 0 1.414l-4 4a1 1 0 0 1-1.414 0"
                      clipRule="evenodd"
                    />
                  </svg>
                </span>
              )}
              {current || !item.href ? <span aria-current={current ? 'page' : undefined}>{item.label}</span> : <a href={item.href}>{item.label}</a>}
            </li>
          )
        })}
      </ol>
    </nav>
  )
  // The bar spans the full screen width, so it goes above <main>; its trail aligns with the house page column.
  return bar ? (
    <div className="dkj-breadcrumbs-bar">
      <div className="container">{trail}</div>
    </div>
  ) : (
    trail
  )
}

type Page = { label: string; href: string; description?: string }

function PageRows({ pages, label }: { pages: readonly Page[]; label: string }) {
  return (
    <nav aria-label={label} className="menu-list">
      {pages.map((page) => (
        <a key={page.href + page.label} className="menu-item" href={page.href}>
          <span className="menu-item__label">
            {page.label}
            {page.description && <span className="menu-item__sub">{page.description}</span>}
          </span>
          <svg className="menu-item__chevron" viewBox="0 0 24 24" width={20} height={20} aria-hidden="true" focusable="false">
            <path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </a>
      ))}
    </nav>
  )
}

/**
 * PageLinks -- the Repo hub's Pages block: one link row per page (label, an optional one-line description beneath it, a
 * chevron at the end), a line between rows. It uses the house `.menu-item` rows (house-style.css, loaded globally) and
 * renders nothing without pages.
 * One group only (either): one data card titled "Pages". With both pages and generalPages (the pages every DKJ-Solutions repo serves, #206): the
 * h2 "Pages" and its sub line stand above two cards side by side, "This repo" (pages) and "General" (generalPages). The home page's
 * sections (Products, About this repo, Brand book, #3270) are the one-group form with a title and subtitle of their own.
 */
export function PageLinks({
  pages,
  generalPages = [],
  title = 'Pages',
  subtitle = 'Every page this dev server serves',
}: {
  pages: readonly Page[]
  generalPages?: readonly Page[]
  title?: string
  subtitle?: string
}) {
  const groups = [
    { group: 'This repo', sub: 'Specific to this repo', rows: pages },
    { group: 'General', sub: 'Not specific to this repo: every DKJ-Solutions repo has them', rows: generalPages },
  ].filter((g) => g.rows.length > 0)
  if (groups.length === 0) return null
  if (groups.length === 1) {
    return (
      <CardGroup title={title} subtitle={subtitle}>
        <Card variant="data" className="grid__full">
          <CardBody>
            <PageRows pages={groups[0].rows} label={title} />
          </CardBody>
        </Card>
      </CardGroup>
    )
  }
  return (
    <CardGroup title={title} subtitle={subtitle}>
      {groups.map((g) => (
        <Card key={g.group} variant="data">
          <CardHead level={3} title={g.group} subtitle={g.sub} />
          <CardBody>
            <PageRows pages={g.rows} label={`${g.group} pages`} />
          </CardBody>
        </Card>
      ))}
    </CardGroup>
  )
}
