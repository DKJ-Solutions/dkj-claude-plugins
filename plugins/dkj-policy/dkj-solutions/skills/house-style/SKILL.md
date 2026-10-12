---
name: house-style
description: The DKJ-Solutions house style -- the design tokens, the twelve themes a user picks from (and the script that applies them) and the base stylesheet every DKJ-Solutions app renders with, as a self-contained CSS file plus a small script. Use it before writing or restyling ANY visual output in a DKJ-Solutions repo -- a web page, a local HTML report, a dashboard, a claude.ai Artifact, an email template, a chart's colours -- so it starts from the house style instead of a fresh design. Load it alongside artifact-design and dataviz, not instead of them; where they offer a placeholder palette, the house tokens replace it.
---

# The DKJ-Solutions house style

**Every DKJ-Solutions app looks like one family, and this skill is where that family is written down**
(Dave, issue [#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1,
2026). The style was tuned by hand on the ETF dashboard in `dkj-etf-tracker`. Rebuilding it per repo
means re-tuning it per repo, and two hand-tuned copies drift. So the general half was lifted out once,
with **every value kept exactly as chosen** (spacing and font sizes have since moved to the Figma
library's scales, below), and the copy beside this page is the only one:
[`house-style.css`](house-style.css).

**It reaches DKJ-Solutions and nothing else.** The plugin is enabled only in DKJ-Solutions repos.
BWJ-Development has its own styling, and this skill says nothing about it.

## How to use it

1. **Copy `house-style.css` into the output, unchanged**, and `house-theme.js` with it where the app
   lets the user pick a theme (below). Where the output must make no external
   requests (a local report, an Artifact), inline it in a `<style>` block. Where the app has a build,
   vendor it as a file. Either way it is a copy of this file, never a retyped version.
2. **Add the repo's own layer after it, in a separate block or file.** Domain colours and components
   (one app's series mapping, one app's special panel) go there. They **use** house tokens and may add
   tokens of their own, under a name the house file does not define.
3. **Never redefine a house token or a house class in the repo layer.** A value that is wrong for every
   app is fixed here, through the inbound route, so that every app gets the fix. A value that is wrong
   for one app is a new domain token in that app, not an override. Same rule as the constitution:
   extend, never override.

## What it holds

**Tokens**, each in light and dark:

| Group | Tokens | Meaning |
|---|---|---|
| Surfaces and ink | `--page`, `--surface`, `--ink`, `--ink-2`, `--muted`, `--grid`, `--axis`, `--border` | background, cards, three levels of text, lines |
| Categorical | `--cat-1`, `--cat-2`, `--cat-3` | one series each. Never two meanings for one slot in a view |
| Direction | `--gain`, `--loss` (charts), `--up`, `--down` (numbers in text) | result and direction, never a category. `--up`/`--down` are the text versions of `--good`/`--bad`, a step more contrast so a number reads as text: darker on light, lighter on dark |
| Status | `--good`, `--warn`, `--bad`, `--warn-bg`, `--status-mark` | badges, meters, notices. `--status-mark` is the mark inside a status icon (check, cross, "!"): white on light, near-black on dark |
| Primary | `--primary`, `--on-primary`, `--primary-soft` | the theme's own colour, set per theme: the pressed `.seg` button, `.btn--primary`, `.badge--info`, `.meter--info`. `--on-primary` is text on it, `--primary-soft` a tint for a background. Never a status or a number |
| Elevation | `--shadow-pop` | tooltips |
| Spacing | `--spacing-0-5` … `--spacing-96` | the spacing scale, same in both modes: `--spacing-N` is N × 4px, a half step (`-0-5`, `-1-5`, …) adds 2px. Every gap, margin and padding uses one, and a repo layer spaces its own components from the same scale |
| Type | `--text-h0` … `--text-h6`, `--text-lg`, `--text-base`, `--text-sm`, `--text-xs` | the type scale, same in both modes: 48/40/32/24/22/18/16 for the headings, 18/14/12/11 for running text. `h1`–`h3` take the token of their own level, body text is `--text-base` |

**The spacing and type scales have a source: the Figma library** *Shopify Theme - LIBRARY*, variable
collection "Collection", groups `spacing/` and `text/`. Their names and values are copied exactly, so a
design in Figma and a page built from this file share one set of numbers. A step added there is added
here, in a branch of its own. The spacing values happened to match the dashboard already. The type
scale did not, so taking it over changed sizes: body 15 → 14, `h2` 29 → 32, `h3` 18 → 24, the 13px
small text → 12, a mini-card value 20 → 18, the info button's mark 10 → 11 (Maikel, October 12, 2026).

## Themes: the user picks the colour

**Every DKJ-Solutions app has the same form, and a colour of its own that the user picks** (Maikel,
October 12, 2026). The house style carries twelve themes. Each one is a mode, light or dark, plus a
primary colour:

| Mode | Themes (`data-theme`), in hue order |
|---|---|
| Light | `magenta` Magenta `#c0258f`, `purple` Paars `#7a3fd6`, `blue` Blauw `#2563d0`, `teal` Petrol `#0f7c86`, `ochre` Oker `#7a6b00`, `rust` Roest `#ad5a0a` |
| Dark | `pink` Roze `#ff7ac8`, `lilac` Lila `#b69cff`, `sky` Hemelsblauw `#5cb3ff`, `cyan` Cyaan `#2fc8d8`, `yellow` Geel `#f2c230`, `orange` Oranje `#f5873a` |

- **No red and no green theme.** Those hues mean bad and good, and a primary colour beside a red "−1,1%"
  makes the number disappear. The status colours are the same in every theme.
- **Two themes move the warning.** In Roest the warning is a dark yellow (`#b88a00`), because the light
  themes' dark orange would sit on the primary. In Geel it is orange (`#f08a24`), because the dark themes'
  yellow would.
- **Every primary reaches 4.5:1** on its background, and so does the text on it.

**Which theme applies.** `house-theme.js`, beside the stylesheet, decides and sets
`<html data-theme="…">`:

1. the user's own choice, remembered per app on the device;
2. otherwise the app's own default for the OS mode, declared on the page:
   `<html data-theme-light="purple" data-theme-dark="cyan">`. Each app picks its own pair, so apps are
   told apart before anyone has chosen;
3. otherwise the house defaults, Blauw (light) and Cyaan (dark).

Load it in `<head>` so nothing flashes, and call `DKJTheme.picker(element)` where the setting goes: it
draws the twelve swatches in two rows, light and dark. `DKJTheme.set(id)`, `DKJTheme.reset()` and
`DKJTheme.current()` cover everything else. Copy it unchanged, like the stylesheet.

**The theme names and the picker's row labels are Dutch on purpose**: DKJ-Solutions apps are
Dutch-language, and the names are the ones their users read. An app in another language passes its own
row labels, `DKJTheme.picker(el, { light: 'Light', dark: 'Dark' })`. A page that ships
`data-theme="light"` or `"dark"` keeps that mode under the script: the script picks that mode's default
instead of following the OS.

**Without the script the stylesheet still works.** No `data-theme` follows the OS with the house defaults,
and `data-theme="light"` / `"dark"` force a mode the way they always did. The dark block therefore appears
twice in the file, once under `prefers-color-scheme` and once for a forced dark theme. CSS cannot share
it, so **an edit to one dark block is made to both**.

**The source is the preview, mirrored in Figma.** The themes were chosen on a preview page and written
to the Figma library *DKJ-Solutions Theme's - LIBRARY*, group `colors/themes/`, one variable per theme
and role (`--oker-light-primary`, `--light-up`). A value changed there is changed here, in a branch of
its own.

**What this changed for an app that takes the update:** the pressed `.seg` button, `.badge--info` and
`.meter--info` take the primary instead of ink and `--cat-1`; the light warning is dark orange instead
of amber and the dark one a brighter yellow; `--down` on light is a darker red (`#a32424`); on dark
`--up`/`--down` are a step lighter and `--bad` is the dark red it never had; status icons take
`--status-mark`.

## Components

**The complete list of reserved names**, so a repo layer knows what not to redefine:
the page header (`body > header`, `main > header`) and its `.controls` row, `main`/`.container`,
`.hero`, `.tiles`/`.tile`, `.card`, `.grid-2`, `.table-wrap`/`.table` (with `.row-total`, and
sortable headers via `.sort`/`.arrow` on `aria-sort`), `.seg` (a segmented switch), `.legend`/`.legend__item` (with
`--line`), `.swatch`, `.badge` (with `--good`, `--warn`, `--bad`, `--info`, `--neutral`, `--sm`),
`.badge-row`, `.meter` (with `--good`, `--warn`, `--bad`, `--info`), `.mini-cards`/`.mini-card` (with
`--highlight`), `.item-grid`/`.item`, `.notice`, `.note`, `.meta`, `.muted`, `.sub`, `.num` (tabular
numerals), `.delta` (with `--up`/`--down`, aliased `.pos`/`.neg`), `.btn` (with `--primary`), `.info-button`, `.tooltip`
(with `--explain`), `.more` (a disclosure), `.moretoggle` (a full-width read-more button), `.chart` (the SVG chart scope),
`.theme-picker` (with `__row`, `__label`, `__swatches`) and `.theme-swatch` (with `--light`, `--dark`), which
`house-theme.js` draws, and `.footer-note`. Each is
commented in the file.

## What was deliberately left out

The parts of the ETF dashboard that only make sense there stayed there: the hazard-striped advice zone
and its tokens, the market report's layout, the month-note button drawn on a chart bar, the
primary/secondary view switch, the mapping from ETF/share/cash to a colour, and the Dutch status class
names. The three
series colours survive as `--cat-1..3`, with the same values. A generic danger/alert component is **not**
in the house style yet. Adding one is a design decision for the owner, not something to back-fill from
the advice zone.

## Changing the house style

A change here reaches every DKJ-Solutions app at its next plugin update, so it is a **visible result**:
the branch stops for the owner's look instead of merging. Bring a consumer's improvement here through
an inbound issue on this repo. Don't make a local edit and hope it travels.
