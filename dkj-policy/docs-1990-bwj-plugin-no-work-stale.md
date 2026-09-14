## docs/1990-bwj-plugin-no-work-stale

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

#### Verified before repairing (per this repo's own rule)

Confirmed commit `b9b2a65a` (Dave, September 14, 2026) is on `main` and that
`report-issue/SKILL.md` and `adopt-dkj-policy-bwj/SKILL.md` now both name `dkj-claude-plugins`
alongside the two BWJ stores.

**Subject correction.** The issue attributes the quoted sentence to `SPECIALISTS.md`, but that exact
blockquote does not exist there -- `SPECIALISTS.md`'s own "no work here" sentence names only the
three add-on teams, never `dkj-policy-bwj`. The sentence is verbatim in `CLAUDE.md`'s repo slot
("Only two of the six describe this repo..."). The underlying inconsistency the issue describes is
real; the file it names is not. Fixing `CLAUDE.md`, not `SPECIALISTS.md`.

While verifying this, found that #1982 (closed NOT_PLANNED because the gate change had not landed
yet) now has a live premise too: the plugin's own portable law pages, `README.md`, `plugin.json` and
`marketplace.json` still say "exactly two repos" / "Enable this only in BWJ's two ... store repos".
Reopened #1982 with the verification rather than folding it into this branch -- different files,
different specialist concern (the plugin's own portable pages vs. this repo's `CLAUDE.md`).

### CREATE

- [x] `CLAUDE.md`'s repo slot: replaced "the three add-on teams and `dkj-policy-bwj` have none" with
      a carve-out for `dkj-policy-bwj`'s ticket-handling chapter (now permitted here since
      `b9b2a65a`), while keeping "none" for its other three (Shopify-store) chapters and for the
      three add-on teams.

### TEST

- [x] `check-plugin-integrity.ps1`: 0 error(s) (link scan included -- the new `#1982` reference
      resolves).
- [x] Confirmed no other file depends on the retired exact phrasing (`grep` for the sentence
      elsewhere in `scripts/` and `.claude/`: no hits).

### DEPLOY: docs/1990-bwj-plugin-no-work-stale

`CLAUDE.md`'s repo slot no longer groups `dkj-policy-bwj` with the three add-on teams as having no
work in this repo. It now says what is actually true since September 14, 2026: three of its four
chapters still have none (this repo has no Shopify store), but its ticket-handling chapter does,
because Dave admitted this repo as a third permitted target at its own gate.

**Score:** 2 -- a documentation correction with no functional effect; worth having right so a future
session does not read the old sentence and wrongly rule out `dkj-policy-bwj`'s `report-issue` skill
for this repo's own inbound findings.

#### What makes this deploy extra special

N/A -- `CLAUDE.md` is this repo's own governance document; it is not shipped to consumers.

**Score:** N/A

#### Pull Request

CLAUDE.md still groups dkj-policy-bwj with the add-on teams as having no work here, after the gate admitted this repo

