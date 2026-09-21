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
- [x] Rewrite the registry in `plugins/dkj-policy/skills/new-branch/SKILL.md`: new entries, corrected
      count, corrected caller lists on entries 1 and 4, and the lesson this sweep carries
- [x] Review pass on the diff -- copy edit, and a check that no entry claims a guard the site does not have

### TEST

- [x] `grep -cE '^[0-9]+\. \*\*'` over the registry block returns 13, matching the stated count, and the
      numbering runs 1..13 with no gap
- [x] Every line number newly cited in the registry was opened and read: `adopt-ci-floor.ps1`
      L883/L980/L988/L1032/L1046/L1053/L1056/L1061, `sync-main.ps1` L549/L570/L573,
      `check-consumer-siblings.ps1` L105/L445/L450/L454/L463, `park-cycle.ps1` L206/L242/L250/L538/L575,
      `tidy-machine.ps1` L488/L529/L550/L555/L586, `gate-lib.ps1`, `fanout-lib.ps1`
- [x] The four caps in entry 9 read off `check-report-lib.ps1` itself rather than off the briefing --
      `Format-SafeToken` and `Format-SuspectToken` 120, `Format-SafePathToken` and
      `Format-SafeProseToken` 200. The briefing had two of them wrong and the code won
- [x] The thirteen caller files of the `check-report-lib.ps1` family counted twice, independently
- [x] `pr-issues.tests.ps1`'s "three libs and no more" assert re-read: it matches on
      `function ConvertTo-ConsoleStrippedText`, which `check-report-lib.ps1` does not define, so entry 9
      is a gap that pin was never asked about and not a test the diff breaks
- [x] Copy-edit pass on the diff: no blocking findings; three clarity fixes applied and re-verified
The lint gate and the full suites are not a step of this branch -- `open-pr.ps1` runs both before it
pushes, and it is the gate's own run that counts. A copy set going ahead of it proves nothing that run
would not have caught.

### DEPLOY: docs/2247-foreign-text-registry-sweep

The registry of every console this workflow prints foreign text to -- in
[`new-branch`'s skill page](../plugins/dkj-policy/skills/new-branch/SKILL.md) -- goes from **seven
entries to thirteen**, after the first sweep anybody ran on purpose. #2247 reported one missing site and
suggested a sweep might be the right repair; it was. Entry 8 is `adopt-ci-floor.ps1`, the reported one.
Entry 9 is the find that mattered: `check-report-lib.ps1`'s `Format-SafeToken` family is a **fourth
hand-typed strip mechanism**, a `\p{C}` pattern with its own three-issue lineage and thirteen caller
files across `scripts/lint/`, `scripts/sync/`, `scripts/task/` and `scripts/maintenance/`, and it had
been invisible for as long as the list existed. Entries 10 to 13 are a branch document's own prose
quoted back at it, GitHub's required-check names, `check-fanout`'s shrinkage report, and
`check-consumer-siblings.ps1`. Entries 1 and 4 are edited rather than duplicated, per the page's own
rule that a new caller inside a listed site is an edit to that entry: `park-cycle.ps1` relays entry 1's
value and prints entry 4's, `tidy-machine.ps1` prints entry 4's, and entry 4 had a value it never named
at all -- `sync-main.ps1`'s raw `$rel`.

**#2247's own premise was false, and the page now says so.** It asserted the site it reported was fully
guarded and that "nothing is exploitable today"; reading that site instead of the report about it found
two raw, uncapped values beside the guarded ones -- one of them sharing a line with a value #2247 had
checked and called safe. The repair for those is **#2248**, deliberately not on this branch: this one
makes the list true, not the scripts safe. The closing overclaim -- that a reader "now has the list" --
is retired for the same reason the sentence before it was: a reader has, at most, every place found so
far. Growing three to seven incidentally and seven to thirteen in one deliberate pass argues the
technique works, not that it is exhausted.

**Score:** 3

#### What makes this deploy extra special

N/A -- a maintenance registry inside a skill page this workflow ships. Its reader is whoever audits
where this workflow prints somebody else's characters, which is this repo's own kind of reader; a
subscriber of a service notices nothing about it. The two unguarded sites it now names are real, but
what a consumer would notice is their repair, and that is #2248 rather than this change.

**Score:** N/A

#### Pull Request

The foreign-text print registry goes from seven sites to thirteen, after the first deliberate sweep
