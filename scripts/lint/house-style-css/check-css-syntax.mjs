// Fails when a house-style stylesheet does not parse (brandbook #102, moved here by #3493).
//
// A CSS minifier only WARNS on a syntax error (a stray `}`, an unclosed block), so a broken rule can ship
// with every build reading OK. This parses each stylesheet with esbuild and treats any warning it raises
// as a failure.
import { readFileSync } from 'node:fs'
import { relative, sep } from 'node:path'
import { transformSync } from 'esbuild'
import { repoRoot, houseSheets } from './house-path.mjs'

const problems = []
for (const file of houseSheets) {
  const rel = relative(repoRoot, file).split(sep).join('/')
  let warnings
  try {
    ;({ warnings } = transformSync(readFileSync(file, 'utf8'), { loader: 'css', logLevel: 'silent' }))
  } catch (e) {
    warnings = e.errors ?? [{ text: String(e) }]
  }
  for (const w of warnings) problems.push(`${rel}:${w.location?.line ?? '?'}: ${w.text}${w.id ? ` [${w.id}]` : ''}`)
}

if (problems.length) {
  console.log(problems.join('\n'))
  console.log(`[ERROR] ${problems.length} CSS syntax problem(s) in ${houseSheets.length} stylesheet(s).`)
  process.exit(1)
}
console.log(`[OK] ${houseSheets.length} stylesheet(s) parse cleanly.`)
