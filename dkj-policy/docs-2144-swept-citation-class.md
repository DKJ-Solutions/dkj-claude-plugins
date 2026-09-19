## docs/2144-swept-citation-class

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

Close the swept-verbatim-citation class #2139 opened and #2144 widened: repair the remaining
citations, settle the decision #2144 asked for on the illustrative examples, and answer whether the
check it proposed is worth building.

#### What the report got wrong, and why that changed the repair

#2144 reported the shipped `specialists-init` transcript as **half-swept** -- *"the marketplace name
`claude-code-specialists` is the old one and correct for 3.0.1, while the plugin name is from two
renames later."* `git log -L` on that line says otherwise. It was written on July 30, 2026 (`aabcc373`,
the same day as the `v3.0.1` tag) as `specialists@davekjohns-workshop`, and **four** later sweeps each
rewrote it -- `3b456abe` took the marketplace half. So both names were swept, not one, and `v3.0.1`'s
own `marketplace.json` names `davekjohns-workshop`. Repairing only the plugin half, as the report
prescribed, would have left the line quoting a pairing that never existed and carried a citation
saying it had been checked.

The same re-reading upgraded one of the items the report set aside. It listed
`measure-skill.tests.ps1:73` under *"illustrative format examples ... arguably not citations at all"*;
the file's own comment two lines above calls the block **"real output, all 19 rows"**, and `git log -L`
confirms a capture at `50348e62` reading `(team-alpha) 4.17.0`, swept twice since. It is a quotation.

### CREATE

- [x] Verify the report against the tree before repairing it -- symptom, reason, repair, size, subject
      and repo. Two of the six moved: the reason (see PLAN) and the size.
- [x] Restore and mark the shipped transcript in
      `plugins/dkj-subagents/dkj-subagents-alpha/skills/specialists-init/SKILL.md` to
      `specialists@davekjohns-workshop`.
- [x] Restore and mark the `measure-skill.tests.ps1` capture -- the header AND the `Source:` line one
      below it, which carries no version and so appears in no detector's output.
- [x] Repair `INSTALL.md`'s layout table: its single `v3.10.0`-onward row carried a spelling no release
      before `v4.33.0` ever held. Split into three measured rows, and mark the table.
- [x] Settle the illustration decision and apply it at five sites (two of them shared-script mirrors):
      an illustration is kept **true**, never frozen.
- [x] Write the convention into the portable manual
      (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/06-16-manual.md`), beside the rename-sweep
      rule it completes.
- [x] Run #2144's proposed check as a one-off and record the verdict in
      `.claude/specialists/lenses/05-15-extension.md`.
- [x] Rewrap the 157-character comment line the #2139 repair left in `check-plugin-integrity.ps1`, and
      the two ragged paragraph wraps it left in the lens.

### TEST

- [x] `scripts/lint/check-plugin-integrity.ps1` -- **0 errors**. It found one on the first run: the
      `INSTALL.md` rewrite had dropped the `v4.5.0` token check 47 reads as a fenced sample's binding.
      Restored as `v5.5.0`, which is what that anchor should always have said -- the old one named a
      version whose layout the table no longer showed.
- [x] `scripts/tests/measure-skill.tests.ps1` -- **93 pass, 0 fail**. Nothing in that suite asserts on a
      plugin or marketplace name; the assertions read the version, the totals and the row counts, which
      is why a restored fixture header is inert.
- [x] Shared-script mirrors verified byte-identical after each paired edit (`measure-skill-lib.ps1`,
      `cut-release.ps1`).
- [x] Full suite via `open-pr.ps1`.

### DEPLOY: docs/2144-swept-citation-class

The class #2139 opened is closed, and the reading that closed it is not the one the report proposed.
Three swept quotations are restored to what their releases actually shipped and **marked at the line**:
the `specialists-init` transcript in shipped payload (swept four times, marketplace name included --
`specialists@davekjohns-workshop`, not the "half-swept" pairing #2144 described), the
`measure-skill.tests.ps1` capture its own comment calls *"real output"* together with the `Source:` line
below it, and `INSTALL.md`'s layout table, whose single `v3.10.0`-onward row carried a path spelling no
release before `v4.33.0` ever held -- now three measured rows, which is the only thing a reader on an
old version can recognise themselves in.

**The decision #2144 asked for: an illustration is kept TRUE, never frozen.** A comment or a sample
showing the *shape* of a line quotes nothing, so freezing it only preserves an anachronism the reader
has to resolve. Five sites (two of them shared-script mirrors) now pair a current name with a version
that name actually had. A third form is named and deliberately left alone -- an **attribution**
(*"`dkj-policy` 4.21.0 shipped it"*) keeps today's name on purpose, because the name is how a reader
identifies the thing now while the version identifies the release. Without that third bullet the
convention reads as a mandate to sweep fourteen correct sentences.

**And #2144's proposed check was run rather than filed as an idea, and the answer is not to build it.**
*A name paired with a version older than the version that name first shipped in is always a swept
quotation* -- the detection half holds, the "always" does not. Over `*.md`, `*.ps1`, `*.json` and
`*.yml` outside the archived release history: **54 pairings, 3 of them swept quotations**, 5
illustrations, and 46 correct as written -- 32 synthetic test fixtures, where an invented version is the
point, and 14 attributions or dated notes, two of which pair a plugin name with the *Claude Code CLI's*
own version. It also missed a real quotation one line below a hit, because that line carries no version.
As a gate that is 6% precision with a known blind spot; as the one-off sweep this branch is, it was
exactly the right tool. The verdict is recorded where whoever owns check 28 will look, so the proposal
is settled rather than standing.

The portable half is in the technical writer's manual, which already carried a rename-sweep rule with
three exceptions. What it lacked is the part #2139 and #2144 measured: **the rule protects nothing on
its own**, because a find-and-replace is run by somebody who has not read it, and **shape is not
protection either** -- a quoted path survived three sweeps in one file while the same shape was swept
twice in another. The marking at the line is the whole guard.

**Score:** 3

#### What makes this deploy extra special

Three of the repaired documents are plugin payload a consumer receives at the next release --
`specialists-init/SKILL.md`, `plugin-versions/SKILL.md` and the technical writer's manual -- plus
`INSTALL.md`, which is the adoption page they read before any of it. **Nothing is asked of them and
there is no migration.** What changes is that the transcript in the adoption skill now quotes what that
CLI actually printed, so a consumer comparing their own output against it is comparing against
something real, and the layout table names the spelling their own stale `@`-import is likely to carry
instead of only today's. A consumer who has adopted the workflow also picks up the rename-sweep
convention, which matters the first time they rename anything of their own.

**Score:** 1

#### Pull Request

The swept-verbatim-citation class, closed
