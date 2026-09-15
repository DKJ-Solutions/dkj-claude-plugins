## fix/2024-console-strip-zl-zp-combining

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

Widen the shared console-strip class -- Cc/Cf plus Zl/Zp (U+2028/U+2029) and stacking combining
marks (Mn/Me) -- across every call site, and stop expressing it as a regex, because on this repo's
own runtime a regex over that class is independently, silently wrong.

**The scope grew mid-branch, twice, and both times were verified against the tree rather than taken
on trust.**

1. **First verification.** #2024 said the class is carried at "at least four" call sites, the fourth
   being `Format-ForConsole` in `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`, added
   by `fix/2019-asana-mirror-console-strip` (#2019). At the time this branch was cut, #2019 was real
   but still parked -- pushed, no PR -- so that file carried no such function on `main` yet, and this
   branch's first two commits scoped to the three call sites that did: `claim-issue-lib.ps1`
   (`Format-ForConsole`), `pr-issues-lib.ps1` (`Format-AuthoredText`), `ref-print-lib.ps1`
   (`Get-DisplayRef` and `Get-DisplayPath`).
2. **Second verification.** While preparing to open the PR, `open-pr.ps1`'s already-done check
   reported #2019 had since merged (PR #2026). Rebasing onto the new `main` confirmed
   `asana-mirror.ps1` now really does carry the fourth copy, and a **second** comment had landed on
   #2024 itself (filed while repairing #2025, the sibling backlog-page fix): on Windows PowerShell
   5.1 / .NET Framework, a regex character class over `\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Mn}\p{Me}` is
   silently wrong twice -- it misses U+00AD SOFT HYPHEN (Format to the runtime, Dash Punctuation to
   the regex engine's pre-Unicode-4.0 tables) and every format character above the BMP (a surrogate
   pair, invisible to a class that matches one UTF-16 code unit). Both measured directly against this
   session's own PowerShell 5.1 runtime before trusting the report.

So the final shape is: **all four call sites**, and the mechanism is a code-point walk
(`ConvertTo-ConsoleStrippedText`, reading `[CharUnicodeInfo]::GetUnicodeCategory`) rather than a
regex, identical byte-for-byte in its executable code across `claim-issue-lib.ps1`,
`pr-issues-lib.ps1`, `ref-print-lib.ps1` and the standalone `asana-mirror.ps1` template (which cannot
dot-source the others, since it ships alone into a consumer's `.github/scripts/`).

### CREATE

- [x] Confirm empirically, on this session's own PowerShell 5.1 runtime, that Zl/Zp/Mn/Me strip correctly with a regex widening, and separately that U+00AD and a supplementary-plane format character do NOT (verifying #2024's second comment before trusting it)
- [x] Design `ConvertTo-ConsoleStrippedText`: a code-point walk over `[CharUnicodeInfo]::GetUnicodeCategory`, one space per UTF-16 unit consumed (so `Get-DisplayPath`'s column-alignment `.Length` guarantee, #1638, still holds for a surrogate pair)
- [x] Replace the regex in `scripts/lib/claim-issue-lib.ps1` (`Format-ForConsole`), `scripts/lib/pr-issues-lib.ps1` (`Format-AuthoredText`), `scripts/lib/ref-print-lib.ps1` (`Get-DisplayRef`, `Get-DisplayPath`, sharing one definition) with calls to the new function, keeping the function itself byte-identical across all three libs
- [x] Rebase onto `main` after #2019 and #2025 merged; resolve the conflicts that surfaced (both were the drift pin and docstrings needing the same "fourth copy" update #2019's own merge had already made)
- [x] Add the same `ConvertTo-ConsoleStrippedText` (hand-typed, no dot-source) to `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`'s `Format-ForConsole`, code-identical to the three libs
- [x] Sync the three libs into their byte-identical plugin mirrors (`plugins/dkj-policy/scripts/lib/*`, `plugins/dkj-subagents/dkj-subagents-shopify/scripts/lib/ref-print-lib.ps1`)
- [x] Update the two prose mentions of the old literal class in `scripts/task/adopt-ci-floor.ps1` and sync its mirror
- [x] Rewrite every test that pinned the literal regex string to instead pin the function definition/code (byte-for-byte across copies): `claim-issue.tests.ps1`, `pr-issues.tests.ps1` drift pin, `dkj-policy-bwj.tests.ps1` drift pin (code-only, since its docstring legitimately differs)
- [x] Add positive coverage at every function for Zl/Zp/Mn/Me AND for U+00AD/a supplementary-plane character: `Format-ForConsole` (both the lib and the template copy), `Format-AuthoredText`, `Get-DisplayRef`, `Get-DisplayPath`
- [x] Update the "no control/format character survives" checks that stayed regex-based (`gate-lib.tests.ps1`, `ref-print-lib.tests.ps1` x2, `worktree-lib.tests.ps1` x2, `remote-ahead-lib.tests.ps1`) to the widened category set

### TEST

- [x] `scripts\tests\claim-issue.tests.ps1` -- 227 passed, 0 failed
- [x] `scripts\tests\pr-issues.tests.ps1` -- 980 asserts passed (incl. the byte-for-byte walker drift pin)
- [x] `scripts\tests\ref-print-lib.tests.ps1` -- 461 pass, 0 fail
- [x] `scripts\tests\remote-ahead-lib.tests.ps1` -- 57 pass, 0 fail
- [x] `scripts\tests\worktree-lib.tests.ps1` -- 100 asserts passed
- [x] `scripts\tests\gate-lib.tests.ps1` -- 161 pass, 0 fail
- [x] `scripts\tests\dkj-policy-bwj.tests.ps1` -- 311 asserts passed (incl. the template's own drift pin against the three libs)
- [x] `scripts\tests\backlog-page-build.tests.ps1`, `entry-scaffold.tests.ps1`, `fold-changelog.tests.ps1`, `internal-note.tests.ps1`, `new-branch.tests.ps1`, `park-cycle.tests.ps1`, `prune-merged.tests.ps1`, `worktree-lane.tests.ps1` -- every other suite that references the changed functions, all 0 fail
- [x] `scripts\lint\check-plugin-integrity.ps1` -- the full lint gate, 0 error(s) (incl. the mirror byte-identity checks)

### DEPLOY: fix/2024-console-strip-zl-zp-combining

The shared console-strip class -- the one that keeps a title, a commit subject, a branch name or an
Asana task's own text from repainting a terminal or reading as something other than what it says --
now covers six categories instead of four, and reads them off the runtime's own Unicode table instead
of a regex.

U+2028 LINE SEPARATOR and U+2029 PARAGRAPH SEPARATOR (Zl/Zp) could make one printed line read as two,
the same harm `\n` (Cc) was already stripped to prevent; stacking combining marks (Mn/Me, "Zalgo text")
could visually obscure the text around them, the same deception the class already guarded against for
RTL overrides and zero-width runs. Both were simple additions to the class -- until a widened regex
turned out to have its own silent gaps on this repo's own runtime (Windows PowerShell 5.1 / .NET
Framework): U+00AD SOFT HYPHEN is Format to the runtime and Dash Punctuation to the regex engine's
pre-Unicode-4.0 category tables, and every format character above the BMP is invisible to a class that
matches one UTF-16 code unit, because those characters are surrogate pairs. So the class stopped being
a regex: `ConvertTo-ConsoleStrippedText` walks the text one code point at a time and reads each
category from `[CharUnicodeInfo]`, which is what `#2025`'s sibling repair to the minor-backlog page
had already measured and answered for its own, differently-scoped strip.

All four places this class is typed moved together and may not disagree: `claim-issue-lib.ps1`
(`Format-ForConsole`), `pr-issues-lib.ps1` (`Format-AuthoredText`), `ref-print-lib.ps1`
(`Get-DisplayRef` and `Get-DisplayPath`, sharing one definition), and the standalone
`dkj-policy-bwj` template `asana-mirror.ps1` (its own hand-typed copy, since it ships into a consumer
with none of this repo's libs present) -- each pinned against the others by a test that compares the
function's code rather than describing it.

**Score:** 3

#### What makes this deploy extra special

N/A. This is workflow tooling read by this repo's own sessions and the consumers that run it; nothing
a subscriber of a service takes delivery of changes here.

**Score:** N/A

#### Pull Request

Widen the shared console-strip class to Zl/Zp and stacking combining marks, and make it a code-point walk

