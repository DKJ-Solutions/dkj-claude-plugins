## fix/1986-scope-from-install-record

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

Two issues filed on September 14, 2026 out of one measured `update-plugins` run, both in the pair of
scripts that keep a checkout's plugins current. They are one subject rather than two: the step-3
receipt PRINTS what step 2 executes, so repairing only the executor would have made one run contradict
itself.

#### #1986 -- the scope was a constant where it is a fact

`update-plugins.ps1` built its target set from the checkout's effective enabled set and then handed
every one of them `--scope project`. The CLI refuses a scope a plugin is not installed at, so a
machine-wide plugin was given the one command that could have moved it, and the run exited 1 on a
machine where nothing was wrong.

**Verified before routing, and the verification changed the size.** The symptom stands as a fact about
the code (`scripts/task/update-plugins.ps1:172`), but the *machine state* it was measured on is gone --
no `shopify-ai-toolkit` record on this checkout any more -- so the repair is read rather than
reproduced. What the reading added is that `plugin-versions.ps1` carries the same hardcode in **seven**
of its own prescriptions, all reachable, so this is the class and not the instance.

#### #1987 -- one remediation for two different failures

`plugin-versions.ps1` distinguished *the plugin is absent from a manifest that parsed* from *the
manifest could not be read at all*, and then gave both the same advice: refresh the clone. For the
second that can be advice which provably cannot work, and the measured case is exactly that -- the
refresh had already run and succeeded seconds earlier, in step 1 of the same run.

**The reason was verified too, in this tree:** the official marketplace clone's `marketplace.json` does
carry both `".c"` and `".C"` (an `lspServers` extension map), and Windows PowerShell 5.1's
`ConvertFrom-Json` folds object keys case-insensitively. The file is valid JSON; no number of refreshes
changes what 5.1 can represent.

#### Scope of this branch, and what is deliberately left

The issue names a second, larger repair -- making the reader survive case-colliding keys -- and says it
is worth its own issue if taken up. It is not done here: `-AsHashtable` does not exist in 5.1, so it
means a case-sensitive reader or a targeted pre-parse, across `plugin-tree-lib`'s whole JSON path. Filed
rather than swept.

### CREATE

- [x] `Get-PluginUpdateScope` + `Get-PluginScopeNames` in `scripts/lib/check-report-lib.ps1`, beside the
      two predicates that already read the same records -- one reader, so the executor and the printed
      prescriptions cannot answer the question differently.
- [x] `update-plugins.ps1`: reads the install administration once, resolves a scope per target, and
      prints a named block above step 1 wherever the administration could not answer.
- [x] `plugin-versions.ps1`: every `claude plugin update` prescription built from the resolved scope;
      the two `claude plugin install` lines deliberately left at `--scope project`.
- [x] `plugin-versions.ps1`: the `-not $cloneHasPlugin` branch split by failure mode, and the
      parse-failure half split again on the duplicated-key shape.
- [x] Both skill pages follow the behaviour: a new **The scope is read, not assumed** section in
      `update-plugins`, and the two paragraphs under the verdict table in `plugin-versions`.
- [x] Shared mirrors rebuilt (`scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] `check-report-lib.tests.ps1` -- the whole decision table for `Get-PluginUpdateScope`, paired
      against the `Get-RecordShape` fixtures directly above it: the shapes that predicate calls unusual
      are exactly the shapes the old command was wrong for. 248 -> 283 asserts.
- [x] `update-plugins.tests.ps1` -- scenarios 9, 10 and 11: a machine-wide and a project record in ONE
      run, `-DryRun` printing the same per-plugin scope, and the fallback stating its reason above step
      1. 38 -> 51 asserts.
- [x] `plugin-versions.tests.ps1` -- scenarios 32, 32b, 33 and 34: the scope on a `behind` row, the
      install carve-out, the split, and the measured duplicated-key shape. 183 -> 200 asserts.
- [x] Lint gate green (`check-plugin-integrity.ps1`, 0 errors) -- including check 11, which refused the
      first draft of the new skill section and named its own convention for eliding a quoted target.
- [x] Full suite gate green: all 105 suites passed in 208s.

#### One thing the suites found that the code did not

`[Parameter(Mandatory = $true)]$InstallRecord` refuses `$null` before the body runs, so the
`if ($null -eq $InstallRecord)` guard the two sibling predicates open with is unreachable and their
documented answer for that input is a promise the signature breaks. The new function carries
`[AllowNull()]` so its own guard is real; the two siblings are a finding of their own and are filed, not
swept into this branch.

### DEPLOY: fix/1986-scope-from-install-record

`update-plugins` and `plugin-versions` now read the `--scope` for every `claude plugin update` off the
install administration instead of assuming `project`, and a marketplace clone whose `marketplace.json`
will not parse no longer prescribes the refresh that provably cannot repair it
([#1986](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1986),
[#1987](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1987)).

**The CLI refuses a scope a plugin is not installed at**, so the hardcoded `project` meant a
machine-wide plugin was handed the one command that could have moved it -- never updated, and the run
exited 1 on a machine where nothing was wrong. It is not only the machine-wide case: a session start
rewrites install records with no command run, flipping a `project` record to `local` and sometimes
dropping the path off one entirely, and `project` is wrong in both of those too.

**The repair went further than the report asked, because the receipt prints what the executor runs.**
`plugin-versions.ps1` carried the same hardcode in seven of its own prescriptions, so fixing only
`update-plugins.ps1` would have left one run contradicting itself in step 3. One reader --
`Get-PluginUpdateScope`, beside the two predicates already reading those records -- now answers it for
both. It returns one of the CLI's own four scope names rather than the file's string, so no byte of
`installed_plugins.json` reaches a command line; where the administration cannot answer, the run falls
back to `project` exactly as before and **says that it did**.

**The two `claude plugin install` lines are deliberately untouched.** Those prescribe installing *into
this checkout*, which is what `project` means and what the reader is being told to do -- they are not
asking where the plugin already lives.

**Score:** 3

#### What makes this deploy extra special

Both scripts are plugin-carried, so a consumer running `update-plugins` on a machine where a plugin is
installed machine-wide previously watched that plugin stay behind release after release while the run
ended in red -- and the same consumer's `plugin-versions` handed them a repair command the CLI would
refuse. Both now work at the scope the machine is actually in, and the one state the tool cannot read is
reported rather than papered over.

The `#1987` half is smaller but is the one that wastes a reader's time in a loop: a clone whose manifest
Windows PowerShell 5.1 cannot represent was told to refresh, forever. It now names the manifest, and for
the one shape whose cause is known it rules the refresh out by name and says whose fault it is.

**Score:** 3

#### Pull Request

update-plugins and plugin-versions take --scope from the install record, and a clone that will not parse no longer prescribes a refresh
