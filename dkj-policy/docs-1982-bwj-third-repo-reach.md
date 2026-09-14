## docs/1982-bwj-third-repo-reach

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

Close #1982: commit `b9b2a65a` widened `dkj-policy-bwj`'s two gate checks (`report-issue`,
`adopt-dkj-policy-bwj` step 0) to admit `dkj-claude-plugins` as a third repo for ticket handling
alone, but left the four portable law pages, the plugin's own `README.md`, `plugin.json` and the
root `marketplace.json` all saying "exactly two repos" -- deliberately, per that commit's own message.
Sweep those pages so each states its actual per-chapter reach: three for ticket handling, two for the
other three chapters (sync log, preview handover, theme lifecycle), which stay Shopify-store policy
that `dkj-claude-plugins` genuinely has no part in.

### CREATE

- [x] `WORKFLOW-portable.md` -- restate the opening as three repos for this chapter, keep the
      org-left-out reasoning for the store pair, name the third (this plugin's own source repo,
      admitted by Dave Sept 14 2026, commit `b9b2a65a`) and what it does/doesn't gain, and separate
      the two axes (org-naming vs. repo-count) explicitly so neither reads as an explanation of the
      other.
- [x] `SYNC-LOG-portable.md`, `PREVIEW-portable.md`, `THEME-LIFECYCLE-portable.md` -- keep the
      two-repo opening, each stating explicitly that ITS reach did not widen and why (a sync log, a
      preview handover and a theme estate are all facts about a live Shopify theme, and the source
      repo runs no store), pointing back to `WORKFLOW-portable.md` for the contrast.
- [x] `dkj-policy-bwj/README.md` -- one paragraph ahead of the chapter table stating the reach now
      differs per chapter, citing the same decision and commit, pointing to the per-chapter pages
      for the detail rather than re-arguing it in the overview.
- [x] `dkj-policy-bwj/.claude-plugin/plugin.json` and root `.claude-plugin/marketplace.json` --
      reworded the closing "Enable this only in BWJ's two ... repos" sentence to state the split.
- [x] `CLAUDE.md`'s own forward-reference to #1982 (`"its own portable law pages still describe the
      reach as exactly two repos, which #1982 tracks separately"`) -- updated to describe the
      resolved state instead of pointing at an open issue this branch closes.
- [x] Root `README.md`'s `dkj-policy-bwj` table row -- its enablement cell restated the same
      "Only BWJ's two store repos" fact the two manifests carried; left unfixed it would have been a
      *new* inconsistency introduced by this branch (disagreeing with the manifests one PR after
      they were corrected), so it was brought in line with the same wording.
- [x] Filed [#2012](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2012) for three
      further, pre-existing "ticket-work step ... BWJ's two Shopify store repos" mentions found while
      doing this sweep (`CONTRIBUTING-portable.md:600`, `plugins/dkj-policy/README.md:210`,
      root `README.md:297`) -- a related but distinct site of the same staleness, in documents #1982
      never named, per this repo's "an inconsistency is always filed, not silently expanded" rule
      rather than widening this branch's scope. Also noted there, not fixed: the same root-README
      table row still opens "Three chapters" and omits `THEME-LIFECYCLE-portable.md` (chapter four,
      added Sept 13, 2026) -- an unrelated axis, spotted in passing.

### TEST

- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors (manifests, link-scan, mojibake and
      every other check pass on the reworded prose and the two JSON manifests).

### DEPLOY: docs/1982-bwj-third-repo-reach

`dkj-policy-bwj`'s four portable law pages, its `README.md`, `plugin.json` and the root
`marketplace.json` said "exactly two repos" everywhere, even after commit `b9b2a65a` (Sept 14, 2026)
admitted this plugin's own source repo (`dkj-claude-plugins`) as a third target for its ticket-handling
chapter alone. Each page now states its own actual reach -- three repos for `WORKFLOW-portable.md`,
two for the other three chapters, each explaining why it did or didn't widen and cross-linking the
one that did. `CLAUDE.md` and the root `README.md`'s plugin table, which restated the same fact, were
brought in line in the same move so this branch does not leave a fresh disagreement behind it. Closes
#1982.

**Score:** 1 -- corrects prose so a reader following a cross-reference is told the truth about which
repos a chapter applies in; nothing here changes what any gate enforces or what a session does.

#### What makes this deploy extra special

N/A -- no subscriber-facing behaviour changed; this is a documentation-only correction inside a policy
plugin's own portable pages.

**Score:** N/A

#### Pull Request

Sweep dkj-policy-bwj's stated reach to match its report-issue/adopt gate

