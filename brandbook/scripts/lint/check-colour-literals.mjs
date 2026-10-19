// Fails when a stylesheet types a colour instead of reading a token.
//
// Scans the house-style.css copy in the dkj-solutions plugin (house-path.mjs) and every .css under src/. A colour code -- #hex, rgb(), rgba(),
// hsl(), hsla() -- is allowed only in house-style.css, as the value of a custom-property declaration
// (--name: #abc). Two things are reported:
//   - in house-style.css, a colour code anywhere else, e.g. `color: #fff` or inside a color-mix() in a rule;
//   - under src/, ANY colour code, a custom-property declaration included (owner's correction, October 14,
//     2026): every colour there reads a house token with var(). Allowing a declaration let a per-theme
//     set of nav colours stand beside the seven primaries it should have read.
// Codes are compared case-insensitively with #abc expanded to #aabbcc, to name the house token a code repeats. TS/TSX are not scanned: their
// colour codes are data (the theme picker's swatch list, an inline SVG placeholder image), not styling.
import { houseCss } from './house-path.mjs'
import { readFileSync, readdirSync } from 'node:fs'
import { join, relative } from 'node:path'

const root = join(import.meta.dirname, '..', '..')
const house = houseCss

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)],
  )
}

const files = [house, ...walk(join(root, 'src')).filter((f) => f.endsWith('.css'))]
// Comments are blanked (newlines kept, so line numbers hold).
const read = (f) => readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '))

const colour = /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?)\([^)]*\)/g
const norm = (c) => {
  c = c.toLowerCase().replace(/\s+/g, '')
  return /^#[0-9a-f]{3}$/.test(c) ? '#' + [...c.slice(1)].map((x) => x + x).join('') : c
}

// Every code the house style defines, with the first token that holds it.
const houseCodes = new Map()
for (const m of read(house).matchAll(/(--[\w-]+)\s*:([^;}]*)/g)) {
  for (const c of m[2].matchAll(colour)) if (!houseCodes.has(norm(c[0]))) houseCodes.set(norm(c[0]), m[1])
}

const problems = []
for (const f of files) {
  const src = read(f)
  const rel = relative(root, f).replaceAll('\\', '/')
  // The spans of every custom-property declaration's value.
  const decls = [...src.matchAll(/(--[\w-]+)\s*:([^;}]*)/g)].map((m) => ({
    name: m[1],
    from: m.index + m[0].length - m[2].length,
    to: m.index + m[0].length,
  }))
  for (const c of src.matchAll(colour)) {
    const line = src.slice(0, c.index).split('\n').length
    const decl = decls.find((d) => c.index >= d.from && c.index < d.to)
    if (f !== house) {
      const hint = houseCodes.has(norm(c[0])) ? `use var(${houseCodes.get(norm(c[0]))})` : 'read a house token with var()'
      problems.push(`${rel}:${line}  ${decl ? decl.name + ': ' : ''}${c[0]} -- no colour code outside the house style; ${hint}`)
    } else if (!decl) {
      problems.push(`${rel}:${line}  ${c[0]} outside a token declaration -- read a token with var()`)
    }
  }
}

if (problems.length) {
  console.log(`[ERROR] ${problems.length} colour code(s) that should be a token:`)
  for (const p of problems) console.log(`  ${p}`)
  process.exit(1)
}
console.log(`[OK] every colour in the stylesheets is a token (${files.length} files).`)
