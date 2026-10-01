---
name: house-style
description: The DKJ-Solutions house style -- the design tokens (light and dark), the light/dark mechanism and the base stylesheet every DKJ-Solutions app renders with, as one self-contained CSS file. Use it before writing or restyling ANY visual output in a DKJ-Solutions repo -- a web page, a local HTML report, a dashboard, a claude.ai Artifact, an email template, a chart's colours -- so it starts from the house style instead of a fresh design. Load it alongside artifact-design and dataviz, not instead of them; where they offer a placeholder palette, the house tokens replace it.
---

# The DKJ-Solutions house style

**Every DKJ-Solutions app looks like one family, and this skill is where that family is written down**
(Dave, issue [#2695](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2695), October 1,
2026). The style was tuned by hand on the ETF dashboard in `dkj-etf-tracker`. Rebuilding it per repo
means re-tuning it per repo, and two hand-tuned copies drift. So the general half was lifted out once,
with **every value kept exactly as chosen**, and the copy beside this page is the only one:
[`house-style.css`](house-style.css).

**It reaches DKJ-Solutions and nothing else.** The plugin is enabled only in DKJ-Solutions repos.
BWJ-Development has its own styling, and this skill says nothing about it.

## How to use it

1. **Copy `house-style.css` into the output, unchanged.** Where the output must make no external
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
| Direction | `--gain`, `--loss` (charts), `--up`, `--down` (numbers in text) | result and direction, never a category |
| Status | `--good`, `--warn`, `--bad`, `--warn-bg` | badges, meters, notices |
| Elevation | `--shadow-pop` | tooltips |

**The light/dark mechanism**: light by default; `prefers-color-scheme: dark` switches to dark unless
the page sets `<html data-theme="light">`; `<html data-theme="dark">` forces dark. That is why the dark
block appears twice in the file. CSS cannot share it, so **an edit to one dark block is made to both**.

**Components**, the complete list of reserved names, so a repo layer knows what not to redefine:
the page header (`body > header`, `main > header`), `main`/`.container`, `.hero`, `.tiles`/`.tile`,
`.card`, `.grid-2`, `.table-wrap`/`.table` (with `.row-total`), `.legend`/`.legend__item` (with
`--line`), `.swatch`, `.badge` (with `--good`, `--warn`, `--bad`, `--info`, `--neutral`, `--sm`),
`.badge-row`, `.meter` (with `--good`, `--warn`, `--bad`, `--info`), `.mini-cards`/`.mini-card` (with
`--highlight`), `.item-grid`/`.item`, `.notice`, `.note`, `.meta`, `.muted`, `.sub`, `.num` (tabular
numerals), `.delta` (with `--up`/`--down`, aliased `.pos`/`.neg`), `.btn`, `.info-button`, `.tooltip`
(with `--explain`), `.more` (a disclosure), `.chart` (the SVG chart scope) and `.footer-note`. Each is
commented in the file.

## What was deliberately left out

The parts of the ETF dashboard that only make sense there stayed there: the hazard-striped advice zone
and its tokens, the mapping from ETF/share/cash to a colour, and the Dutch status class names. The three
series colours survive as `--cat-1..3`, with the same values. A generic danger/alert component is **not**
in the house style yet. Adding one is a design decision for the owner, not something to back-fill from
the advice zone.

## Changing the house style

A change here reaches every DKJ-Solutions app at its next plugin update, so it is a **visible result**:
the branch stops for the owner's look instead of merging. Bring a consumer's improvement here through
an `inbound` issue on this repo. Don't make a local edit and hope it travels.
