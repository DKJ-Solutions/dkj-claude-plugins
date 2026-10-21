import { Fragment, useEffect, useRef, useState } from 'react'
import { Icon, ICON_NAMES } from '../../components/Icon'
import { Demo, Section } from '../Showcase'
import { HouseThemeReachDemo } from './HouseApp'
import { FG_STEPS, PAPER_STEPS, PRIMARY_STEPS, THEME_STEPS, ThemesDemo } from './HouseStyle'
import { useThemeId } from '../theme'

/** House colour tokens (house-style/house-style.css), grouped by what a theme switch changes, as in house-style/README.md. */
const HOUSE_COLORS = {
  'the primary and the two greys -- changes with every theme': PRIMARY_STEPS,
  'paper, behind the text and on the primary -- changes with every theme': PAPER_STEPS,
  'text (fg), on the paper -- changes with every theme': FG_STEPS,
  'changes only between light and dark -- categories': ['cat-1', 'cat-2', 'cat-3'],
  'changes only between light and dark -- status colours': [
    'negative-1', 'negative-3', 'negative-5', 'positive-1', 'positive-3', 'positive-5', 'warning-1', 'warning-3', 'warning-5',
  ],
} as const


const TEXT_SIZES = [
  '--text-h1', '--text-h2', '--text-h3', '--text-h4', '--text-h5',
  '--text-lg', '--text-base', '--text-sm', '--text-xs',
] as const
const WEIGHTS = ['regular', 'medium', 'semibold', 'bold'] as const
const LINE_HEIGHTS = ['none', 'tight', 'snug', 'prose'] as const
const TRACKING = ['caps', 'label', 'tag'] as const
/** Every step of the house spacing scale. */
const SPACES = [
  '0-5', '1', '1-5', '2', '2-5', '3', '3-5', '4', '4-5', '5', '5-5', '6', '6-5', '7', '7-5', '8', '8-5', '9', '9-5', '10',
  '11', '12', '14', '16', '18', '20', '24', '28', '32', '36', '40', '44', '48', '52', '56', '60', '64', '72', '80', '96',
] as const
/** Sizes: the house app shell, then the brand layer's layout widths. */
const SIZES = ['--control-h', '--tap', '--topbar-h', '--column-narrow', '--dkj-column-w', '--dkj-topbar-h', '--dkj-drawer-w', '--dkj-datecol'] as const
const DURATIONS = ['--dkj-duration-fast', '--dkj-duration-base', '--dkj-duration-slow', '--dkj-duration-panel', '--dkj-duration-flash'] as const
const FOCUS = ['--dkj-focus-w', '--dkj-focus-offset', '--dkj-focus-offset-inset', '--shadow-pop'] as const
const MOTION = [...DURATIONS, '--dkj-ease-out', '--dkj-popup-scale', '--dkj-popup-step'] as const
/** Read as text: tokens that are a number or a word rather than a colour to swatch. */
const READOUTS = [...FOCUS, ...MOTION, '--dkj-font-mono'] as const
const RADII = ['xs', 'sm', 'md', 'md-plus', 'lg', 'xl', 'pill'] as const
const CONTROLS = ['inline-toggle', 'control-dense', 'control-compact', 'control-h', 'tap', 'control-lg'] as const

/** value: as computed (every var() already filled in). declared: as written in the stylesheet, var() names intact. */
type Swatch = { name: string; value: string | undefined; declared: string | undefined }

/**
 * A custom property as WRITTEN on the root -- the computed value has every var() substituted, which turns
 * "var(--muted) 7%, var(--paper-2)" into nested hexes nobody can read. The last matching declaration wins:
 * the theme rules come after the base rule, and a media block counts only while it matches.
 */
function readDeclared(names: string[]): Record<string, string> {
  const root = document.documentElement
  const found: Record<string, string> = {}
  const walk = (rules: CSSRuleList) => {
    for (const rule of Array.from(rules)) {
      if (rule instanceof CSSMediaRule) {
        if (window.matchMedia(rule.conditionText).matches) walk(rule.cssRules)
      } else if (rule instanceof CSSStyleRule && root.matches(rule.selectorText)) {
        for (const n of names) {
          const v = rule.style.getPropertyValue(n).trim()
          if (v) found[n] = v
        }
      }
    }
  }
  for (const sheet of Array.from(document.styleSheets)) {
    try {
      walk(sheet.cssRules)
    } catch {
      // A cross-origin sheet (a web font) cannot be read, and declares no tokens.
    }
  }
  return found
}

const hex2 = (n: number) => n.toString(16).padStart(2, '0')

/** The colour a CSS colour value resolves to, as #rrggbb (or #rrggbbaa when it is translucent), painted on a 1px canvas. */
function resolveHex(value: string): string | undefined {
  const ctx = document.createElement('canvas').getContext('2d', { willReadFrequently: true })
  if (!ctx) return undefined
  ctx.fillStyle = value
  ctx.fillRect(0, 0, 1, 1)
  const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data
  return `#${hex2(r)}${hex2(g)}${hex2(b)}${a < 255 ? hex2(a) : ''}`
}

const unvar = (s: string) => s.replace(/var\((--[\w-]+)\)/g, '$1')

/**
 * A declared color-mix() as a recipe in token names: "color-mix(in srgb, var(--muted) 7%, var(--paper-2))"
 * reads ["--paper-2", "+ 7% --muted"] -- the base, then how much of which colour goes through it. A share
 * that is itself a token (--surface-tint) shows its value. undefined when it is neither a mix nor an alias.
 */
function mixRecipe(declared: string): string[] | undefined {
  // An alias (--x: var(--paper-2)) names the token it stands for.
  const alias = /^var\((--[\w-]+)\)$/.exec(declared)
  if (alias) return [`= ${alias[1]}`]
  const m = /^color-mix\(in srgb,\s*(.+?)\s+([\d.]+%|var\(--[\w-]+\)),\s*(.+)\)$/.exec(declared)
  if (!m) return undefined
  const [, color, share, base] = m
  const pct = share.startsWith('var(') ? getComputedStyle(document.documentElement).getPropertyValue(unvar(share)).trim() : share
  return [unvar(base), `+ ${pct} ${unvar(color)}`]
}

function SwatchGrid({ items }: { items: Swatch[] }) {
  return (
    <div className="dkj-swatches">
      {items.map(({ name, value, declared }) => {
        const recipe = declared ? mixRecipe(declared) : undefined
        return (
          <div key={name} className="dkj-swatch">
            <span className="dkj-swatch-chip" style={{ background: `var(${name})` }} />
            <span className="dkj-swatch-text">
              <code className="dkj-swatch-name">{name}</code>
              {/* A mix shows the colour it comes to, then its recipe; a plain value shows itself. */}
              <span className="dkj-swatch-value">{recipe ? resolveHex(value!) : value}</span>
              {recipe && (
                <span className="dkj-swatch-recipe" title={declared}>
                  {recipe.map((step, i) => (
                    <Fragment key={i}>
                      {i > 0 && ' '}
                      <span>{step}</span>
                    </Fragment>
                  ))}
                </span>
              )}
            </span>
          </div>
        )
      })}
    </div>
  )
}

const HEADINGS = ['h1', 'h2', 'h3', 'h4', 'h5'] as const
type HeadingLevel = (typeof HEADINGS)[number]
type HeadingFacts = { face: string; stack: string; size: string; weight: string; token: string; hex: string }

/**
 * Every heading level as the house style renders it, with its face, size, weight and colour read off the
 * rendered element -- so a theme click, or a change to house-style.css, shows up here without an edit. The
 * colour is named by the theme colour it matches, not looked up in a table.
 */
function HeadingOverview({ theme }: { theme: string }) {
  const refs = useRef<Partial<Record<HeadingLevel, HTMLHeadingElement | null>>>({})
  const [facts, setFacts] = useState<Partial<Record<HeadingLevel, HeadingFacts>>>({})
  useEffect(() => {
    const root = getComputedStyle(document.documentElement)
    const serif = root.getPropertyValue('--font-serif').trim().replace(/\s+/g, ' ')
    const steps = THEME_STEPS.map((s) => `--${s}`)
    const stepHex = steps.map((t) => [t, resolveHex(root.getPropertyValue(t).trim())] as const)
    const sizes = ['--text-h1', '--text-h2', '--text-h3', '--text-h4', '--text-h5']
    const next: Partial<Record<HeadingLevel, HeadingFacts>> = {}
    for (const level of HEADINGS) {
      const el = refs.current[level]
      if (!el) continue
      const cs = getComputedStyle(el)
      const stack = cs.fontFamily.replace(/\s+/g, ' ')
      const hex = resolveHex(cs.color) ?? cs.color
      const size = sizes.find((t) => root.getPropertyValue(t).trim() === cs.fontSize)
      // Quotes and spacing differ between the declared token and the computed stack; the family names do not.
      const bare = (v: string) => v.replace(/["'\s]/g, '')
      next[level] = {
        face: bare(stack) === bare(serif) ? 'serif (--font-serif)' : 'sans (the body face)',
        stack,
        size: size ? `${size} (${cs.fontSize})` : cs.fontSize,
        weight: cs.fontWeight,
        token: stepHex.find(([, h]) => h === hex)?.[0] ?? '(no theme colour)',
        hex,
      }
    }
    setFacts(next)
  }, [theme])
  return (
    <div className="dkj-headings">
      {HEADINGS.map((level) => {
        const Tag = level
        const f = facts[level]
        return (
          <div key={level} className="dkj-heading-row">
            <Tag ref={(el: HTMLHeadingElement | null) => { refs.current[level] = el }}>Heading {level.slice(1)}</Tag>
            {f && (
              <p className="dkj-heading-meta" title={f.stack}>
                {f.face} &middot; <span className="dkj-heading-chip" style={{ background: f.hex }} />
                <code>{f.token}</code> {f.hex} &middot; <code>{f.size}</code>, {f.weight}
              </p>
            )}
          </div>
        )
      })}
    </div>
  )
}

function Readouts({ names, values }: { names: readonly string[]; values: Record<string, string> }) {
  return (
    <dl className="dkj-readouts">
      {names.map((n) => (
        <div key={n}>
          <dt>
            <code>{n}</code>
          </dt>
          <dd>{values[n]}</dd>
        </div>
      ))}
    </dl>
  )
}

/** Live token readouts: every value is read from the computed style, so a theme click changes them. */
export function Foundations() {
  const theme = useThemeId()
  const [values, setValues] = useState<Record<string, string>>({})
  const [declared, setDeclared] = useState<Record<string, string>>({})
  useEffect(() => {
    // Re-read when the house theme changes (useThemeId also fires when the OS scheme moves the default theme).
    const cs = getComputedStyle(document.documentElement)
    const names = [
      ...Object.values(HOUSE_COLORS).flat().map((c) => `--${c}`),
      ...READOUTS,
    ]
    setValues(Object.fromEntries(names.map((n) => [n, cs.getPropertyValue(n).trim()])))
    setDeclared(readDeclared(names))
  }, [theme])

  return (
    <Section
      id="tokens"
      title="Tokens"
      intro="house-style/house-style.css is the one token source for every DKJ-Solutions app; src/brand-layer.css adds only what the house style does not have (--dkj-*: radius, type, controls, focus, motion, layout), and no colour. Click a theme swatch above: every value below is read live and follows."
    >
      {Object.entries(HOUSE_COLORS).map(([group, names]) => (
        <Demo key={group} label={`House colour -- ${group}`} wide>
          <SwatchGrid items={names.map((n) => ({ name: `--${n}`, value: values[`--${n}`], declared: declared[`--${n}`] }))} />
        </Demo>
      ))}
      <Demo label="Themes -- the twelve a user picks from, each with its own eleven colours" wide>
        <ThemesDemo />
      </Demo>
      <Demo label="Theme reach -- links, native controls, selection, and the opt-in --accent modifiers" wide>
        <HouseThemeReachDemo />
      </Demo>
      <Demo label="Type scale -- house" wide>
        <div className="dkj-scale">
          {TEXT_SIZES.map((f) => (
            <div key={f} className="dkj-scale-row">
              <code>{f}</code>
              <span style={{ fontSize: `var(${f})`, color: 'var(--fg-1)', lineHeight: 'var(--dkj-lh-tight)' }}>The quick label 1,234</span>
            </div>
          ))}
        </div>
      </Demo>
      <Demo label="Headings -- h1 to h5: font family, colour, size and weight, read live" wide>
        <HeadingOverview theme={theme} />
      </Demo>
      <Demo label="Type -- weights, line heights, tracking and mono (--dkj-*)" wide>
        <div className="dkj-scale">
          {WEIGHTS.map((w) => (
            <div key={w} className="dkj-scale-row">
              <code>--dkj-fw-{w}</code>
              <span style={{ fontSize: 'var(--text-lg)', fontWeight: `var(--dkj-fw-${w})`, color: 'var(--fg-1)' }}>The quick label 1,234</span>
            </div>
          ))}
          {LINE_HEIGHTS.map((l) => (
            <div key={l} className="dkj-scale-row">
              <code>--dkj-lh-{l}</code>
              <span className="dkj-lh-sample" style={{ lineHeight: `var(--dkj-lh-${l})` }}>
                Two lines of running text in a narrow column, so the space between them shows the line height.
              </span>
            </div>
          ))}
          {TRACKING.map((t) => (
            <div key={t} className="dkj-scale-row">
              <code>--dkj-tracking-{t}</code>
              <span className="dkj-tracking-sample" style={{ letterSpacing: `var(--dkj-tracking-${t})` }}>Uppercase label</span>
            </div>
          ))}
          <div className="dkj-scale-row">
            <code>--dkj-font-mono</code>
            <span style={{ fontFamily: 'var(--dkj-font-mono)', color: 'var(--fg-1)' }}>const tap = '44px' -- 0123456789</span>
          </div>
        </div>
      </Demo>
      <Demo label="Spacing -- house, every step" wide>
        <div className="dkj-scale">
          {SPACES.map((s) => (
            <div key={s} className="dkj-scale-row">
              <code>--spacing-{s}</code>
              <span className="dkj-bar" style={{ width: `var(--spacing-${s})` }} />
            </div>
          ))}
        </div>
      </Demo>
      <Demo label="Radius (--dkj-radius-*)">
        <div className="dkj-demo-row">
          {RADII.map((r) => (
            <div key={r} style={{ display: 'grid', justifyItems: 'center', gap: 'var(--spacing-1)', fontSize: 'var(--text-xs)' }}>
              <span className="dkj-radius" style={{ borderRadius: `var(--dkj-radius-${r})` }} />
              <code>{r}</code>
            </div>
          ))}
        </div>
      </Demo>
      <Demo label="Controls and tap targets (--dkj-*)">
        <div className="dkj-scale">
          {CONTROLS.map((s) => (
            <div key={s} className="dkj-scale-row">
              <code>--dkj-{s}</code>
              <span className="dkj-bar" style={{ width: `var(--dkj-${s})`, height: `var(--dkj-${s})`, opacity: 0.35 }} />
            </div>
          ))}
        </div>
      </Demo>
      <Demo label="Sizes -- house app shell and brand layer layout" wide>
        <div className="dkj-scale">
          {SIZES.map((s) => (
            <div key={s} className="dkj-scale-row">
              <code>{s}</code>
              <span className="dkj-bar" style={{ width: `var(${s})` }} />
            </div>
          ))}
          <div className="dkj-scale-row">
            <code>--dkj-popup-scale</code>
            <span className="dkj-bar" style={{ width: 'calc(var(--dkj-column-w) * var(--dkj-popup-scale))' }} />
          </div>
          <div className="dkj-scale-row">
            <code>--dkj-popup-step</code>
            <span className="dkj-bar" style={{ width: 'calc(var(--dkj-column-w) * var(--dkj-popup-scale) * var(--dkj-popup-step))' }} />
          </div>
        </div>
      </Demo>
      <Demo label="Focus ring and shadow">
        <div className="dkj-demo-row dkj-focus-row">
          <span className="dkj-focus-sample" style={{ outlineOffset: 'var(--dkj-focus-offset)' }}>offset</span>
          <span className="dkj-focus-sample" style={{ outlineOffset: 'var(--dkj-focus-offset-inset)' }}>inset</span>
          <span className="dkj-shadow-sample">shadow</span>
        </div>
        <Readouts names={FOCUS} values={values} />
      </Demo>
      <Demo label="Motion -- hover or focus the tracks to play each duration">
        <div className="dkj-scale dkj-motion" tabIndex={0}>
          {DURATIONS.map((d) => (
            <div key={d} className="dkj-scale-row">
              <code>{d}</code>
              <span className="dkj-motion-track">
                <span className="dkj-motion-dot" style={{ transitionDuration: `var(${d})` }} />
              </span>
            </div>
          ))}
        </div>
        <Readouts names={MOTION} values={values} />
      </Demo>
      <Demo label="Icons (stroke set, currentColor)">
        <div className="dkj-demo-row" style={{ color: 'var(--fg-1)' }}>
          {ICON_NAMES.map((n) => (
            <span key={n} title={n} style={{ display: 'grid', justifyItems: 'center', gap: 'var(--spacing-1)', width: '4rem', fontSize: 'var(--text-xs)' }}>
              <Icon name={n} size={24} />
              {n}
            </span>
          ))}
        </div>
      </Demo>
    </Section>
  )
}
