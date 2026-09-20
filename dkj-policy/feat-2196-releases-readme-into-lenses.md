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
- [ ] Sylvester's lens takes the release-notes page block -- the page title seam, the worker name, the
      output location, what is committed, the path token and what the lock is actually for
- [ ] Rendall's lens takes the rest -- the seam values in force here, the local decisions and the
      measured instances behind the portable rules
- [ ] `dkj-policy/releases/README.md` is deleted
- [ ] The portable half stops telling a consumer the page exists -- `RELEASES-portable.md` (4 places),
      `plugins/dkj-policy/README.md` and the `adopt-dkj-policy` skill page (2 places)
- [ ] The source repo's own references are repointed -- root `README.md` (3), Rendall's lens (3),
      Sylvester's lens table row, and `history.md`'s dated cross-reference

### TEST

- [ ] `adopt-workflow-folder.tests.ps1` proves the page is NOT written, and that a consumer holding a
      legacy copy keeps it
- [ ] The lint gate's dead-link scan is green -- it is what proves no link into the deleted page survived
- [ ] The full suite runs, as CI does

### DEPLOY: feat/2196-releases-readme-into-lenses

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

The releases answers page leaves the workflow folder, here and in consumers

