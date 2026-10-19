import { APPS, VIEW_KINDS } from '../../apps/registry'
import { Section } from '../Showcase'

/** The apps overview, derived from src/apps/registry.ts: per app its header, then its views grouped by kind. */
export function Apps() {
  return (
    <Section
      id="apps"
      title="Apps"
      intro="Every DKJ-Solutions app that follows the house style, and the views it is made of. Each view lists the components it uses; follow a link to see the component. Change the theme above and everything follows."
    >
      {APPS.map((app) => (
        <article key={app.id} className="dkj-app" id={`app-${app.id}`} aria-labelledby={`app-${app.id}-title`}>
          <header>
            <h3 className="dkj-app-name" id={`app-${app.id}-title`}>
              {app.name}
            </h3>
            <p className="dkj-app-desc">{app.description}</p>
            <p className="dkj-app-meta">
              <span>
                Repo: <a href={`https://github.com/${app.repo}`}>{app.repo}</a>
              </span>
              {app.url && (
                <span>
                  Live: <a href={app.url}>{app.url}</a>
                </span>
              )}
              <span>Stack: {app.stack}</span>
              <span>{app.views.length} views</span>
            </p>
          </header>
          {VIEW_KINDS.map(({ kind, label }) => {
            const views = app.views.filter((v) => v.kind === kind)
            if (views.length === 0) return null
            return (
              <div key={kind}>
                <h4 className="dkj-kind">{label}</h4>
                <ul className="dkj-views">
                  {views.map((v) => (
                    <li key={v.id} className="dkj-view">
                      <h5>{v.name}</h5>
                      <p>{v.description}</p>
                      <div className="dkj-view-components">
                        {v.components.map((c) => (
                          <a key={c} href={`#${c}`}>
                            {c}
                          </a>
                        ))}
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
        </article>
      ))}
    </Section>
  )
}
