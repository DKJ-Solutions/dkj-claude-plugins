## feat/2171-plugin-stops-scaffolding-folder-docs

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

**#2171, Dave, September 20, 2026:** the two pages a consumer gets in its own `dkj-policy/` folder only make
that repo more complicated and produce more inconsistency. **There is one CONTRIBUTING for a consumer to
read, and it is the plugin's.** Everything a consumer's own repo answers goes into the specialist's lens
instead; the folder README's content may be merged into `.claude/specialists/README.md`.

#### Two different files wear this name, and only ONE of them is this branch

1. **The scaffold output** -- what `adopt-workflow-folder.ps1` writes into a fresh consumer. There is no
   template: both pages are composed inline as string arrays and written at the `Rel =` lines near the end
   of the placement list. On top of that sits the refreshable fenced block from #1766, replaced on every
   `-Apply`. **This branch is that, and only that.**
2. **This repo's own two pages** -- 1,132 lines of `CONTRIBUTING.md` and 167 of `README.md`, hand-composed,
   which the scaffolder has never touched (`Test-IsWorkflowSourceRepo` refuses here). Almost every paragraph
   is a measured instance with an issue number and a date, so removing them is a MIGRATION, not a delete.
   **That is the second branch, after this one lands** -- see the phase note below.

#### The two answers that set the scope (Dave, September 20, 2026)

- **Full reach: this repo's own copies go too**, in the follow-up branch. Otherwise "there is only one
  CONTRIBUTING" is false in the very repo that ships the sentence.
- **The five already-adopted consumers are REPORTED, never touched.** Part 1 says the two pages are legacy
  -- the plugin no longer writes or refreshes them, keeping them is fine, deleting them is theirs to decide.
  Nothing in another repo is removed from here, and no delete command is printed: a consumer's copy may hold
  the only statement of something they answered.

#### What must NOT change with it

- **The reading gates keep reading a legacy copy.** `check-consumer-prose.ps1` runs the supremacy and
  retired-name detectors over `Get-ConsumerProseDocuments`, whose reserved-name sweep is where the folder
  README and CONTRIBUTING become machine-known. Five consumers still hold those files and the gate's own
  measured instance IS one of them, so narrowing that corpus would silently retire a gate. The same holds
  for the reserved names in `Get-BranchFilePaths`, which is what stops the fold mistaking either page for a
  branch document.
- **The folder stays.** The changelog, `releases/` and the per-branch document are untouched, and
  `check-script-contract.ps1` tests the FOLDER's existence rather than these two files -- so nothing there
  moves.
- **`releases/README.md` is out of scope.** It is a third scaffolded page and the issue names two.
- **The archived release history is never swept** -- `releases/**` and the folded changelog keep the paths
  they were written with, the carve-out this repo already runs.

#### Phase note -- why this branch stops where it does

A (this branch) is the mechanism: the plugin stops writing. B (`docs/2171-...`, opened after this merges) is
this repo's own migration -- the measured passages into Derek's, Rendall's and Sylvester's lenses, the
README's update chapter into `.claude/specialists/README.md`, then the deletion and the retargeting of the
14 markdown links that point at either page. A first, because B's prose then describes a settled state
rather than one still moving. The lenses are NOT on the always-on path, so B costs no session budget --
verified with `measure-skill` before it lands.

### CREATE

- [x] A1 -- `scripts/task/adopt-workflow-folder.ps1`: stop composing and placing the two pages (both content
      blocks and their two entries in the placement list), leaving every other target it writes exactly as
      it is -- the PR template, the two CI workflows, `releases/README.md`, the changelog intro and the one
      seam it is permitted to answer
- [x] A2 -- drop the refreshable fenced-block machinery for the folder README (the block builder and its
      four top-up states) and put a LEGACY REPORT in its place: a consumer holding either page is told the
      plugin no longer writes or refreshes it, with no delete command printed
- [x] A3 -- regenerate the plugin mirror with `scripts/sync/build-shared-scripts.ps1`, so the registered
      pair stays LF-identical
- [x] A4 -- rewrite `scripts/tests/adopt-workflow-folder.tests.ps1`: the scaffold-target assert and the
      per-page asserts flip from *is written* to *is NOT written, and an existing copy is left untouched and
      reported*
- [x] A5 -- prove the reading gates are unaffected: a legacy folder CONTRIBUTING is still read by
      `check-consumer-prose.ps1`, and the reserved names still shield both pages from the fold
- [x] A6 -- the rank-order model drops from three ranks to two for a NEW consumer, while rank 2 stays real
      wherever a legacy copy exists: `plugins/dkj-policy/CONTRIBUTING-portable.md`, `check-policy-drift.ps1`
      and its SKILL page (including the ASCII rank diagram in both)
- [x] A7 -- `plugins/dkj-policy/skills/adopt-dkj-policy/SKILL.md`: Part 1 stops promising the two pages and
      states the legacy report instead
- [x] A8 -- open-pr gate pass: lint + full suites green before the push

### TEST

**The adoption suite, rewritten rather than trimmed: 94 asserts, green from the repo root AND from the
mirror's own directory depth.** What it now proves is the absence: neither page appears among the scaffold
targets, neither is created by `-Apply`, and a fresh consumer sees no `[legacy]` line at all. An absence
nobody asserts is one the next refactor restores by accident.

**The case that actually protects a consumer** is the legacy report over a page that is already there: both
pages present with arbitrary content and deliberately mixed line endings, both reported, both byte-identical
after `-Apply`, and no delete command anywhere in the output. Both one-of-two directions covered too.

**264 lines were dropped rather than bent** -- the fenced UPDATE-section states and the CRLF byte-exactness
pass from inbound #1829. The mechanism they proved is gone from the script, so there was no honest rewrite
target; a comment in their place names #2171 so the gap does not read as an oversight.

**The reading gates were proven UNAFFECTED before anything else was touched**, because that was the risk in
this change: `consumer-prose-gate` 78 asserts, `pr-issues` 1,061, `policy-drift-report` 25, all green with no
edit to any of them. A consumer that still holds either page still has it read.

**Lint gate: 0 errors** over the full check set, and 118 suites green -- including the one this change
retired a caller from: `document-newline` held `adopt-workflow-folder.ps1` to calling `Get-DocumentNewline`,
which it did only inside the fenced block, so its row left the reach set rather than gaining an exemption.
The check covers the dead-link scan and the shared-script mirror
equality that this change had to keep true across two regenerations.

### DEPLOY: feat/2171-plugin-stops-scaffolding-folder-docs

`adopt-dkj-policy`'s Part 1 no longer writes `dkj-policy/README.md` or `dkj-policy/CONTRIBUTING.md` into a
consuming repo (Dave, #2171): two pages in the consumer's own tree only made that repo more complicated and
produced more inconsistency than they removed. **There is one `CONTRIBUTING` for a consumer to read and it
is the plugin's portable page**; what a repo answers for itself goes into its specialist lens, where the
rest of its repo-specific answers already live.

The refreshable fenced block (#1766) went with the page it lived in, along with its four top-up states and
the enabled-plugin read that composed its UPDATE chapter. That block existed because a page scaffolded once
is never corrected afterwards -- the right repair for a page the plugin OWNS -- and removing the page
answers the same defect one level up rather than contradicting it. With no fenced region left, *nothing that
already exists is ever touched* is true of this command without qualification for the first time.

**An existing copy is reported and never touched, and no delete command is printed.** A copy may carry the
only written statement of something that repo answered, and nothing here can tell that from a stale
scaffold. **The gates that READ those names are deliberately unchanged** -- `check-consumer-prose` runs its
detectors over both and `check-policy-drift` still lists them -- so a page still on disk keeps the standing
its repo gives it. Narrowing a gate to match would have retired it in the very repos whose pages are the
reason it exists.

The rank-order model now says the truth for both kinds of repo: the plugin's portable pages and skills sit
above the floor either way, and the middle rank is real only where a repo still carries the page it names.

**Score:** 4

#### What makes this deploy extra special

**This is a page a consumer was told to read, and the sentence that pointed at it shipped in the portable
half.** So the removal cannot be done in the scaffolder alone: a repo adopting today would have been handed
a rank model naming a file it never receives, and a repo that adopted earlier would have read that its
second layer no longer exists while the file sits in its tree and its gates go on reading it. Both readings
are wrong, and they are wrong in opposite directions -- which is why the portable page, the two skill pages
and the drift report all state the condition explicitly rather than picking one of the two repos to be
correct for.

**Nothing is removed from any consumer, on purpose.** The five repos holding these pages keep them, keep
their prose gate, and keep their rank 2. What they get on their next `adopt-dkj-policy` run is one `[legacy]`
line per page saying the plugin no longer authors it. That is the whole migration, and it is deliberately
not a command they can paste.

**Score:** 3

#### Pull Request

The plugin stops scaffolding a consumer's folder README and CONTRIBUTING
