## feat/1965-theme-lifecycle

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

#### What this branch is for

Inbound [#1965](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1965): BWJ's two Shopify
stores want one identical theme lifecycle -- a backup of live rotated at the release cut, and a sweep
of the repo's spent preview themes after the live push.

#### Where it lands, and why that is NOT where the issue asked

The issue asked for `dkj-policy-bwj`. The **mechanism** went to `dkj-subagents-shopify` instead, and the
repo's own written ruling is what settled it rather than a preference. `dkj-policy-bwj`'s README states
the #1881 default -- *anything the two stores share goes here* -- and names this exception in the same
breath: **`dkj-subagents-shopify` already owns the theme mechanisms**, and the chapters in
`dkj-policy-bwj` are *"policy, never mechanism."* Backing up a theme and sweeping an estate are Shopify
craft rather than BWJ practice; any Shopify repo wants a verified backup and a prefix-keyed sweep.

What IS BWJ's is the **policy** binding them to the cut and the live push, and that is chapter four:
`THEME-LIFECYCLE-portable.md`. The issue's own reasoning -- *both stores would otherwise build this
twice* -- is satisfied either way, since both enable `dkj-subagents-shopify`.

#### The order question, verified and then decided

#1965 point 5 said the shared documentation contradicts the requested order. Checked, and it is
sharper than reported: `cut-release`'s page does not merely state an order, it gives a **condition** --
a push that can fail or be partial, to a target with no locking that third parties edit, is
**push-then-cut** -- and names the invariant that buys: a failed push cannot leave a **stranded
release**. `dkj-subagents-shopify`'s own webshop-manager manual says the same in prose. A Shopify live
theme is exactly that target, which is why `sync-main` exists at all.

**Dave decided push-then-cut stands (September 14, 2026)**, and the backup was retargeted rather than
the order: it is the clean **baseline of what shipped**, the fixed point third-party drift is measured
from until the next release.

#### What was dropped, and it is recorded rather than half-shipped

**Behaviour 2 -- a preview theme of the trunk at the cut -- is not built.** Under push-then-cut the
trunk is already live at that moment, so the preview would be byte-identical to the live storefront: a
theme slot spent on a review target with nothing to review. It has value only under the other order,
and that is going back on #1965 rather than into a step that does nothing.

#### What could not be measured here, stated rather than glossed

This repo publishes plugins and has **no theme estate**, so nothing about the Shopify CLI's own
behaviour could be re-measured. Every figure from the consumer -- 61 themes of which ~39 are other
people's, the 38 -> 538 -> 738 -> 833 fill over eight minutes -- is cited as **that consumer's
measurement** in the lib header, the skill page and the policy page, rather than restated as a fact of
this tree. What IS measured here is everything the pure rules decide, which is where the destructive
decisions live.

### CREATE

- [x] `scripts/lib/theme-lifecycle-rules.ps1` -- the pure rules: the reserved namespace
      (`Get-RepoThemePrefix`, `Test-RepoOwnedThemeName`), the two name composers, `Get-ThemeFillVerdict`
      (the async-copy guard), `Get-ThemeSweepPlan`, `Get-BackupRotationPlan`, `Get-CutOrderWarning`.
- [x] `scripts/task/backup-live-theme.ps1` -- create, **verify**, then rotate. Fails loudly and rotates
      nothing on any verdict but *complete*.
- [x] `scripts/task/sweep-preview-themes.ps1` -- dry-run by default, one printed row per theme
      including every theme it leaves alone.
- [x] `scripts/task/push-preview.ps1` -- creates previews under the reserved prefix, and still finds a
      pre-#1965 theme by its old name so a branch in flight does not grow a second one.
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/skills/theme-lifecycle/SKILL.md` -- the mechanism's page.
- [x] `plugins/dkj-policy/dkj-policy-bwj/THEME-LIFECYCLE-portable.md` -- chapter four: the order and
      what it makes the backup MEAN, the three standing approvals for deleting a theme and their
      bounds, the migration, and the per-store seams.
- [x] Registered in `scripts/lib/shared-scripts-lib.ps1`; BWJ README, both plugin descriptions and the
      root README's `skills:all` spans updated for a fourth chapter and a new skill.
- [x] **#1965 point 9** -- the *"hard ceiling of 20 themes"* claim corrected in six places. It is
      plan-dependent, and the store that filed the issue holds 61. The argument was never the number.

#### The two design points that carry the safety

- **The delete set is keyed on a prefix this repo WROTE, never on a role or a resemblance.** Keyed on
  `role -eq 'unpublished'` a sweep would have destroyed ~39 themes belonging to an agency, an
  experimentation tool, an installed app and colleagues -- and would have looked correct in a dry run
  that only counted themes. Keyed on *"looks like a branch name"* it is guesswork, because several of
  those are plain hyphenated words.
- **The store domain is its own seam, `Get-ShopifyThemeEstateStore`.** Verified before building on it:
  `sync-main.ps1` opens its PR with bare `gh` and its own header names the missing lint and test gates
  as the accepted cost. So a consumer leaving `Get-ShopifyStoreDomain` unanswered as a brake is
  coherent, and reading it here would have lifted that brake as a side effect of adopting a backup.

### TEST

- [x] `scripts/tests/theme-lifecycle-rules.tests.ps1` -- weighted towards the NEGATIVE cases, because
      the happy path is one assert and the ways to be wrong are what delete somebody's theme: a
      miniature of the consumer's store in which exactly **one of nine** themes is sweepable, every
      foreign shape asserted unowned, both blind states (no live id known, a namespace collision) in
      which nothing is swept, and both states in which rotation **refuses** rather than emptying the
      store's only backup.
- [x] The fill verdict pinned in all four states against the consumer's measured sequence -- including
      the one that matters, a count that settles **below** the source.
- [x] `check-plugin-integrity.ps1` -- 0 errors (it caught a cross-plugin relative link from the new
      skill page, which a consumer installing only that plugin could not resolve; now absolute).
- [x] Full suite via `open-pr`.

### DEPLOY: feat/1965-theme-lifecycle

BWJ's two Shopify stores get **one identical theme lifecycle**, in two scripts plus the policy that
binds them to the cycle. After a live push, `sweep-preview-themes` removes the spent preview themes
**this repo created**. At the release cut that closes that push, `backup-live-theme` duplicates live,
polls until the copy is provably complete, and only then rotates the previous backup out -- so exactly
one backup is retained and there is never a window with none.

**The verify step is the substance, not the backup.** `shopify theme duplicate` returns long before the
copy is done -- measured in the consumer, a duplicate of live grew 38 to 833 files over roughly eight
minutes -- and a short copy is silent: the theme exists, is correctly named, has the right role.
Anything but *complete* now fails the run and rotates nothing.

**Every delete is bounded by a reserved name prefix the repo writes, never by a theme's role.** On the
store this was specified from, 39 of 61 themes belong to an agency, an experimentation tool, an
installed app or colleagues; a role-keyed sweep would have taken all of them and looked correct doing
it. Previews created before the prefix landed are therefore left standing as a one-time manual
cleanup -- the safe direction.

The policy lives in `dkj-policy-bwj`'s new fourth chapter: the push-then-cut order and what it makes the
backup *mean*, and the three standing approvals for deleting a theme with their bounds stated
explicitly, so each store points at the page rather than re-deciding locally.

**Score:** 4

#### What makes this deploy extra special

Two of the issue's own load-bearing claims were checked against the tree before anything was built on
them, and both changed the result. The requested cut/push order turned out to contradict a *reasoned*
condition on `cut-release`'s page rather than a bare convention -- so the order stayed and the backup
was retargeted, and the one requested behaviour that is a no-op under it was dropped and sent back to
the issue rather than shipped as a step that does nothing. And the separate store seam was built only
after confirming `sync-main`'s bare PR route really does skip the gates, which is what made a second
seam for one fact the right answer instead of duplication.

**Score:** 3

#### Pull Request

Back up the live theme at the cut, rotate it, and sweep the repo's spent previews
