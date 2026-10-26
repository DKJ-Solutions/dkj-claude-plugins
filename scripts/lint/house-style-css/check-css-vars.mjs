// Fails when a house-style stylesheet reads a custom property that nothing defines (brandbook #9, moved
// here by #3493).
//
// An undefined var(--x) is valid CSS and resolves to nothing, so no parser and no build complains about
// it. This collects every var(--name) in the house-style stylesheets and subtracts:
//   - every --name: any of them declares;
//   - every parameter the markup sets, which the stylesheet documents in a comment as style="--name: ...",
//     e.g. the legend's --c (read from the raw text, since the comments are blanked below);
//   - a reference with a fallback, var(--x, ...), which is optional by construction.
// Whatever is left is printed and fails the gate.
import { readFileSync } from 'node:fs'
import { relative, sep } from 'node:path'
import { repoRoot, houseSheets } from './house-path.mjs'

// Block comments are blanked (newlines kept, so line numbers hold): a commented-out var() is not a
// read, and a commented-out declaration is not a definition.
const text = new Map(
  houseSheets.map((f) => [f, readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '))]),
)

const defined = new Set()
for (const src of text.values()) for (const m of src.matchAll(/(--[\w-]+)\s*:/g)) defined.add(m[1])
for (const f of houseSheets) for (const m of readFileSync(f, 'utf8').matchAll(/style="\s*(--[\w-]+)\s*:/g)) defined.add(m[1])

const missing = []
for (const [f, src] of text) {
  for (const m of src.matchAll(/var\(\s*(--[\w-]+)\s*(,)?/g)) {
    const [, name, fallback] = m
    if (fallback || defined.has(name)) continue
    const line = src.slice(0, m.index).split('\n').length
    missing.push(`${relative(repoRoot, f).split(sep).join('/')}:${line}  ${name}`)
  }
}

if (missing.length) {
  console.log(`[ERROR] ${missing.length} var() reference(s) to a custom property nothing defines:`)
  for (const m of missing) console.log(`  ${m}`)
  process.exit(1)
}
console.log(`[OK] every var() in the house style resolves (${defined.size} custom properties defined).`)
