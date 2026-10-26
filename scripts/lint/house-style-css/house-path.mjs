// The stylesheets this gate reads: every .css in the dkj-solutions plugin's house-style folder (#3493).
// house-style.css is the token source; any other stylesheet there is a layer on top of it and holds no
// colour code of its own. Read from the folder and every folder under it rather than named, so a
// stylesheet added later is gated without an edit here.
import { readdirSync } from 'node:fs'
import { join } from 'node:path'

export const repoRoot = join(import.meta.dirname, '..', '..', '..')
export const houseDir = join(repoRoot, 'plugins', 'dkj-policy', 'dkj-solutions', 'assets', 'house-style')
export const houseCss = join(houseDir, 'house-style.css')
export const houseSheets = readdirSync(houseDir, { recursive: true })
  .filter((f) => f.endsWith('.css'))
  .sort()
  .map((f) => join(houseDir, f))
