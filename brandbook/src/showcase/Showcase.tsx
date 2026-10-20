import { useEffect, useRef, type ReactNode } from 'react'
import { SOURCES, type ComponentId } from '../components/sources'
import { cx } from '../components/cx'
import { usagesOf } from '../apps/registry'
import './showcase.css'

/** A labelled group of demos for one component, with its origin printed underneath. */
export function Section({ id, title, intro, children }: { id: ComponentId | 'tokens' | 'classes' | 'apps' | 'overlap'; title: string; intro?: string; children: ReactNode }) {
  const isComponent = id !== 'tokens' && id !== 'classes' && id !== 'apps' && id !== 'overlap'
  const sources = isComponent ? SOURCES[id] : null
  const usages = isComponent ? usagesOf(id) : []
  return (
    <section className="dkj-section" id={id} aria-labelledby={`${id}-title`}>
      <h2 className="dkj-section-title" id={`${id}-title`}>
        {title}
      </h2>
      {intro && <p className="dkj-section-intro">{intro}</p>}
      <div className="dkj-demos">{children}</div>
      {sources && (
        <footer className="dkj-source">
          {usages.length > 0 && (
            <p className="dkj-used-in">
              <strong>Used in:</strong>{' '}
              {usages.map(({ app, view }, i) => (
                <span key={`${app.id}/${view.id}`}>
                  {i > 0 && ', '}
                  <a href={`#app-${app.id}`}>{app.name}</a> &rsaquo; {view.name}
                </span>
              ))}
            </p>
          )}
          {sources.map((s) => (
            <dl key={s.repo}>
              <div>
                <dt>Source</dt>
                <dd>{s.repo}</dd>
              </div>
              <div>
                <dt>{s.file}</dt>
                <dd>{s.components.join(', ')}</dd>
              </div>
              <div>
                <dt>{s.css}</dt>
                <dd>
                  <code>{s.selectors.join('  ')}</code>
                </dd>
              </div>
            </dl>
          ))}
        </footer>
      )}
    </section>
  )
}

/** One variant or state, with its label above it. wide: spans the full row. surface: sits on a card surface. */
export function Demo({ label, children, wide, surface = true }: { label: string; children: ReactNode; wide?: boolean; surface?: boolean }) {
  return (
    <figure className={cx('dkj-demo', wide && 'dkj-demo--wide')}>
      <figcaption>{label}</figcaption>
      <div className={cx('dkj-demo-stage', surface && 'dkj-demo-stage--surface')}>{children}</div>
    </figure>
  )
}

/**
 * The preview settings: the house settings button (DKJTheme.settings) -- a round toggle whose panel holds
 * the theme picker, the page width (fluid, phone, full; set as <html data-width>) and a reset.
 */
export function Toolbar() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    // The house API has no destroy, and settings() leaves an element it has drawn alone (StrictMode runs this twice safely).
    window.DKJTheme.settings(ref.current, {
      label: 'Preview settings',
      theme: 'Theme',
      reset: 'Reset theme',
      light: 'Light',
      dark: 'Dark',
      width: 'Width',
      fluid: 'Fluid',
      phone: 'Phone',
      full: 'Full',
    })
  }, [])
  return (
    <div className="dkj-settings">
      <div className="dkj-settings-anchor" ref={ref} />
    </div>
  )
}
