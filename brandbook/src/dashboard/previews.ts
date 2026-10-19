import type { ComponentType } from 'react'
import { ConnectedReposPreview } from './ConnectedReposPreview'
import {
  EtfDashboardPreview,
  LifeHubDashboardPreview,
  MesowiseDashboardPreview,
  MusicDashboardPreview,
  RecipesDashboardPreview,
  ThumbnailDashboardPreview,
} from './RepoPreviews'

export type DashboardPreview = { id: string; label: string; description: string; Component: ComponentType }

/**
 * The repos whose dashboard can be previewed, each on /dashboards/<id> (the id is the repo name in src/repos.ts). Add an
 * entry to preview another repo; its data stays placeholder data. The Repo hub's repo list links every entry here.
 */
export const PREVIEWS: readonly DashboardPreview[] = [
  {
    id: 'dkj-claude-plugins',
    label: 'dkj-claude-plugins',
    description: 'The connector dashboard: every repo that runs the plugins, its status, installed version and checkout.',
    Component: ConnectedReposPreview,
  },
  {
    id: 'dkj-etf-tracker',
    label: 'dkj-etf-tracker',
    description: 'The last run from the ledger to the generated investment page, step by step.',
    Component: EtfDashboardPreview,
  },
  {
    id: 'dkj-maplestory-classic-mesowise',
    label: 'dkj-maplestory-classic-mesowise',
    description: 'What is live on GitHub Pages, and the game-data tables the app works from.',
    Component: MesowiseDashboardPreview,
  },
  {
    id: 'dkj-music-library',
    label: 'dkj-music-library',
    description: 'The library as the last sync left it, and the recent syncs.',
    Component: MusicDashboardPreview,
  },
  {
    id: 'dkj-recipes',
    label: 'dkj-recipes',
    description: 'The recipe collection, and every recipe that does not follow the template.',
    Component: RecipesDashboardPreview,
  },
  {
    id: 'dkj-thumbnail-generator',
    label: 'dkj-thumbnail-generator',
    description: 'The last thumbnail rounds against the yardstick.',
    Component: ThumbnailDashboardPreview,
  },
  {
    id: 'dkj-lifehub',
    label: 'dkj-lifehub',
    description: 'The content folders, and the checks the local app relies on.',
    Component: LifeHubDashboardPreview,
  },
]
