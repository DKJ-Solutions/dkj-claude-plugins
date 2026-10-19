import { SHOWCASE_PATH } from './routes'

/**
 * The DKJ-Solutions repos that follow the brand book: the repos in the DKJ-Solutions GitHub organisation as of
 * October 13, 2026, except this brand book itself. Each has a recreated app preview in the showcase (#preview/<repo>).
 */
export const REPOS = [
  'dkj-claude-plugins',
  'dkj-etf-tracker',
  'dkj-maplestory-classic-mesowise',
  'dkj-music-library',
  'dkj-recipes',
  'dkj-thumbnail-generator',
  'dkj-lifehub',
] as const

/** The twelve house theme ids (house-style/house-theme.js). */
export type ThemeId =
  | 'magenta' | 'purple' | 'blue' | 'teal' | 'ochre' | 'rust'
  | 'pink' | 'lilac' | 'sky' | 'cyan' | 'yellow' | 'orange'

/**
 * Each DKJ-Solutions repo's default theme, the single source in code (documented in house-style/README.md, "Which
 * theme applies"). The brand book's own is the house default. A missing repo fails tsc.
 */
export const DEFAULT_THEMES: Record<(typeof REPOS)[number] | 'dkj-brandbook', ThemeId> = {
  'dkj-brandbook': 'blue',
  'dkj-etf-tracker': 'sky',
  'dkj-lifehub': 'teal',
  'dkj-claude-plugins': 'lilac',
  'dkj-music-library': 'pink',
  'dkj-recipes': 'rust',
  'dkj-maplestory-classic-mesowise': 'yellow',
  'dkj-thumbnail-generator': 'purple',
}

/** A repo's default theme, or undefined for a name that is not a known repo. */
export const defaultThemeOf = (repo: string): ThemeId | undefined => (DEFAULT_THEMES as Record<string, ThemeId>)[repo]

/** A theme's Dutch display name from the house script ("Paars"), falling back to its id. */
export const themeName = (id: string) => window.DKJTheme.themes.find((t) => t.id === id)?.name ?? id

export const ORG = 'DKJ-Solutions'

/** A repo's recreated app preview in the showcase. */
export const appPreviewPath = (repo: string) => `${SHOWCASE_PATH}#preview/${repo}`
