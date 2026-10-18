## feat/3130-brandbook-into-dkj-solutions

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

#### What #3130 asks

Move the whole of `DKJ-Solutions/dkj-brandbook` into the dkj-solutions plugin. Copy first; archive the
brandbook only once everything works here. The brandbook gets its own page on this repo's Repo hub. A
step plan comes first, then the migration.

#### What is being moved (measured October 18, 2026, brandbook `origin/main` at `c3cefff`)

- 137 tracked files, no open issues or PRs, `dist/` untracked.
- `house-style/`: the canonical `house-style.css`, `house-theme.js`, the rules `README.md` and
  `patterns/repo-dashboard.html`. This is what consumers take.
- `src/` plus the Vite/React/TS tooling: the visual brandbook app (showcase, previews, the reference
  Repo hub, the default-theme-per-repo table) with its own web lint gate (`scripts/lint/lint-web.ps1`
  plus three `.mjs` checks) and CI job.
- The brandbook's own workflow scaffolding (`dkj-policy/`, six standard runners, `.claude/` lenses) is
  **not** moved, because this repo has its own. Its release history stays readable in the archived repo.
- Three house-style changes sit unreleased on the brandbook's `main` (#205, #207, #206/#210). Together
  they add 13 lines to `house-style.css`, so `main` no longer matches the v0.4.0 pin that consumers
  vendor. This branch therefore copies `house-style/` **at the v0.4.0 tag** (`b1f1a69`), byte-identical
  to the pin. The three changes are ported on their own branch with the URL repoint (step 4), because
  that is when consumers can fetch them.

#### What changes in this repo

- **The tag-pinned cross-repo pipeline dissolves.** `house-style-repoint.yml`,
  `scripts/ci/repoint-house-style.ps1`, `scripts/lib/house-style-repoint-lib.ps1` and their suite
  exist only because the files came from another repo (#3100, #2954). With the canonical copy in this
  repo they are retired.
- **Two copies become one.** `plugins/dkj-policy/dkj-solutions/assets/house-style/` becomes the
  canonical copy. `scripts/dashboard/house-style/` stops being a vendored copy and the hub serves the
  plugin's copy.
- **The pin.** The skill's tag, commit and sha256 table keep guarding the consumers' own vendored copies
  against drift, but are computed in this repo. The raw URL becomes this repo's path at a release tag.
- **The rule.** The dkj-solutions `CLAUDE.md` rule "change it upstream, in dkj-brandbook" becomes
  "change it in the dkj-solutions plugin", and the brandbook issue route stops. The same goes for the
  skill, the plugin README, `plugin.json`, `marketplace.json`, `CONTRIBUTING-portable.md:302` and Gwen's
  lens. History (CHANGELOG, release documents, dated measurement citations) is left as written.

#### The order: five branches, one change each

1. **This branch: the house style itself.** Copy `house-style/` into the plugin, hold that copy to the
   skill's pin, retire the repoint runner, collapse the hub's copy, and rewrite the rule text. A
   house-style change is normally a visible result, but this one is not: the CSS and JS are
   byte-identical to the pin.
2. **The brandbook app** ([#3131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3131)), to the location the owner picks (decision D1), with its web lint gate as a CI
   job here.
3. **The hub page `/brandbook`** ([#3132](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3132)), in the form the owner picks (decision D2). A visible result, so it
   stops for the owner's look.
4. **Repointing the consumer URL** ([#3133](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3133)) to this repo's raw path, once a release tag carries the files, and
   porting the three brandbook changes made since v0.4.0. A visible result, so it stops for the owner's
   look.
5. **Archiving the brandbook** ([#3134](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3134)), only after the criteria below hold: its README points here, and the repo
   is archived. Outward-facing, so it takes the owner's word.

Nothing is released or version-bumped by any of the five; a cut stays on explicit request.

#### When "everything works" (the archive criteria)

- All gates and suites green here, with no reference to `dkj-brandbook` left outside history.
- The house-style sessioncheck and `check-house-style.ps1` read the in-repo pin, and a consumer
  (`dkj-etf-tracker` or `dkj-maplestory-classic-mesowise`) passes the reusable CI check against it.
- The brandbook app builds and its web lint passes from its new place.
- The `/brandbook` hub page is approved by the owner.

#### Decisions for the owner

Answered by Dave, October 18, 2026:

- **D1, where the React app lands:** in `brandbook/` at the repo root, outside `plugins/`. Consumers
  install only the css, js, README and patterns through the plugin. The app stays a maintainer tool,
  with its own CI job.
- **D2, how the hub page renders:** as a native PowerShell page like the hub's other pages. It renders
  the tokens, the twelve themes and the components from the house style, needs no Node, and links to
  `npm run dev` for the full app.
- **D3, the consumer contract:** consumers keep vendoring a sha256-checked copy, fetched from this
  repo's raw path at a release tag. The house style gives up its own 0.x version and follows the plugin
  lockstep.

#### Consequence of D3: the raw URL moves only after a release

A raw URL at a tag needs a tag that contains the files, and no release of this repo has them yet. So
this branch makes the in-repo copy canonical and keeps it byte-identical to the v0.4.0 pin. The skill's
consumer URL keeps pointing at `dkj-brandbook/v0.4.0` for now, which still serves after an archive. The
URL is repointed to `dkj-claude-plugins/<tag>/plugins/dkj-policy/dkj-solutions/assets/house-style/` in
the first branch after the next release cut, which is step 4.

### CREATE

- [x] Owner's answers to D1-D3 recorded above
- [x] Copy `house-style/` (css, js, README, patterns) from brandbook tag v0.4.0 (`b1f1a69`) into
      `plugins/dkj-policy/dkj-solutions/assets/house-style/`, with css and js byte-identical to the pin
- [x] The canonical copy is held to the skill's pin by `check-house-style.ps1` and its suite (the pin
      itself stays on `dkj-brandbook/v0.4.0` until step 4)
- [x] Retire the repoint runner (workflow, script, lib, suite)
- [x] Hub serves the plugin's copy; `scripts/dashboard/house-style/` removed
- [x] Rule text rewritten in every non-history place that names dkj-brandbook
- [x] Review findings (code, copy, security) repaired
- [x] Steps 2-5 filed as #3131, #3132, #3133 and #3134, so the plan outlives this document

### TEST

- [x] The touched suites (check-house-style 74/0, connector-dashboard 115/0, dev-preview-sessionstart 105/0, dev-pages 175/0), `check-plugin-integrity.ps1` and `check-house-style.ps1` green

### DEPLOY: feat/3130-brandbook-into-dkj-solutions

The house style's canonical copy now lives in the dkj-solutions plugin, at
`plugins/dkj-policy/dkj-solutions/assets/house-style/`. Alongside `house-style.css` and
`house-theme.js` it now holds the rules `README.md` and `patterns/repo-dashboard.html`, all taken from
dkj-brandbook v0.4.0. The Repo hub serves that copy instead of a vendored one of its own. The scheduled
runner that opened a repoint PR for every brandbook release is retired, together with its script, lib
and suite, because there is no longer a second repo to follow. This is step 1 of #3130; the remaining
steps are #3131 to #3134.

**Score:** 3

#### What makes this deploy extra special

The house-style rule in the dkj-solutions `CLAUDE.md` changes. A consuming repo that needs the house
style changed now files a `feature-inbound` or `bug-inbound` issue on `DKJ-Solutions/dkj-claude-plugins`,
no longer on `dkj-brandbook`. The files a consumer vendors, and their pin, are unchanged.

**Score:** 2

#### Pull Request

The dkj-solutions plugin becomes the house style's home (#3130 step 1)

