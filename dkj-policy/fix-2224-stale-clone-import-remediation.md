## fix/2224-stale-clone-import-remediation

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

check-roster-sync's dead-import finding names three causes, all of which imply the roster path is wrong, and closes with an unconditional 'Repair the path'. For a '~/'-relative import into the marketplace clone the likeliest cause is a stale clone, and following that instruction reverts a correct post-rename path.

### CREATE

- [x] Split the dead-import finding in `../scripts/sync/check-roster-sync.ps1` by import class. A
      `~/`-relative import resolves into the machine-wide marketplace clone; an in-tree one does not,
      and only the first can be repaired by a refresh.
- [x] For the clone class: lead the cause list with the stale clone, and close with
      `REFRESH FIRST -- claude plugin marketplace update <name> -- and edit the path only if that does
      not resolve it`. The marketplace name is lifted out of the path and validated with
      `Test-PluginMarketplaceSlug` before it is printed into a command the reader will paste.
- [x] Leave the in-tree class exactly as it was. There is no clone under it, so `Repair the path` is
      still the right instruction there.
- [x] Mirror to `../plugins/dkj-subagents/dkj-subagents-alpha/scripts/sync/check-roster-sync.ps1` --
      the shared-scripts drift lint holds the two byte-identical.

#### Not in this branch, and why

- [~] Dropped: the dual-line overlap that `INSTALL.md` prescribes for this migration. It cannot be
      followed in any repo running `roster-sessioncheck` -- that check errors on *every* unresolvable
      roster import, so carrying both lines is a permanent blocking session-start error by design.
      That is a real contradiction between two things this repo ships, but it is a different subject
      from this finding's wording, so it is filed separately rather than swept in here.

### TEST

- [x] `scripts/tests/roster-sync.tests.ps1` -- 394 pass, 0 fail. Six new asserts pin both branches of
      the split: the clone class leads with the refresh, names the pasteable command and makes the
      edit conditional; the in-tree class still says `Repair the path` and is never offered a refresh
      that cannot help.
- [x] Verified against the live defect rather than only the fixture. Before: `roster-sessioncheck`
      blocking, budget gate `3 document(s) measured` with the persona carried, not measured. After
      `claude plugin marketplace update dkj-claude-plugins`: `0 error(s)`, the import resolves, and
      the budget gate reads `4 document(s) measured` with the persona byte-identical to the installed
      copy.

### DEPLOY: fix/2224-stale-clone-import-remediation

`check-roster-sync`'s dead-import finding used to close with `Repair the path`, and named only causes
that imply the roster path is wrong. For a `~/`-relative import that is the wrong instruction: such a
path resolves into the machine-wide marketplace clone, which tracks the trunk and advances on
`claude plugin marketplace update` alone -- not on a release, a push or a `plugin update`. So the
likeliest cause is a stale clone, and editing the path reverts one that is already correct. Measured
here on September 20, 2026: the persona rename of #2128 had landed on the trunk while this machine's
clone sat 510 commits back, the orchestrator's body was silently absent from every session, and the
finding pointed at the one file that carries the rename. The finding now splits by import class --
the clone class leads with the refresh and makes the edit conditional on it failing, the in-tree class
is unchanged because a refresh cannot help it.

**Score:** 3

#### What makes this deploy extra special

The check ships to every consumer, and the rename it misdiagnoses is live right now: `INSTALL.md`
walks consumers through exactly this import-line migration, so a consumer whose clone has not caught
up meets this finding at session start and is told to undo the edit the guide just asked them to make.
Following it costs them the orchestrator in both directions -- the old path is dead after the refresh,
the new one before it -- with nothing reporting either state. The repair is wording only: no gate
changes, no behaviour beyond which sentence the reader acts on.

**Score:** 3

#### Pull Request

A dead marketplace import no longer tells you to edit the path when the clone is simply stale

