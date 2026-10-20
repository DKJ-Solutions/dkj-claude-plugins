## feat/3198-general-pages-in-dkj-policy

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

The owner's decision on #3198 (October 20, 2026): the General pages (Artifacts, Issues, Release notes,
SessionStart) and the hub/dev-preview machinery they need move to `dkj-policy`, which every repo runs;
only the DKJ-Solutions card (the Brandbook) stays in `dkj-solutions`. How the pages render in a repo
without the DKJ house style was left to this branch: they keep the house style everywhere, read from the
`dkj-solutions` folder inside `dkj-policy`'s own payload, because they are the plugin's tooling, not a
repo's product. That is a visible result, so this branch is parked for the owner's eye.

### CREATE

- [x] Move the hook to `plugins/dkj-policy/hooks/`, and the servers and their libs to a plugin-only `plugins/dkj-policy/hub/` (`lib/`, `pages/`, `preview/`), with `git mv`
- [x] Split the Brandbook and the DKJ-Solutions card out of `general-pages-lib.ps1` into `dkj-solutions/scripts/lib/dkj-solutions-pages-lib.ps1`
- [x] `Test-DkjSolutionsEnabled` gates the card and `/brandbook`; `Get-HouseStyleDir` names the house style inside `dkj-policy`; the script search drops the cache walk for the plugin's own folder
- [x] Register the hook in `dkj-policy`'s `hooks.json`, drop it from `dkj-solutions`'
- [x] Repoint the source repo's hub, its house-style allowlist and the three suites; document the hub in `plugins/dkj-policy/hub/README.md`

### TEST

- [x] `dev-pages` (247), `dev-preview-sessionstart` (191) and `connector-dashboard` (168) green, with new asserts for the BWJ path (no DKJ-Solutions card, `/brandbook` a 404) and for `Test-DkjSolutionsEnabled`
- [x] `check-plugin-integrity` clean
- [x] The full gate, `open-pr -GatesOnly`, before the park

### DEPLOY: feat/3198-general-pages-in-dkj-policy

Every repo that runs `dkj-policy` now gets a Repo hub at session start, with the General pages linked
from it: Artifacts, Issues, Release notes and SessionStart. That includes the BWJ-Development repos,
which never enable `dkj-solutions`. Until now the dev-preview hook, the placeholder page and the general
pages server shipped with `dkj-solutions`, so a repo without that plugin got no Repo hub at all. They now
ship with `dkj-policy` and are documented in its
[`hub/README.md`](../plugins/dkj-policy/hub/README.md), the `Get-DevPreview` seam included. A BWJ repo
therefore starts a placeholder server on a port from 4880 to 4889 and a general pages server on one from
4890 to 4899 at every session start, unless it states a preview of its own. The pages keep the
DKJ-Solutions house style in every repo, because they are the plugin's own screens. The DKJ-Solutions card
and its Brandbook page stay in `dkj-solutions` and appear only in a repo that enables it.

**Score:** 4

#### What makes this deploy extra special

A DKJ-Solutions repo sees nothing change: the same hub, cards and pages, now served by `dkj-policy`. That
holds when both plugins are updated together, as `update-plugins` does: an older `dkj-solutions` beside
this `dkj-policy` would still carry its own copy of the hook.

**Score:** N/A
#### Pull Request

The General pages and the Repo hub machinery move to dkj-policy

