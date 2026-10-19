## feat/3131-brandbook-app

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

Step 2 of the #3130 plan (#3131): the dkj-brandbook Vite/React/TS app into `brandbook/` at the repo
root, reading the one house-style copy in the dkj-solutions plugin. Treated as a ship rather than a
visible park: the plan marks steps 3 and 4 as visible results and gives this one a gate-shaped done
condition (build and web lint, locally and in CI). The three post-v0.4.0 house rules the app uses
(`.grid__head`, `.grid__full`, `.card__head > h3`) are not in the plugin copy yet; porting them is
#3133's, which is a visible step.

### CREATE

- [x] Copy the app's tracked files (src, public, index.html, configs, lock, `.nvmrc`, `.gitignore`, the three `.mjs` checks) from dkj-brandbook `main` at c3cefff
- [x] Point `src/main.tsx`, `vite.config.ts` (plus `server.fs.allow`) and the checks (`scripts/lint/house-path.mjs`) at `plugins/dkj-policy/dkj-solutions/assets/house-style/`
- [x] The gate as `npm run gate` instead of `lint-web.ps1`, so the app adds no `.ps1` to the script layer and no skill is owed
- [x] `.github/workflows/brandbook.yml`: path-scoped, so not a required check
- [x] Confidentiality pass over `src/` (previews included): public DKJ-Solutions URLs only, no addresses or names
- [x] check-house-style: drop the `.sr-only` duplicate from `src/index.css`, allowlist the five deliberate extensions in `Get-HouseStyleAllowlist`
- [x] `brandbook/README.md`

### TEST

- [x] `npm ci` + `npm run gate` green from `brandbook/` (eslint 0 errors, the two pre-existing warnings; CSS syntax, vars, colours OK; build OK)
- [x] Dev server serves the house stylesheet from outside the app root (HTTP 200 through `/@fs/`)
- [x] check-house-style: `[OK] the house style holds at v0.4.0`

### DEPLOY: feat/3131-brandbook-app

The brandbook app now lives in this repo at [`brandbook/`](../brandbook/README.md), step 2 of #3130:
the Repo hub pattern and the component showcase, built and linted by `npm run gate` and by a new
path-scoped [`brandbook`](../.github/workflows/brandbook.yml) workflow. It reads the house style from
`plugins/dkj-policy/dkj-solutions/assets/house-style/` where it lives, so there is one copy, and it sits
outside `plugins/`, so no consumer installs it. Five deliberate extensions it carries are answered in
`Get-HouseStyleAllowlist`. Until #3133 ports the post-v0.4.0 house rules, its grid headings render
without them.

**Score:** 2

#### What makes this deploy extra special

N/A: nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

Move the brandbook React app into brandbook/ at the repo root

