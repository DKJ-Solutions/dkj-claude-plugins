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

/**
 * The product port starts at the root: in dev, '/' is root.html, a page linking the brand book, and the two house
 * files it loads are served beside it. Added before Vite's own middleware, so the base never sees these paths.
 * Not in the build, which is the app alone.
 */
function productRoot(): Plugin {
  const page = new URL('root.html', import.meta.url)
  const files: Record<string, [URL, string]> = {
    '/': [page, 'text/html; charset=utf-8'],
    '/index.html': [page, 'text/html; charset=utf-8'],
    '/house-style.css': [new URL('house-style.css', houseDir), 'text/css; charset=utf-8'],
    '/house-theme.js': [new URL('house-theme.js', houseDir), 'text/javascript; charset=utf-8'],
  }
  return {
    name: 'product-root',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = (req.url ?? '').split('?')[0]
        // The base without its slash, as a person types it.
        if (path === '/brandbook') {
          res.statusCode = 303
          res.setHeader('Location', '/brandbook/')
          return res.end()
        }
        const file = files[path]
        if (!file) return next()
        res.setHeader('Content-Type', file[1])
        res.end(readFileSync(file[0]))
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  // The dkj-solutions plugin's general server serves the build under /brandbook/ in every other DKJ-Solutions repo;
  // the dev server uses the same base, so a link means the same thing in both. Its root is productRoot's page.
  base: '/brandbook/',
  plugins: [react(), houseTheme(), productRoot()],
  // The dev server serves only the app root by default; house-style.css is imported from outside it.
  server: { fs: { allow: [searchForWorkspaceRoot(process.cwd()), fileURLToPath(houseDir)] } },
})
