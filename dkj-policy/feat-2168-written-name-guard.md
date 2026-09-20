## feat/2168-written-name-guard

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

#### The defect

`Get-SpecialistFileShapes` decides, per kind, which filename spelling is **written** (`Current`) and
which are merely **read** (`AlsoRead`). The #2128 rename series moves one kind per step, and each step
has two halves that must travel together: the files on disk, and that kind's `Current` row. Nothing
paired them, and nothing could see when one half was missing.

`AlsoRead` keeps every READER resolving both spellings, so a step that renames the files and forgets
the row leaves the tree completely green -- the lint gate, all suites and CI all passed on PR #2165 --
while every WRITER goes on composing the retired name into a fresh consumer. Two of the four steps
shipped that way: the Subagent row (#2131, found at the merge) and the Lens row (#2133, found eight
days later and repaired in #2167).

**Step F closed while this branch was open**, which changes what the guard is for rather than whether
it is wanted. #2135 merged at 10:41 today and did it correctly -- the four persona files renamed and
their `Current` row flipped in one commit -- so the #2128 round is complete and every kind now agrees
with its row. That is what makes the check born green here, and it is also the last state in which the
pairing is carried by a paragraph and by whoever reads it. The next rename series gets a gate instead.

#### The shape chosen

A new check **3d** in `scripts/lint/check-plugin-integrity.ps1`, as #2168 proposed: for every kind,
enumerate its files and assert that each one is the name `Get-SpecialistFileName` would write for its
own id. The alternative the issue floated -- an assert in `check-report-lib.tests.ps1` -- was declined
for the reason the issue itself names: that suite is deliberately property-based and this assertion is
about today's answers on today's disk, which is the opposite kind.

Three decisions inside it, each one stated in the code:

- **Both halves are refused**, because they are one finding read from either side. Files moved without
  the row, and a row flipped without the files, both leave a file whose id resolves under an accepted
  spelling under a name no writer would produce.
- **A name matching NEITHER spelling is passed over.** Its id does not resolve, so checks 3b, 3c and 6
  own it under their own rules -- two findings for one file would have the reader repairing whichever
  spelling was named second.
- **The source repo only.** A consumer meets a rename through a plugin update rather than by choosing
  to, so their files sitting on the previous spelling is the dual-read layer working as designed. Here
  it is a defect, because here the table and the files land in one commit.

### CREATE

- [x] check 3d in `scripts/lint/check-plugin-integrity.ps1`, after 3c -- the three plugin kinds re-use
      the sets checks 3/3b/3c already gathered, the lens walks check 4's four candidate directories.
- [x] its entry in the `checks:list` docstring span (check 37 holds the list against the headers).
- [x] a `[COVERAGE]` line, `written-name`, so the verdict never travels without the count behind it.

### TEST

- [x] born green on the real tree: `Summary: 0 error(s)`, `[written-name] checked 87` (26 subagents,
      27 manuals, 4 personas, 30 lenses).
- [x] probed against the real tree in both directions, since a guard that has never been seen to fire
      is indistinguishable from one that cannot:
      a lens renamed to the retired spelling gives `1 of 30 Lens file(s) ... a rename that stopped half
      way`; the Persona row flipped with the files left alone gives `all 4 Persona file(s) ... the
      Current row and the files came apart`.
- [x] four scenarios in `scripts/tests/check-plugin-integrity-docs.tests.ps1`: the written spelling is
      silent and carries its count, a stray is reported with both names, a whole kind reads as the row
      coming apart and fails the gate, and a name matching neither spelling is left to 3b/3c/6.
      The scenario names come from `Get-SpecialistFileName` and never from a literal -- a typed name
      would pass on exactly the day the row and the files come apart.
- [x] `written-name` added to the entries suite's `[COVERAGE]` loop, where the fixture carries none of
      the four kinds and the category is genuinely empty.
- [x] the full gate and all suites green.

### DEPLOY: feat/2168-written-name-guard

A rename step that forgets its row flip is refused now instead of shipping green.
`Get-SpecialistFileShapes` decides, per specialist kind, which filename spelling is **written** and
which are merely **read**, and the #2128 rename series moves one kind per step -- the files on disk
and that kind's `Current` row, two halves nothing paired. `AlsoRead` keeps every reader resolving
both, so a step that moved the files and left the row behind passed the lint gate, every suite and CI
(measured on #2165) while every writer went on composing the retired name into a fresh consumer. Two
of the four steps shipped exactly that way -- the Subagent row (#2131, found at the merge) and the
Lens row (#2133, found eight days later and repaired in #2167). Step F (#2135) closed while this branch
was open, correctly pairing both halves in one commit, so the round is done and the guard is for the
next one.

Check **3d** in `check-plugin-integrity.ps1` holds each kind's `Current` row against the names
actually on disk: 87 files today, being 26 subagent defs, 27 manuals, 4 personas and 30 lenses, and
it is born green. It refuses **both** half-states, because files moved without the row and a row
flipped without the files are one finding read from either side -- and it names which it found, since
every file of a kind on the other spelling is a row that did not travel while some of them is a move
that stopped half way, and the two have different repairs. A name matching NEITHER spelling is passed
over, so checks 3b, 3c and 6 keep sole ownership of it and no file gets two owners.

It reaches this tree only, and `Get-SpecialistFileShapes`' docstring says so where it used to say the
guard did not exist yet: a consumer meets a rename through a plugin update rather than by choosing
to, so their files sitting on the previous spelling is the dual-read layer doing its job. No row may
be pruned because a gate now watches it.

**Score:** 3

#### What makes this deploy extra special

N/A -- the check lives in `scripts/lint/check-plugin-integrity.ps1`, this repo's own gate: not in the
shared-scripts registry, not carried by any plugin, and not one of the runners `adopt-dkj-policy`
scaffolds into a consumer's CI. No subscriber of this service receives it, which is also why the
`minor` label came off #2168.

**Score:** N/A

#### Pull Request

a guard holds each specialist kind's written spelling against the names on disk
