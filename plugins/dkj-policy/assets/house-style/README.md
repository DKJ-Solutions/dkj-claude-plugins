# The DKJ-Solutions house style

**Every DKJ-Solutions app looks like one family, and this folder is where that family is written down**
(Dave, issue [#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1,
2026). The style was tuned by hand on the ETF dashboard in `dkj-etf-tracker`. Rebuilding it per repo
means re-tuning it per repo, and two hand-tuned copies drift. So the general half was lifted out once,
with **every value kept exactly as chosen** (spacing and font sizes have since moved to the Figma
library's scales, below), and the copy in this folder is the only one:
[`house-style.css`](house-style.css) and [`house-theme.js`](house-theme.js).

**It lives in the `dkj-policy` plugin**, because the plugin's own hub and General pages render in it in
every repo, BWJ-Development's included
([#3531](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3531), October 26, 2026). The **rule**
that a DKJ-Solutions app starts from it stays in the `dkj-solutions` plugin, whose `house-style` skill
points here and pins the files. It spent October 13 to 18, 2026 in the `dkj-brandbook` repo, came back
into `dkj-solutions` with [#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130), and
moved one level up into `dkj-policy` with #3531. **A session or a build
fetches a tagged release, never `main`** (owner's decision on
[dkj-brandbook#3](https://github.com/DKJ-Solutions/dkj-brandbook/issues/3), October 13, 2026):
`house-theme.js` is executable and runs with the origin of every page it is inlined into, and `main` is a
moving ref that an admin can push to past the review. A tag is a version somebody chose to release. Raw
URLs, with `<tag>` the release tag the skill pins, which the release cut writes into the skill
([#3133](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3133)):

- `https://raw.githubusercontent.com/DKJ-Solutions/dkj-claude-plugins/<tag>/plugins/dkj-policy/assets/house-style/house-style.css`
- `https://raw.githubusercontent.com/DKJ-Solutions/dkj-claude-plugins/<tag>/plugins/dkj-policy/assets/house-style/house-theme.js`

**As a rule it reaches DKJ-Solutions and nothing else.** BWJ-Development styles its own apps; only the
plugin's own screens look the same there.

**Every change to a stylesheet in this folder passes a CSS gate of its own**
([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)): `house-style-css` in this repo's
CI runs `scripts/lint/house-style-css/`, which parses each stylesheet, fails a `var()` that nothing defines
(a parameter the markup sets is documented in a comment as `style="--name: ..."`, as the legend's `--c` is),
and fails a colour code anywhere but a token declaration in `house-style.css`. It reads every `.css` here,
so a stylesheet added later is gated without an edit.

**A house-style change is judged by eye on the House style page**, `specimens.html` in this folder: every
token, the twelve themes and every component with its variants and states, drawn from the stylesheet beside it.
It ships with the plugin, and every hub that enables `dkj-solutions` shows it under Plugins, on
`/plugins/dkj-solutions/house-style` (#3493), as one card per section with a page each
(`/plugins/dkj-solutions/house-style/<section>`, #3563); in the source repo that page reads the working tree, so a change
shows there before the release that ships it. It replaces the brand book app's showcase, which is retired. `house-style-css` is the gate
that checks the stylesheet's syntax and tokens; the page is the look.

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
   (`--paper-2`, `--muted`) so its contents follow a tint, as the info and accent dialogs do;
   the token is never changed for the page. Everything inside such a subtree inherits the re-declared value,
   so a tinted dialog nested inside an info dialog would tint from `--cat-1`; do not nest them.
4. **Design to one screen of about 1300 x 900, at the full width, with nothing the brief did not ask for**
   (the owner, October 26, 2026; about 1300 x 900, a guideline, since October 27, when it replaced 1400 x 600): no scroll where cutting ornament or going wider avoids it, blocks side
   by side rather than stacked, and no eyebrow, sub line, lead or extra row unless the brief asks for
   one. The full rule is in the `house-style` skill, under "Density".

## What it holds

**Tokens**, each in light and dark:

| Group | Tokens | Meaning |
|---|---|---|
| Paper | `--paper-1` … `--paper-4` | what sits **behind** the text, in very small steps, each only just darker on light (lighter on dark) than the one before: the page (`paper-1`), cards and tiles (`paper-2`), every line and the tinted surfaces (`paper-3`: borders, row dividers, grid lines, the meter track, an accent table head, a hover, the accent dialog), a stronger border (`paper-4`: an open card, a selected box). **All four read on `--primary`** (4.55:1 or better, #3235), so they are also the text on a primary fill (`.fill-primary`), `paper-1` the text on a `--muted` fill and the mark inside a status icon, and the paper steps the text on an inverted (`--fg-1`) surface |
| Categorical | `--cat-1`, `--cat-2`, `--cat-3` | one series each. Never two meanings for one slot in a view |
| Direction | `--positive-3` and `--negative-3` (also the gain and the loss in charts, so a direction chart can share a view with any series), `--positive-5`, `--negative-5` (numbers in text) | result and direction, never a category. `--positive-5`/`--negative-5` are the text versions of `--positive-3`/`--negative-3`, a step more contrast so a number reads as text: darker on light, lighter on dark |
| Status | `--positive-3`, `--warning-3`, `--negative-3`, `--warning-5`, `--warning-1`, `--negative-1`, `--positive-1` | badges, meters, notices. `--warning-1`, `--negative-1` and `--positive-1` are the backgrounds of a warning, negative or positive message. The mark inside a status icon (check, cross, "!") is `--paper-1` |
| Primary | `--primary` | the theme's colour, **one** step (owner, #3235, October 21, 2026): the most saturated colour of the theme's hue that reads on all four paper steps, so the paper reads on it too. **The highlight**: `h1`, the fill of `.btn--primary` (a filled main action, like the filled icon button; #109) and of `.fill-primary`, a state (hover, pressed, sorted, active, today), `strong`, list markers, links, a value meant to stand out, the accent dialog's title and the settings panel's title, and native controls through `accent-color` |
| Greys | `--muted`, `--muted-inverse` | a grey of the theme's colour, for what may recede: `--muted` reads extra well (7:1) on the page, `--muted-inverse` on the far end (7:1 on `--fg-1`). `--muted` is the eyebrow, every sub line (`.sub`, `.dialog__sub`, a component's `-sub`), every note (`.note`, `.footer-note`, `.muted`, on a `<p>` too), the tile label, the pressed `.seg` button, `.badge--info`, `.meter--info`, focus rings, meters and the `--accent` modifiers ([below](#how-far-a-theme-reaches)); `--muted-inverse` the same roles on an inverted surface (`.fill-inverse`). Never a status or a number |
| Text | `--fg-1` … `--fg-4` | what sits **on** the paper: four colours near black on light (near white on dark), in **very small** steps, so `fg-4` is still very dark, only a little less so than `fg-1` (owner, #3235). `fg-1` is **all text**, every paragraph and everything else: labels, table heads, legends, quiet icons, the text on a tinted surface, and the ground of an inverted surface; `fg-2` is `h2` and `.meta` on a span; `fg-3` is `h3`; `fg-4` has no role yet (the breadcrumb's current page took it until the bar turned `--primary`, #3235). On a fill the text switches to the paper ([Fills](#fills-the-text-switches-with-the-ground)) |
| Elevation | `--shadow-pop` | tooltips |
| Spacing | `--spacing-0-5` … `--spacing-96` | the spacing scale, same in both modes: `--spacing-N` is N × 4px, a half step (`-0-5`, `-1-5`, …) adds 2px. Every gap, margin and padding uses one, and a repo layer spaces its own components from the same scale |
| Type | `--text-h1` … `--text-h3`, `--text-lg`, `--text-base`, `--text-sm`, `--text-xs`, `--font-serif` | the type scale, same in both modes: 32/18/14 for the headings (`h3` at 14px, the body size, and no `h4` or `h5` since October 25, 2026, the owner: [below](#the-heading-cut-of-october-25-2026)) (`h2` 18px since October 25, 2026, the owner; it went from 32 at weight 600 to 24 at 700 on October 24, and keeps the 700), and `.lead` is `--text-base` since the same day (it was `--text-lg`), 18/14/12/11 for running text. `h1`–`h3` each take the token of their own level, body text is `--text-base`. No heading is larger than 32px (owner's decision, October 22, 2026: as much content as possible on a 900px-high screen, since October 27 one of about 1300 x 900), so `h1` stands apart by its size and colour (by its capitals too until October 24, 2026); it was 48px from October 20, when `--text-h0` was retired. The hero figure is set at `--text-h1`. There is no `h6` either: the 24px `h3` was retired the same day, because it stood too close to `h2`, and every level below moved up one ([below](#the-heading-shift-of-october-20-2026)). The one exception is a section label (`GroupHeading`): it stays a heading for the document outline, but every level renders at `--text-base`, uppercase and muted (owner's decision, October 15, 2026). `--font-serif` was the face of `h1` and `h2` until October 24, 2026, when the owner moved both to the sans; it stays for a title that keeps that face |
| App shell | `--control-h`, `--tap`, `--topbar-h`, `--column-narrow` | sizes for a mobile-first app, same in both modes: 38px for a value field and the button beside it, 44px as the smallest touch target, 56px for the top bar, 512px for the narrow app column |

`--gain` was removed (October 14, 2026). A gain in a chart is `--positive-3` (owner's decision, October 15, 2026, #131); before that it was `--cat-1`.

**The colour tokens were renamed the same day** (owner's decision): the status and direction colours so each
name says which side it is on, and the black, white and grey ones merged into one five-step ramp. An app that takes this update renames them in its own layer:

| Was | Now |
|---|---|
| `--good`, `--up` | `--positive-3`, `--positive-5` |
| `--bad`, `--down` | `--negative-3`, `--negative-5` |
| `--loss` | removed: a loss in a chart takes `--negative-3` (a legend item takes `--negative-3` through its `--c`) |
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

**The primary scale grew from nine to twelve steps on October 19, 2026** (owner's decision): three groups of four,
the light steps `-1` to `-4`, the greys `-5` to `-8` and the dark steps `-9` to `-12`. Every role moves to a new
number, the four anchors (`-1`, `-4`, `-9`, `-12`) take new values and the lines stay on `-3`. The headings change:
`h2` takes `-10` (it was the h1's colour) and `h3`–`h6` take `-11`. **The names stay valid, so nothing fails on a stale
number: it just shows another colour.** An app that takes this update renames in its own layer, highest first so
nothing is renamed twice:

| Was | Now |
|---|---|
| `--primary-9` (all text, an inverted surface), **first** | `--primary-12` |
| `--primary-8` (`h3`–`h6`) | `--primary-10`, now `h2` only; `h3`–`h6` take the new `--primary-11` |
| `--primary-7` (the highlight: `h1`, `h2`, links, states, `accent-color`) | `--primary-9`, now `h1` without `h2` |
| `--primary-6` (sub lines, notes, `.muted`) | `--primary-7` |
| `--primary-5` (the fills, focus rings, meters) | `--primary-6` |
| `--primary-4` (a grey, no role yet) | `--primary-5`, a stronger border |
| `--primary-3` (every line, the tinted surfaces), **last** | `--primary-3` (unchanged) |
| (new) | `--primary-4`, the light anchor; `--primary-8`, the far grey; `--primary-11`, `h3`–`h6` |

**Check after migrating:** list every use with `grep -rnE -- "--primary-[0-9]+" src` and read each hit against the
table; a missed rename shows the wrong colour rather than an error.

**The primary scale split into paper and ink on October 20, 2026** (owner's decision): the colours behind
the text are paper, in very small steps, and the colours on it are ink, in large steps. `--primary-*` no longer
exists. The paper roles keep their colours except the stronger border, which turns from a grey into a tint a
step beyond the line: `--paper-4` sits 36% of the way from the page to the light anchor, as `-2` and `-3` sit at 4%
and 16%. The ink steps take **new values**: seven steps evenly spaced in lightness from the highlight to the far end, so
`h2` and `h3`–`h5` shift slightly and the muted greys read darker on light and lighter on dark. `--primary-4`, the
light anchor, had no role and is no token any more. An app that takes this update renames
in its own layer; the names do not overlap, so the order does not matter:

| Was | Now |
|---|---|
| `--primary-1` (the page) | `--paper-1` |
| `--primary-2` (cards, tiles) | `--paper-2` |
| `--primary-3` (every line, the tinted surfaces) | `--paper-3` |
| `--primary-4` (the light anchor, no role) | removed |
| `--primary-5` (a stronger border) | `--paper-4`, with a **new value**: a tint instead of a grey |
| `--primary-6` (the eyebrow, the fills, focus rings, meters) | `--ink-3` |
| `--primary-7` (sub lines, notes, `.muted`) | `--ink-4` |
| `--primary-8` (the breadcrumb's current page) | `--ink-5` |
| `--primary-9` (the highlight: `h1`, links, states, `accent-color`) | `--ink-1` |
| `--primary-10` (`h2`) | `--ink-2` |
| `--primary-11` (`h3`–`h5`) | `--ink-6` |
| `--primary-12` (all text, an inverted surface) | `--ink-7` |

**`--ink-2` is live again with a new meaning**: it was retired on October 14, 2026 (the old secondary text). The
gate reports every `--primary-*` left behind as a retired token, so nothing is missed silently; on an inverted
surface `h1` follows `h2` to `--paper-3`, since the light anchor it took is gone.

**The ink split into one primary, two greys and four text steps on October 21, 2026** (owner, issue
[#3235](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3235)). Every theme still has eleven colours, now
computed by `scripts/build/build-house-palette.ps1` in the `dkj-solutions` plugin from the theme's hue and mode: one primary that
reads on all four paper steps (and they on it), two greys that read extra well on the page and on the far end, four
paper steps and four text steps in very small steps. **Every value changes**: the primary is a little darker on
light (it has to read on `--paper-4` now, not only on the page), the paper steps are a little lighter, and `h2` and
`h3`–`h5` are no longer in the colour but in the text steps. `--ink-*` no longer exists; `--primary` and `--muted`
were retired on October 14, 2026 and are **live again**, in the same sense they had then (the theme's colour, a muted
grey). An app that takes this update renames in its own layer; the names do not overlap, so the order does not
matter:

| Was | Now |
|---|---|
| `--ink-1` (the highlight: `h1`, links, states, `accent-color`) | `--primary` |
| `--ink-2` (`h2`, `.meta`) | `--fg-2` |
| `--ink-3` (the eyebrow, the fills, focus rings, meters) | `--muted` |
| `--ink-4` (sub lines, notes, `.muted`) | `--muted` |
| `--ink-5` (the breadcrumb's current page) | `--fg-4` |
| `--ink-6` (`h3`–`h5`) | `--fg-3` |
| `--ink-7` (all text, an inverted surface) | `--fg-1` |
| (new) | `--muted-inverse`: the grey on an inverted surface, where `--muted` would not read |
| (new) | `.fill-primary` and `.fill-inverse`: a block on the primary or on the far end, where the text switches to the paper |

**On an inverted surface**, a grey that was `--ink-3` or `--ink-4` takes `--muted-inverse`, not `--muted`. The gate
reports every `--ink-*` left behind as a retired token, so nothing is missed silently.

**An app still on the twelve `--primary-*` steps** (v5.26.0 and earlier) skips the ink names and maps straight
across: `--primary-1`, `-2`, `-3` → `--paper-1`, `-2`, `-3`; `--primary-4` → removed; `--primary-5` → `--paper-4`;
`--primary-6` and `-7` → `--muted`; `--primary-8` → `--fg-4`; `--primary-9` → `--primary`; `--primary-10` →
`--fg-2`; `--primary-11` → `--fg-3`; `--primary-12` → `--fg-1`. Bare `--primary` is a token of its own, not one of the twelve steps: the
gate tells `--primary-9` from it.

**A number in a colour token is a step away from the page** (owner's decisions, October 14 and 20, 2026). For
`--negative-*`, `--positive-*` and `--warning-*` that is `-1`, `-3`, `-5`: `-1` is light on the light themes and dark
on the dark themes (the ground end) and `-5` the opposite (the text end). The theme's own colour has two numbered
groups (#3235), and each counts from its own start: `--paper-1` … `--paper-4` from the page outward (page, cards,
lines and tinted surfaces, a stronger border), and `--fg-1` … `--fg-4` from the strongest text outward (all text,
`h2`, `h3`, and one step with no role yet), both in very small steps. `--primary`, `--muted` and
`--muted-inverse` carry no number: there is one of each. There are no untinted neutrals: the
greys are the theme's own, a greyed step of its colour. For the status families:
`-1` is the background of a message, `-3` the fill (icon, badge, meter, a
loss in a chart), `-5` the text.

**The colour tokens grouped by what a theme switch changes** (the grouping the House style page's tokens
section uses):

| A switch … | Tokens | Why |
|---|---|---|
| to any other theme changes them | `--primary`, `--muted`, `--muted-inverse`, `--paper-1` … `--paper-4`, `--fg-1` … `--fg-4` | each theme sets all eleven as fixed values, computed from its own hue; the House style page lists the primary and the greys, the paper and the text as three groups |
| changes them only between light and dark: categories | `--cat-1`, `--cat-2`, `--cat-3` | series slots, set once in the light block and once in the dark block, a shade apart |
| changes them only between light and dark: status colours | `--negative-1`, `--negative-3`, `--negative-5`, `--positive-1`, `--positive-3`, `--positive-5`, `--warning-1`, `--warning-3`, `--warning-5` | set once in the light block and once in the dark block, a shade apart. One exception: `--warning-3` also moves in Roest and Geel ([below](#themes-the-user-picks-the-colour)) |

**The spacing and type scales have a source: the Figma library** *Shopify Theme - LIBRARY*, variable
collection "Collection", groups `spacing/` and `text/`. Their names and values are copied exactly, so a
design in Figma and a page built from this file share one set of numbers. A step added there is added
here, in a branch of its own. The spacing values happened to match the dashboard already. The type
scale did not, so taking it over changed sizes: body 15 → 14, `h2` 29 → 32, `h3` 18 → 24, the 13px
small text → 12, a mini-card value 20 → 18, the info button's mark 10 → 11 (Maikel, October 12, 2026).
Two departures from the library followed on October 20, 2026: its `h0` was retired with `h1` taking the 48px,
and its 24px `h3` was retired with every level below it moving up one.
**No heading is larger than 32px** (owner's decision, October 22, 2026): every pixel of a 900px-high screen goes to content,
so `h1` came down from 48px to `h2`'s 32px, and the hero figure with it. The target screen is now about 1300 x 900 (the owner, October 27, 2026, after 1400 x 600 from October 26; rule 4 under [How to use it](#how-to-use-it)), which makes the reason stronger.
**The `h1` is in the body sans and its own case, at weight 700** (owner's decision, October 24, 2026). From
October 21, 2026 ([#3247](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3247)) it was set in
capitals, and before that day in `--font-serif`; both went, so it stands apart from the `h2` by its size and
colour alone.

### The heading shift of October 20, 2026

**The 24px `h3` stood too close to the 32px `h2`, so it is gone and every level below it moved up one**
(owner's decision, October 20, 2026). There are five heading levels now and no `h6`:

| Was | Now |
|---|---|
| `h3`, `--text-h3`, 24px | retired |
| `h4`, `--text-h4`, 22px | `h3`, `--text-h3`, 22px |
| `h5`, `--text-h5`, 18px | `h4`, `--text-h4`, 18px |
| `h6`, `--text-h6`, 16px | `h5`, `--text-h5`, 16px |

**A size token kept its name and changed its value**, so an app that takes this update moves each use one level
up in its own layer, lowest first so nothing moves twice: `--text-h4` → `--text-h3`, then `--text-h5` →
`--text-h4`, then `--text-h6` → `--text-h5`, and the same for the heading elements (`h4` → `h3`, `h5` → `h4`,
`h6` → `h5`). An `h3` that was an `h3` (a card title) stays one and simply renders at 22px. `--text-h6` is a
retired token, so the gate reports a use left behind; a missed `--text-h4` or `--text-h5` shows a size one
step too small rather than an error.

### The heading cut of October 25, 2026

**`h3` is 14px, the body size, and `h4` and `h5` are gone with their tokens** (owner's decision, October 25,
2026). Three heading levels remain, and `h3` stands apart from running text by its weight (600) and its colour
(`--fg-3`) alone:

| Was | Now |
|---|---|
| `h3`, `--text-h3`, 22px | `h3`, `--text-h3`, 14px |
| `h4`, `--text-h4`, 18px | retired: an `h3` |
| `h5`, `--text-h5`, 16px | retired: an `h3` |

**An app that takes this update makes every `h4` and `h5` an `h3`**, and moves each use of a retired token in its
own layer: a heading-like use (a title) to `--text-h3`, running text that borrowed `--text-h5` to `--text-base`. A
large figure that borrowed `--text-h3` for its size (a tile value, a secondary hero value, a large stepper) moves to
`--text-lg`, because a figure at the body size no longer stands out. `--text-h4` and `--text-h5` are retired tokens,
so the gate reports a use left behind. The house rules for an `h4` and an `h5` are gone, so one left in markup
renders at the browser's default size.

## Themes: the user picks the colour

**Every DKJ-Solutions app has the same form, and a colour of its own that the user picks** (Maikel,
October 12, 2026). The house style carries twelve themes. Each one is a mode, light or dark, plus a
primary colour, its `--primary` in either mode (the dot the picker draws):

| Mode | Themes (`data-theme`), in hue order |
|---|---|
| Light | `magenta` Magenta `#b90085`, `purple` Paars `#7f00ff`, `blue` Blauw `#0000ff`, `teal` Petrol `#006e79`, `ochre` Oker `#716300`, `rust` Roest `#9c4b00` |
| Dark | `pink` Roze `#ff9fd4`, `lilac` Lila `#d6adff`, `sky` Hemelsblauw `#b8b8ff`, `cyan` Cyaan `#63cfdc`, `yellow` Geel `#e2ba51`, `orange` Oranje `#ffaa74` |

- **No red and no green theme.** Those hues mean bad and good, and a primary colour beside a red "−1,1%"
  makes the number disappear. The status colours are the same in every theme.
- **Two themes move the warning.** In Roest the warning is a dark yellow (`#b88a00`), because the light
  themes' dark orange would sit on the primary. In Geel it is orange (`#f08a24`), because the dark themes'
  yellow would.
- **Every primary reaches 4.5:1** on all four of its paper steps, and so does each paper step on it (#3235).

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
eight repos: all eight differ, four light and four dark. The assignment was made in the brand book app
(`src/repos.ts`, until #3493 retired it) and is this table now. Each repo declares its theme on its own `<html>`, as above.

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
`DKJTheme.settings(element)` draws a round toggle on the card colour with its edge in the theme's colour (a `--primary`
border; the icon turns `--primary` under the pointer and while open; #3235), that opens a panel with the picker, the page width
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
`data-theme-key` suffix as the theme); otherwise the app's own default, `<html data-width-default="fluid">`;
otherwise `full` ([#3269](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3269): a DKJ-Solutions app
opens at the whole width unless it opts out). `DKJTheme.setWidth('phone')` and `DKJTheme.width()` set and read it from code. An app
whose layout has no page column to widen leaves the group out with `widths: false`. The attribute sits
inside `:where()`, so a column class of the app's own still decides its own width. Every `main` and
`.container` without such a class follows the width, a footer's or a demo's too. The top bar's inner row
(`.topbar__inner`) deliberately does not: it stays the narrow column, the width of the app's own controls.
Without the script there is no `data-width`, and the column is fluid, deliberately: the stylesheet alone
also serves e-mail, Artifacts and static reports, which have no settings panel to narrow an unbounded
column back to a reading width.

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
`.meter--info` take the primary instead of the then `--ink` and `--cat-1`; the light warning is dark orange instead
of amber and the dark one a brighter yellow; `--negative-5` on light is a darker red (`#a32424`); on dark
`--positive-5`/`--negative-5` are a step lighter and `--negative-3` is the dark red it never had; status icons take
the mark colour, now `--paper-1`.

### How far a theme reaches

**A page built only from house classes shows the theme beyond its primary button**
([#72](https://github.com/DKJ-Solutions/dkj-brandbook/issues/72)). Until then a theme set one token,
and only the primary controls and the focus rings used it. Plain links kept the browser's blue in
every theme. Now:

- **By default**, with nothing for the app to do: every link takes the theme's colour as text (`--primary`, owner's decision, October 15, 2026), visited or not, with
  a thicker underline on hover and a `--muted` focus ring. Native checkboxes, radios, sliders and
  progress bars take `--primary` through `accent-color`, the text caret through `caret-color`, and selected
  text gets a primary tint. The link rules sit in `:where()`, so they weigh nothing: any class on an
  `<a>` (a `.btn`, a `.menu-item`, an app's own) wins without an override. An `<a>` without an `href`
  is not a link and is left alone. `accent-color` and `caret-color` are set once on the root, so a
  subtree that sets its own `--muted` or `--primary` keeps the page's theme on its native controls.
- **Opt-in**, one modifier on a house element: `.header--accent` puts a primary rule under the page
  header and `.table--accent` a
  `--paper-3` table head, its text `--fg-1`, as all text. They are modifiers rather than defaults, so an app
  that takes the update keeps its layout until it adds one.
  `.card--accent` and `.tile--accent` drew a primary rule across the top and draw nothing now (owner's
  decision, October 15, 2026); an app that still carries either class loses the rule and nothing else.

**What this changes for an app that takes the update:** its unstyled links, checkboxes, radios and
sliders turn the theme's colour. Links an app already styles through a class keep their look.

**The theme now colours the ground too** (owner's request: the themes were visible but did not stand
out). Three more things follow it by default, in light and in dark (and a measurement):

- **Every theme writes out its own eleven values**, computed rather than tuned (owner, #3235, October 21, 2026).
  `--primary`, `--muted`, `--muted-inverse`, `--paper-1` … `--paper-4` and `--fg-1` … `--fg-4` are fixed hex values
  in each theme's block, not mixes (owner's decision, October 14, 2026: the percentages were too hard to follow), and
  `scripts/build/build-house-palette.ps1` in the `dkj-solutions` plugin computes them from the theme's hue and mode, checks every
  contrast below and writes them in with `-Apply`. A theme is changed there, never by hand in the stylesheet.
- **The model, in the owner's words, for a light theme** (a dark one is the mirror, with white and black swapped):
  - **One primary**: the colour of the theme that reads best on white, and white reads well on it too. Computed as
    the most saturated colour (HSL saturation 100%) of the theme's HSL hue that reaches 4.55:1 on **all four** paper
    steps, so every paper step reads on it as well. **On a dark theme the floor is 9:1**, so the primary is a light
    tint of the colour, and the dark paper on a primary fill reads at 9:1 or better (owner, October 21, 2026: at
    4.55:1 the dark primaries were the colour at full strength, and a primary fill was a vivid band under near-black
    text; a deep fill with light text was tried and dropped the same day). **And no dark primary is more saturated than
    OKLCH chroma 0.13**, Roze's: Cyaan and Geel reach 9:1 at full strength already, so the floor alone left them neon,
    and above the cap they are taken again at that chroma, at the lightness where they reach 9:1. Cyaan read too
    vivid even at 0.13 and has a cap of its own, 0.10, Hemelsblauw's (owner, the same day). The hue is the HSL hue of the owner's original theme colour
    (Blauw and Hemelsblauw 240), held in HSL because at a constant OKLCH hue a saturated blue turns violet; Lila takes
    270, the hue of its light counterpart Paars, because at its own 254 it read as blue (owner, October 19, 2026).
  - **Two greys**: a grey of the colour that reads extra well on white (`--muted`) and one that reads extra well on
    black (`--muted-inverse`). Both are OKLCH chroma 0.03 in the theme's hue, as close to their ground as 7.05:1
    allows, so they recede by colour while they still read.
  - **Four colours that read on the primary**: the paper, from white towards a little darker, OKLCH L 0.995, 0.975,
    0.945 and 0.905 on light (0.13, 0.155, 0.19 and 0.235 on dark), with the chroma rising from 0.006 to 0.045. The
    eye is most sensitive to the first tint off white or black, so the card is only just lifted off the page.
  - **Four colours that read on the paper**: the text, near black, in very small steps, OKLCH L 0.12, 0.16, 0.20
    and 0.24 at chroma 0.03 on light (0.99, 0.955, 0.92 and 0.885 on dark), so `fg-4` is still very dark.

  **A role takes the same step in both modes** (owner's decision, October 15, 2026): never `light-dark()` between
  two steps, and no dark-only rule that picks another step. Meters, the fills and most focus rings are `--muted`
  everywhere (a sort header, a `.seg` button, a chart bar and the read-more toggle ring in `--primary`), and the text on a `--muted` or `--primary` fill is `paper-1`. The picker's dot is `--primary` in every
  theme, on its theme's `paper-1` (October 17, 2026). Paper and text both run away from the page: `paper-1` and
  `fg-1` are the two ends, the lightest and the darkest on light, the other way round on dark.
- **A tinted surface takes `--fg-1` as its text.** `--paper-3` is every line and also the surface of the
  `.table--accent` head, the hover of a joined choice and of the settings toggle, a near or today date row, a date
  row's hover, the accent dialog and an InfoRows box. The text on it is `--fg-1`, like all text (17.2:1 or better).
- **Measured** (WCAG relative luminance, worst and best of the twelve themes, October 21, 2026): `--primary` on
  `paper-1` 5.9:1 to 8.5:1 on light and 10.7:1 to 13.6:1 on dark, on `paper-4` 4.56:1 to 6.5:1 on light and 9.0:1 to
  11.2:1 on dark, the same both ways round. On dark the primary sits close to the text (1.4:1 to 1.8:1 against
  `fg-1`), so `h1` and links stand out from the text by colour rather than by lightness; `fg-1` on
  `paper-1` 19.5:1 to 20.1:1 and `fg-4` on `paper-4` 11.8:1 to 12.5:1; `--muted` on `paper-1` 7.05:1 to 7.13:1 and on
  a card 6.6:1 to 6.9:1; `--muted-inverse` on `fg-1` 7.05:1 to 7.10:1. Nothing in the model is below 4.5:1, which
  the paper-and-ink model of October 20 missed for `ink-1` on a card in Magenta, Roest and Lila. A `paper-3` line
  on a card is faint: 1.05:1 (Pink) to 1.10:1 (Blauw); a `paper-4` border on it 1.16:1 to 1.25:1.
- **The page and the cards are tinted.** On light the page is the whitest layer and a card sits a shade off it;
  on dark the card is a shade lighter than the page. Either way the page is the ground end (owner's decision,
  October 14, 2026: it used to be the other way round on light).
- **Lines are tinted.** `--paper-3` is every line: borders, row dividers, grid lines and the meter track
  (a separate grid colour was dropped on October 14, 2026: it was too close to the border to tell apart).
- **The theme picker previews it:** each swatch shows its own theme's page, with the primary as the dot.
- **Links are the theme's colour**, as `--primary` (owner's decision, October 15, 2026). **`h1` and `h2` are
  `--primary`, `.meta` on a span is `--fg-2` and `h3` is `--fg-3`** (the owner, October 24, 2026, for `h2`:
  from #3235 until then it was `--fg-2`, and before #3235 `h2` and `h3`–`h5` were steps of the colour).
- **On a fill the text switches** (#3235, the owner: *"h2 heeft niet altijd dezelfde kleur"*, an h2 does not always have the same colour). See
  [Fills](#fills-the-text-switches-with-the-ground).
- **Status, direction and categorical colours** (`--positive-3`, `--negative-3`, `--warning-3`, `--cat-*`,
  `--positive-5`, `--negative-5`) are never tinted.

### Fills: the text switches with the ground

**A block can stand on the theme's colour or on the far end, and its text then takes the paper** (#3235). An `h2`
reads on the page and on the primary alike, so it is not one colour: `--fg-2` on the page, `--paper-1` on a
primary fill.

| Class | Ground | Text | A quieter line (`.sub`, `.muted`, `.note`, `.eyebrow`, `.card__sub`) |
|---|---|---|---|
| `.fill-primary` | `--primary` | `--paper-1`: headings, paragraphs, `.lead`, `.msg`, `.meta`, `.card__title` and links | `--paper-3` (all four paper steps read on the primary) |
| `.fill-inverse` | `--fg-1` | `--paper-1`, the same elements | `--muted-inverse` (7:1 on `--fg-1`) |

The switch is written with `:is()` and stands last in the stylesheet, so it beats `.sub`, `.muted`, `p.meta` and the
zero-weight headings without an `!important`, and a quieter line on a `<p>` keeps its quieter colour. A link weighs
only one class, so a `.btn` or an app's own class on an `<a>` keeps its colours; its focus ring turns `--paper-1`. A
component an app puts inside a fill (a button, a badge) keeps its own colours, so a `.btn--primary` on
`.fill-primary` does not show: use an outline button there.

**What this changes for an app that takes the update:** every page turns a light shade of its theme, and
the headings take its tint (through `:where()`, so a heading inside a coloured container, or one the app colours itself, keeps that colour). An app that hard-codes a grey next to a house surface will show the seam.

## Components

**The complete list of reserved names**, so a repo layer knows what not to redefine:
the page header (`body > header`, `main > header`, with `.header--accent`) and its `.controls` row, `main`/`.container`,
`.hero`, `.tiles`/`.tile` (with `--accent`), `.card` (with `--accent`, and the head parts `__head`, `__title` (an `h3`), `__sub`, with a `.badge` before the title text, or a plain `h3`), `.grid-2` (and `.grid-3`, the same three to a row, two below 1000px, one below 760px) (with `.grid__head`, which holds a group's `h2`, and `.grid__full`), `.table-wrap`/`.table` (with `--accent`, `.row-total`, and
sortable headers via `.sort`/`.arrow` on `aria-sort`), `.seg` (a segmented switch), `.legend`/`.legend__item` (with
`--line`), `.swatch`, `.badge` (with `--good`, `--warn`, `--bad`, `--info`, `--neutral`, `--sm`),
`.badge-row`, `.badge-list` (a `<ul>` of `.badge-row` items), `.meter` (with `--good`, `--warn`, `--bad`, `--info`), `.mini-cards`/`.mini-card` (with
`--highlight`), `.item-grid`/`.item`, `.notice`, `.note`, `.meta`, `.muted`, `.sub`, `.eyebrow`, `.lead`, `.msg` (with `--warn`), `.facts` (with `--row`: the facts as one row on the page, label over value, no card), `.fill-primary`, `.fill-inverse`, `.page-column`, `.page-cta`, `.num` (tabular
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
`.sr-only`. The brand-book components ([below](#brand-book-components)) reserve these too: `.alert` (`__title`, `__icon`), `.banner` (`--accent`, `__lead`), `.panel` (`--accent`, `--positive`, `--button`, `__label`, `__value`), `.chip` (`--yes`, `--no`, `--todo`), `.tag` (`--info`, `--warn`), `.filter-chips`/`.filter-chip` (`__check`, `__dot`, and `.filter-chips__clear`), `.round-toggle`, `.badge-toggle`, `.help`, `.more--structured` (`.more__title`, `__meta`, `__trailing`, `__version`), `.group-heading` (`__count`, `__count--over`), `.question-head`, `.verdict`, `.amount`, `.answer` (`__label`, `__value`), `.flash`, `.page-header`, `.field__fixed`, `.check`, `.stepper` (`--lg`), `.combo` (`__input` (with `--under`), `__picked`, `__glass`, `__list`, `__option` with `--own`, `--more`, `__name`, `__meta`), `.value-box` (`__num` with `--lg`, `--negative`, `--positive`, `--regular`, `__was`, `__unit`, `--changed`, `--flush`), `.stat-rows` (`--help`)/`.stat-row` (`__name`, `__sub`, `__help`, `__op`, `--help`, `--formula`, `--head`), `.step-head` (`__value`), `.info-rows` (`--info`, `__head`, `__list`), `.info-row` (`__box`, `__named`, `__value` with `--placeholder`), `.info-dot`, `.info-stem`, `.bill` (`--qty`, `__head`, `__slot`, `__name`, `__qty`, `__price`, `__action`, `__subtotal`, `__total`), `.compare`, `.calc` (`--boxed`, `__row`, `__box`, `__what`, `__sub`, `__op`, `__num`, `__result`), `.calc-section` (`__question`), `.date-list`/`.date-row` (`--near`, `--today`, `--invalid`, `--link`, `__when`, `__main`, `__body`, `__title`, `__sub`, `__trailing`, `__icon`, `__reason`), `.figure` (`--ratio-*`, `--contain`, `__frame`, `__placeholder`, `__glyph`, `__label`, `__caption`), `.prose` (`--sm`, `--fill`), `.chart-detail`, `.chart-row`, `.chart-swatch`, `.chart-figure`, and the additions to existing classes: `.card--open`, `.card--invalid`, `.msg--error`, `.table .row-negative`/`.row-positive`/`.row-warn`, `.table .col-start`/`.col-end`, `.facts__detail`, `.facts__total` and `.chart .bar--active`. Each is commented in the file.

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
- **Dialog.** A native `<dialog>` opened with `showModal`. Put `.dialog__title` on an `h3` or a `p`; in a
  `.dialog--drawer` it is bold. The page stands still behind a modal
  (`html:has(dialog:modal)`), and `html:has(.topbar)` adds the scroll padding for the top bar.
  `.dialog--drawer` slides in from the side. A dialog on top of a dialog sets `--dialog-scale` (default
  0.95) smaller on itself: a hook the app sets, not a house token.
- **Contrast.** Field labels and the quiet icons use `--fg-1`, which holds 4.5:1 on
  `--paper-2`.
- **Input font.** The input's 16px is a literal, not a type step: iOS zooms in on focus below 16px.

**What this changes for an app that takes the update:** nothing that exists, only additions. But an app
that defines its own `.field`, `.dialog`, `.topbar`, `.menu-row`, `.icon-btn` or `.sr-only` now collides
with a house name, and renames its class or adopts the house one.

**What stayed in the app, because it is domain:** MesoWise's tinted "advised" and "profile" dialogs, the
level-up colours, the equipment lists, the stat lines, its own chip variants and the download button. The
generic `.chip`, the stat rows and the stepper are house classes since the
[brand-book components](#brand-book-components) moved in.

## Brand-book components

**The brand-book app was retired under [#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)** (owner's decision, October 26, 2026), and its component CSS moved here first so consumers receive it. Only the families the house style had no class for were ported, renamed to the house convention (unprefixed, `.block`, `.block__part`, `.block--modifier`); a family the house style already had was dropped in favour of the house class, so there is one vocabulary. The components were lifted from MesoWise and the ETF tracker, plus brand-book originals (`.prose`, `.figure`, `.filter-chips`, `.date-list`). The group sits at the end of [`house-style.css`](house-style.css), under "Brand-book components".

**Ported:** alert, banner, panel, chip, tag, filter chips, round and badge toggles, help, a structured disclosure (`.more--structured`), group heading, question head and verdict, amount, answer box, flash, page header, read-only field value, checkbox, stepper, search combobox, value box, stat and formula rows, step header, info rows, bill, comparison and calculation tables, date list, figure, prose, and the chart's tooltip rows.

**Dropped, the house class replaces it:** button and its variants (`.btn`, `.btn--primary`, `.btn--touch`, `.btn--block`), icon button (`.icon-btn`, `.action-row`), card (`.card`), dialog and drawer (`.dialog`, `.dialog--drawer`), top bar, menu rows, breadcrumbs, field, table wrap, message, tooltip, badge, meter, tile, hero figure, delta, legend, mini card, read-more, segmented choice (`.seg`, and `.menu-item` for a list), definition list (`.facts`), inline "?" toggle (`.info-button`). Not carried over, because the house class has no such state and the look is not general: the hover, outline, positive, compact and disabled-primary looks of the brand-book button, the `--row` and `--joined` choice layouts, the accent and info dialog tints, the `.table-wrap` column drop-out (`col-low`), the meter and badge in `--cat-1`, and the warning tone helper: `.warn` is a class MesoWise and the ETF tracker already style themselves, so `.msg--warn` and `.notice` carry a warning instead.

**Added to existing classes** (no existing rule changed): `.card--open`, `.card--invalid`, `.msg--error`, `.table-wrap:focus-visible`, `.table .row-negative`, `.row-positive`, `.row-warn`, `.col-start`, `.col-end`, `.facts__detail`, `.facts__total`, `.chart .bar--active`.

- **New tokens.** `--radius-xs` 4px, `--radius-sm` 6px, `--radius-md` 8px, `--radius-md-plus` 10px, `--radius-lg` 12px, `--radius-pill` 999px; `--control-lg` 52px; `--datecol` 10ch; `--font-mono`. Everything else the brand book defined maps onto an existing token (`--tap`, `--control-h`, `--topbar-h`, `--column-narrow`, the spacing and type scales) or onto a literal as in the older classes (weights, line heights, tracking, focus ring, motion).
- **Sizes and focus.** Interactive parts are at least `--tap` (44px) high, or grow their hit area to it (`::after`). The focus ring is `--muted`, 2px, offset 2px (inset where the part is clipped).
- **Contrast.** Every pairing is a token pair already used in the house style. A date row marked `--invalid` shows its date and reason in `--negative-5` (the brand book used `--negative-3`, which is a fill step, not a text step). The native checkbox takes the theme through `accent-color`.
- **Browser support.** `.calc` needs `subgrid`, `.more--structured` container queries, `.step-head__value` uses `text-box` (ignored where unsupported, the figure is only less tightly centred).
- **Markup contracts.** The combobox marks its active option with `aria-selected="true"`, not a class. A stat row's button is an `.icon-btn` made `--control-h` square.

**What this changes for an app that takes the update:** nothing that exists, only additions. But an app that defines its own `.chip`, `.help`, `.amount`, `.calc`, `.verdict`, `.question-head` (all measured in MesoWise) or `.tag`, `.panel`, `.banner`, `.alert`, `.check`, `.answer`, `.flash`, `.prose`, `.figure`, `.stepper`, `.combo`, `.bill`, `.compare` now collides with a house name, and renames its class or adopts the house one. MesoWise's `.value` and `.input` do not collide (the value box is `.value-box`, and the standalone input class was not ported: `.field` styles its input).

## Page patterns

### An h2 may title a card

**Retired rule** (Maikel, October 24, 2026): from October 19, 2026
([#3175](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3175)) an `h2` always stood above the
card or cards it heads and never inside one, and `check-house-style` held that as its fourth check, `heading`.
Both are gone: an `h2` may now title a card, as the Stopwatch's label cards do.

- **The grouping form still stands where a page groups cards**: a `.grid-2` whose first child is a
  `.grid__head` (the `h2`, then a `p.card__sub`), then the cards; a card with `.grid__full` takes the whole
  row. In a `.page-column`, a `.grid-2` with a `.grid__head` takes
  an extra `--spacing-5` above it, so an `h2` sits closer to its own cards than to the group before it.
- **A card's own title under such a group is still an `h3`**: `.card__head` > `h3.card__title` (room for a
  `.badge` before the text) or a plain `h3`, then an optional `.card__sub`. A `.card__title` renders at
  `--text-h3`, in the sans.
- **A card that stands on its own may carry an `h2`** instead, when it is one of a set of cards that each name
  a subject of the page, rather than a part of one group.

### Every page: the breadcrumb bar

**Every page a DKJ-Solutions dev server serves opens with a breadcrumb bar** (owner's request, October 17,
2026). That is every page you can open in the preview browser: the home page, the product, and any
page below either. The bar says where the page sits and is the way back, so no page needs a "back" link of
its own.

- **Place:** the first element in `<body>` above `<main>` and
  outside it, so it spans the full width. Its trail lines up with the page column.
- **Always visible:** the bar sticks to the top of the screen while the page scrolls. It is one `--tap`
  (44px) high and one line: a trail longer than the screen scrolls sideways inside the bar instead of
  wrapping, so the height never changes. Whatever else sticks to the top sits under it, at `top: var(--tap)`;
  the house style already does that for the floating settings button and for in-page anchors.
- **The trail:** it always starts at **Home**, linking to `/` (it read **Repo hub** until #3270). Each further crumb is one level
  down: the product (under its own name), then a page inside it. The last crumb is the current page,
  unlinked, with `aria-current="page"`. The bar stands on the theme's colour, `--primary` (owner, #3235, October 21, 2026), so
  the trail is in the paper steps, which all read on it: the chevron `--paper-3`, the ancestor links `--paper-2` (with
  a `--paper-1` focus ring), the current page `--paper-1`, every crumb at weight 400 and `--text-base` (owner, October 24, 2026; it was `--text-sm`); a link shows its underline only under the pointer. On the home page itself the trail is that one crumb: the bar is
  still there, so it sits in the same place on every page.
- **The labels** are the pages' own names, short, in the app's language. A crumb names a page, never a
  section on a page: an in-page anchor is not a level.
- **The page's `h1` reads exactly what its current crumb reads** (owner, October 25, 2026): the same words,
  the same case, so the bar and the page never name one page twice in two ways. Write the name once and
  render both from it. A page whose current crumb is a label or a run (a Stopwatch label, a single run)
  takes that same text as its `h1`. The one page without an `h1` is the home page under a site header
  ([below](#the-site-header-above-the-bar)), and the rule has nothing to match there.
- **The markup:** `.breadcrumbs-bar` > `.container` > `nav.breadcrumbs[aria-label="Breadcrumb"]` > `ol`,
  one `li` per crumb, and a `<span class="breadcrumbs__sep" aria-hidden="true">` holding the chevron at the start
  of every `li` but the first (the stylesheet sizes it to `1.25rem` and thickens it with a stroke):

  ```html
  <svg viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M9.793 16.707a1 1 0 0 1 0-1.414L13.086 12 9.793 8.707a1 1 0 0 1 1.414-1.414l4 4a1 1 0 0 1 0 1.414l-4 4a1 1 0 0 1-1.414 0" clip-rule="evenodd"/></svg>
  ```

  [`patterns/repo-dashboard.html`](patterns/repo-dashboard.html) carries it.

**What this changes for an app that takes the update:** nothing that exists, only an addition. A page
without the bar does not break, but it does not follow the house style until it has one. An app with its
own sticky element at `top: 0` (a sidebar, a toolbar) moves it to `top: var(--tap)` when it adds the bar,
or the bar covers it.

### Every page: a long page becomes cards, with a page each

**A page never grows into one long column of sections** (owners, October 26 and 27, 2026,
[#3563](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3563)). Once a page holds **more than
four sections**, each a `.grid__head` with its own `h2`, it becomes an **overview**: one card per section,
and each card opens **a page of its own** at `<page>/<section>`. Finding one part of a page should never mean
scrolling past the rest. This was decided one page at a time (the Stopwatch, SessionStart in #3543, the
house style's own specimens in #3563, the Specialists in #3551) and is written down here once, so a new or
growing page gets this shape without anyone having to point it out.

- **The overview card is THE card**: the hub's one card link ([The card](#the-hub), a `.card.card--link`
  holding one `.menu-item` row, written by `Format-HubCardLinkHtml`), three to a row in a `.grid-3`. Its
  label is the section's name, and its one-line description is the section's **headline**: the figure
  that tells you whether the page is worth opening, such as the number of specimens in a house-style
  section. No hand-written variant: no `h2` or `h3` link inside the card, and no extra rows.
- **The section's page** is that section alone, under one more crumb, so the trail reads Home >
  ... > the overview > the section. Its `h1` is the section's name and its lead is the section's line. Its
  own `.grid__head` goes, because the `h1` already says it.
- **A list is not sections.** A logbook, a release list or an issue list may run long inside **one**
  section. The rule counts `.grid__head` blocks, not cards or rows.
- **Where it holds itself:** the plugin hub's page shell (`Format-GeneralPageHtml`) counts the sections of
  every page it renders, and above four it puts a warning at the top of that page naming the count and
  this rule. A page that breaks the rule says so on its own, instead of waiting to be spotted.

### The site header, above the bar

**An app may open with a site header, and the breadcrumb bar then stands right under it** (owner, October
22, 2026). **Every hub page carries it**: the dkj-policy plugin's hub server draws it on the home page and
every general page of every repo, with the repo's name and `hub` after it. A repo's own product may add it; an app without one keeps the bar as described above.

- **The header:** `header.site-header` > `.container`, at most `--spacing-18` (72px) high, on `--primary`
  over the full width. On the left the app's mark and name, `a.site-header__brand` linking home (`/`); on
  the far right the settings button, `DKJTheme.settings` mounted in a plain `#settings` inside the header,
  so nothing floats. The mark is `.site-header__mark`, the organisation's initials on `--paper-1`, until the
  app has a logo of its own: set at `--text-h1` (32px; it was `--text-h2` until that token went to 24px, October 24, 2026) with a thin padding, so the edges hug the letters (#3301); `.site-header__tag` sets a quieter word after the name (`product`).
- **No eyebrow under it:** the header already names the site, so the intro opens with the `h1`. **A home page has no
  intro at all** (owner, October 22, 2026): its `h1` and lead only repeated the header, so `<main>` opens on its first
  block.
- **The bar under it leaves the primary to the header:** `.site-header + .breadcrumbs-bar` stands on
  `--paper-1` with a `--paper-3` line under it, and the trail is in the text steps (links `--fg-3`, the
  chevron `--muted`, the current page `--primary`, since October 24, 2026, the owner; it was `--fg-1`). The header
  scrolls away; the bar still sticks to the top.

```html
<header class="site-header"><div class="container">
  <a class="site-header__brand" href="/" aria-label="my-app, home"><span class="site-header__mark" aria-hidden="true">DKJ</span><span class="site-header__name">my-app</span></a>
  <div id="settings"></div>
</div></header>
<div class="breadcrumbs-bar">...</div>
```

**What this changes for an app that takes the update:** nothing, unless it adds a `.site-header`; the
bar's own colours change only right under one.

### The hub

It is called a hub, not a dashboard (owner's call, October 17, 2026, [#199](https://github.com/DKJ-Solutions/dkj-brandbook/issues/199)): its job is to get you to the page you want quickly, while a dashboard is a page that shows how something stands, and the pages below it can be dashboards.

**Every DKJ-Solutions repo's hub has this one form, and only its content differs** (owner's
decision, October 16, 2026, [#139](https://github.com/DKJ-Solutions/dkj-brandbook/issues/139)). Where a repo
states no dev server, or has not opted out of it (`OwnHub` in `Get-DevPreview`), the hub is the dkj-policy
plugin's own hub server, and the repo's server is its product
([#3245](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3245)).

**The hub is one page, on `/`, under the site header** (owner, October 22, 2026,
[#3289](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3289)). From October 21 it was two
([#3270](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3270)): a portal home page on `/` and
About this repo on `/about`. Once the site header named the repo on every page, the home page had nothing
left of its own but one link to About, so About's blocks moved onto it. `/about` answers 303 to `/`, so an
old link still lands.

**The home page is a grid of card links, and what the repo IS sits on a page of its own** (owner, October
24, 2026, [#3383](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3383)). The source repo's hub
took this form first, on October 22; the plugin's hub followed it once a consumer rebuilt its hub to the
sectioned page this section used to lay down and its owner did not recognise it as the house hub. The home
page only gets you somewhere: every page is a card, three to a row, with no heading above them. The facts,
the open issues and the pull requests moved to the **Repository** page on `/repository`.

**The home page, top to bottom, in this order:**

| # | Block | House class (the stylesheet-only form) | Fixed, or the repo's own |
|---|---|---|---|
| 0 | The general banner, the first thing on the page, above the site header, with no margin, border or radius (owner, October 24, 2026): a countdown to the next full hour, and once an hour has passed a tone and a **10 airsquats** checkbox that shows the total owed ([#3250](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3250)), the same on every machine ([#3438](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3438)) | a `.notice` holding one `.msg` line, written by `Format-RepoHubBanner` in `dkj-policy`'s `hub/lib/general-pages-lib.ps1` | fixed: a hub a repo builds itself carries it only if it calls that function |
| 1 | The site header: the mark and the repo's name with `hub` after it, linking home, and the settings button on the far right ([above](#the-site-header-above-the-bar)). It names the repo, so there is **no intro**: no `h1`, no lead, no eyebrow | `.site-header`, `DKJTheme.settings(el)` mounted in its `#settings` | fixed; the name is the repo's own |
| 2 | The breadcrumb bar under it: the one crumb **Home** ([above](#every-page-the-breadcrumb-bar)) | `.breadcrumbs-bar` / `.breadcrumbs` | fixed |
| 3 | **The pages**, every one a card of its own, in this order: the repo's products, its own pages with **Repository** among them, and the general pages but Issues, those of a group behind its one card (below) | one `.grid-3`, **no** `.grid__head`, holding one `.card.card--link` per page or group | fixed form; the products and the repo's own pages are the repo's own |
| 4 | Only where the plugin's hub serves a repo that states no product: the two **Set up a product** cards, under their own `h2` | a `.grid-2` with a `.grid__head`, then one `.card.grid__full` per step | the plugin's own text |
| 5 | A footer note naming where the data comes from | `.footer-note` | the repo's own source |

**The Repository page, on `/repository`, under the same site header, its trail Home > Repository:**

| # | Block | House class | Fixed, or the repo's own |
|---|---|---|---|
| 0 | The intro: `h1` **Repository** and a lead, under the breadcrumb bar, as on every page below the hub | `h1`, `.lead` | fixed title; the lead is the repo's own |
| 1 | **The facts**, as one row on the page rather than in a card: label over value | `.facts.facts--row` (a `<dl>`) | the facts are the repo's own |
| 2 | **Its pages**, a card each: **Issues** first, then the repo's pages on GitHub (its pull requests, its CI runs) where it has a GitHub remote | one `.grid-3` of `.card.card--link` | Issues fixed; the GitHub cards the repo's own |
| 3 | Where a repo keeps in-flight lists: one stat tile per list, the loading or warning line, and **In flight**, one data card per list under one `h2` | `.tiles` / `.tile`; `.msg` with `role="status"` / `.msg.msg--warn` with `role="alert"`; a `.grid-2` with a `.grid__head`, then one `.card.grid__full` per list around `.table-wrap` / `.table` | the repo's own lists. A count not read yet shows `--` |
| 4 | A footer note naming where the data comes from | `.footer-note` | the repo's own source |

A repo with no in-flight lists leaves block 3 out; this source repo's hub and the plugin's are both such
repos. **An open issue is not listed twice**: where the **Issues** card is on the page, an in-flight issues
list is that page's job, and the page links it rather than repeating it.

**The card.** It is the one card link on **every** page, not only on the home page: an overview of
sections, a group page and a plugin's own page all use it ([#3563](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3563)).
Each card is a `.card.card--link` holding one house `.menu-item` row as an `<a>` (label,
optional one-line description beneath it, a chevron at the end) inside a `<nav class="menu-list">`: its link
stretches over the whole card, so a click anywhere on the card follows it, and the whole card tints on hover
([#3298](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3298)). A `.tile` is a figure that does
not respond, so the two cannot be mistaken for each other. Its label is the page's own name as its breadcrumb
reads it, short, in the app's language; its description is one line or nothing. A card links a route on the
same dev server; only the Repository page's GitHub cards leave it. A page that cannot be linked (a product
whose server is not running, a general pages server that is not up) is a plain `.card` holding one `.msg`
saying so, in the place its card would take. `Format-HubCardLinkHtml` in `dkj-policy`'s
`hub/lib/general-pages-lib.ps1` writes the card; both served hubs use it.

```html
<section class="card card--link"><nav class="menu-list" aria-label="Repository"><a class="menu-item" href="/repository"><span class="menu-item__label">Repository<span class="menu-item__sub">This repo's facts and its open issues</span></span><svg class="menu-item__chevron">...</svg></a></nav></section>
```

**The order of the cards.** The products come first, because they are what the repo offers its visitors; a
product is never the page on `/`. Then the repo's own pages, **Repository** among them; then the general
pages every repo has (Artifacts, Release notes, SessionStart), Issues left to the Repository page. No hub
carries a Brand book card ([#3475](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3475)), and the
brand book app is retired ([#3493](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3493)).

**A card is ALWAYS one link, never two or more** (owner, October 27, 2026). Pages that belong together
are grouped on a **group page** of their own, and the hub carries one card linking that page. **Clock**
(`/clock`) is the first: its card stands where the Test gate's stood, and the page is an `h1` with one card
link each for Test gate, Stopwatch and Logbook, whose trails read Home > Clock > the page. A page joins a group by the
`Group` key in `Get-GeneralPages`; the group itself is a row of `Get-HubGroups`, and
`Format-HubGroupPageHtml` draws its page.

**The in-flight lists, where a repo has them:** open pull requests, newest first, with the branch as the
sub line (and "(draft)" on a draft); open issues by their `prio-N` label, unprioritised last and the highest
number first within a priority, with who claimed it as the sub line; every branch off the trunk, with its pull
request where one is open. A repo leaves out a list it has no use for and adds one it needs, each as a tile
and a card. An empty list keeps its card and says so in the table ("No open issues.").

**What is fixed:** the two pages and their routes (with `/about` sending on to `/`), the order, the site
header and the crumbs, the grid with no heading, the Repository card on the home page and the Issues card on
the Repository page. **What is the repo's own:** the name, its products, its own pages, which lists appear,
the facts, and the data source. A private repo reads its lists without the GitHub API's unauthenticated
access and says how in the footer note.

**No `<header>` directly inside `<main>`.** The house style makes `main > header` the page-header row, a
flex row with its controls beside the title. The site header stands above `<main>`, outside it, and #137
hit exactly this with an intro that was a `<header>`.

**The form is complete from `house-style.css`** ([#141](https://github.com/DKJ-Solutions/dkj-brandbook/issues/141)).
Every block above has a house class. The blocks stack in the page column, `.page-column` on `<main>`, which
takes the top margin of its direct `.card`, `.tiles`, `.notice` and `.footer-note`, so they sit one
`--spacing-5` apart; `.grid-2` does the same for a direct `.card`, `.tiles` or `.notice`, so its rows sit
one `--spacing-4` apart ([#207](https://github.com/DKJ-Solutions/dkj-brandbook/issues/207)), and
`.grid__head` and `.grid__full` span every column of it. An in-page anchor scrolls to `5rem` below the top,
clear of the settings button; a card a table links down to carries a compact outline "Back to overview"
button in its card head ([#156](https://github.com/DKJ-Solutions/dkj-brandbook/issues/156)). A repo without
a build copies [`patterns/repo-dashboard.html`](patterns/repo-dashboard.html) and
[`patterns/repo-repository.html`](patterns/repo-repository.html), the stylesheet-only reference pages for
the home page and the Repository page: they link `house-style.css` and `house-theme.js` and carry no CSS of
their own, and their settings button sits in the site header. **These patterns are the only reference**: the brand book app drew no hub specimen or previews of other repos' hubs from October 21, 2026 (owner,
[#3274](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3274)) and is retired now, so a repo with
a framework builds the form from the blocks above with its own components.

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
