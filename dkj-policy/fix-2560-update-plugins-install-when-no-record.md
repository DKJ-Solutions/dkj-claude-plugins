## fix/2560-update-plugins-install-when-no-record

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

Inbound #2560, verified on pickup: `Get-PluginUpdateScope` answers `Source = 'default'` with an empty
Note when nothing names this checkout, and step 2 then ran `update --scope project` regardless. The
reporter measured the CLI moving another checkout's project record on that call. The repair is the
reporter's first option, `install --scope project`, which `plugin-versions.ps1` already prescribes
for the same state.

### CREATE

- [x] `update-plugins.ps1`: a per-target `Verb`, `install` for `default` with no Note, `update`
      otherwise; exec, `-DryRun` and the summary all read it. Plugin mirror synced.
- [x] `update-plugins` SKILL.md: a paragraph in the scope section.

### TEST

- [x] `update-plugins.tests.ps1`: scenarios 1-7 now carry a record for this checkout (they had none,
      which is the #2560 state); new 14 (no record here, another checkout holds one) and 15 (dry run).
      82 pass, 0 fail standalone.

### DEPLOY: fix/2560-update-plugins-install-when-no-record

Inside this repo: `update-plugins.ps1` step 2 no longer hands `claude plugin update --scope project`
to a plugin with no install record for this checkout. It runs `claude plugin install <id> --scope
project` instead, which is the command `plugin-versions.ps1` already prescribes for that state, and the
summary counts it as installed. The test suite's older scenarios gained a record for this checkout,
since they were written against the state this fixes.

**Score:** 2

#### What makes this deploy extra special

For whoever runs `update-plugins` in a checkout where the plugins are enabled but were never installed
there: the run used to move **another checkout's** install record and then report success. It now
installs into the checkout it was run from, so the receipt at the end agrees with the summary above it.

**Score:** 3

#### Pull Request

update-plugins installs where this checkout has no install record, instead of updating another checkout's

