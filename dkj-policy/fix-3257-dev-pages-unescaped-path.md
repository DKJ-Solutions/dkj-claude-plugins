## fix/3257-dev-pages-unescaped-path

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

Issue #3257. The reason was verified first: `'a' -match 'C:\x\dkj'` throws "insufficient hexadecimal
digits" on this machine, and under `$ErrorActionPreference = 'Continue'` the statement is skipped and the
suite still ends `0 failed`. An AST sweep compiled every constant `-match`/`-notmatch`/`-replace`/`-split`
pattern under `scripts/` and `plugins/`, and this was the only one that does not parse.

### CREATE

- [x] The copy-command assert in `scripts/tests/dev-pages.tests.ps1` reads the literal path with
  `.Contains(...)` instead of a regex.
- [x] The suite has a `trap` that counts a terminating error as a failure, the #1881 pattern, so a throw
  inside an assert goes red instead of disappearing.

### TEST

- [x] `dev-pages.tests.ps1`: 275 passed, 0 failed. It was 274 before, because the copy-command assert now
  runs.
- [x] A throwaway copy with the old throwing pattern put back: `[FAIL] unhandled terminating error`, exit 1.

### DEPLOY: fix/3257-dev-pages-unescaped-path

In `dev-pages.tests.ps1`, the assert that checks each checkout's copy command never ran. Its pattern held
a literal `C:\x\` path, `\x` starts a regex hex escape, so the `-match` threw and the suite still reported
`0 failed`. The path is now matched literally, and a terminating error anywhere in the suite counts as a
failure ([#3257](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3257)). Prevents a regression
in the Repo hub's copy command from passing the suite unseen.

**Score:** 1

#### What makes this deploy extra special

N/A: a test suite in this repo only, so nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

dev-pages.tests.ps1: escape the C:\x\ path in the copy-command assert

