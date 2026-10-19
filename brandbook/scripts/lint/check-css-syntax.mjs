// Fails when a tracked stylesheet does not parse (#102).
//
// vite's CSS minifier only WARNS on a syntax error (a stray `}`, an unclosed block) and the build stays
// green, so a broken rule shipped with the gate reading OK. This parses every tracked *.css with esbuild,
// the parser vite already minifies with (a dependency of vite, so nothing new to install), and treats any
// warning it raises as a failure. Every stylesheet is read from git, not from the import graph, so a file
// nothing imports yet is checked too.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { transformSync } from 'esbuild'
import { appRoot as root, houseCss } from './house-path.mjs'

// git ls-files run from the app root lists the app's own stylesheets only, so the house copy is added by name.
const files = [
  ...execFileSync('git', ['ls-files', '*.css'], { cwd: root, encoding: 'utf8' }).split('\n').filter(Boolean),
  relative(root, houseCss),
]

const problems = []
for (const file of files) {
  const css = readFileSync(join(root, file), 'utf8')
  let warnings
  try {
    ;({ warnings } = transformSync(css, { loader: 'css', logLevel: 'silent' }))
  } catch (e) {
    warnings = e.errors ?? [{ text: String(e) }]
  }
  for (const w of warnings) problems.push(`${file}:${w.location?.line ?? '?'}: ${w.text}${w.id ? ` [${w.id}]` : ''}`)
}

if (problems.length) {
  console.log(problems.join('\n'))
  console.log(`[ERROR] ${problems.length} CSS syntax problem(s) in ${files.length} stylesheet(s).`)
  process.exit(1)
}
console.log(`[OK] ${files.length} stylesheet(s) parse cleanly.`)
