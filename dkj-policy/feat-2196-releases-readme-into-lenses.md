## feat/2196-releases-readme-into-lenses

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

#### What this branch is

The third and last prose page leaves `dkj-policy/`. #2171 stopped the scaffolder writing a consumer's
folder `README.md` and `CONTRIBUTING.md`, and #2179 deleted the source repo's own two and moved every
answer into the lens of the specialist who owns it. `releases/README.md` is the page that was left
standing, and #2196 is the same movement one directory down.

#### The issue's reason is one step behind the tree, and the work changes with it

#2196 reads *"there should be only one place that explains how the release workflow works, and that's
the plugin"*. That page stopped explaining the release workflow in August 2026, when the process half
moved into `RELEASES-portable.md` -- the page says so in its own opening paragraph. What is left is
15,146 B of this repo's **answers**: the seam values in force here, the local decisions, and the
measured instances behind the portable rules.

So the case for removal is #2171's rather than the one the issue states -- a per-repo page beside a
portable page makes *"there is only one RELEASES"* false in the repo that ships the sentence -- and the
work is a **relocation**, not a deletion. Nothing on that page may be lost.

#### Where each passage lands (Dave, September 20, 2026)

Split by owner, exactly as #2179 split the folder docs across four lenses:

| Passage | Lands in |
|---|---|
| Seam values in force here, Local decisions, Measured instances | Rendall #06, `### Versioning & releases` |
| The release-notes page: `Get-ReleasePageTitle`, the worker, the path token, the `noindex` reasoning | Sylvester #15 -- it is machinery and hosting, not a release decision |

#### What is NOT in scope

`dkj-policy/releases/history.md` stays exactly where it is. It is the release **list**, a separate
document a script appends to, and the issue names only the README.

### CREATE

- [x] The scaffolder stops writing a consumer's `dkj-policy/releases/README.md` -- `$releasesReadme`
      and its file-list entry go from `scripts/task/adopt-workflow-folder.ps1` and the plugin mirror,
      and the header comment that lists what the folder contains follows
- [x] Sylvester's lens takes the release-notes page block -- the page title seam, the worker name, the
      output location, what is committed, the path token and what the lock is actually for
- [x] Rendall's lens takes the rest -- the seam values in force here, the local decisions and the
      measured instances behind the portable rules
- [x] `dkj-policy/releases/README.md` is deleted
- [x] The portable half stops telling a consumer the page exists -- `RELEASES-portable.md` (4 places),
      `plugins/dkj-policy/README.md` and the `adopt-dkj-policy` skill page (2 places)
- [x] The source repo's own references are repointed -- root `README.md` (3), Rendall's lens (3),
      Sylvester's lens table row, and `history.md`'s dated cross-reference

### TEST

- [x] `adopt-workflow-folder.tests.ps1` proves the page is NOT written, and that a consumer holding a
      legacy copy keeps it
- [x] The lint gate's dead-link scan is green -- it is what proves no link into the deleted page survived
- [x] The full suite runs, as CI does

### DEPLOY: feat/2196-releases-readme-into-lenses

The workflow folder's third and last prose page is retired, in the source repo and in every consumer
that adopts from here. `dkj-policy/releases/README.md` held this repo's answers to
`RELEASES-portable.md` — the seam values, the local decisions, the measured instances — and
`adopt-workflow-folder` scaffolded a small version of it into a consumer on every adoption. Neither
happens any more.

**The case is #2171's, not the one the issue states.** #2196 asked for the removal on the ground that
the release workflow should be explained in one place. That page stopped explaining it in August 2026,
when the process half moved into `RELEASES-portable.md`; what it still carried was 15,146 B of
*answers*. The real case is the one that retired the two pages beside it the same day: a per-repo prose
page next to a portable one makes *"there is only one RELEASES"* false in the repo that ships the
sentence, and it is a second place free to drift. So the work is a **relocation**, and nothing on that
page was dropped.

**Split by owner, as #2179 split the folder docs.** The seam values, the local decisions and the
measured instances are in [Rendall's lens](../.claude/specialists/lenses/specialist-05-06-lens.md);
the release-notes page, its Cloudflare worker, the path token and the `noindex` reasoning are hosting
machinery rather than release decisions, so they are in
[Sylvester's](../.claude/specialists/lenses/specialist-05-15-lens.md).

**What a consumer sees.** A repo adopting from here gets one file in `dkj-policy/` — its `CHANGELOG.md`
— where it used to get two. A repo that already holds any of the three retired pages keeps it: the run
reports a `[legacy]` line and touches nothing, and no delete command is printed, because a copy may
carry the only written statement of something that repo answered and nothing here can tell that from a
stale scaffold. The gates that read those names are deliberately unchanged.

`releases/history.md` keeps its name although the clash it was avoiding is gone with the page. It is
the computed default every consumer has resolved to since #885, and moving a default renames a file
under repos that never asked.

Resolves #2196.

**Score:** 3

#### What makes this deploy extra special

Four dead links in the archived release record were repointed with the prose left exactly as
published — the rule that tree runs under, and the reason the dead-link gate is what proves this change
is complete rather than a grep being.

And two asserts were **dropped rather than retargeted**: the pair guarding inbound #786, which held the
scaffolded releases page to carrying no history table. Retargeting them at the changelog would have
tested a page that never carried one. #786's precondition was a scaffolded page making a promise, and
this command now makes none.

**Score:** 2

#### Pull Request

The releases answers page leaves the workflow folder, here and in consumers
