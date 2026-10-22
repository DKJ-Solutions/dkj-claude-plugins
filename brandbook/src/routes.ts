/**
 * The pages of the brand book. It is served under /brandbook/ (vite.config.ts sets that base), so the brand book
 * itself is the index, and Home is the origin's own '/' rather than a page of this app: the product port's root page
 * in this repo (productRoot), a repo's Repository wherever the plugin's general server serves the build.
 */
export const HUB_PATH = '/'
export const SHOWCASE_PATH = import.meta.env.BASE_URL
