## feat/house-style-themes

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Implement the themes the owner approved in the preview artifact (V482ox5FtMLgQ36MPfWjWk) and mirrored to the Figma library DKJ-Solutions Theme's - LIBRARY. Default theme per app: the app declares a light and a dark default, the OS picks between them.

### CREATE

- [x] `house-style.css`: twelve themes as `data-theme` values (light magenta, purple, blue, teal, ochre, rust; dark pink, lilac, sky, cyan, yellow, orange), each setting `--primary`; Rust and Yellow also move `--warn` off the primary
- [x] `house-style.css`: new tokens `--primary`, `--on-primary`, `--primary-soft`, `--status-mark`; `--up`/`--down` a step more contrast than `--good`/`--bad` in both modes; dark gains its own `--bad`; light warning dark orange, dark warning yellow
- [x] `house-style.css`: no `data-theme` follows the OS (Blauw / Cyaan); `light` and `dark` still force a mode; the dark block covers `dark` and the six dark themes
- [x] Components follow the theme: the pressed `.seg` button, `.badge--info`, `.meter--info`, every badge mark; new `.btn--primary`, `.theme-picker`, `.theme-swatch`
- [x] `house-theme.js`: the user's choice, else the app's `data-theme-light`/`data-theme-dark` default for the OS mode, else the house default; `DKJTheme.picker(el)` draws the two rows of swatches
- [x] `SKILL.md`, the plugin README and `plugin.json`: the themes, the script, the new tokens and classes, and what changed for an app taking the update; the broken token table repaired

### TEST

- [x] Test page loading the real `house-style.css` and `house-theme.js` unchanged, published for the owner's look: https://claude.ai/artifact/XnJiGKF81AMeXDdQ6CV8Si
- [x] Copy edit (Edith): two comments that contradicted the code, fixed; hex values, ids and names agree across CSS, JS and SKILL.md
- [x] Code review (Victor): cascade correct, no blocking bug; fixed in this branch: a shipped `data-theme="light"`/`"dark"` is honoured, `picker()` binds once per element, no reliance on `Element.closest`, swatch colours set through the CSSOM (strict CSP), chosen and focused swatches drawn differently. Left as the owner chose: the white mark on the light warning icon
- [x] `node --check` on `house-theme.js`; the file is ASCII

### DEPLOY: feat/house-style-themes

The DKJ-Solutions house style has twelve themes the user picks from: six light, six dark, each a
primary colour on the shared form. `<html data-theme="purple">` sets one; `house-theme.js` applies
the user's choice, else the app's own light/dark default for the OS mode, and draws the picker. No red
and no green theme, because those colours mean bad and good; the status colours are the same in every
theme. The status tokens were reworked with them: `--up`/`--down` are now a step more contrast than
`--good`/`--bad` in both modes, and dark gets its own `--bad`.

**Score:** 3

#### What makes this deploy extra special

Every DKJ-Solutions app can let its users pick a colour, and two apps no longer look identical: each
declares its own default pair. An app that takes the update without changing anything gets the house
defaults, Blauw and Cyaan: its switches and info badges turn blue or cyan instead of ink, the warning
icon on light turns dark orange, and the negative number on light a darker red.

**Score:** 4

#### Pull Request

House style: twelve themes the user picks, a primary colour per theme, and the status colours per mode

