## fix/2025-backlog-page-invisible-strip

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

Verified on the trunk: ConvertTo-BacklogHtmlText escapes only the three markup metacharacters, and the driver never prints the Asana text to a console -- so this is purely the HTML path. Next: settle the HTML-narrow strip class in backlog-page-rules.ps1 and assert it in scripts/tests/backlog-page-build.tests.ps1.

### CREATE

- [x] Settle the design question #2025 left open: an ALLOWLIST over Cc/Cf rather than a list of the
      deceptive characters, so a format character assigned in a future Unicode version is stripped on
      the day it exists. Eight code points stay -- tab/CR/LF, ZWNJ, ZWJ, and the three bidi MARKS.
- [x] `ConvertTo-BacklogVisibleText` in `backlog-page-rules.ps1`, called from
      `ConvertTo-BacklogHtmlText` -- the one chokepoint the title, every notes block and the repo
      label already pass through, so the policy sits in one place rather than three.
- [x] `dir="auto"` on the `<h2>` and every `<p>` carrying Asana text. This is the half that makes
      KEEPING the bidi marks worth anything: it resolves each field's direction from its own first
      strong character and isolates it from the entry beside it.
- [~] Reuse `Format-ForConsole`. Dropped, as #2025 itself proposed dropping it, and the reason held on
      reading it: it spaces out EVERY Cc and Cf, which its own docstring accepts as the price of a
      console line that cannot be told a direction. An HTML element can be told one, so flattening
      here would destroy text this page renders correctly, against a spoof the strip has removed.
- [~] Type the `[\p{Cc}\p{Cf}]` class the three console libs type. Dropped on a MEASUREMENT rather than
      on taste -- see TEST. The category is read from `[CharUnicodeInfo]` instead.

### TEST

- [x] 60 asserts green in `scripts/tests/backlog-page-build.tests.ps1` (was 39).
- [x] Measured the two silent gaps in `[\p{Cc}\p{Cf}]` under Windows PowerShell 5.1, and pinned both in
      the suite rather than only this repair's answer to them:
      **(1)** U+00AD SOFT HYPHEN is Cf in the runtime's table and `Pd` to the REGEX engine, whose
      category tables predate Unicode 4.0 -- the only such divergence in the BMP, all 65,536 compared
      one by one. **(2)** every format character above the BMP is invisible to `\p{Cf}` outright,
      because a .NET character class matches one UTF-16 unit and those are surrogate pairs -- that is
      the U+E0020..U+E007F TAG block, the invisible-text channel, plus U+E0001, U+1D173..U+1D17A and
      U+110BD/U+110CD.
- [x] Four pre-existing asserts pinned the exact `<h2>`/`<p>` markup and moved with it. A fifth,
      `$noNotes -notmatch '<p>'`, would have passed TRIVIALLY afterwards -- nothing writes a bare `<p>`
      any more -- so it was tightened to `'<p'` rather than left reading as a green test of nothing.
- [x] Full lint gate + all suites.

#### What the measurement found outside this diff

- [x] The two gaps are not confined to this file: the three libs that type that class for the CONSOLE
      carry both. Outside this branch's subject and diff, so filed rather than swept -- see the issue
      number in the PR body.

### DEPLOY: fix/2025-backlog-page-invisible-strip

The minor-backlog page dkj-policy-bwj builds now removes the invisible and direction-overriding
characters an Asana task can carry into it, instead of escaping only `&`, `<` and `>`. That page renders
a task's Name and Notes -- free text written by anybody with board access -- for a colleague with no
GitHub login and no second copy to check it against, so a U+202E override, an unterminated isolate, a
zero-width run or a plane-14 tag sequence could make the printed text read as something other than what
it says. Escaping markup never touched that class.

It is an ALLOWLIST rather than a list of the deceptive characters: everything in Cc/Cf goes except eight
code points, so one assigned in a future Unicode version is stripped on the day it exists rather than on
the day somebody remembers it. The eight that stay are what this page's own content needs -- tab, CR and
LF, the two joiners that shape Persian and Indic words and every joined emoji, and the three bidi
**marks**, which nudge one neutral character and cannot open a scope. Every element carrying task text
now also carries `dir="auto"`, which resolves its direction from its own first strong character and
isolates it from the entry beside it; that is what makes keeping those marks worth anything, and it is
why this does not reuse `Format-ForConsole`, whose flattening is the right answer only for a console
line that cannot be told a direction.

The strip reads each code point's category from `[CharUnicodeInfo]` rather than typing the
`[\p{Cc}\p{Cf}]` class the three console libs type, because on Windows PowerShell 5.1 that class is
silently wrong twice -- it misses U+00AD, whose category the regex engine's pre-Unicode-4.0 tables still
give as `Pd`, and it misses every format character above the BMP, including the U+E0020..U+E007F tag
block, because a character class matches one UTF-16 unit and those are surrogate pairs. The suite pins
both gaps themselves, not only this repair's answer to them.

**Score:** 3

#### What makes this deploy extra special

N/A. dkj-policy-bwj is tooling for the two BWJ store repos, and nothing a subscriber of a service takes
delivery of changes here. The reader this page is written for is a colleague inside the business, which
is the tier-0 audience one hop before the tier-2 one.

**Score:** N/A

#### Pull Request

The backlog page strips the invisible characters an Asana task can carry into it

