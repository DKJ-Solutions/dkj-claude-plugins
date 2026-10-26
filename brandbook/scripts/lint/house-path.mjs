// The one house-style copy this app reads: the dkj-solutions plugin's assets (#3131). The app sits at
// brandbook/ in dkj-claude-plugins, outside plugins/, so the path climbs one level out of the app root.
import { join } from 'node:path'

export const appRoot = join(import.meta.dirname, '..', '..')
export const houseDir = join(appRoot, '..', 'plugins', 'dkj-policy', 'assets', 'house-style')
export const houseCss = join(houseDir, 'house-style.css')
