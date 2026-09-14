## feat/1990-adopt-bwj-asana-mirror

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Run `adopt-dkj-policy-bwj` in this repo now that its own gate admits `dkj-claude-plugins` as a third
permitted target (Dave, September 14, 2026, v5.3.0). Place what the CI mechanism needs; defer the
Asana wiring itself, since no board exists yet for this repo and a copied/guessed GID mirrors this
repo's own inbound tracker onto the wrong store's board.

### CREATE

- [x] Verified `git remote get-url origin` ends in `dkj-claude-plugins` -- step 0 passes.
- [x] Copied `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.yml` ->
      `.github/workflows/asana-mirror.yml` verbatim (no target file existed -- clean first run).
- [x] Copied `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1` ->
      `.github/scripts/asana-mirror.ps1` verbatim.
- [x] Created the `needs-info` label on this repo (`gh label create`) -- the other labels step 4
      needs (`documentation`, `prio-1..4` with matching colors, the reach label `minor`) already
      existed.
- [~] `scripts/repo-config.ps1`'s Asana seam (`Get-AsanaWorkspaceGid`, `Get-AsanaProjectGid`) --
      dropped on Dave's explicit choice: no Asana project exists yet for this repo (only
      `GitHub - WH` and `GitHub - SWB`, the two BWJ stores' own boards, were found), and the skill
      itself says a copied/provisional GID fails silently -- worse here, it would mirror this
      **public** repo's own inbound tracker onto somebody else's board. Left for a follow-up branch
      once a real board exists.
- [~] Step 3 (the `ASANA_PAT` / `GH_PROJECT_TOKEN` / `ASANA_PROJECT_GID` checklist) -- printed to
      Dave in-session, not written anywhere; nothing to set until the board above exists.
- [~] Step 5 (read the board's numbered sections / the GitHub project's `Status` options) --
      blocked on the same missing board; nothing to read yet.
- [~] Step 6 (point this repo's governance at `WORKFLOW-portable.md`) -- deferred to Tessa rather
      than patched in-place: the natural anchor (`CLAUDE.md:218-224`) is the same paragraph that
      says `dkj-policy-bwj` "have none [real work] here", which this branch's own admission makes
      stale for chapter one. Filed as
      [#1990](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1990) rather than patched
      ad hoc, since the governance pointer and the roster correction read better as one edit.
- [~] Step 7 (scaffold `dkj-policy-bwj/SYNC-LOG.md`) -- N/A. That is chapter two, for a Shopify
      theme sync; this repo declares `Get-ShopifyRepoHasNoStore` and has no theme to sync.

### TEST

- [x] `check-plugin-integrity.ps1` + every suite, via `open-pr.ps1`.

### DEPLOY: feat/1990-adopt-bwj-asana-mirror

`dkj-policy-bwj`'s CI mechanism (the Asana-mirror workflow + script) now sits in this repo's own
`.github/`, and the `needs-info` label exists, so the parts of `adopt-dkj-policy-bwj` that do not
depend on an actual Asana board are placed. The board itself -- workspace/project GID, the CI
secrets, the stage map -- stays open by design: this repo had no board of its own (only the two BWJ
stores' boards existed), and wiring one up on a guess was refused rather than guessed. Until a
follow-up branch adds the seam, the copied workflow is inert: it has no `ASANA_PROJECT_GID` variable
and no `ASANA_PAT`/`GH_PROJECT_TOKEN` secrets, so it fails closed rather than mirroring anywhere.

**Score:** 2 -- small, noticed only by whoever next reads `.github/workflows/` or picks up #1990;
nothing here changes how anyone works today, because the mechanism is not yet wired to a board.

#### What makes this deploy extra special

N/A -- a consumer of this marketplace gains nothing; this is the source repo placing, for itself,
config the third-repo admission (b9b2a65a) already shipped the permission for.

**Score:** N/A

#### Pull Request

Adopt dkj-policy-bwj's Asana-mirror CI mechanism in this repo (board wiring deferred)

