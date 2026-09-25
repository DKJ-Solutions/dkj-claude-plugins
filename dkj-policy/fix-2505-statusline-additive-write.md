## fix/2505-statusline-additive-write

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

-Apply inserts the statusLine key into settings.json without re-serialising the rest of the file, and warns when git ignores the shim it placed.

### CREATE

- [x] Verified both reasons in the tree: `-Apply` round-tripped the file through `ConvertTo-Json`
  (line 310), and nothing asked git about the shim.
- [x] `adopt-statusline.ps1`: the key is inserted as text before the root's closing brace, in the
  file's indent unit, line ending and BOM state, and the result is parsed back before it is written.
- [x] `adopt-statusline.ps1`: `git check-ignore -v` on the shim path on every run, dry runs included,
  printing the matched rule and the `!.claude/statusline/` exception on a hit.
- [x] Found on the way and repaired: `-Apply` crashed under StrictMode on a `{}` settings file
  (`.PSObject.Properties.Name` over zero members), so the reads go through `Get-MemberNames`.
- [x] Plugin mirror synced; the `adopt-dkj-policy` skill page says what both behaviours are.

### TEST

- [x] `adopt-statusline.tests.ps1`: exact-text asserts for LF/2-space, CRLF/tab and blank-line
  files, a first member on the brace line, a kept BOM, an empty object, an ignored vs. an excepted
  shim in a real git fixture, and the unknown verdict outside a work tree:
  68/68 green (two gaps from code review closed on the branch).

### DEPLOY: fix/2505-statusline-additive-write

`adopt-statusline -Apply` now adds the `statusLine` key to `.claude/settings.json` without touching the
rest of the file ([#2505](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2505)). It used to
parse the file and write it back. Windows PowerShell 5.1 re-padded every line and dropped blank ones, so
a one-key addition became a diff of the whole file. Now the member is inserted in the file's own indent
and line ending, and a BOM is kept. The run also warns when git ignores the shim it places, for example
under a `.claude/*` rule, and names the `!.claude/statusline/` exception. Without that exception, other
checkouts got a status line pointing at a file they never received. An empty `{}` settings file no
longer crashes the run.

**Score:** 3

#### What makes this deploy extra special

N/A -- a setup command a repo's maintainer runs; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

adopt-statusline writes additively and reports an ignored shim

