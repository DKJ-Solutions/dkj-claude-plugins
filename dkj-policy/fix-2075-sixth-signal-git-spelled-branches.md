## fix/2075-sixth-signal-git-spelled-branches

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

#### What #2075 measured

`claim-issue`'s sixth signal (#2064) weighs the branches the fourth and fifth scans surfaced: it asks
git how far each is ahead of the trunk (`rev-list --count`) and which of the issue's cited paths sit on
it and not on the trunk (`ls-tree`). It is fed from **two** scans, and on `origin/main` the two handed
it different spellings of the same thing.

The fifth signal's names come off `git branch -a` unchanged. The **fourth** signal's had already been
through `Format-ForConsole`, because its finding records are what the printed report reads from:

```powershell
Branches = @($branches | ForEach-Object { Format-ForConsole -Text $_ })
```

and the collection into the sixth signal took exactly that field, under a comment saying it collects
*"the same records the report prints from"* -- accurate about the records, and wrong about the field,
because the sixth signal does not **print** those names, it **queries** them.

`Format-ForConsole` replaces each stripped character **with a space**, so a branch name carrying one
becomes a name git does not have. `rev-list --count` then fails, `$ahead` stays `-1`, `ls-tree` returns
nothing, `$onlyThere` is empty, and `$prerequisiteFound` is never set. Both calls pass `-DiscardStderr`
and are guarded on their exit code, so nothing prints and nothing errors: **no dependency reported**,
which on the page is indistinguishable from there being none.

#### Why it only ever bites in the adversarial case

`git check-ref-format` enforces `\p{Cc}` and **accepts** `\p{Cf}`, so a ref carrying U+202E or a
zero-width run is fetchable and pushable. On an ordinary ASCII name the stripped and unstripped
spellings are the identical string -- which is why no run, no fixture and no existing assert would ever
have shown this. The failure lands in exactly the case the strip exists for, and nowhere else.

#### The repair, and why the direction has to be asserted

The seam is already drawn correctly one screen down, in the sixth signal's own weighing loop -- the
printed record gets `Branch = (Format-ForConsole -Text $branch)` and the git calls get `$branch` -- and
`fix/2069-title-overlap-strip-and-plural-v2` draws the same one for the fifth signal. What was
inconsistent was only the fourth signal's **input**.

So: keep `Branches` stripped, because that is what the report prints, and carry the git-spelled names
beside it in a second field the sixth signal reads. And pin **both halves** in the suite -- structurally
rather than behaviourally, since on an ASCII name a behavioural assert cannot tell the two fields apart.

### CREATE

- [x] `scripts/task/claim-issue.ps1`: the fourth signal's finding record carries `GitBranches` -- the
      names as git spells them -- beside the stripped `Branches` the report prints from
- [x] `scripts/task/claim-issue.ps1`: the collection into `$surfacedBranches` reads `GitBranches`, and
      the comment above it says which field and why
- [x] `plugins/dkj-policy/scripts/task/claim-issue.ps1`: mirror regenerated via
      `scripts/sync/build-shared-scripts.ps1`

### TEST

- [x] `scripts/tests/claim-issue.tests.ps1`: three asserts on the fourth signal's block -- the record
      carries the unstripped names, the sixth signal is fed those, and never the stripped copies
- [x] `scripts/tests/claim-issue.tests.ps1` green (285 asserts)
- [x] the lint gate + the full test gate green via `open-pr.ps1`

### DEPLOY: fix/2075-sixth-signal-git-spelled-branches

`claim-issue`'s sixth signal now asks git about the branch names **git has**. It is fed by two scans,
and one of them handed it names that had already been through the console sanitiser -- which replaces
what it strips with a space, so the ref it named did not exist. `rev-list --count` and `ls-tree` both
came back empty, both are guarded on their exit code and discard stderr, and the block printed *not a
dependency*: the one verdict in that report a reader cannot distinguish from the truth.

The finding record now carries both spellings and each reader takes its own -- `Branches` stripped for
the report, `GitBranches` as git wrote it for the scan. That is the seam the sixth signal's own weighing
loop already drew for itself, and the one `fix/2069-title-overlap-strip-and-plural-v2` draws for the
fifth signal; the fourth signal's input was the place it had never been drawn.

Pinned with three structural asserts rather than a behavioural case, deliberately: `git
check-ref-format` accepts `\p{Cf}`, so the failure needs a branch carrying a bidi override or a
zero-width run, and on every ordinary name the two fields hold the identical string. No run can tell
them apart, so the direction is the whole finding and an assert is the only thing that can state it.

**Score:** 2

#### What makes this deploy extra special

A consumer running `claim-issue` gets a signal that had a silent hole in it: the one case the branch-name
strip was added for was also the one case the prerequisite scan could not answer. Nobody has hit it --
it needs somebody to push a branch whose name carries a formatting character -- so this is a failure
named rather than a failure repaired, and that is worth saying plainly.

What generalises past this one script is the rule the repair states twice in comments and three times in
asserts: **sanitise on the way out, never on the way in.** A value that is going to be printed and a
value that is going back to the tool it came from are two different values, and where one variable
carries both, the tool is the one that loses -- quietly, and only when it matters.

**Score:** 1

#### Pull Request

The sixth signal is fed git-spelled branch names, not the stripped copies the report prints
