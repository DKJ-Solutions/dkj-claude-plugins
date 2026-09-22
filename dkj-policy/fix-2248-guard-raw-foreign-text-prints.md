## fix/2248-guard-raw-foreign-text-prints

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

Four value classes verified unguarded against the tree: the consumer workflow FILENAME and the required-check CONTEXT NAME in adopt-ci-floor.ps1, the Get-ShopifySyncLogPath seam answer in sync-main.ps1, and the sibling repo file paths in check-consumer-siblings.ps1. Repair each at its own site, carry the two plugin mirrors (dkj-policy adopt-ci-floor, dkj-subagents-shopify sync-main), and make registry entries 4, 8 and 13 in new-branch/SKILL.md true again -- all three currently say the value prints RAW and is not repaired on this branch.

### CREATE

- [x] `adopt-ci-floor.ps1`: guard the consumer's own workflow filename (`Get-DisplayPath`, L884 and
      L1034) and the required-check context name (`Get-DisplayRef`, L1048). In the `else` branch both
      are computed once -- `$ctxDisplay`, `$wRelDisplay` (L1058) -- and reused across the four report
      branches, rather than re-interpolated at each.
- [x] `sync-main.ps1`: guard the `Get-ShopifySyncLogPath` seam answer at all three sites
      (`Get-DisplayPath`, L550, L572, L577).
- [x] `check-consumer-siblings.ps1`: guard the sibling checkout's file paths at all four sites
      (`Format-SafePathToken`, L450, L455, L459, L471) -- chosen over `Get-DisplayPath` because these
      lines reach session context through `Write-Info`, where a square bracket can be counted as a
      hook marker.
- [x] Widen that guard to `$label`/`$f.Member`/`$f.Members` (L448, L450, L455, L471), the same
      connector-manifest `repo` field `check-connectors.ps1` already guards this way at six sites.
      `$f.Class` and the `$where` clause are this repo's own values and stay unguarded, with the
      reason stated in the code.
- [x] Carry both plugin mirrors -- `dkj-policy`'s `adopt-ci-floor.ps1` and `dkj-subagents-shopify`'s
      `sync-main.ps1` -- and confirm each byte-identical to its source again.
- [x] Make registry entries 4, 8 and 13 in
      [`../plugins/dkj-policy/skills/new-branch/SKILL.md`](../plugins/dkj-policy/skills/new-branch/SKILL.md)
      true: each said the value prints RAW and was not repaired on this branch.
- [~] `$_.Exception.Message` at `sync-main.ps1` L577 stays raw -- dropped here deliberately. It is a
      repo-wide question (34 console sites, none stripped, and the registry has no entry for the
      class), not a one-line patch inside an unrelated fix. Filed as #2271.
- [x] **#2272, found after the above by the regression pin's own fixture**: two further sites in
      `check-consumer-siblings.ps1` printed the same `$label` completely raw -- L425 (the
      `$unreadable` line) and L430 (the per-member `read` line). Both now guard `$label` via
      `Format-SafePathToken`, and `$inv.Reason` via `Format-SafeProseToken` -- a composed sentence
      that embeds foreign text only in its two `Get-GitHubInventory` arms, guarded at the print
      rather than at composition because the same value feeds a live `?ref=` API call (L263).
      Ruled in scope rather than deferred: entry 13 had already been rewritten to say this site was
      guarded, so leaving them raw would have made the registry false the day it was written.
- [x] Extend registry entry 13 for those two sites and the second guard function.

### TEST

- [x] Lint gate (`check-plugin-integrity.ps1`) clean.
- [x] Full suite gate green, bar one documented PowerShell-contention flake in
      `test-suite-gate.tests.ps1` -- unrelated to any file touched here, and green standalone.
- [x] Targeted suites green: `adopt-ci-floor`, `ref-print-lib`, `check-report-lib`,
      `sibling-divergence`, `shared-scripts` (mirror parity) and `pr-issues` (which pins *which* libs
      may carry the strip pattern -- untouched, since this branch only calls the existing functions).
- [x] Every line number cited in the three registry entries verified against the tree after the edit.
- [x] Behavioural regression pin written -- `scripts/tests/check-consumer-siblings.tests.ps1`, new,
      22 asserts, where this script had no suite-level coverage at all before (only its pure lib).
      It drives the real script with `-Source disk` over crafted manifests and asserts on the
      rendered console lines, never on the source containing a guard's name: a spelling test would
      fail on any harmless refactor and teach people to update the assert rather than think.
- [x] Three asserts added to `adopt-ci-floor.tests.ps1` for the required-check context name.
- [x] The suite's own "deliberately not covered" section re-read against the tree in full. Two of
      its four bullets had gone stale -- one describing the now-repaired L425/L430 sites, one
      describing an unreadable member as uncovered when it now is. `sync-main.ps1`'s `$rel` guard is
      named there as a live-exercise gap that remains open, rather than left silent.

### DEPLOY: fix/2248-guard-raw-foreign-text-prints

Four classes of foreign text -- characters typed by somebody outside this repo -- reached a console
unstripped. Three of the four sat on or beside a line where a neighbouring value *was* guarded, which
is what makes them misses rather than judgements: `adopt-ci-floor.ps1` printed the consumer's own
workflow filename raw next to a job id it sent through `Get-DisplayRef`, and `sync-main.ps1` printed
the `Get-ShopifySyncLogPath` seam answer raw next to a branch name it guarded on the same line. All
four are now guarded -- `Get-DisplayPath` for the paths and filenames, `Get-DisplayRef` for the
required-check context name, `Format-SafePathToken` for `check-consumer-siblings.ps1`, whose lines
reach session context through `Write-Info` where a square bracket can be counted as a hook marker.

The repair went further than the report at one site. `check-consumer-siblings.ps1`'s
`$label`/`$f.Member`/`$f.Members` are the same connector-manifest `repo` field that
`check-connectors.ps1` already guards at six sites, so they are guarded here too; `$f.Class` and the
`$where` clause are this repo's own values and are deliberately left alone, with the reason in the
code rather than in anyone's memory.

**Then the regression pin written for that repair found two more sites the repair had missed** --
`$label`, the same manifest field, printed completely raw at the `$unreadable` line and the
per-member `read` line earlier in the same file (#2272). Both are guarded here rather than deferred,
because registry entry 13 had by then been rewritten to say this site was repaired: leaving them
would have made the entry false the day it was written, which is the exact failure the entry
describes. `$inv.Reason` at those lines is guarded too, via `Format-SafeProseToken` -- it is a
composed sentence carrying foreign text only in its two `Get-GitHubInventory` arms, and it is
guarded at the print rather than at composition because the same value feeds a live `?ref=` API
call.

**This also corrects a claim the registry was making.** #2247 asserted of `adopt-ci-floor.ps1` that
"this is an accuracy defect in the registry, not an unguarded site -- nothing is exploitable today",
and that was false: two more values at the same site were unguarded, one of them on the very line the
assertion cited as proof. Registry entries 4, 8 and 13 each said their value prints RAW and was not
repaired; all three now describe the guard and the line it sits on. What each entry said about how
the *list itself* fails is kept, because that outlives the repair.

One value was deliberately not touched. `$_.Exception.Message` stays raw, here and at 33 other
console sites -- .NET composes that sentence, but it interpolates the offending path into it, so a
guarded path can come back unguarded in the second half of the same line. Whether to strip all 34, or
only where the exception's own input was foreign, or to state in the registry that the class is out
of scope, is a repo-wide decision rather than a one-line patch inside an unrelated fix. Filed as
#2271 with the measurement.

**Score:** 2

#### What makes this deploy extra special

These three scripts run in a consumer's own tree rather than in this one -- `adopt-ci-floor.ps1`
exists to read a consuming repo's `.github/workflows/` and ruleset and report what it found, and
`check-consumer-siblings.ps1` reads sibling checkouts. So every value repaired here is the reader's
own text being read back to them, and it is their console that was unguarded.

Nothing was exploited and this prevents a failure that has not happened, so the failure is worth
naming precisely: a format character in a workflow filename, or in a required-check name a
third-party integration built out of branch- or PR-derived text, makes the floor report say something
other than what it means -- an RTL override reverses a verdict line, a zero-width run welds two names
into one that reads as a legitimate third, an escape sequence repaints the terminal. These scripts
print verdicts a person acts on, which is the whole reason the guard exists everywhere else in the
workflow. Reaching the consumer needs a release; nothing they run today changes on its own.

**Score:** 1

#### Pull Request

Guard the foreign text adopt-ci-floor, sync-main and check-consumer-siblings printed raw

