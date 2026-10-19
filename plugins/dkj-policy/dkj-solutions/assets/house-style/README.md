# The DKJ-Solutions house style

**Every DKJ-Solutions app looks like one family, and this folder is where that family is written down**
(Dave, issue [#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1,
2026). The style was tuned by hand on the ETF dashboard in `dkj-etf-tracker`. Rebuilding it per repo
means re-tuning it per repo, and two hand-tuned copies drift. So the general half was lifted out once,
with **every value kept exactly as chosen** (spacing and font sizes have since moved to the Figma
library's scales, below), and the copy in this folder is the only one:
[`house-style.css`](house-style.css) and [`house-theme.js`](house-theme.js).

**It lives in the `dkj-solutions` plugin**, where the `house-style` skill that loads in every
DKJ-Solutions session points at it. It spent October 13 to 18, 2026 in the `dkj-brandbook` repo and came
back with [#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130). **A session or a build
fetches a tagged release, never `main`** (owner's decision on
[dkj-brandbook#3](https://github.com/DKJ-Solutions/dkj-brandbook/issues/3), October 13, 2026):
`house-theme.js` is executable and runs with the origin of every page it is inlined into, and `main` is a
moving ref that an admin can push to past the review. A tag is a version somebody chose to release. Raw
URLs, with `<tag>` the release tag the skill pins, which the release cut writes into the skill
([#3133](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3133)):

- `https://raw.githubusercontent.com/DKJ-Solutions/dkj-claude-plugins/<tag>/plugins/dkj-policy/dkj-solutions/assets/house-style/house-style.css`
- `https://raw.githubusercontent.com/DKJ-Solutions/dkj-claude-plugins/<tag>/plugins/dkj-policy/dkj-solutions/assets/house-style/house-theme.js`

**It reaches DKJ-Solutions and nothing else.** BWJ-Development has its own styling.

## How to use it

1. **Copy `house-style.css` into the output, unchanged**, and `house-theme.js` with it where the app
   lets the user pick a theme (below). Where the output must make no external
   requests (a local report, an Artifact), inline it in a `<style>` block. Where the app has a build,
   vendor it as a file. Either way it is a copy of this file, never a retyped version.
2. **Add the repo's own layer after it, in a separate block or file.** Domain colours and components
   (one app's series mapping, one app's special panel) go there. They **use** house tokens and may add
   tokens of their own, under a name the house file does not define.
3. **Never redefine a house token or a house class in the repo layer.** A value that is wrong for every
   app is fixed here, through an issue on this repo, so that every app gets the fix. A value that is wrong
   for one app is a new domain token in that app, not an override. Same rule as the constitution:
   extend, never override. One narrow exception: a component subtree may re-declare a house colour token
   (`--primary-5`, `--primary-2`) so its contents follow a tint, as the info and accent dialogs do;
   the token is never changed for the page. Everything inside such a subtree inherits the re-declared value,
   so a tinted dialog nested inside an info dialog would tint from `--cat-1`; do not nest them.

## What it holds

**Tokens**, each in light and dark:

| Group | Tokens | Meaning |
|---|---|---|
| Surfaces and lines | `--primary-1`, `--primary-2`, `--primary-3` | background (`-1`), cards (`-2`), every line: borders, row dividers, grid lines, the meter track (`-3`): a fixed value per theme, a grey with a light tint of the theme's colour ([below](#how-far-a-theme-reaches)) |
| Categorical | `--cat-1`, `--cat-2`, `--cat-3` | one series each. Never two meanings for one slot in a view |
| Direction | `--positive-3` and `--negative-3` (also the gain and the loss in charts, so a direction chart can share a view with any series), `--positive-5`, `--negative-5` (numbers in text) | result and direction, never a category. `--positive-5`/`--negative-5` are the text versions of `--positive-3`/`--negative-3`, a step more contrast so a number reads as text: darker on light, lighter on dark |
| Status | `--positive-3`, `--warning-3`, `--negative-3`, `--warning-5`, `--warning-1`, `--negative-1`, `--positive-1` | badges, meters, notices. `--warning-1`, `--negative-1` and `--positive-1` are the backgrounds of a warning, negative or positive message. The mark inside a status icon (check, cross, "!") is `--primary-1` |
| Primary | `--primary-3` … `--primary-9` | `--primary-4`, `-5` and `-6` are the greys: softened, greyer steps of the theme's colour in the middle of the scale, with `-5` in the middle, a little more coloured than the other two (`-4` a step towards the ground, no role yet; `-6` a step towards the far end), and the colour itself is `--primary-7` and `-8`. `-5` is the pressed `.seg` button, `.badge--info`, `.meter--info`, and the `--accent` modifiers ([below](#how-far-a-theme-reaches)); `--primary-1` is the text on it. `-6` is every sub line (`.sub`, `.dialog__sub`, a component's `-sub`) and every note (`.note`, `.footer-note`, `.muted`), on a `<p>` too (owner's decision, October 15, 2026). `--primary-9` is **all text**, paragraphs and everything else: labels, table heads, legends, quiet icons, and the text on a tinted surface; `--primary-7` is **the highlight**, kept for `h1` and `h2`, the fill of `.btn--primary` (a filled main action, like the filled icon button; owner's decision, October 15, 2026, #109), a state (hover, focus, pressed, sorted, active, today), `strong`, list markers, links, a value meant to stand out, the accent dialog's title and the settings panel's title, and native controls through `accent-color` (owner's decision, October 15, 2026: as all text `-7` was no longer an accent, and `-9` was chosen over `-8`). `--primary-3` is also the tinted surface (an accent table head, a hover, the accent dialog). `--primary-8` is also `h3`–`h6`; `--primary-9` is the far end: **every paragraph** (`<p>`, `.meta` on it included; sub lines, notes and `.muted` excepted), and an inverted surface, where `h1` and `h2` take `--primary-3` and `h3`–`h6` take `--primary-2`. Never a status or a number |
| Elevation | `--shadow-pop` | tooltips |
| Spacing | `--spacing-0-5` … `--spacing-96` | the spacing scale, same in both modes: `--spacing-N` is N × 4px, a half step (`-0-5`, `-1-5`, …) adds 2px. Every gap, margin and padding uses one, and a repo layer spaces its own components from the same scale |
| Type | `--text-h0` … `--text-h6`, `--text-lg`, `--text-base`, `--text-sm`, `--text-xs`, `--font-serif` | the type scale, same in both modes: 48/40/32/24/22/18/16 for the headings, 18/14/12/11 for running text. `h1`–`h6` each take the token of their own level, body text is `--text-base`. The one exception is a section label (`GroupHeading`): it stays a heading for the document outline, but every level renders at `--text-base`, uppercase and muted (owner's decision, October 15, 2026). `--font-serif` is the face of `h1` and `h2`, for a title that keeps it at another level |
| App shell | `--control-h`, `--tap`, `--topbar-h`, `--column-narrow` | sizes for a mobile-first app, same in both modes: 38px for a value field and the button beside it, 44px as the smallest touch target, 56px for the top bar, 512px for the narrow app column |

`--gain` was removed (October 14, 2026). A gain in a chart is `--positive-3` (owner's decision, October 15, 2026, #131); before that it was `--cat-1`.

**The colour tokens were renamed the same day** (owner's decision): the status and direction colours so each
name says which side it is on, and the black, white and grey ones merged into one five-step ramp. An app that takes this update renames them in its own layer:

| Was | Now |
|---|---|
| `--good`, `--up` | `--positive-3`, `--positive-5` |
| `--bad`, `--down` | `--negative-3`, `--negative-5` |
| `--loss` | removed: a loss in a chart takes `--negative-3` (in the brand book, `LegendItem color="negative-3"`) |
| `--warn`, `--warn-bg` | `--warning-3`, `--warning-1` |
| `--on-warn` | removed: text on a `--warning-3` fill takes `--neutral-3`, which turns light on the dark themes |
| (new) | `--warning-5`: a warning in text, a step darker on light and lighter on dark, like `--negative-5` |
| (new) | `--negative-1`, `--positive-1`: the backgrounds of a negative or positive message, beside `--warning-1` |
| `--page-base`, `--on-primary`, `--status-mark` | `--primary-1` |
| `--surface-base` | `--neutral-1` |
| `--grid-base`, `--border-base`, `--axis` | `--neutral-2`. `--primary-3` is now a solid line over it instead of a translucent one |
| `--ink-2`, `--ink` | `--neutral-3` |
| `--muted` | removed: notes, quiet icons and chevrons take `--neutral-3`; the `.muted` class keeps its name |
| the five-step neutral ramp (October 14, 2026) | cut to three steps; **the name `--neutral-1` is live again with a new meaning**. Mapping, old → new, in the order to apply it so nothing is renamed twice: |
| old `--neutral-1` (the ground: text and icons on the primary, the mark in a status icon, the dialog backdrop) | `--primary-1` (the theme's own page colour, tinted) |
| old `--neutral-2` (surface base) | `--neutral-1`, with a **new value**: `#ebebe8` / `#262625` instead of `#f9f9f7` / `#1a1a19`, to set it clearly apart from the page |
| old `--neutral-3` (lines) | `--neutral-2`, same value |
| old `--neutral-4` (secondary text) | `--neutral-3`, same value |
| old `--neutral-5` (primary text, focus outlines, the inverted button, the 7% tints), **last** | `--neutral-3`. **Primary text changed value**: `#0b0b0b` / `#ffffff` became `#52514e` / `#c3c2b7`, so primary text has lower contrast and the 7% tints are weaker |
| `--page`, `--surface`, `--primary-soft` | `--primary-1`, `--primary-2`, `--primary-3` |
| `--border`, `--grid` | `--primary-3`, one line colour for both |
| `--primary`, `--primary-ink` | `--primary-4`, `--primary-4` |
| the six-step primary scale (October 14, 2026) | grown to **seven steps with the theme's colour in the middle** (owner's decision: `--primary-4` is the most saturated step, the anchor; `-3` and `-5` the greyest, `-5` the far-side mirror of `-3`). **`--primary-4` and `--primary-5` are live again with new meanings.** Mapping, old → new, in the order to apply it so nothing is renamed twice: |
| old `--primary-4` (lines), **first** | `--primary-3`, same value |
| old `--primary-3` (the tinted background) | `--primary-3`: the tinted surfaces now share the line colour, with `--primary-5` as their text |
| old `--primary-5` (the colour: fills, switches, focus rings) | `--primary-4` |
| old `--primary-6` (the colour as text: links, `h1`, `h2`), **last** | `--primary-4`. On dark the fills and the links change value: they were near-white and are now the theme's colour itself (Oranje `#f5873a`) |
| (new) | `--primary-5` (all text), `--primary-6` (no role yet), `--primary-7` (an inverted surface) |
| the three-step neutral ramp (October 14, 2026) | **removed** (owner's decision): the greys are the primary scale's own `-3` and `-5`, tinted towards the theme. Apply after the primary rows above |
| `--neutral-3` (all text, labels, focus outlines, the inverted button) | `--primary-5`. Same lightness (`#52514e` became e.g. `#524a5e` in Paars, `#c3c2b7` became e.g. `#c39b85` in Oranje), now in the theme's tint |
| `--neutral-2` (the grey line: borders, the info-button outline, the neutral badge, the blockquote bar) | `--primary-3`; a chart's zero line, axis and crosshair take `--primary-5`, so they stay apart from the `--primary-3` gridlines |
| `--neutral-1` (the next plane: the info dialog's base) | `--primary-2` |

**Check after migrating:** an undefined `var(--neutral-*)` or `var(--primary-6)` used in its old meaning fails silently or wrongly (text inherits its colour, an SVG fill or stroke goes black). Find leftovers with `grep -rn "neutral-" src`.

The class modifiers keep their names: `.badge--good`, `.badge--bad`, `.badge--warn`, `.meter--good`,
`.meter--bad`, `.meter--warn`, `.delta--up`, `.delta--down`.

**The primary scale grew from seven to nine steps on October 15, 2026** (owner's decision): two new greys sit
either side of the old `-4`, so the greys are now a trio, `-4`, `-5` and `-6`, with `-5` in the middle. Every role
keeps its colour and moves with its step; only the number changes. An app that takes this update renames in its own
layer, in this order so nothing is renamed twice:

| Was | Now |
|---|---|
| `--primary-7` (every paragraph, all text, an inverted surface), **first** | `--primary-9` |
| `--primary-6` (`h3`–`h6`) | `--primary-8` |
| `--primary-5` (the highlight: `h1`, `h2`, a state, `accent-color`) | `--primary-7` |
| `--primary-4` (the fills, focus rings, links, the picker's dot), **last** | `--primary-5` |
| (new) | `--primary-4`, a grey a step towards the ground (darker on dark, lighter on light), no role yet |
| (new) | `--primary-6`, a grey a step towards the far end (lighter on dark, darker on light): sub lines, notes and `.muted` |
| links (`a:any-link`, `.dkj-prose a`, `.dkj-msg a`) | `--primary-7`, the colour, instead of the grey `--primary-5` (owner's decision, the same day). |
| sub lines and notes (`.sub`, `.dialog__sub`, `.note`, `.footer-note`, `.muted`, `.dkj-muted`, `.dkj-card-sub`, `.dkj-dialog-sub`, `.dkj-row-sub`, `.dkj-daterow-sub`, `.dkj-calc-sub`) | `--primary-6` instead of `--primary-9`, on a `<p>` too (owner's decision, the same day) |

**A number in a colour token is a step on the ground-to-text scale** (owner's decision, October 14, 2026):
`-1` is light on the light themes and dark on the dark themes (the ground end) and the highest number is the
opposite (the text end). `--negative-*`, `--positive-*` and `--warning-*` follow it with `-1`, `-3`, `-5`, and
`--primary-1` … `--primary-9` is a nine-step family. There are no untinted neutrals: the greys are the primary's
own `-4`, `-5` and `-6`, a greyed step of the theme's colour with `-5` in the middle, and the colour itself is `-7`
and `-8`. The primary steps are (page, cards, lines and tinted surfaces, a grey with no role yet, the fills and
links, sub lines and notes, the highlight, `h3`–`h6`, all text and an inverted surface). For the status families:
`-1` is the background of a message, `-3` the fill (icon, badge, meter, a
loss in a chart), `-5` the text.

**The colour tokens grouped by what a theme switch changes** (the grouping the showcase's Tokens section
uses):

| A switch … | Tokens | Why |
|---|---|---|
| to any other theme changes them | `--primary-1` … `--primary-9` | each theme sets all nine as fixed values, around its own `--primary-5` |
| changes them only between light and dark: categories | `--cat-1`, `--cat-2`, `--cat-3` | series slots, set once in the light block and once in the dark block, a shade apart |
| changes them only between light and dark: status colours | `--negative-1`, `--negative-3`, `--negative-5`, `--positive-1`, `--positive-3`, `--positive-5`, `--warning-1`, `--warning-3`, `--warning-5` | set once in the light block and once in the dark block, a shade apart. One exception: `--warning-3` also moves in Roest and Geel ([below](#themes-the-user-picks-the-colour)) |

**The spacing and type scales have a source: the Figma library** *Shopify Theme - LIBRARY*, variable
collection "Collection", groups `spacing/` and `text/`. Their names and values are copied exactly, so a
design in Figma and a page built from this file share one set of numbers. A step added there is added
here, in a branch of its own. The spacing values happened to match the dashboard already. The type
scale did not, so taking it over changed sizes: body 15 → 14, `h2` 29 → 32, `h3` 18 → 24, the 13px
small text → 12, a mini-card value 20 → 18, the info button's mark 10 → 11 (Maikel, October 12, 2026).

## Themes: the user picks the colour

**Every DKJ-Solutions app has the same form, and a colour of its own that the user picks** (Maikel,
October 12, 2026). The house style carries twelve themes. Each one is a mode, light or dark, plus a
primary colour, its `--primary-7` in either mode (the dot the picker draws):

| Mode | Themes (`data-theme`), in hue order |
|---|---|
| Light | `magenta` Magenta `#720252`, `purple` Paars `#4f0399`, `blue` Blauw `#0704c0`, `teal` Petrol `#02494f`, `ochre` Oker `#494001`, `rust` Roest `#633001` |
| Dark | `pink` Roze `#fe97d0`, `lilac` Lila `#c2affe`, `sky` Hemelsblauw `#b5b5fe`, `cyan` Cyaan `#0fd6e8`, `yellow` Geel `#e8b70c`, `orange` Oranje `#fea56e` |

- **No red and no green theme.** Those hues mean bad and good, and a primary colour beside a red "−1,1%"
  makes the number disappear. The status colours are the same in every theme.
- **Two themes move the warning.** In Roest the warning is a dark yellow (`#b88a00`), because the light
  themes' dark orange would sit on the primary. In Geel it is orange (`#f08a24`), because the dark themes'
  yellow would.
- **Every primary reaches 4.5:1** on its background, and so does the text on it.

**Which theme applies.** `house-theme.js`, beside the stylesheet, decides and sets
`<html data-theme="…">`:

1. the user's own choice, remembered per app on the device;
2. otherwise the app's own default theme, declared on the page: `<html data-theme-default="teal">`. Each
   app picks its own, so apps are told apart before anyone has chosen. The theme fixes the mode: a light
   default stays light for a viewer whose OS is dark, until they pick;
3. otherwise, for an app that has not moved to that yet, its default for the OS mode:
   `<html data-theme-light="purple" data-theme-dark="lilac">`;
4. otherwise the house defaults, Blauw (light) and Cyaan (dark).

**Each repo has one default theme of its own** (the owner's decision, October 17, 2026). Twelve themes,
eight repos: all eight differ, four light and four dark. The brand book is the source of the assignment,
and `src/repos.ts` carries it in code. Each repo declares its theme on its own `<html>`, as above.

| Repo | Default theme |
|---|---|
| `dkj-brandbook` | `blue` Blauw (light) |
| `dkj-lifehub` | `teal` Petrol (light) |
| `dkj-recipes` | `rust` Roest (light) |
| `dkj-thumbnail-generator` | `purple` Paars (light) |
| `dkj-etf-tracker` | `sky` Hemelsblauw (dark) |
| `dkj-claude-plugins` | `lilac` Lila (dark) |
| `dkj-music-library` | `pink` Roze (dark) |
| `dkj-maplestory-classic-mesowise` | `yellow` Geel (dark) |

Load it in `<head>` so nothing flashes, and call `DKJTheme.picker(element)` where the setting goes: it
draws the twelve swatches in two rows, light and dark. `DKJTheme.set(id)`, `DKJTheme.reset()` and
`DKJTheme.current()` cover everything else. Copy it unchanged, like the stylesheet.

**Or give the app the settings button, and the setting is done** ([#70](https://github.com/DKJ-Solutions/dkj-brandbook/issues/70)).
`DKJTheme.settings(element)` draws a round toggle that opens a panel with the picker, the page width
(below) and a reset, and returns the panel's slot (`.theme-settings__extra`), where the app puts settings of
its own. The script owns the behaviour, so an app writes none of it: the toggle opens
and closes the panel, Escape closes it and puts focus back on the toggle, and a click outside it or focus
leaving it closes it. A click inside never does. The element is inline by default, for a place such as a
`.topbar`. Give it `theme-settings--floating` and it is fixed at the top right of the screen instead.
The panel lies over the page, so nothing moves when it opens. Every text is optional and Dutch by default:
`DKJTheme.settings(el, { label: 'Settings', title: 'Settings', theme: 'Theme', reset: 'Reset theme', light: 'Light', dark: 'Dark', width: 'Width', fluid: 'Fluid', phone: 'Phone', full: 'Full' })`.

**The page width is part of the settings panel** ([#203](https://github.com/DKJ-Solutions/dkj-brandbook/issues/203)).
The panel has a width group with three choices, and the script sets the one that applies as
`<html data-width="fluid|phone|full">` in `<head>`, before the page paints, like the theme. The
stylesheet sizes `main` and `.container` from it, so the breadcrumb bar's trail keeps lining up with the
column, and `.container--narrow` / `main.narrow` follow too:

- `fluid`: the house column (1080px, or the narrow column where a page uses it);
- `phone`: a 360px column, the smallest phone an app supports;
- `full`: no maximum, the whole width.

Which width applies: the user's own choice, remembered per app on the device (`dkj-width`, with the same
`data-theme-key` suffix as the theme); otherwise the app's own default, `<html data-width-default="full">`;
otherwise `fluid`. `DKJTheme.setWidth('phone')` and `DKJTheme.width()` set and read it from code. An app
whose layout has no page column to widen leaves the group out with `widths: false`. The attribute sits
inside `:where()`, so a column class of the app's own still decides its own width. Every `main` and
`.container` without such a class follows the width, a footer's or a demo's too. The top bar's inner row
(`.topbar__inner`) deliberately does not: it stays the narrow column, the width of the app's own controls.
Without the script there is no `data-width`, and the column is fluid.

**The theme names and the picker's row labels are Dutch on purpose**: DKJ-Solutions apps are
Dutch-language, and the names are the ones their users read. An app in another language passes its own
row labels, `DKJTheme.picker(el, { light: 'Light', dark: 'Dark' })`. A page that ships
`data-theme="light"` or `"dark"` keeps that mode under the script: the script picks that mode's default
instead of following the OS, and ignores a `data-theme-default` of the other mode.

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
of amber and the dark one a brighter yellow; `--negative-5` on light is a darker red (`#a32424`); on dark
`--positive-5`/`--negative-5` are a step lighter and `--negative-3` is the dark red it never had; status icons take
the mark colour, now `--primary-1`.

### How far a theme reaches

**A page built only from house classes shows the theme beyond its primary button**
([#72](https://github.com/DKJ-Solutions/dkj-brandbook/issues/72)). Until then a theme set one token,
and only the primary controls and the focus rings used it. Plain links kept the browser's blue in
every theme. Now:

- **By default**, with nothing for the app to do: every link takes the theme's colour as text (`--primary-7`, owner's decision, October 15, 2026), visited or not, with
  a thicker underline on hover and a primary focus ring. Native checkboxes, radios, sliders and
  progress bars take `--primary-7` through `accent-color`, the text caret through `caret-color`, and selected
  text gets a primary tint. The link rules sit in `:where()`, so they weigh nothing: any class on an
  `<a>` (a `.btn`, a `.menu-item`, an app's own) wins without an override. An `<a>` without an `href`
  is not a link and is left alone. `accent-color` and `caret-color` are set once on the root, so a
  subtree that sets its own `--primary-5` or `--primary-7` keeps the page's theme on its native controls.
- **Opt-in**, one modifier on a house element: `.header--accent` puts a primary rule under the page
  header and `.table--accent` a
  `--primary-3` table head, its text `--primary-9`, as all text. They are modifiers rather than defaults, so an app
  that takes the update keeps its layout until it adds one.
  `.card--accent` and `.tile--accent` drew a primary rule across the top and draw nothing now (owner's
  decision, October 15, 2026); an app that still carries either class loses the rule and nothing else.

**What this changes for an app that takes the update:** its unstyled links, checkboxes, radios and
sliders turn the theme's colour. Links an app already styles through a class keep their look.

**The theme now colours the ground too** (owner's request: the themes were visible but did not stand
out). Three more things follow it by default, in light and in dark (and a measurement):

- **Every theme writes out its own nine values.** `--primary-1` … `--primary-9` are fixed hex values in each
  theme's block, not mixes (owner's decision, October 14, 2026: the percentages were too hard to follow).
- **On dark `-5` is the greyest step, in the middle of the scale, and `-7`/`-8` carry the colour.** Dark
  follows the light rule mirrored (owner's decision, October 15, 2026): each step has one OKLCH lightness and one
  chroma in all six dark themes, capped by relative chroma where a hue holds less, and only the hue differs.

  | Step | OKLCH lightness | Chroma |
  |---|---|---|
  | `-1` | 0.19 | 0.035 |
  | `-2` | 0.21 | 0.045 |
  | `-3` | 0.32 | 0.08, at most 0.6 relative |
  | `-4` | 0.458 | a quarter of `-5`'s base chroma, in its hue (October 15, 2026: a step darker, extra grey; October 17, 2026: halved again, greyer) |
  | `-5` | 0.538 | 0.105, at most 0.49 relative (the owner's Oranje `#8f6249`; at most the chroma of the owner's Hemelsblauw `#4c4c8d`): its base chroma, taken at 0.3 (October 15, 2026: greyer, at 0.6; October 17, 2026: halved again) |
  | `-6` | 0.618 | a quarter of `-5`'s base chroma, in its hue (October 15, 2026: a step lighter, extra grey; October 17, 2026: halved again, greyer) |
  | `-7` | 0.80 | 0.99 relative |
  | `-8` | 0.90 | 0.83 relative |
  | `-9` | 0.981 | 0.008 |

  Hemelsblauw sits on `#0000ff`'s HSL hue 240, like Blauw.

  **A role takes the same step in both modes** (owner's decision, October 15, 2026): never `light-dark()` between
  two `--primary-*` steps, and no dark-only rule that picks another step. Text in the theme's colour (values),
  focus rings, lines and meters are `-5` everywhere, and the text on a `-5` fill is `-1`. On
  dark that reads at about 3.3:1 (`-1` on `-5` 3.51:1, `-5` on the card 3.38:1, both Roze), which the owner accepted.
  The picker's dot is `-7` in every theme, on its theme's `-1` (October 17, 2026). The scale runs from the ground (`-1` page, `-2` card:
  lightest on light, darkest on dark) to the far end (`-8`, `-9`: darkest on light, whitest on dark). `-5` carries the fills
  in both modes, and the focus rings, with `--primary-1` as text on a fill. **On light every
  theme behaves the same and only the hue differs** (owner's decision, October 15, 2026): each step has one OKLCH
  lightness and one chroma in all six, capped at a share of what the hue can hold (relative chroma) where the hue
  holds less.

  | Step | OKLCH lightness | Chroma | From the owner's example |
  |---|---|---|---|
  | `-1` | 0.989 | 0.0053 | Petrol `#faffff`, at the lightest lightness every hue holds |
  | `-2` | 0.972 | 0.0136 | Petrol `#f2ffff`, the same way |
  | `-3` | 0.848 | 0.066, at most 0.45 relative | Petrol `#9adae2` |
  | `-4` | 0.55 | a quarter of `-5`'s base chroma, in its hue | October 15, 2026: a step lighter than `-5`, extra grey; October 17, 2026: halved again |
  | `-5` | 0.47 | 0.1135, at most 0.486 relative: its base chroma, taken at 0.3 (October 15, 2026: greyer, at 0.6; October 17, 2026: halved again) | Paars `#5d458b`, Magenta `#954c7a`, Blauw `#49498d` |
  | `-6` | 0.39 | a quarter of `-5`'s base chroma, in its hue | October 15, 2026: a step darker than `-5`, extra grey; October 17, 2026: halved again |
  | `-7` | 0.369 | 0.99 relative | Blauw `#0707bf` |
  | `-8` | 0.289 | 0.83 relative | Blauw `#181873` |
  | `-9` | 0.131 | 0.99 relative | Blauw `#00002b` |

  Each step keeps its hue; Blauw's sit on `#0000ff`'s HSL hue 240, from 264 to 286 in OKLCH as their chroma
  falls, because at a constant OKLCH hue that blue leans to cyan.
- **A tinted surface takes `-9`.** `--primary-3` is every line and also the surface of the `.table--accent`
  head, the hover of a joined choice and of the settings toggle, a near or today date row, a date row's hover,
  the accent dialog and an InfoRows box. The text on it is `--primary-9`, like all text, and not the colour
  (the colour is too close to `-3` on light to read).
- **How the values were made.** Each step has one OKLCH lightness and one chroma in all six light themes, and
  one pair in all six dark themes, so the themes differ only in hue (owner's decisions, October 15, 2026). Where
  a hue cannot hold that chroma, the step takes a fixed share of what it can hold (relative chroma). The constants
  are in the light token comment of `house-style.css`; the lightness of each step:

  | | -1 | -2 | -3 | -4 | -5 | -6 | -7 | -8 | -9 |
  |---|---|---|---|---|---|---|---|---|---|
  | light | 0.989 | 0.972 | 0.848 | 0.70 | 0.47 | 0.39 | 0.369 | 0.289 | 0.131 |
  | dark | 0.19 | 0.21 | 0.32 | 0.38 | 0.538 | 0.70 | 0.80 | 0.90 | 0.981 |

  `-4`, `-5` and `-6` are the greys, `-7` and `-8` carry the colour. Blauw and Hemelsblauw sit on `#0000ff`'s HSL
  hue 240.
- **The page and the cards are tinted.** On light the page is the whitest layer and a card sits a shade off it;
  on dark the card is a shade lighter than the page. Either way the page is the ground end (owner's decision,
  October 14, 2026: it used to be the other way round on light).
- **Lines are tinted.** `--primary-3` is every line: borders, row dividers, grid lines and the meter track
  (a separate grid colour was dropped on October 14, 2026: it was too close to the border to tell apart).
- **The theme picker previews it:** each swatch shows its own theme's page, with the primary as the dot.
- **Links are the theme's colour**, as `--primary-7` (owner's decision, October 15, 2026: the step that carries the colour, where `-5` is a grey). **`h1` and `h2` are `--primary-7` and `h3`–`h6` are `--primary-8`**;
  on a `--primary-9` surface `h1` and `h2` are `--primary-3` and `h3`–`h6` are `--primary-2` (owner's decision, October 14, 2026).
- **Measured** (WCAG relative luminance, worst theme, October 15, 2026): `--primary-9`, all text, reaches
  17.4:1 or better on the page and 11.9:1 or better on `--primary-3`. `--primary-7`, the highlight, reaches 9.42:1
  or better on the page and the card on light (Petrol) and 9.02:1 on dark (Roze), 6.53:1 or better on
  `--primary-3`, and 6.42:1 or better on a warning, negative or positive background (Roze on dark). `--primary-5`
  reaches 6.25:1 on the card on light (Oker) and 3.38:1 on dark (Roze); `--primary-1` on a `--primary-5` fill
  6.54:1 on light (Oker) and 3.51:1 on dark (Roze), which the owner accepted. Status, direction and categorical
  colours (`--positive-3`, `--negative-3`, `--warning-3`, `--cat-*`, `--positive-5`, `--negative-5`) are never
  tinted.

**What this changes for an app that takes the update:** every page turns a light shade of its theme, and
the headings take its tint (through `:where()`, so a heading inside a coloured container, or one the app colours itself, keeps that colour). An app that hard-codes a grey next to a house surface will show the seam.

## Components

**The complete list of reserved names**, so a repo layer knows what not to redefine:
the page header (`body > header`, `main > header`, with `.header--accent`) and its `.controls` row, `main`/`.container`,
`.hero`, `.tiles`/`.tile` (with `--accent`), `.card` (with `--accent`, and the head parts `__head`, `__title` (an `h3`), `__sub`, with a `.badge` before the title text, or a plain `h3`), `.grid-2` (with `.grid__head`, which holds a group's `h2`, and `.grid__full`), `.table-wrap`/`.table` (with `--accent`, `.row-total`, and
sortable headers via `.sort`/`.arrow` on `aria-sort`), `.seg` (a segmented switch), `.legend`/`.legend__item` (with
`--line`), `.swatch`, `.badge` (with `--good`, `--warn`, `--bad`, `--info`, `--neutral`, `--sm`),
`.badge-row`, `.badge-list` (a `<ul>` of `.badge-row` items), `.meter` (with `--good`, `--warn`, `--bad`, `--info`), `.mini-cards`/`.mini-card` (with
`--highlight`), `.item-grid`/`.item`, `.notice`, `.note`, `.meta`, `.muted`, `.sub`, `.eyebrow`, `.lead`, `.msg` (with `--warn`), `.facts`, `.page-column`, `.page-cta`, `.num` (tabular
numerals), `.delta` (with `--up`/`--down`, aliased `.pos`/`.neg`), `.btn` (with `--primary`, and a `:disabled` state for both), `.info-button`, `.tooltip`
(with `--explain`, and `--open` for one anchored to a trigger), `.more` (a disclosure), `.moretoggle` (a full-width read-more button), `.chart` (the SVG chart scope),
`.theme-picker` (with `__row`, `__label`, `__swatches`), `.theme-swatch` (with `--light`, `--dark`) and
`.theme-settings` (with `--floating`, `__toggle`, `__open`, `__close`, `__panel`, `__title`, `__group`,
`__label`, `__picker`, `__width`, `__foot`, `__extra`, `__reset`), which `house-theme.js` draws, and `.footer-note`. The app components
([below](#app-components-from-mesowise)) reserve these too: `.container--narrow`/`main.narrow`, `.field`
(with `__error`), `.btn--touch`, `.btn--block`, `.icon-btn` (with `--ghost`), `.action-row`, `.dialog`
(with `__body`, `__head` (with `--two`, `--back`), `__title`, `__sub`, `__close` (with `--save`,
`--cancel`, `--back`), and `--drawer`), `.topbar` (with `__inner`, `__brand`, `__name`), `.menu-list`,
`.menu-row` (with `__label`, `__value`), `.menu-item` (with `__icon`, `__label`, `__chevron`),
`.breadcrumbs` (with `__sep`), `.breadcrumbs-bar` ([below](#every-page-the-breadcrumb-bar)) and
`.sr-only`. Each is commented in the file.

**Focus and targets.** Every interactive house class shows a visible focus ring on keyboard focus (an SVG
`.chart .bar` shows a stroke instead), and its hit area is at least 44px (`--tap`) high where the mark is
smaller: the `.info-button`'s 16px mark, the `.table` header's `.sort` and the `.moretoggle`
([#19](https://github.com/DKJ-Solutions/dkj-brandbook/issues/19)). A tooltip opened from a trigger takes
`.tooltip--open`, which shows it and lets the pointer move onto its text; a chart tooltip that follows the
pointer is shown by its own script and stays click-through.

## App components (from MesoWise)

**The house style is extended with the MesoWise app** (Maikel, October 12, 2026; ported here on
October 13, 2026 by [#18](https://github.com/DKJ-Solutions/dkj-brandbook/issues/18), after the owner's
choice on [dkj-claude-plugins#2955](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2955)):
the components that app had and the house style lacked were lifted into the same stylesheet. They are
the generic, mobile-first parts of an app shell: a narrow column, a form field, touch buttons, a dialog
and a side drawer, a top bar and a menu list. The group sits at the end of
[`house-style.css`](house-style.css), under "App components".

- **Sizes.** Touch targets are at least `--tap` (44px) high. The column is `--column-narrow` (512px), a
  phone and, on a computer, the same width.
- **Buttons.** `.btn--touch` and `.btn--block` are modifiers of `.btn`, so the `.btn:disabled` state
  covers them too, `.btn--touch.btn--primary` included.
- **Dialog.** A native `<dialog>` opened with `showModal`. Put `.dialog__title` on an `h6` (an `h5` in a
  `.dialog--drawer`, whose title is `--text-h5`) or a `p`: a heading element takes the token of its own level. The page stands still behind a modal
  (`html:has(dialog:modal)`), and `html:has(.topbar)` adds the scroll padding for the top bar.
  `.dialog--drawer` slides in from the side. A dialog on top of a dialog sets `--dialog-scale` (default
  0.95) smaller on itself: a hook the app sets, not a house token.
- **Contrast.** Field labels and the quiet icons use `--primary-9`, which holds 4.5:1 on
  `--primary-2`.
- **Input font.** The input's 16px is a literal, not a type step: iOS zooms in on focus below 16px.

**What this changes for an app that takes the update:** nothing that exists, only additions. But an app
that defines its own `.field`, `.dialog`, `.topbar`, `.menu-row`, `.icon-btn` or `.sr-only` now collides
with a house name, and renames its class or adopts the house one.

**What stayed in the app, because it is domain:** MesoWise's tinted "advised" and "profile" dialogs, the
level-up colours, the equipment lists, the stat lines, the chips and the download button.

## Page patterns

### An h2 never stands inside a card

**A hard rule** (Maikel, October 19, 2026,
[#3175](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3175)): **an `h2` always stands above the
card or cards it heads, never inside one.** The `h2`s are what group a page: one `h2` with its sub line, the
cards that belong to it, then the next `h2`. A heading inside a card's border reads as that card's label and
groups nothing.

- **The form:** a `.grid-2` whose first child is a `.grid__head` (the `h2`, then a `p.card__sub`), then the
  cards. Two cards sit side by side; a card with `.grid__full` takes the whole row, so stacked cards each carry
  it. With React, the brand book's `CardGroup`.
- **A card's own title is an `h3`**: `.card__head` > `h3.card__title` (room for a `.badge` before the text) or a
  plain `h3`, then an optional `.card__sub`. A card that is the only one under its `h2` needs no title of its
  own. With React, `CardHead` in a `Card variant="data"` renders an `h3`.
- **Related cards share one `h2`.** Where several cards answer one question (three ways of counting the same
  issues, the in-flight lists), they stand under one `h2` with an `h3` each, rather than an `h2` each.
- **The spacing does the grouping.** In a `.page-column`, a `.grid-2` with a `.grid__head` takes an extra
  `--spacing-5` above it, so an `h2` sits clearly closer to its own cards (`--spacing-4`) than to the group
  before it.
- **The gate holds it:** `check-house-style`'s fourth check, `heading`, reports an `h2` carrying
  `.card__title` (or the brand book's `.dkj-card-title`) and an `h2` opening a `.card__head`
  (or `.dkj-card-head`).

**What this changes for an app that takes the update:** a card titled with `h2.card__title` fails the gate.
Move the `h2` and its sub line into a `.grid__head` above the card, and add `.grid__full` to the card. A
`.card__title` now renders at `--text-h3`, in the sans, where it was `--text-h2` in the serif.

### Every page: the breadcrumb bar

**Every page a DKJ-Solutions dev server serves opens with a breadcrumb bar** (owner's request, October 17,
2026). That is every page you can open in the preview browser: the Repo hub, the product, and any
page below either. The bar says where the page sits and is the way back, so no page needs a "back" link of
its own.

- **Place:** the first element in `<body>` (in React, the first thing the page renders), above `<main>` and
  outside it, so it spans the full width. Its trail lines up with the page column.
- **Always visible:** the bar sticks to the top of the screen while the page scrolls. It is one `--tap`
  (44px) high and one line: a trail longer than the screen scrolls sideways inside the bar instead of
  wrapping, so the height never changes. Whatever else sticks to the top sits under it, at `top: var(--tap)`;
  the house style already does that for the floating settings button and for in-page anchors.
- **The trail:** it always starts at **Repo hub**, linking to `/`. Each further crumb is one level
  down: the product (under its own name), then a page inside it. The last crumb is the current page,
  unlinked, with `aria-current="page"`. On the Repo hub itself the trail is that one crumb: the bar is
  still there, so it sits in the same place on every page.
- **The labels** are the pages' own names, short, in the app's language. A crumb names a page, never a
  section on a page: an in-page anchor is not a level.
- **Without React:** `.breadcrumbs-bar` > `.container` > `nav.breadcrumbs[aria-label="Breadcrumb"]` > `ol`,
  one `li` per crumb, and a `<span class="breadcrumbs__sep" aria-hidden="true">/</span>` at the start of every
  `li` but the first. [`patterns/repo-dashboard.html`](patterns/repo-dashboard.html) carries it. With React,
  the brand book's `Breadcrumbs` component with `bar` renders the same.

**What this changes for an app that takes the update:** nothing that exists, only an addition. A page
without the bar does not break, but it does not follow the house style until it has one. An app with its
own sticky element at `top: 0` (a sidebar, a toolbar) moves it to `top: var(--tap)` when it adds the bar,
or the bar covers it.

### The Repo hub

It is called a hub, not a dashboard (owner's call, October 17, 2026, [#199](https://github.com/DKJ-Solutions/dkj-brandbook/issues/199)): the index's job is to get you to the page you want quickly, while a dashboard is a page that shows how something stands, and the pages below the index can be dashboards.

**Every DKJ-Solutions repo's Repo hub has this one form, and only its content differs** (owner's
decision, October 16, 2026, [#139](https://github.com/DKJ-Solutions/dkj-brandbook/issues/139)). The Repo
hub is the index (`/`) of a repo's dev server: what the repo is for and what is in flight. The form is
the one approved in [#137](https://github.com/DKJ-Solutions/dkj-brandbook/issues/137), and its reference
implementation is this repo's own [`RepoDashboard.tsx`](https://github.com/DKJ-Solutions/dkj-brandbook/blob/v0.4.0/src/dashboard/RepoDashboard.tsx).

**The blocks, top to bottom, in this order:**

| # | Block | Brand book component (React) | House class (the stylesheet-only equivalent) | Fixed, or the repo's own |
|---|---|---|---|---|
| 0 | The breadcrumb bar, above `<main>`: the one crumb **Repo hub** ([above](#every-page-the-breadcrumb-bar)) | `Breadcrumbs bar` | `.breadcrumbs-bar` / `.breadcrumbs` | fixed |
| 1 | The settings button | `Toolbar` (showcase; the settings button only) | `DKJTheme.settings(el)` from `house-theme.js` (`.theme-settings`) | fixed |
| 2 | The intro, wrapping 3 to 6: a `<div>`, never a `<header>` (below) | `<div className="dkj-intro">` | a plain `<div>` | fixed |
| 3 | Eyebrow: `<owner>/<repo>` | `<p className="dkj-eyebrow">` | `.eyebrow` | fixed form, the repo's own slug |
| 4 | `h1`: **Repo hub** | `<h1>` | `h1` | fixed, word for word |
| 5 | Lead: one paragraph on what the repo is for | `<p className="dkj-lead">` | `.lead` | the repo's own text |
| 6 | A primary button to the product | `Button variant="primary"` | `.btn.btn--touch.btn--primary`, in a `<p class="page-cta">` | product repos only, with the repo's own label. The product has its own route and is never the page on `/` |
| 7 | **Pages**: links to the repo's own pages, one row per page (below the table). With general pages too, two groups, **This repo** and **General**, under one `h2` | `PageLinks` (a `CardGroup` around one `Card variant="data"` holding a `<nav>` of house `.menu-item` link rows, or two cards when there are two groups) | a `.grid-2` with a `.grid__head` (the `h2` and its `.card__sub`) above the card(s); the list is a `<nav class="menu-list">` of `<a class="menu-item">` rows, each with `.menu-item__label`, optionally `.menu-item__sub`, and `.menu-item__chevron`. One group: one `.card.grid__full` with no title of its own. Two groups: two cards titled with an `h3` | optional: any repo with a page of its own besides `/` and the product, or with general pages. Fixed titles and form; the repo's own pages and their group |
| 8 | One stat tile per in-flight list, counting it | `StatTiles` / `StatTile` | `.tiles` / `.tile`, with `.label` and `.v` | the repo's own lists. A count not read yet shows `--` |
| 9 | A loading line, or a warning that the lists could not be read | `Message live="status"` (loading) / `Message tone="warn" live="alert"` (error) | `.msg` with `role="status"` / `.msg.msg--warn` with `role="alert"` | fixed. The role makes a screen reader announce the line when it appears |
| 10 | **In flight**: one data card per in-flight list, in the tiles' order, under one `h2` | `InFlightCards`: a `CardGroup` around one `Card variant="data" className="grid__full"` per list, each with `CardHead` (title, sub line) and `DataTable` | a `.grid-2` with a `.grid__head` (`h2` + `.card__sub`), then one `.card.grid__full` per list around `.table-wrap` / `.table`; the card head is `.card__head` with `.card__title` (an `h3`) and `.card__sub` | fixed title; the lists and the sub line are the repo's own |
| 11 | **About this repo**: a facts card, its `h2` and sub line above it | `Card variant="data"` with `DefinitionList variant="facts"`, in a `CardGroup` | a `.grid-2` with a `.grid__head` (`h2` + `.card__sub`) and the `.card.grid__full` holding the facts list `.facts` (a `<dl>`) | fixed title; the sub line and the facts are the repo's own |
| 12 | A footer note naming where the data comes from | `FooterNote` | `.footer-note` | the repo's own source |

**The Pages block (7)**, added in [#200](https://github.com/DKJ-Solutions/dkj-brandbook/issues/200). Four decisions, each with its reason:

- **Where: block 7, directly under the intro and above the stat tiles.** The hub's job is to get you to the
  page you want, so the way on comes before the status, and it does not depend on the lists having loaded,
  so it never moves or waits while they are read.
- **What it looks like: a card under the `h2` "Pages" (with one group of pages; two groups are below) holding a navigation list, the house `.menu-item` row as an
  `<a>`** (label, optional one-line description beneath it, a chevron at the end; a line between rows). The
  `.menu-item` is already the house's "this goes somewhere" row, so nothing is invented but the description
  line (`.menu-item__sub`, the muted `--text-sm` line, as `.card__sub`). A row is a full-width, `--tap`-high
  link that tints on hover; a `.tile` is a figure that does not respond, so the two cannot be mistaken for
  each other, which is the separation the action buttons already have from the tiles. The `h2` stands above
  the card, never inside it ([above](#an-h2-never-stands-inside-a-card)).
- **Fixed or optional: optional, with a fixed form.** A repo with no page of its own besides `/` and the
  product leaves it out; a repo with at least one more page carries it, and its rows are the repo's own
  (label in the app's language, short, the page's own name as the breadcrumb uses it; the description is one
  line or nothing, and each link is a route on the same dev server, never an external site).
- **Relation to block 6: the product button stays the single primary action and is not repeated as a row.**
  The button is the one thing most visitors came for; the rows are everything else. A repo with a product
  and other pages has both; a repo with several pages and no product has no block 6 and the Pages card is
  the first thing under the lead. What used to be a second, outline button next to the product button moves
  into this list, so the intro keeps one button.

**A second group, General, and the heading above the cards**
([#206](https://github.com/DKJ-Solutions/dkj-brandbook/issues/206), approved in
[dkj-claude-plugins#3121](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3121)). Every DKJ-Solutions
repo serves some pages that are not its own (Issues, Release notes), so a repo with both carries **two cards
side by side, under one `h2` that stands above them**: **This repo** (sub line "Specific to this repo") and
**General** (sub line "Not specific to this repo: every DKJ-Solutions repo has them"), each titled with a
plain `h3`. The `h2` is **Pages** with the sub line "Every page this dev server serves". **Only one group
with pages, whichever group it is, keeps the same heading:** the `h2` Pages and its sub line above one
`.card.grid__full`, which has no title of its own (#3175; until then that card carried `h2.card__title` inside
it). Blocks 10 and 11 take the same heading form: the `h2` and a sub line stand above the cards; block 11's
sub line is the repo's own, one line on what its facts are (for example "What this repo is"). So **every `h2`
stands above its cards and carries a sub line.**

Without React, one group is a `.grid-2` > `.grid__head` (`h2` + `p.card__sub`) + `.card.grid__full` > `nav.menu-list[aria-label="Pages"]` >
one `a.menu-item[href]` per page (direct siblings, so the house rule `.menu-item + .menu-item` draws the line
between rows) > `span.menu-item__label` (the label, then optionally `span.menu-item__sub`) + the
`.menu-item__chevron` svg; [`patterns/repo-dashboard.html`](patterns/repo-dashboard.html) carries it. A
description sits inside the label span so the chevron stays aligned at the end of the row. Two groups: a
`.grid-2` whose first child is `.grid__head` (`h2` + `p.card__sub`, spanning both columns), then two
`.card`s, each `.card__head` > `h3` + `.card__sub`, then `nav.menu-list[aria-label="<title> pages"]`. Block 11:
a `.grid-2` with a `.grid__head` and one `.card.grid__full`.

`Button` and `Card` render the brand-book classes `.dkj-btn` and `.dkj-card`; the house `.btn--primary` and
`.card` are the stylesheet's own classes for the same blocks. In the reference the blocks stack in the page
column with one `--spacing-5` gap between them (`.dkj-dashboard`, a grid on `<main>`); the stylesheet-only
equivalent is `.page-column` on `<main>`, which also takes the top margin of its direct `.card`, `.tiles`,
`.notice` and `.footer-note` so the gap stays one `--spacing-5`. An in-page anchor (an element with an `id`
in the column) scrolls to `5rem` below the top, clear of the settings button, in both forms; a card a table
links down to carries a compact outline "Back to overview" button in its card head
([#156](https://github.com/DKJ-Solutions/dkj-brandbook/issues/156)).

**The in-flight lists, where a repo has them:** open pull requests, newest first, with the branch as the
sub line (and "(draft)" on a draft); open issues by their `prio-N` label, unprioritised last and the highest
number first within a priority, with who claimed it as the sub line; every branch off the trunk, with its pull
request where one is open. A repo leaves out a list it has no use for and adds one it needs, each as a tile
and a card. An empty list keeps its card and says so in the table ("No open issues.").

**What is fixed:** the order, the components, the `h1`, the intro's form, the "Pages" and "About this repo"
titles, the "Pages" heading's sub line, and the "This repo" and "General" group titles with their sub lines.
**What is the repo's own:** the slug, the lead, the product button and its label, whether the Pages block
appears and which pages it links (with their labels and descriptions, and in which group: the General group
is optional), which lists appear, the facts and their sub line, and the data source. The reference reads its lists live from the GitHub API, unauthenticated, which
a public repo can do; a private repo reads them some other way and says which in the footer note.

**The intro is not a `<header>` directly inside `<main>`.** The house style makes `main > header` the
page-header row, a flex row with its controls beside the title, so a `<header>` there lays the eyebrow, the
`h1`, the lead and the button out side by side. #137 hit exactly this; a `<div>` keeps them stacked.

**Without React, the form is complete from `house-style.css`** ([#141](https://github.com/DKJ-Solutions/dkj-brandbook/issues/141)).
Every block in the table has a house class: the eyebrow (`.eyebrow`), the lead (`.lead`), the page links
(`.menu-list`, `.menu-item`, `.menu-item__label`, `.menu-item__sub`), the loading line
(`.msg`, `.msg--warn`), the data-card head (`.card__head`, `.card__title`, `.card__sub`), the facts list
(`.facts`) and the page column (`.page-column`, with `.page-cta` for the button's spacing). The house
`.card`, `.tiles`, `.notice` and `.footer-note` carry a top margin of their own, and `.page-column` zeroes it
for its direct children, so the rhythm is the reference's. `.grid-2` does the same for a direct `.card`,
`.tiles` or `.notice`, so its rows sit one `--spacing-4` gap apart
([#207](https://github.com/DKJ-Solutions/dkj-brandbook/issues/207)); `.grid__head` and `.grid__full` span
every column of it, for a heading above its cards
([#206](https://github.com/DKJ-Solutions/dkj-brandbook/issues/206)). A repo without a build copies
[`patterns/repo-dashboard.html`](patterns/repo-dashboard.html), the stylesheet-only reference page: it links
`house-style.css` and `house-theme.js` and carries no CSS of its own. It differs from the React page in two
places: the settings button is fixed at the top right of the screen (`theme-settings--floating`) instead of
sitting in the showcase's sticky wrapper, and the product button is the house `.btn--touch` (44px, the
brand-book button's height).

**`.btn` draws no underline on a link any more** (#141): a `.btn` on an `<a>` showed the browser's underline,
because the house link rules set its thickness and not whether it shows. An app with link buttons loses that
underline when it takes this update; a `<button class="btn">` is unchanged.

## What was deliberately left out

The parts of the ETF dashboard that only make sense there stayed there: the hazard-striped advice zone
and its tokens, the market report's layout, the month-note button drawn on a chart bar, the
primary/secondary view switch, the mapping from ETF/share/cash to a colour, and the Dutch status class
names. The three
series colours survive as `--cat-1..3`, with the same values. A generic danger/alert component is **not**
in the house style yet. Adding one is a design decision for the owner, not something to back-fill from
the advice zone.

## Changing the house style

A change here reaches every DKJ-Solutions app the next time it takes a copy, so it is a **visible
result**: the branch stops for the owner's look instead of merging. Bring a consumer's improvement here
as an issue on this repo. Don't make a local edit and hope it travels.

**A merged change reaches nobody until it is released.** A release is a tag on `main`, and it is set only
on the owner's explicit request, like any tag. The first four releases were set by hand as
`house-style-v1` to `house-style-v4`. The owner brought those four together as `v0.1.0`, the first
`vX.Y.Z` release (#172, #178), and every release since is cut with the `dkj-policy` plugin's
`cut-release` and tagged `vX.Y.Z`. The cut also writes the release's changelog notes and its row in
[`dkj-policy/releases/history.md`](https://github.com/DKJ-Solutions/dkj-brandbook/blob/v0.4.0/dkj-policy/releases/history.md), which lists the four earlier releases
too. A tag is never moved or reused: a fix is a new release. Then the `house-style` skill in the
`dkj-solutions` plugin
([DKJ-Solutions/dkj-claude-plugins](https://github.com/DKJ-Solutions/dkj-claude-plugins)) is repointed to
the new tag, through an inbound issue there, and the apps get it with that plugin release. So one house-style
change costs one tag here and one pointer update there, and that second step is the point: nothing reaches
the apps that has not been released.
