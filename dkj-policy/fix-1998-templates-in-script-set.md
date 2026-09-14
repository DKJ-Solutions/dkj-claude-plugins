## fix/1998-templates-in-script-set

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

One tracked `.ps1` -- `asana-mirror.ps1`, 1812 lines, scaffolded into a consumer's CI with `issues: write`
-- sits in none of `Get-PsScriptFiles`' three plugin subtrees. Measure checks 5, 27, 33, 36 and 42b against
it BEFORE widening the set.

#### The reported gap was verified exactly, and it is exactly one file

`git ls-files '*.ps1'` under `scripts/` and `plugins/`, outside any `tests/` folder: **203**. The gate's
`[exec-policy/script]` coverage line reported **202**. Grouping every tracked `.ps1` under `plugins/` by
its first subtree gives `skills`, `scripts`, `hooks` and `templates` -- and `templates` holds one file,
`plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1`, which is the whole of the difference. #1998's
count and its cause both hold.

#### The measurement the issue asked for, taken before the change rather than after

The issue's own caution is that the set is shared, so widening it starts five checks reading 1812 new lines
at once and the right order is to measure each first. Done, on the file itself and then on the gate:

| check | before | after | findings |
|---|---|---|---|
| 5 `[parse]` | 312 | 313 | 0 |
| 27 `[script-ascii]` | 312 | 313 | 0 |
| 33 `[shopify-cli]` | 312 | 313 | 0 |
| 36 `[section-number]` | 159 headers / 23 files | 159 / 23 | 0 |
| 42b `[exec-policy/script]` | 78 invocations / **202** files | 78 / **203** | 0 |

Gate `Summary: 0 error(s)` both times. Check 36 is the one row that does not move, and that is an answer
rather than a miss: the file carries **zero** column-0 `# --- ` markers, so check 36's subject set inside it
is empty. This was the cheapest moment the repair will ever have, exactly as #1998 predicted.

#### The second question the issue raised, decided on a measurement rather than on taste

"Three named subtrees" or "everything under a plugin root except what is deliberately excluded". Today the
two forms select the **identical** set -- every tracked `.ps1` under `plugins/` is in one of those four
directories -- so the choice costs nothing now and is entirely about the next subtree somebody adds. The
named list is silent about it and fails open; it had already failed open twice. Inverted, with the cost
stated at the code: the walk is the filesystem's rather than git's, so an untracked `.ps1` anywhere under
`plugins/` now enters the set where before it had to land in one of three directories.

### CREATE

- [x] `Get-PsScriptFiles` in `scripts/lint/check-plugin-integrity.ps1` anchored on the plugin root itself
      instead of a list of three subtree names, with the measurement and the cost recorded at the line
- [x] the repo-wide `skills/` clause deliberately left beside it -- it also catches `.claude/skills/**`,
      which is outside `plugins/` entirely

### TEST

- [x] three scenarios (80, 81, 82) added to `scripts/tests/check-plugin-integrity-commands.tests.ps1`,
      pinning the PROPERTY rather than a count: put a defect in a plugin's `templates/` and the gate finds
      it. A coverage number would pin one tree's arithmetic and go stale on the next file added
- [x] two checks asserted, not one -- check 5 parses each file itself while check 33 reads the shared
      CommandAst cache over the same set, so a set change feeding one and not the other would pass a single
      assert
- [x] scenario 80 needs `-Full`: `$SkippedForSpeed` names `parse`, so the ordinary fixture invocation
      cannot see check 5. Written without it first and it failed alone -- left recorded at the call
- [x] **discrimination proven**: with `Get-PsScriptFiles` stashed back to the three-subtree anchor, 3 of
      the 5 new asserts go red. The two that stay green are the no-false-positive guards, which is correct
- [x] `check-plugin-integrity-commands.tests.ps1` green; full lint + test gate via `open-pr.ps1`

### DEPLOY: fix/1998-templates-in-script-set

`Get-PsScriptFiles` -- the file set five script-layer checks share -- took three named subtrees inside
`plugins/`: `skills/`, `scripts/` and `hooks/`. One tracked file sat in none of them, and it is not an inert
template: `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1` is copied by `adopt-dkj-policy-bwj`
into a BWJ store repo as `.github/scripts/asana-mirror.ps1`, where it runs in that consumer's CI holding
`issues: write`. So 1812 lines this repo scaffolds into somebody else's automation had never been parsed,
held to the ASCII rule, checked for a bare Shopify call, or read for a printed command missing its execution
policy -- and a parse error in it reaches them rather than us, which is check 5's own argument for existing,
one directory over from where it was looking.

**The anchor is inverted rather than extended by a fourth name, and the choice was measured.** Today both
forms select the identical set, so the whole difference is the next subtree somebody adds: a named list is
silent about it, and this one had already failed open twice. The cost is stated at the code rather than
discovered later -- the walk is the filesystem's, not git's, so an untracked `.ps1` anywhere under
`plugins/` now enters the set where before it had to land in one of three directories.

**Born green, which was the point of measuring first.** All five checks pass over the newly-read file:
`[exec-policy/script]` coverage moves 202 -> 203 and `[parse]`, `[script-ascii]` and `[shopify-cli]` move
312 -> 313, with `Summary: 0 error(s)` before and after. `[section-number]` is unchanged at 159, because
the file carries no column-0 `# --- ` markers at all -- an empty subject set rather than a miss.

**Score:** 3

#### What makes this deploy extra special

The three new scenarios pin the property and not the arithmetic: put a defect in a plugin's `templates/`
and the gate must find it, whatever the file count happens to be that week. And they were proved to
discriminate rather than assumed to -- with the old anchor stashed back in place, three of the five asserts
go red, and the two that stay green are the ones guarding against a repair that widens the set by accusing
whatever it newly reads.

**Score:** 2

#### Pull Request

Bring plugins/**/templates/** into Get-PsScriptFiles, so the script-layer checks read what this repo scaffolds into a consumer's CI
