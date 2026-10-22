import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig, searchForWorkspaceRoot, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

/**
 * The one house-style copy: the dkj-solutions plugin's assets, one level out of this app (#3131). It is read where it
 * lives, never copied in, so the app and every consumer render from the same bytes.
 */
const houseDir = new URL('../plugins/dkj-policy/dkj-solutions/assets/house-style/', import.meta.url)

/**
 * Inlines house-theme.js as the first script in <head>, in dev and in the build,
 * so data-theme is set before first paint and nothing flashes. The file is read, never copied, so it cannot drift.
 * Its header comment mentions a closing script tag, which would end an inline script early: that is escaped.
 */
function houseTheme(): Plugin {
  const file = new URL('house-theme.js', houseDir)
  return {
    name: 'house-theme-inline',
    transformIndexHtml: () => [{ tag: 'script', children: readFileSync(file, 'utf8').replaceAll('</script', '<\\/script'), injectTo: 'head-prepend' }],
  }
}

// https://vite.dev/config/
export default defineConfig({
  // The Repository (scripts/dashboard/serve-connector-dashboard.ps1) serves the build under /brandbook/; the dev server
  // uses the same base, so a link means the same thing in both.
  base: '/brandbook/',
  plugins: [react(), houseTheme()],
  // The dev server serves only the app root by default; house-style.css is imported from outside it.
  server: { fs: { allow: [searchForWorkspaceRoot(process.cwd()), fileURLToPath(houseDir)] } },
})
