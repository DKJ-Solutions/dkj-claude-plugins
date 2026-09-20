## fix/2204-lensdircandidates-enumeration-guard

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

Add `-ErrorAction SilentlyContinue` to the one `Get-ChildItem` in `Get-LensDirCandidates`
(`scripts/lib/check-report-lib.ps1`), matching the pattern its sibling `Get-SpecialistFiles` already uses
one screen down, so a caller running under `$ErrorActionPreference = 'Stop'` no longer has a
permission-denied directory or a broken reparse point under `.claude/plugins/` escalated into a throw.
Narrow at the root, for every caller of the shared primitive, rather than at each call site.

#### What the pickup check found, and what it changed

The symptom stands exactly as #2204 reports it: line 2051 of `check-report-lib.ps1` enumerated the plugin
families bare, while `Get-SpecialistFiles` 400 lines below already passed the flag. Verified before the
repair, re-verified after a `git pull --ff-only` brought the base forward nine commits.

**The issue's CONTEXT is a step ahead of the tree, and that turned out to matter.** It describes
`Get-ConsumerLensPaths` as living in `scripts/lib/entry-scaffold-lib.ps1` and wrapping its call in
`try { ... } catch { }` "as the narrower fix's stand-in until this lands." **#2199 is still open**, so that
promoted function does not exist yet; the `Get-ConsumerLensPaths` that does exist arrived with #2184, sits
in `scripts/task/check-policy-drift.ps1:265`, and carries **no** `try/catch` at all. So there is no stand-in
to unwind here, and this branch is the one-line narrowing plus its test and nothing else. When #2199 does
land it inherits a guarded primitive and should not add the wrapper its plan describes -- the third bullet
of #2204's own recommendation is the reason, and it is now true rather than pending.

**The `GetFullPath` surface #2204 raises as a second, structurally distinct throw is not addressed here, and
deliberately not.** It lives inside `Get-ConsumerLensPaths`'s file loop, which is #2199's code; the
recommendation's claim is that narrowing at the root closes it "as a side effect", and that holds only for
*this* risk -- an enumeration that can no longer hand the loop a pathological entry. Nothing in this branch
can reach a loop that does not exist yet.

### CREATE

- [x] `scripts/lib/check-report-lib.ps1` -- `-ErrorAction SilentlyContinue` on the family enumeration in
      `Get-LensDirCandidates`, plus a docblock paragraph stating why the guard sits at the root and not at
      each call site.
- [x] The three plugin mirrors regenerated with `scripts/sync/build-shared-scripts.ps1` --
      `dkj-subagents-alpha`, `dkj-policy` and `dkj-subagents-shopify` all carry this lib, and the
      shared-scripts drift lint holds them byte-identical to the source.

### TEST

- [x] `scripts/tests/check-report-lib.tests.ps1` -- section 11 pins the guard. The suite already runs under
      `$ErrorActionPreference = 'Stop'` at line 18, so it is the caller condition itself rather than a
      contrived one; a shadowing advanced `Get-ChildItem` in the script scope raises the non-terminating
      error that a real unreadable directory would, without the `icacls` edit and the per-runner privileges
      a real one needs. Five asserts: no throw, the flag is what prevented it (`-ErrorAction
      SilentlyContinue` arrives bound), and the three composed candidates survive -- the walk degrades to
      what it already returns for a family that is simply absent.
- [x] **The test was proved to catch the regression rather than merely to pass.** With the guard reverted,
      the section goes red with 5 failures (`377 pass, 5 fail`, exit 1); with it restored, `382 pass, 0 fail`.
- [x] Source held to ASCII -- the script layer's rule, and check 27 enforces it.

### DEPLOY: fix/2204-lensdircandidates-enumeration-guard

`Get-LensDirCandidates` -- the shared primitive that answers where a consumer's repo lenses may live, and
the one every discovery-seam reader walks -- enumerated `.claude/plugins/` with a bare `Get-ChildItem`. That
raises a non-terminating error on a directory it cannot read, and any caller running under
`$ErrorActionPreference = 'Stop'` has it escalated to a throw; a permission-denied entry or a broken reparse
point is enough. The walk now passes `-ErrorAction SilentlyContinue`, on the pattern `Get-SpecialistFiles`
already used one screen down, so a family directory that cannot be read contributes no candidate -- exactly
what the walk already did for a family that is simply absent. Guarded at the root rather than at each call
site, because one guard answers the risk for every caller of a shared primitive, while a call-site-wide
`try/catch` answers it for one and masks that caller's own future regressions along with it.

**Score:** 2

#### What makes this deploy extra special

The lib mirrors into three plugins -- `dkj-subagents-alpha`, `dkj-policy` and `dkj-subagents-shopify` -- so
every consumer that installs one of them gets the guarded walk at the next release. What it buys them is a
failure that has not happened yet, which is the whole of its weight: a repo whose `.claude/plugins/` holds
an entry this account cannot enumerate would, from a caller under `Stop`, have seen the roster check, the
drift lint, the policy-drift report or the teardown throw rather than degrade. Nobody has reported that, and
nothing a consumer can see changes on a healthy tree -- the walk returns the same candidates it always did.

**Score:** 1

#### Pull Request

Guard Get-LensDirCandidates' plugin-family enumeration
