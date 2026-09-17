## feat/2058-shared-sha256-hex-helper

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

Fold the hand-copied SHA256->hex idiom into one tested helper. Adopt it in gate-lib, session-cache-lib, theme-archive-rules and check-consumer-siblings. sync-rules stays out (git object id, SHA1).

#### The scope narrowed from four adopters to three, and the reason is in the tree

The intent above named `theme-archive-rules.ps1` as a fourth adopter. It is not one, and neither is
`theme-lifecycle-rules.ps1` -- the file carrying the six-character theme-name renderer #2058 leads
with. Both are registered in `Get-SharedScriptPairs` with an argued **DEPENDENCY-FREE** property, and
both registrations call it a safety property rather than a style: the live-theme guard reads
`repo-config.ps1` on every command inside a catch that returns no live theme id, so a lib in that
family which pulls anything in is a way to disarm a guard over a revenue-serving theme -- on a store
carrying about 39 themes belonging to other people. Adopting there would also need a **second**
registration of the new lib for `dkj-subagents-shopify`, since the two plugins are separately
versioned and separately installed and a cross-plugin dot-source breaks silently on a version
mismatch, which `sync-rules.ps1` rules out by name.

So the fold is three sites, one registration, one mirror. What that costs is written into the lib's
own header rather than left to be rediscovered, and filed back onto #2058.

#### What the branch found that #2058 had not

The issue filed this as a reuse note, saying explicitly that nothing observable was wrong and that the
trade was a judgement for whoever next touched one of the files. Reading the copies before folding
them settled that judgement: `check-consumer-siblings.ps1` had **already drifted**, in two ways at
once. It never disposed its SHA-256 provider -- and it creates one **per file**, inside a
`Get-ChildItem -Recurse` over every comparable path in a consumer checkout -- and it rendered
**uppercase** hex, where every other copy rendered lowercase. Neither was load-bearing, which is
precisely why it was free to drift.

### CREATE

- [x] `scripts/lib/hash-hex-lib.ps1` -- `Get-Sha256Hex`, text or bytes in, lowercase hex out, optional `-Chars` cut
- [x] Registered in `Get-SharedScriptPairs` for `dkj-policy` (LibOnly, no contract row -- nothing in it is repo-owned)
- [x] Adopted in `scripts/lib/gate-lib.ps1` (`Get-GateFingerprint`)
- [x] Adopted in `scripts/lib/session-cache-lib.ps1` (`Get-SessionCacheFileName`, the 16-character cut)
- [x] Adopted in `scripts/sync/check-consumer-siblings.ps1` (`Get-DiskInventory`) -- the drifted copy
- [~] `theme-archive-rules.ps1` and `theme-lifecycle-rules.ps1` -- dropped, see PLAN above; filed back onto #2058
- [x] Mirrors regenerated via `build-shared-scripts.ps1`, and the mirror README row added

### TEST

- [x] `scripts/tests/hash-hex-lib.tests.ps1` -- 15 asserts, digests pinned against published SHA-256 vectors rather than against the function's own output
- [x] Output equivalence measured against each pre-fold implementation over five inputs, empty string and non-ASCII included -- every digest identical, `check-consumer-siblings`' matching once lowercased
- [x] Lint gate green; full suite green (run by `open-pr`, which refuses to push on either)
- [x] `connector-sessioncheck.tests.ps1` fixture owes the new lib a copy -- caught by this branch's own run, see CREATE

### DEPLOY: feat/2058-shared-sha256-hex-helper

The SHA-256-to-lowercase-hex idiom now has one definition, `Get-Sha256Hex` in
`scripts/lib/hash-hex-lib.ps1`, and three of the five files that carried it by hand call it:
`gate-lib.ps1`, `session-cache-lib.ps1` and `check-consumer-siblings.ps1`. Text or bytes in,
lowercase hex out, with an optional `-Chars` cut for the callers that put a short hash in a name.

**The fold found the drift the issue predicted, already there.** #2058 filed this as a reuse note and
said in so many words that nothing observable was wrong. The copy in `check-consumer-siblings.ps1`
disagreed: it never disposed its SHA-256 provider -- and it creates one **per file**, inside a
`Get-ChildItem -Recurse` over every comparable path in a consumer checkout -- and it rendered
uppercase hex where every other copy rendered lowercase. Both are repaired by the adoption. The case
change is unobservable, checked rather than assumed: a run picks one scheme, those values are only
ever compared with each other, and none of them is printed, stored or carried across runs -- which is
exactly what let it drift unnoticed.

**Two of the five are deliberately left hand-written**, and that is a departure from what the issue
asked for. `theme-archive-rules.ps1` and `theme-lifecycle-rules.ps1` are registered with an argued
dependency-free property that their own registrations call a safety property: the live-theme guard
reads `repo-config.ps1` on every command inside a catch that returns no live theme id, so a lib in
that family which pulls anything in is a way to disarm a guard over a revenue-serving theme. Adopting
there would also need a second registration of the new lib for a separately versioned plugin. The
cost is that the six-character theme-name renderer stays hand-written; the reasoning is in the lib's
header and on the issue.

The fold is output-preserving, measured against each pre-fold implementation over five inputs
including the empty string and a non-ASCII one. `sync-rules.ps1` is untouched, as the issue asked:
its SHA-1 composes git's own object id, and the new function's name is the fence that keeps it out.

**Score:** 2

#### What makes this deploy extra special

N/A -- nothing a subscriber of this service can observe. This is internal tooling: one shared helper
behind three call sites whose output is byte-identical to what it replaced, so no consumer-visible
behaviour changes. The undisposed provider it repairs was a slow leak in a maintenance check that
runs in this repo, not in anything a consumer runs.

**Score:** N/A

#### Pull Request

One shared SHA-256-to-hex helper for the four sites that hand-copied it

