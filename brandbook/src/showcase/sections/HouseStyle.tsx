import houseCss from '../../../../plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css?raw'
import houseThemeJs from '../../../../plugins/dkj-policy/dkj-solutions/assets/house-style/house-theme.js?raw'
import { Demo, Section } from '../Showcase'

const STEPS = Array.from({ length: 12 }, (_, i) => i + 1)

/** The light and dark house defaults, read from house-theme.js's HOUSE_DEFAULT (the API does not expose them). */
const HOUSE_DEFAULTS = (() => {
  const m = /HOUSE_DEFAULT\s*=\s*\{\s*light:\s*'([a-z]+)',\s*dark:\s*'([a-z]+)'\s*\}/.exec(houseThemeJs)
  return m ? [m[1], m[2]] : []
})()

/**
 * Each theme's own values, from its block in house-style.css (":root[data-theme="<id>"], .theme-swatch[data-id="<id>"]
 * { ... }"): its twelve --primary-* steps, and what else it sets (the warning colour on Roest and Geel). Read from the
 * stylesheet's text, so a theme's row shows that theme whatever theme the page itself is in.
 */
function themeBlock(id: string): { steps: (string | undefined)[]; extras: string[] } {
  const block = new RegExp(`:root\\[data-theme="${id}"\\]\\s*,\\s*\\.theme-swatch\\[data-id="${id}"\\]\\s*\\{([^}]*)\\}`).exec(houseCss)
  const props = new Map(Array.from((block?.[1] ?? '').matchAll(/--([a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{3,8})\s*;/g), (p) => [p[1], p[2]] as const))
  return {
    steps: STEPS.map((n) => props.get(`primary-${n}`)),
    extras: [...props].filter(([k]) => !/^primary-([1-9]|1[0-2])$/.test(k)).map(([k, v]) => `--${k} ${v}`),
  }
}

/** The twelve themes a user picks from, in the picker's order, each with its own twelve steps. */
export function ThemesDemo() {
  const themes = window.DKJTheme.themes
  return (
    <div className="table-wrap">
      <table className="table dkj-themes">
        <thead>
          <tr>
            <th>Theme</th>
            <th>Mode</th>
            {STEPS.map((n) => (
              <th key={n}>-{n}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {themes.map((t) => {
            const { steps, extras } = themeBlock(t.id)
            const notes = [...(HOUSE_DEFAULTS.includes(t.id) ? [`the house default for ${t.mode}`] : []), ...extras.map((x) => `also sets ${x}`)]
            return (
              <tr key={t.id}>
                <td>
                  <strong>{t.name}</strong> <code>{t.id}</code>
                  {notes.length > 0 && <p className="note">{notes.join('; ')}</p>}
                </td>
                <td>{t.mode === 'dark' ? 'Dark' : 'Light'}</td>
                {steps.map((hex, i) => (
                  <td key={i}>{hex ? <span className="dkj-theme-chip" style={{ background: hex }} title={`--primary-${i + 1} ${hex}`} /> : '--'}</td>
                ))}
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

/**
 * Every class house-style.css defines, by its "/* ---- Name ---- *\/" section. A pattern read, not a CSS parse: the
 * declaration blocks go (innermost first, so the selectors inside an @media stay), and what is left is selectors.
 */
const CLASS_SECTIONS = (() => {
  const heads = Array.from(houseCss.matchAll(/\/\* -{4} (.+?)\s+-+ \*\//g))
  return heads
    .map((h, i) => {
      const from = h.index! + h[0].length
      const to = i + 1 < heads.length ? heads[i + 1].index! : houseCss.length
      const text = houseCss.slice(from, to).replace(/\/\*[\s\S]*?\*\//g, '').replace(/\{[^{}]*\}/g, ' ').replace(/[{}]/g, ' ')
      const classes = [...new Set(Array.from(text.matchAll(/(?<![\w-])\.([a-z][a-z0-9_-]*)/g), (m) => m[1]))]
      return { title: h[1], classes }
    })
    .filter((s) => s.classes.length > 0)
})()

export function HouseClasses() {
  return (
    <Section
      id="classes"
      title="House classes"
      intro="Every class house-style.css defines, by its section, read from the stylesheet itself. A repo's own layer extends these and never restyles one."
    >
      <Demo label={`${CLASS_SECTIONS.length} sections, ${new Set(CLASS_SECTIONS.flatMap((s) => s.classes)).size} classes`} wide>
        <div className="table-wrap">
          <table className="table dkj-classes">
            <thead>
              <tr>
                <th>Section</th>
                <th>Classes</th>
              </tr>
            </thead>
            <tbody>
              {CLASS_SECTIONS.map((s) => (
                <tr key={s.title}>
                  <td>{s.title}</td>
                  <td>
                    {s.classes.map((c) => (
                      <code key={c}>.{c} </code>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Demo>
    </Section>
  )
}
