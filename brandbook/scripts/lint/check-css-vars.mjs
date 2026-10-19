// Fails when src/ reads a custom property that nothing defines (#9).
//
// An undefined var(--x) is valid CSS and resolves to nothing, so eslint, tsc and the build all stay
// green over it. This collects every var(--name) in src/**/*.{ts,tsx,css} and subtracts:
//   - every --name: declared in the house-style.css copy (house-path.mjs) or any stylesheet under src/;
//   - every '--name' key set from TS/TSX (an inline style such as { '--dkj-depth': depth });
//   - a reference with a fallback, var(--x, ...), which is optional by construction;
//   - a name built in a template string, var(--spacing-${s}), which no static scan can resolve.
// Whatever is left is printed and fails the gate.
import { houseCss } from './house-path.mjs'
import { readFileSync, readdirSync } from 'node:fs'
import { join, relative } from 'node:path'

const root = join(import.meta.dirname, '..', '..')

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)],
  )
}

const srcFiles = walk(join(root, 'src')).filter((f) => /\.(tsx?|css)$/.test(f))
// Block comments are blanked (newlines kept, so line numbers hold): a commented-out var() is not a
// read, and a commented-out declaration is not a definition.
const text = new Map(
  [houseCss, ...srcFiles].map((f) => [
    f,
    readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' ')),
  ]),
)

const defined = new Set()
for (const [f, src] of text) {
  const decl = f.endsWith('.css') ? /(--[\w-]+)\s*:/g : /['"](--[\w-]+)['"]\s*:/g
  for (const m of src.matchAll(decl)) defined.add(m[1])
}

const missing = []
for (const f of srcFiles) {
  const src = text.get(f)
  for (const m of src.matchAll(/var\(\s*(--[\w-]+)(\$\{)?\s*(,)?/g)) {
    const [, name, template, fallback] = m
    if (template || fallback || defined.has(name)) continue
    const line = src.slice(0, m.index).split('\n').length
    missing.push(`${relative(root, f).replaceAll('\\', '/')}:${line}  ${name}`)
  }
}

if (missing.length) {
  console.log(`[ERROR] ${missing.length} var() reference(s) to a custom property nothing defines:`)
  for (const m of missing) console.log(`  ${m}`)
  process.exit(1)
}
console.log(`[OK] every var() in src/ resolves (${defined.size} custom properties defined).`)
