import { useEffect, useState } from 'react'
import { cx } from './components/cx'
import { Icon } from './components/Icon'
import { Breadcrumbs } from './components/Navigation'
import { REPOS } from './repos'
import { HUB_PATH, SHOWCASE_PATH } from './routes'
import { Toolbar } from './showcase/Showcase'
import { Intro } from './showcase/sections/Intro'
import { RepoPreview } from './showcase/previews/RepoPreview'
import { Apps } from './showcase/sections/Apps'
import { RepoHub } from './showcase/sections/RepoHub'
import { Actions } from './showcase/sections/Actions'
import { Data } from './showcase/sections/Data'
import { Forms } from './showcase/sections/Forms'
import { Foundations } from './showcase/sections/Foundations'
import { HouseClasses } from './showcase/sections/HouseStyle'
import { Metrics } from './showcase/sections/Metrics'
import { Overlap } from './showcase/sections/Overlap'
import { Overlays } from './showcase/sections/Overlays'
import { Surfaces } from './showcase/sections/Surfaces'

/** The navigation mirrors the section order below; each id is a component id in src/components/sources.ts. */
const NAV = [
  { group: 'Foundations', items: ['tokens', 'classes'] },
  { group: 'Actions', items: ['Button', 'SegmentedChoice', 'FilterChips', 'IconButton', 'RoundToggle'] },
  { group: 'Surfaces & content', items: ['Card', 'TintedPanel', 'Banner', 'Alert', 'Message', 'Chip', 'TitleTag', 'Help', 'Disclosure', 'ReadMoreToggle', 'GroupHeading', 'QuestionBlock', 'Amount', 'Prose', 'Figure', 'FooterNote'] },
  { group: 'Metrics', items: ['StatTile', 'HeroValue', 'Delta', 'Legend', 'ColumnChart', 'BarChart', 'LineChart', 'MiniCard', 'Meter', 'Badge'] },
  { group: 'Forms & rows', items: ['Field', 'Checkbox', 'Stepper', 'SearchCombobox', 'ValueBox', 'StatRow', 'FormulaRow', 'DateRow'] },
  { group: 'Overlays & navigation', items: ['Dialog', 'Tooltip', 'Drawer', 'TopBar', 'PageHeader', 'Breadcrumbs', 'PageLinks', 'MenuRow', 'StepHeader', 'InfoRow'] },
  { group: 'Data', items: ['DefinitionList', 'DataTable', 'BillTable', 'ComparisonTable', 'CalcTable', 'AnswerBox'] },
  { group: 'Apps', items: ['apps', 'repo-hub', 'overlap'] },
] as const

const LABELS: Record<string, string> = { apps: 'Overview', 'repo-hub': 'Repo hub', overlap: 'Overlap', tokens: 'Tokens', classes: 'House classes' }


/** The repo whose preview the hash asks for, or null for the brand book itself. */
function usePreviewRepo() {
  // Repo names are plain ASCII, so the raw hash is compared as-is: no decode that a malformed hash could make throw.
  const read = () => {
    const m = /^#preview\/(.+)$/.exec(window.location.hash)
    return m && (REPOS as readonly string[]).includes(m[1]) ? m[1] : null
  }
  const [repo, setRepo] = useState(read)
  useEffect(() => {
    let frame = 0
    // Leaving a preview for a section: that section only exists after the next render, so scroll to it then.
    const onHash = () => {
      const next = read()
      setRepo(next)
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        const target = next ? null : document.getElementById(window.location.hash.slice(1))
        if (target) target.scrollIntoView()
        else window.scrollTo(0, 0)
      })
    }
    window.addEventListener('hashchange', onHash)
    return () => {
      window.removeEventListener('hashchange', onHash)
      cancelAnimationFrame(frame)
    }
  }, [])
  return repo
}

const CONTENTS_KEY = 'dkj-brandbook-contents-open'
const NARROW = '(max-width: 52rem)'

/** Whether the contents panel is open; remembered per viewer, and open by default on a wide screen. */
function useContentsOpen() {
  const [open, setOpen] = useState(() => {
    try {
      const saved = window.localStorage.getItem(CONTENTS_KEY)
      if (saved !== null) return saved === 'true'
    } catch {
      // No storage (a private window, blocked site data): fall back to the default.
    }
    return !window.matchMedia(NARROW).matches
  })
  const set = (next: boolean) => {
    setOpen(next)
    try {
      window.localStorage.setItem(CONTENTS_KEY, String(next))
    } catch {
      // Not remembered, but the panel still opens and closes.
    }
  }
  return [open, set] as const
}

export default function App() {
  const previewRepo = usePreviewRepo()
  const [open, setOpen] = useContentsOpen()
  // On a narrow screen the panel lies over the page, so a link there closes it; on a wide one it stays open.
  const follow = () => {
    if (window.matchMedia(NARROW).matches) setOpen(false)
  }
  return (
    <div className={cx('dkj-shell', open && 'dkj-shell--open')}>
      {/* The toggle: half over the panel's edge, shown on hover or keyboard focus (always where there is no hover). */}
      <button
        type="button"
        className="dkj-panel-toggle"
        aria-label={open ? 'Close contents' : 'Open contents'}
        aria-controls="dkj-contents"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <Icon name={open ? 'arrow-left' : 'arrow-right'} />
      </button>
      {/* Closed, the panel is a strip at the left edge: a click on it opens the panel (the toggle is the accessible
          control), and its content is inert -- out of the tab order and hidden from a screen reader. */}
      <aside className="dkj-contents" id="dkj-contents" aria-labelledby="dkj-contents-title" onClick={open ? undefined : () => setOpen(true)}>
        <div className="dkj-contents-inner" inert={!open}>
          <h2 className="dkj-contents-title" id="dkj-contents-title">
            Contents
          </h2>
          <p className="dkj-contents-sub">Jump to a section or an app preview</p>
          <nav className="dkj-nav" aria-labelledby="dkj-contents-title">
            {/* Group labels, not headings: each names its list (aria-labelledby), so the menu keeps its compact size. */}
            {NAV.map((g, n) => (
              <div key={g.group}>
                <p className="dkj-nav-group" id={`dkj-nav-group-${n}`}>
                  {g.group}
                </p>
                <ul aria-labelledby={`dkj-nav-group-${n}`}>
                  {g.items.map((i) => (
                    <li key={i}>
                      <a href={`#${i}`} onClick={follow}>
                        {LABELS[i] ?? i}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
            <p className="dkj-nav-group" id="dkj-nav-group-repos">
              DKJ-Solutions
            </p>
            <ul aria-labelledby="dkj-nav-group-repos">
              {REPOS.map((r) => (
                <li key={r}>
                  <a href={`#preview/${r}`} title={r} aria-current={r === previewRepo ? 'page' : undefined} onClick={follow}>
                    {r}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      </aside>
      {/* The page column: the breadcrumb bar over <main>, beside the panel, which takes the full height. */}
      <div className="dkj-page">
        <Breadcrumbs
          bar
          items={[
            { label: 'Home', href: HUB_PATH },
            ...(previewRepo ? [{ label: 'Brand book', href: SHOWCASE_PATH }, { label: previewRepo }] : [{ label: 'Brand book' }]),
          ]}
        />
        <main className="dkj-main">
          <Toolbar />
          <div className="dkj-content">
            {previewRepo ? (
              <RepoPreview repo={previewRepo} />
            ) : (
              <>
                <Intro />
                <Foundations />
                <HouseClasses />
                <Actions />
                <Surfaces />
                <Metrics />
                <Forms />
                <Overlays />
                <Data />
                <Apps />
                <RepoHub />
                <Overlap />
              </>
            )}
          </div>
        </main>
      </div>
    </div>
  )
}
