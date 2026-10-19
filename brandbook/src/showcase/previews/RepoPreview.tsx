import type { ComponentType } from 'react'
import { APPS } from '../../apps/registry'
import { Card } from '../../components/Card'
import { Message } from '../../components/Feedback'
import { defaultThemeOf, themeName } from '../../repos'
import { useRepoDefaultTheme } from '../theme'
import { EtfPreview } from './EtfPreview'
import { LifeHubPreview } from './LifeHubPreview'
import { MesowisePreview } from './MesowisePreview'
import { MusicLibraryPreview } from './MusicLibraryPreview'
import { PluginsPreview } from './PluginsPreview'
import { RecipesPreview } from './RecipesPreview'
import { ThumbnailPreview } from './ThumbnailPreview'

/** The recreated previews, keyed by repo name; a repo not in here shows a "preview follows" card. */
const PREVIEWS: Partial<Record<string, ComponentType>> = {
  'dkj-maplestory-classic-mesowise': MesowisePreview,
  'dkj-etf-tracker': EtfPreview,
  'dkj-claude-plugins': PluginsPreview,
  'dkj-music-library': MusicLibraryPreview,
  'dkj-recipes': RecipesPreview,
  'dkj-thumbnail-generator': ThumbnailPreview,
  'dkj-lifehub': LifeHubPreview,
}

/** A repo's page behind the navigation list: its links, then the recreated app in a frame, or a placeholder. */
export function RepoPreview({ repo }: { repo: string }) {
  const Preview = PREVIEWS[repo]
  const app = APPS.find((a) => a.repo === `DKJ-Solutions/${repo}`)
  const theme = defaultThemeOf(repo)
  useRepoDefaultTheme(repo)
  return (
    <section className="dkj-section" aria-labelledby="preview-title">
      <p className="dkj-preview-back">
        <a href="#apps">&larr; Back to the brand book</a>
      </p>
      <h2 className="dkj-section-title" id="preview-title">
        {app?.name ?? repo}
      </h2>
      <p className="dkj-section-intro">
        {Preview
          ? "A recreated preview, built from the brand-book components with placeholder content. It opens in the repo's own default theme; pick another theme or change the width above and it follows."
          : 'No recreated preview yet.'}
      </p>
      <p className="dkj-app-meta dkj-preview-meta">
        <span>
          Repo: <a href={`https://github.com/DKJ-Solutions/${repo}`}>DKJ-Solutions/{repo}</a>
        </span>
        {theme && (
          <span>
            Default theme: {themeName(theme)}
          </span>
        )}
        {app?.url && (
          <span>
            Live: <a href={app.url}>{app.url}</a>
          </span>
        )}
        {app && (
          <span>
            Views: <a href={`#app-${app.id}`}>{app.views.length} in the apps overview</a>
          </span>
        )}
      </p>
      {Preview ? (
        <div className="dkj-preview-frame">
          <Preview />
        </div>
      ) : (
        <Card>
          <Message>The preview of {repo} follows: its screens are recreated here once they have been researched.</Message>
        </Card>
      )}
    </section>
  )
}
