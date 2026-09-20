## fix/2218-shallow-clone-ancestry

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

#### What was verified before anything was written

The report's REASON, not only its symptom. Measured in this checkout, September 20, 2026:
`git rev-parse --is-shallow-repository` in `~/.claude/plugins/marketplaces/dkj-claude-plugins`
answers `true` and `git rev-list --count HEAD` answers `1` -- so the clone genuinely holds one
commit and the ancestry test is unanswerable by construction, exactly as #2218 states. The code
path was read too: with the versions equal, `Compare-Version` returns 0, which is not `-lt 0`, so
the run falls into the `else` that names a stale clone and a history rewrite and prescribes the
refresh. Both halves of the report stand.

#### The call the issue left open

#2218 states the honest verdict -- *"cannot be determined from a shallow clone"* -- and leaves one
decision: whether version equality alone is a sufficient verdict. It is, and for a measured reason
rather than a preference: `claude plugin update` arbitrates on the **version string** (#1772), so
where the two sides carry the same one there is nothing any command can close. What is deliberately
NOT claimed is the neighbouring `unreleased` verdict, which asserts the clone holds newer commits --
an ancestry fact a depth-1 clone cannot support.

### CREATE

- [x] `Resolve-Clone` carries `IsShallow`, read once beside HEAD via
      `git rev-parse --is-shallow-repository`, with a `.git/shallow` file test behind it for a git
      older than 2.15 -- so an old git falls back rather than answering "deep" by default.
- [x] The absent-commit branch splits on it: on a shallow clone the version strings arbitrate alone
      and the verdict says why it cannot say more. Equal versions become `ver-match` with no command;
      a newer clone is still `behind`; a newer install is still `clone-behind` with the refresh.
- [x] The deep-clone branch is untouched -- there an absent commit really is evidence.
- [x] The clone's header line carries `shallow clone`, so every verdict claiming shallowness is
      checkable from the same screen.
- [x] `build-shared-scripts.ps1` re-run: the `dkj-policy` mirror of the script is back in sync.

### TEST

- [x] Five scenarios added to `scripts/tests/plugin-versions.tests.ps1` (36, 36b, 36c, 36d, 36e) on a
      `New-ShallowClone` fixture -- a real depth-1 clone built with `git clone --no-local --depth 1`,
      because `git init` is never shallow and a hand-written `.git/shallow` would fake the fallback
      while leaving the call the script actually makes answering `false`.
- [x] The measured case is pinned both ways: the default view reads `up to date`, and `-Brief` emits
      no marker line at all -- the half that reaches a consumer's context at every session start.
- [x] 36e pins the boundary: a deep clone still reads an absent commit as evidence, and never prints
      the word shallow.
- [x] Full suite green, and `check-plugin-integrity.ps1` green.

### DEPLOY: fix/2218-shallow-clone-ancestry

`plugin-versions` no longer reports every plugin behind after a marketplace refresh. That refresh
re-clones the marketplace at depth 1 instead of fast-forwarding it, so the recorded install sha is
absent from the clone by construction -- and the run read that absence as evidence, naming a stale
clone and a history rewrite that had not happened, and prescribing the command that produced the
state. It now detects a shallow clone, says so on the clone line, and lets the version strings
arbitrate alone: equal versions read as up to date with nothing to run. A deep clone is unchanged,
where an absent commit really is evidence.

**Score:** 4

#### What makes this deploy extra special

Every consumer of this workflow sees these lines at every session start, forwarded by
`connector-sessioncheck`. In the measured state -- the one every checkout is in after a marketplace
refresh -- the report claimed 6 of 7 plugins were behind, at identical versions on both sides, and
handed over a command that recreates the state it complains about. A subscriber acting on that
either runs a refresh loop that never clears, or learns to skim the marker that does matter.

**Score:** 4

#### Pull Request

plugin-versions no longer reports a shallow marketplace clone as a stale one

