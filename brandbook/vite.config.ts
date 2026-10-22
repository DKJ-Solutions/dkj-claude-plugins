import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { request, type IncomingMessage, type ServerResponse } from 'node:http'
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
 * The hub's ports: Get-DevPreview's Ports in scripts/repo-config.ps1. The hub is
 * scripts/dashboard/serve-connector-dashboard.ps1, and it builds the product's two live pages.
 */
const HUB_PORTS = Array.from({ length: 10 }, (_, i) => 4870 + i)

/**
 * This checkout's tag, as Get-DevPreviewRootHash computes it in dkj-policy's hub/lib/dev-preview-rules.ps1: the first
 * four bytes of the SHA1 of the lowercased repo root, without a trailing separator. The hub answers it on /whoami.
 */
const ROOT_HASH = createHash('sha1')
  .update(fileURLToPath(new URL('..', import.meta.url)).replace(/[\\/]+$/, '').toLowerCase(), 'utf8')
  .digest('hex')
  .slice(0, 8)

/** A loopback GET to the hub on -port, or null when nothing answers within a moment. */
function hubGet(port: number, path: string): Promise<IncomingMessage | null> {
  return new Promise((resolve) => {
    const req = request({ host: '127.0.0.1', port, path, method: 'GET', headers: { host: `localhost:${port}` }, timeout: 500 }, resolve)
    req.on('timeout', () => req.destroy())
    req.on('error', () => resolve(null))
    req.end()
  })
}

/** Whether the server on -port is this checkout's hub: its /whoami is this root's hash. */
async function isOurHub(port: number): Promise<boolean> {
  const res = await hubGet(port, '/whoami')
  if (!res || res.statusCode !== 200) return false
  let body = ''
  for await (const chunk of res) body += chunk
  return body.trim() === ROOT_HASH
}

let hubPort: number | null = null

/** This checkout's hub port: the one found last while it still answers, else the first of HUB_PORTS that does. */
async function findHub(): Promise<number | null> {
  if (hubPort !== null && (await isOurHub(hubPort))) return hubPort
  hubPort = null
  for (const port of HUB_PORTS) {
    if (await isOurHub(port)) return (hubPort = port)
  }
  return null
}

/**
 * Relays one request to the hub and sends its answer back as it came, so the page is on this origin: its Home crumb
 * ('/') is the product's root, and its links (/refresh?page=connectors, a 303 back to /connectors) stay here too.
 */
async function relayToHub(req: IncomingMessage, res: ServerResponse, target: string) {
  const port = await findHub()
  if (port === null) {
    res.statusCode = 503
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    return res.end('This page is built by the hub (scripts/dashboard/serve-connector-dashboard.ps1), which is not running for this checkout: the dev-preview hook starts it at the next session start.')
  }
  const method = req.method === 'HEAD' ? 'HEAD' : 'GET'
  const up = request({ host: '127.0.0.1', port, path: target, method, headers: { host: `localhost:${port}` } }, (answer) => {
    res.writeHead(answer.statusCode ?? 502, answer.headers)
    answer.pipe(res)
  })
  up.on('error', () => {
    if (res.headersSent) return res.destroy()
    res.statusCode = 502
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.end('The hub did not answer this request. Reload the page in a moment.')
  })
  up.end()
}

/** The product's pages the hub builds: each path, and the refresh that re-reads the connectors or the DKJ repos. */
function hubTarget(path: string, query: string): string | null {
  if (path === '/connectors' || path === '/specialists' || path === '/dkj-repos') return path
  const page = path === '/refresh' ? /(?:^|&)page=(connectors|dkj-repos)(?:&|$)/.exec(query) : null
  return page ? `/refresh?page=${page[1]}` : null
}

/**
 * The product port starts at the root: in dev, '/' is root.html, a page linking the brand book, the connectors, the
 * specialists and the DKJ repos, and the two house files it loads are served beside it. The three live pages are relayed from the
 * hub, which builds them. Added before Vite's own middleware, so the base never sees these paths. Not in
 * the build, which is the brand book app alone.
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
        const [path, query = ''] = (req.url ?? '').split('?')
        const target = hubTarget(path, query)
        if (target) return void relayToHub(req, res, target)
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
