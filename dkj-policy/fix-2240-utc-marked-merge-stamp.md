## fix/2240-utc-marked-merge-stamp

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

Verified against the tree: the Z-suffix repair is sound and less invasive than #2240 feared -- Get-EntryHeadingStamp can NORMALISE the suffix away instead of sorting it, so every comparison key stays the fixed-width 15 chars #1280's ordering walk relies on. Next: the writer emits Z, the reader accepts an optional Z and returns the bare key, tests for both forms.

#### What the six inbound checks answered

Verified before anything was written, since a report is a snapshot of the moment somebody filed it:

- **Symptom** -- stands. `Format-EntryMergeStamp` renders `yyyyMMdd-HHmmss` with nothing saying which zone.
- **Reason** -- stands, and it is narrower than #1542's subject rather than a reopening of it. The value
  was already correct; only its legibility was open.
- **Subject** -- both cited lines exist: the writer, and the reader anchored on `(\d{8}-\d{6})\s*$`.
- **Size** -- one writer, one fallback composer, one reader. Every other matcher on that heading goes
  through `Get-EntrySectionHeadingTail`, which is a deliberate tolerance and already accepts a suffix.
- **Repair** -- sound, and **less invasive than the report feared**. It flagged amending the sort key as
  the risk; the reader can strip the marker instead of passing it through, so the ordering key stays the
  fixed-width 15 characters #1280's walk relies on and no comparison changes at all.
- **Repo** -- correct. Found in a consumer, subject is source-side `dkj-policy`.

So the report's own fallback proposal -- marking the zone in the changelog's introduction instead -- was
not needed, and it was the weaker answer anyway: no introduction travels into the release records where
the same heading is copied verbatim.

### CREATE

- [x] The marker as a **named constant** in `entry-scaffold-lib.ps1`, beside the separator it sits next
      to, carrying the measurement and why the sort key survives it.
- [x] `Format-EntryMergeStamp` appends it -- **to whichever of its two values it returns**, so the
      fallback path cannot come out spelled differently from the PR path, and idempotently, so a value
      handed back in is not marked twice.
- [x] `Get-EntryHeadingStamp` accepts it as optional and **strips it from the answer**, grouped before
      the `?` so the marker stays optional as a whole rather than only its last character.
- [x] The fold's own comment says why it composes its fallback **without** the marker.
- [x] `fold-changelog/SKILL.md`'s worked example of a folded heading carries it, since that is what the
      fold now writes.
- [x] Shared-script mirrors rebuilt (`build-shared-scripts.ps1`).
- [~] No changelog-introduction note: dropped, and the reasoning is above -- the marker makes it
      redundant and it would not reach the release records.
- [~] The stale *"the `Pull Request` heading carries the stamp"* claims: **not corrected here**, filed as
      [#2242](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2242). The fold has stamped the
      entry's own heading since August 23, 2026 and ~15 places still describe the old location --
      including line 803 of the docstring this branch edits. Dropped rather than part-fixed: some of
      those sites are historical and correct, so classifying them is its own assignment, and repairing
      one would leave a single site disagreeing with fourteen.

### TEST

- [x] `entry-scaffold.tests.ps1` extended: the marker read from the lib rather than typed; both writer
      paths and the idempotent one; both spellings read back to one key; the writer's current output
      round-tripped through the reader, which is the assert that catches the reader being left behind.
- [x] Both **rollout-window** orderings pinned -- a marked stamp folded into a bare list, and a bare one
      folded into a marked list (a consumer one release behind).
- [x] The design pinned by a tie: a marked stamp equal to a bare one. `CompareOrdinal` ranks the bare
      form 90 code points first, so unstripped this assert fails -- it is not a tautology.
- [x] Lint gate + every suite green before the push.

### DEPLOY: fix/2240-utc-marked-merge-stamp

The merge stamp on a folded entry's heading now says that it is UTC: `20260921-143322Z`. The value is
unchanged -- what was wrong was never the moment but that the moment did not name its zone, so a reader
supplied their own and was wrong by their own offset. Measured in a consumer: an entry that had landed
eight minutes earlier read as two hours stale.

The marker is appended by the one function that writes the stamp, on its fallback path as well as its
main one, so a changelog cannot end up carrying both spellings for no discoverable reason. The reader
accepts it and strips it, which is what keeps `CHANGELOG.md`'s ordering untouched: every comparison key
is still the fixed-width 15 characters, so entries written on either side of this change sort together
and an equal instant in the two spellings is a tie rather than a ranking.

**Score:** 2

#### What makes this deploy extra special

A consumer reads this stamp in two places -- their own `CHANGELOG.md` while an entry is pending, and
their release records under `releases/changelog/`, where the same heading is copied verbatim and is read
long after the fold by people who were not there for it. Both now state the zone. Nothing a consumer
has already folded becomes unreadable: the bare form is still accepted for ever, and a consumer whose
fold is a release behind keeps writing it and keeps being ordered correctly.

**Score:** 2

#### Pull Request

The folded entry's merge stamp says it is UTC

