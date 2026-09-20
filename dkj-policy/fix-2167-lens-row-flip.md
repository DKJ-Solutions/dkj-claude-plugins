## fix/2167-lens-row-flip

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

#### What #2167 reported, and what verifying it added

The #2128 rename series moves each specialist file kind in its own step, and each step has two
halves: rename that kind's files, and flip that kind's row in `Get-SpecialistFileShapes` so the new
spelling becomes the one a WRITER writes. Step D (#2133, PR #2165) renamed all 30 lens files and
never flipped the row, so on `main` the Lens row still declared `<id>-extension.md` as written and
`specialist-<id>-lens.md` as merely tolerated -- the wrong way round.

Verified against the tree before touching anything, because the report's reason is an inference and
the repair follows from it. All five held:

| kind | `Current` in the table | on disk | |
|---|---|---|---|
| Manual | `specialist-...-manual` | `specialist-01-01-manual.md` | agrees |
| Subagent | `specialist-...-subagent` | `specialist-02-09-subagent.md` | agrees |
| Persona | `...-persona` | `01-01-persona.md` | agrees -- step F has not run |
| Lens | `...-extension` | `specialist-01-01-lens.md`, 30 of them, 0 on the old spelling | **inverted** |

#### Why no gate could see it, and why that is the table's own design

`AlsoRead` still carried `specialist-...-lens`, so every READER resolved both spellings and nothing
went red -- that is the property the dual-name layer exists for. The row decides only which spelling
is *preferred* and which is *written*, and the suite's assertions are deliberately property-based
("one written spelling, several read ones") rather than pinned to today's answers, so they keep
holding across a flip in either direction. Nothing in the tree compares a row's `Current` against
the names actually on disk.

#### Scope: the two degraded writer arms travel with the row, the teardown reader does not

`bootstrap.ps1` carries a guarded load of the lib and a degraded arm per composer, documented as
"the one spelling this version writes". Flipping the row without them would leave that docstring
false, so both arms move with it. `teardown.ps1`'s degraded arm is a READER glob (`*-extension.md`)
and is left exactly as it is: the issue's whole property is that no reader changes, the arm can only
ever name one spelling, and which one serves a given consumer depends on whether they have migrated.
It is also unreachable in practice -- the lib ships in the same payload as the script that loads it.

#### A third site the issue did not name, and the guard filed for it

`scripts/tests/bootstrap-drift.tests.ps1` pins the written lens name as a literal in eight places and
was the only thing in the tree that went red on the flip. Deriving those from
`Get-SpecialistFileName` was considered and DECLINED: the suite would then prove only that the
bootstrap and the table agree, which is exactly the state #2167 describes. The pin is the point, and
sweeping it each step is its cost -- so the literals move with the row and stay literals.

That makes three sites a rename step has to touch beyond the files themselves, none of them paired to
the others by anything. #2168 proposes the guard that would pair them -- a check holding each kind's
`Current` against the names actually on disk -- and is filed rather than built here, because a new
lint check is its own subject. This branch records the hazard in the docstring and cites #2168 there;
prose enforces nothing, which is what #2168 is for.

### CREATE

- [x] Flip the Lens row in `Get-SpecialistFileShapes`: `Current` takes `Prefix = 'specialist-'; Stem = 'lens'`, `AlsoRead` keeps `Prefix = ''; Stem = 'extension'` for a consumer who has not migrated
- [x] Correct the docstring sentence enumerating which rows have swapped -- it named two of four, and three have now
- [x] Record the hazard in that same docstring: the rename and the row flip are separate acts, nothing pairs them, and a missed flip is invisible to every gate. Two of four steps shipped that way (#2131, #2167)
- [x] Flip the two degraded writer arms in `bootstrap.ps1` (`Get-LensNameCandidates`, `Get-LensWriteName`) so they still state what this version writes
- [x] Copy the canonical lib to its three plugin mirrors and confirm all four are byte-identical
- [x] Move the eight pinned lens names in `scripts/tests/bootstrap-drift.tests.ps1` to the written spelling, keeping them literals -- deriving them would make the suite prove only that the bootstrap and the table agree
- [x] File #2168 for the guard that would pair a rename with its row flip, and cite it from the docstring
- [~] No reader touched -- dropped as work, kept as the property being preserved: the whole point of the table is that a flip reaches no reader

### TEST

- [x] `check-plugin-integrity.ps1`: 0 errors, measured on this branch
- [x] All `scripts/tests/*.tests.ps1` suites green, measured on this branch
- [x] `Get-SpecialistFileName -Kind Lens -Id '05-15'` returns `specialist-05-15-lens.md`, and `Get-SpecialistFileNameCandidates` returns it first
- [x] The 30 lenses on disk are all found by `Get-SpecialistFiles -Kind Lens`, under the written spelling

### DEPLOY: fix/2167-lens-row-flip

`specialists-init` scaffolds a fresh consumer's lenses under the current name again. Step D of the
#2128 rename series moved all 30 lens files to `specialist-<g>-<id>-lens.md` but never flipped the
Lens row in `Get-SpecialistFileShapes`, so every WRITER went on composing the retired
`<g>-<id>-extension.md` -- into a consumer whose own tree carries the new spelling, and which the
migration note had just told to move away from it. `Current` now holds the new spelling and
`AlsoRead` the old, so an unmigrated consumer still resolves. No reader changes, which is the
property the table exists for. The two degraded writer arms in `bootstrap.ps1` move with it, and the
docstring now records why no gate could see the omission, that two of four steps have shipped it,
and where the guard that would pair the two halves is proposed (#2168).

**Score:** 3

#### What makes this deploy extra special

N/A -- this repo's audience is its own developers and the consumers of the plugin, not a subscriber
to a service.

**Score:** N/A

#### Pull Request

the Lens row flips to the new written spelling
