/**
 * The pages of the brand book. It is served by the Repo hub under /brandbook/ (vite.config.ts sets that base), so
 * the brand book itself is the index, and the hub it sits under is the hub's own '/' rather than a page of this app.
 */
export const HUB_PATH = '/'
export const SHOWCASE_PATH = import.meta.env.BASE_URL
/** The Repo hub pattern: how a DKJ-Solutions repo's home page is laid out, drawn with the brand book's components. */
export const DASHBOARD_PATH = `${import.meta.env.BASE_URL}repo-hub`
/** The Repo hub pattern's second page, About this repo (DKJ-Solutions/dkj-claude-plugins#3270). */
export const ABOUT_PATH = `${import.meta.env.BASE_URL}repo-hub/about`
/** The preview of other repos' Repo hubs, to check that the hub shape fits what they will put in theirs. */
export const DASHBOARDS_PATH = `${import.meta.env.BASE_URL}dashboards`

/** A path without its trailing slash and index.html, so /x, /x/ and /x/index.html compare equal. */
const normalise = (path: string) => path.replace(/\/index\.html$/, '').replace(/\/$/, '')

export function isDashboardsPath(pathname: string) {
  return normalise(pathname) === normalise(DASHBOARDS_PATH)
}

/** One repo's dashboard preview: /dashboards/<id>. */
export const dashboardPreviewPath = (id: string) => `${DASHBOARDS_PATH}/${id}`

/** The id in /dashboards/<id>, or null for any other path. Ids are plain ASCII repo names, so nothing is decoded. */
export function dashboardPreviewId(pathname: string) {
  const prefix = `${DASHBOARDS_PATH}/`
  const path = normalise(pathname)
  return path.startsWith(prefix) && path.length > prefix.length ? path.slice(prefix.length) : null
}

export function isDashboardPath(pathname: string) {
  return normalise(pathname) === normalise(DASHBOARD_PATH)
}

export function isAboutPath(pathname: string) {
  return normalise(pathname) === normalise(ABOUT_PATH)
}
