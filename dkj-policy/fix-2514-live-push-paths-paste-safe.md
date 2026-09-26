## fix/2514-live-push-paths-paste-safe

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

Verified against the tree before the repair: `Format-LivePushCommand` space-joins `--only <path>`
with no check, and `live-preflight.ps1` loads no paste-safety check at all. The issue's claim that
`prepare-release` already applies `Test-PathPasteSafe` holds only on the parked, unmerged
`feat/2509-prepare-release`, not on the trunk. That changes nothing here.

#### The accent question the issue left open

Decided for a letter class. `Test-PathPasteSafe` is ASCII only, and #821 measured an accented theme
filename in a real consumer store through `sync-main`. An ASCII-only check would refuse that store's
live push with no remedy but renaming a file the theme editor created. So the push path gets its own
pattern: the ref set plus the Latin letters U+00C0-U+017E without the multiplication and division
signs, matched case-sensitively. It stops one short of the end of Latin Extended-A, because U+017F
LONG S reads as an `f` (Sebastian's review), and past it are letters that display as `|` and `!`.

### CREATE

- [x] `Get-LivePushUnsafePaths` in `live-push-rules.ps1`, and `Format-LivePushCommand` throws on an unsafe path as the backstop for any caller
- [x] `live-preflight.ps1` refuses at step 3, so step 7's backup is skipped, names the paths through `Format-SafePathToken`, and step 8 reports the command as not composed
- [x] step 3's `push` and `held` lines print each path through `Format-SafePathToken` too, since they print before the check and whatever it decides (Sebastian's review)
- [x] both files mirrored byte-for-byte into `dkj-subagents-shopify`
- [x] the `live-preflight` skill page documents the third failure and the step-3 refusal

### TEST

- [x] `live-push-rules.tests.ps1`: the three measured shapes plus the other shell metacharacters, bidi, combining mark, Extended-B lookalike, the multiplication sign and the Kelvin sign are refused; ordinary and Latin-accented paths pass; the throw carries no path
- [x] lint + all suites green through `open-pr`

### DEPLOY: fix/2514-live-push-paths-paste-safe

The live push command `live-preflight` prints can no longer carry a theme path that runs something
when the line is pasted. Step 3 now refuses a push list holding a path outside letters (Latin accents
included), digits, `.`, `_`, `/` and `-`, and names each such path with its control characters
stripped. That happens before the backup, so a refused run costs no theme slot.
`Format-LivePushCommand` throws on such a path too, so no other caller can print one. The check is
`Get-LivePushUnsafePaths` in `live-push-rules.ps1`
([#2514](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2514)).

**Score:** 3

#### What makes this deploy extra special

A store running `live-preflight` is no longer handed a push command that could run a crafted theme
filename such as `assets/$(calc.exe).css` when somebody pastes it. That filename can arrive through a
theme-editor sync without anyone having push rights. Nothing has exploited this yet, and ordinary and
accented filenames push exactly as before.

**Score:** 1

#### Pull Request

live-preflight refuses a push list whose paths are not safe to paste

