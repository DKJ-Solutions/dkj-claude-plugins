## feat/1925-plugin-own-lib-gate

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

#### What #1925 asked for, and the one thing it named wrongly

The issue cites the neighbouring check as "Check 35 (`[mirror-depth]`)". The tag is right and the
number is not -- 35 is the fixture-git check and `[mirror-depth]` is 39. The symptom, the reasoning
and the proposed shape all stand; only the citation was stale, so nothing in the repair changes with
it. Verified against the header list before building, per the inbound rule.

### CREATE

- [x] `Get-ScriptRootRelativeLoads` + `Resolve-ScriptRootRelativePath` + `Get-AssignmentTargetName`
      in `scripts/lib/shared-scripts-lib.ps1`, beside `Get-DepthSensitiveResolutions`
- [x] check 40 in `scripts/lint/check-plugin-integrity.ps1`, with its `.DESCRIPTION` entry

### TEST

- [x] six scenarios in `scripts/tests/check-plugin-integrity-docs.tests.ps1`, beside check 39's
- [x] probed, not only measured: the measured instance replanted in a shopify mirror, and an escaping
      path pointed at a file that really exists in this tree

### DEPLOY: feat/1925-plugin-own-lib-gate

The lint gate now proves that a script a plugin SHIPS can actually load the libs it names -- closes
#1925. Check 8 holds a registered mirror byte-identical to its source and check 39 holds a
depth-crossing `$PSScriptRoot` resolution to a declared suite; between them sat the class where the
text is right, the folder is right, and the file is simply not there. A lib registered for two
plugins and dot-sourced by a script that mirrors into a third resolves inside that third plugin and
finds nothing -- check 8 has no entry to compare against, and check 39's subject is a two-hop ascent
while `..\lib\` is one hop. Measured on the `fix/1917-judge-repo-root-resolution` branch:
`adopt-shopify-floor.ps1`, `archive-theme.ps1`, `push-preview.ps1` and `sync-main.ps1` each gained
`. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')`, that lib was registered for `dkj-policy`
and `dkj-subagents-alpha`, and all four mirror into `dkj-subagents-shopify`, which ships no such file. Four
scripts dead ON LOAD in a consumer, at their first statement, and this gate reported `0 error(s)`.

Two arms, because they fail differently and only one of them is visible from here. The file must
EXIST, and the path must stay INSIDE the plugin root -- an escaping path resolves in this tree,
which holds every path a plugin script could climb to, and is gone in the installed copy where the
`plugins/` level, the family level and every sibling plugin are stripped away. That is check 30's
lesson one layer over, and existence alone is structurally blind to it. The second arm was found by
probing rather than by measuring, which is check 35's own rule applied to its neighbour.

A load GUARDED by `Test-Path` is counted and not judged: that is the author declaring the absence
expected, and this tree means it -- `release-lib`'s `branch-info` sibling is repo-owned and travels
in no mirror. 70 of the 224 references are guarded, so judging them would have arrived needing an
exemption list on day one, the shape this repo declined at 124. Only `$PSScriptRoot` is a subject,
bound through the AST: a `$repoRoot`-relative path names a file in the consumer's own root by design,
and reading those as plugin-relative reports 14 findings here, all 14 false and all 14 that same
seam. Born green at 154 unguarded loads across 104 plugin scripts, 0 findings -- and born green by
one hour, since it had four an hour earlier.
**Score:** 3

#### What makes this deploy extra special

A subscriber notices nothing on the day, and that is the point: the gate runs here, on the repo that
SHIPS the plugins, and what it buys them is that a script which would die at its first statement in
their install can no longer reach a release. The failure it prevents is not hypothetical -- it was
sitting on a branch when this was written, four scripts deep, with every existing gate green over it.
Nothing to migrate, nothing to run, no new refusal in any consumer-side script.
**Score:** 2

#### Pull Request

A plugin script may only dot-source a lib its own plugin ships

