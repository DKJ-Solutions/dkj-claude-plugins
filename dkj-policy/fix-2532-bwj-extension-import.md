## fix/2532-bwj-extension-import

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

#2532, filed from the #2531 branch: `adopt-dkj-policy-bwj` step 6 still asked a person to add the BWJ
extension import by hand, the gap #2531 closed for the constitution import. Verified on pickup: step 6
is prose only, and no script in `dkj-policy-bwj` writes the line.

The bwj adopter has no script of its own, so step 6 gets one, `adopt-extension-import.ps1`. The #2531
writer is extracted into a shared lib so the two adoptions cannot drift, as the issue proposes. The lib
is `claude-md-import-lib.ps1` rather than `consumer-check-lib.ps1`: that lib's `Resolve-CheckRepoRoot`
loads a sibling `repo-root-lib.ps1`, and `dkj-policy-bwj` ships its own file under that name with
different functions, so mirroring `consumer-check-lib` there would leave a function that breaks when
called. The issue's side question, whether a session check should also warn, is filed as #2538.

### CREATE

- [x] `scripts/lib/claude-md-import-lib.ps1`: the constitution pair moved out of `consumer-check-lib.ps1`,
  the extension pair, and `Add-ClaudeMdImportLine` with `-AfterPattern` placement. `consumer-check-lib`
  loads it at file scope, guarded, so existing callers still reach the constitution pair.
- [x] `adopt-workflow-folder.ps1` calls the shared writer instead of its inline copy.
- [x] `plugins/dkj-policy/dkj-policy-bwj/scripts/task/adopt-extension-import.ps1`: new, dry run by default.
- [x] Registry: `claude-md-import-lib` into dkj-policy and dkj-policy-bwj, `measure-context-lib` into
  dkj-policy-bwj. Mirrors rebuilt; row added to `plugins/dkj-policy/scripts/README.md`.
- [x] `adopt-dkj-policy-bwj` SKILL.md: step 6 runs the script, and the description names the write.
- [x] Filed #2538 for the session-check question.
- [x] Review pass: Victor found that the scan accepted an indented `@`-line as an import, a pre-existing
  looseness of the #2531 writer. Claude Code reads only a column-0 `@`, so the scan now uses
  `Get-ImportLinePath`, the rule the closure walk applies. Covered by a new test.

### TEST

- [x] `bwj-extension-import.tests.ps1` (new): no CLAUDE.md, below the constitution in a CRLF+BOM file,
  re-run unchanged, a constitution line with no terminator, no constitution yet (and a later constitution
  write landing above the extension), already imported under an older marketplace name, a nested fence,
  an indented look-alike line, the dry run, and the marketplace segment read from a bwj payload path.
  27 passed.
- [x] `adopt-workflow-folder.tests.ps1` 140 passed; `consumer-prose-gate.tests.ps1` 129 passed;
  `shared-scripts.tests.ps1` 1071 passed; `check-plugin-integrity.ps1` 0 errors.

### DEPLOY: fix/2532-bwj-extension-import

`adopt-dkj-policy-bwj` now writes the BWJ extension import into the consumer's `CLAUDE.md`. Step 6 runs
`adopt-extension-import.ps1`, which puts
`@~/.claude/plugins/marketplaces/<marketplace>/plugins/dkj-policy/dkj-policy-bwj/CLAUDE.md` directly
below the constitution import. Until now the step asked a person to add it, so a BWJ repo could run
without its four chapters in context, the same gap
[#2531](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2531) closed for the constitution.
The line keeps the file's line endings and byte-order mark, and nothing is written when it is already
imported. Both adoptions now use one writer, `Add-ClaudeMdImportLine` in `claude-md-import-lib.ps1`.

**Score:** 3

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

adopt-dkj-policy-bwj writes the BWJ extension import into CLAUDE.md instead of asking for it

