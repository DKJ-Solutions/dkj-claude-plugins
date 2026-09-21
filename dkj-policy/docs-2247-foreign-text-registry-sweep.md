## docs/2247-foreign-text-registry-sweep

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

Correct the foreign-text print registry in new-branch's SKILL.md: adopt-ci-floor.ps1 prints a consumer's own job ids, repo slug and workflow filenames and is not among the listed sites. Sweep the tree for the same shape rather than adding one entry, and correct the count.

### CREATE

#### What the sweep found, and why this is not a one-entry edit

#2247 reported ONE missing site and suggested a sweep might be the right repair. The sweep was run and
it was: the registry was missing several sites, including an entire FOURTH hand-typed strip mechanism
(`check-report-lib.ps1`'s `Format-SafeToken` family, `\p{C}`, 13 caller files) that had been invisible
for as long as the list existed.

#2247 also asserted that the site it reported was fully guarded and that "nothing is exploitable
today". Reading the site showed two values printed RAW, one of them on the same line as a guarded one.
That is the code half, and it is deliberately NOT in this branch -- filed as #2248.

- [x] Claim #2247 and open the branch
- [x] Verify the reported symptom against the tree -- the registry does say "seven" and does not carry
      `adopt-ci-floor.ps1`
- [x] Sweep `scripts/**` and `plugins/**` for print sites outside the seven, guarded and unguarded alike
- [x] Verify the two decisive sweep claims by hand: `$w.Rel`'s origin and its raw prints, and
      `check-report-lib.ps1` as a genuinely separate mechanism from the three libs
- [x] File the code half separately -- #2248, the unguarded prints in `adopt-ci-floor.ps1`,
      `sync-main.ps1` and `check-consumer-siblings.ps1`
- [ ] Rewrite the registry in `plugins/dkj-policy/skills/new-branch/SKILL.md`: new entries, corrected
      count, corrected caller lists on entries 1 and 4, and the lesson this sweep carries
- [ ] Review pass on the diff -- copy edit, and a check that no entry claims a guard the site does not have

### TEST

### DEPLOY: docs/2247-foreign-text-registry-sweep

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

The foreign-text print registry gains the sites a sweep found, starting with adopt-ci-floor.ps1

