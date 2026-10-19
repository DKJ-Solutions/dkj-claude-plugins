## feat/3132-brandbook-hub-page

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

Step 3 of #3130 (decision D2): a native `/brandbook` page on the Repo hub, rendered in PowerShell from
`plugins/dkj-policy/dkj-solutions/assets/house-style/`, with no Node dependency. A visible result, so
the branch stops for the owner's look before any pull request.

### CREATE

- [x] `ConvertFrom-HouseStyleAssets` + `Format-BrandbookPageHtml` in `scripts/lib/dev-pages-lib.ps1`;
  the hub row in `Get-RepoHubPages`
- [x] The `/brandbook` route and `Get-BrandbookModel` in `scripts/dashboard/serve-connector-dashboard.ps1`
- [x] Two allowlist entries in `scripts/repo-config.ps1` for the gate's false positives (a pattern that
  reads the stylesheet, and the suite's fixture stylesheet)

### TEST

- [x] `dev-pages.tests.ps1`: 229 passed (the model on a fixture and on the real assets, the page, escaping)
- [x] `connector-dashboard.tests.ps1`: 121 passed; the group-3 assert added here does not run yet,
  because groups 3 and 4 run no assert at all on `main` either (#3137)
- [x] `check-house-style.ps1`: OK at v0.4.0
- [x] Rendered by headless Edge at 1280px and 390px, checked by eye before the hand-over

### DEPLOY: feat/3132-brandbook-hub-page

The Repo hub of this repo gains a **Brandbook** page at `/brandbook`, step 3 of
[#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130): the twelve themes with their
nine steps each, every light token with a sample drawn in the picked theme, a few live specimens and
every house class by its stylesheet section. It is read from the plugin's `assets/house-style/` on every
request, so it shows the tree rather than the installed release, and it points at `npm run dev` in
`brandbook/` once [#3131](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3131) has moved the
full app in.

**Score:** 2

#### What makes this deploy extra special

N/A: the Repo hub is this source repo's own dev server; no consumer receives it.

**Score:** N/A

#### Pull Request

Repo hub: a native /brandbook page

