## feat/2219-stale-clone-headline

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

#### What #2219 reported, and what the tree actually said

The report attributes all 35 lines to ONE stale marketplace clone, and it is right that one cause
explains the wall -- but not that cause. Measured on this checkout, September 20, 2026, with the clone
already sitting at `main`'s tip (`2e13c8d8`):

| run | errors |
|---|---|
| the payload a session actually loads (`~/.claude/plugins/cache/.../dkj-subagents-alpha/5.5.0`) | 34 |
| this repo's own copy on `main` | 0 |

So the clone is current, the `@`-import resolves, and 34 lines remain. The cause is the **plugin
payload**, which a `claude plugin marketplace update` does not touch -- the second of the two channels
`CLAUDE.md` names. The report's own repair -- gate on the import failing AND the clone's HEAD differing
-- would therefore have fired on neither condition today, and shipped a guard that cannot fire.

The 34 split in two, and only one half is still open:

- **30 `no repo-lens` lines.** The payload predates #2135's lens rename, and the dual-read layer
  (`Get-SpecialistFileShapes`) holds the written spelling plus the PREVIOUS one -- it cannot look
  forward. This is the half this branch repairs, and it recurs at every future rename for every session
  that lags one release.
- **4 `no roster row` lines.** Already repaired: #2130 replaced the token boundary `(?<![\d-])` with
  `(?<!\d)(?<!\d-)`, so a roster naming a persona only through `specialist-<g>-<id>-lens.md` matches
  again. Verified above -- they are gone from the current copy's 0.

### CREATE

- [x] `Get-UnknownLensNameById` in `scripts/sync/check-roster-sync.ps1`: markdown files in the lens
      candidate directories that this check does not recognise as a lens, mapped to the specialist id
      their name carries, matched with the shared `Get-RosterIdTokenPattern`.
- [x] Per-id holding in the specialist loop: a missing-lens finding whose id IS named by such a file is
      held instead of printed. Bound to `-not $hasLens`, so a resolved lens is never evidence.
- [x] One non-counting `[LENS-NAMING]` roll-up naming the count, one example file, that nothing in the
      repo needs changing, and the remedy (refresh the marketplace, then update the plugins).
- [x] `roster-sessioncheck.ps1`: pick the marker up, ride it along in the drift branch, and give it its
      own verdict between the setup states and the in-sync line.
- [~] A roster-row arm on the same evidence -- dropped. The coupling is historical rather than
      structural (`Test-InRoster` owes nothing to `Get-SpecialistFileShapes`), that half is already
      repaired by #2130, and with the current pattern the arm could never fire. Unreachable suppression
      is the one shape a suppressor must not have. Recorded in the code where a later reader will meet it.
- [x] Mirror `plugins/dkj-subagents/dkj-subagents-alpha/scripts/sync/check-roster-sync.ps1`
      byte-identical.

### TEST

- [x] `scripts/tests/roster-sync.tests.ps1`: fixture parameter `-UnknownNamingLensIds` (a hypothetical
      NEXT generation, since both current spellings are recognised by construction) plus scenarios
      11r-11v -- the marker fires and is non-counting; a specialist with no file of any spelling still
      errors; a mixed migration holds only the unreadable half; a `README.md` in the lens directory is
      not evidence; an unbootstrapped repo still gets `[BOOTSTRAP]`.
- [x] Hook scenarios H13/H13b/H13c: its own verdict, riding along with a real finding, and absent on a
      readable repo.
- [x] `check-plugin-integrity.ps1`: 0 errors. `roster-sync.tests.ps1`: 382 pass, 0 fail.
      `sync-roster` and `shared-scripts` suites green.

### DEPLOY: feat/2219-stale-clone-headline

`check-roster-sync` no longer reports a whole repo's worth of specialists as lens-less when the
difference is that its own payload cannot read the lens filenames. A missing-lens finding whose id is
named by a markdown file in the lens directory that this check does not recognise is held, and the run
prints one non-counting `[LENS-NAMING]` line instead: the count, one example file, that nothing in the
repo needs changing, and the remedy, which is a plugin update. The evidence is per id, so a specialist
that is genuinely lens-less keeps erroring exactly as before.

Measured here the same day: 34 error lines out of a v5.5.0 payload against a tree on the #2135 lens
naming, 30 of which prescribed creating a file that was already sitting there under another name -- 30
wrong repairs, each one carrying a citation. The readers resolve two spellings and never three, by
design, so they cannot look forward; and a session loads the last RELEASED payload. That combination
reproduces at every rename, for every session that lags one release, which is what makes this a guard
rather than a one-off.

**Score:** 3

#### What makes this deploy extra special

A consumer meets this the same way, and worse: they cannot read the source to work out what happened.
It only bites while they lag a release AND the lens naming has moved, so it is rare -- but when it does,
the current output tells them to create one file per specialist, and following it leaves a second,
obsolete generation in their repo that nothing then cleans up.

**Score:** 2

#### Pull Request

A lens naming this check cannot read is reported once, instead of one wrong repair per specialist
