## fix/stray-scratchpad-file

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

Damage this session caused, and the gate that would have caught it.

#### What happened

While shipping [#1996](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1996), a tool was
handed an absolute path to write its output to. Windows substituted **U+F03A** for the drive colon and
dropped every separator, so the whole path became **one 53 KB file in the repo root** whose name is the
flattened path. A `git add -A` swept it into a commit, and it merged to `main`.

**It was green through every gate.** The lint gate, the test gate and CI all passed, because not one
check in this tree has an opinion about what a path is *called*. That is the finding, not the file.

**And the cost is not cosmetic.** Git cannot write that name into a Windows working tree at all, so the
next `git clone` on Windows fails on checkout -- on a public repo, for every consumer.

#### Checked before repairing

The file's content is this branch's predecessor's own diff, byte for byte -- nothing secret, nothing
that is not already public in PR #1996. So this is a junk-in-the-tree repair and not a disclosure one,
and it is stated here because the two would have been handled very differently.

### CREATE

- [x] `git rm` the stray file. No other tracked path in the tree carries a private-use, Windows-reserved
      or control character -- checked before assuming it was the only one.
- [x] `Get-UncheckoutableNameClass` in `scripts/lib/check-report-lib.ps1`: the naming rule, as a pure
      function returning a class name (`private-use` / `windows-reserved` / `control`) or `''`.
- [x] Check 43 `[tracked-name]` in `scripts/lint/check-plugin-integrity.ps1`: `git ls-files -z`, then
      that predicate. Skipped silently where the tree is not a git checkout, on check 3's precedent.

#### Two decisions worth keeping

**Not a `.gitignore` job.** A pattern has to predict the mangled spelling, and not predicting it is the
entire shape of the failure. A name-shaped rule needs no prediction: it asks whether the name can exist.

**The subject is what git TRACKS, not what is on disk.** An untracked scratch file in a working copy is
what a scratchpad is for; a working-tree check would fire on every run made mid-task and be trained away
inside a week.

### TEST

- [x] `check-report-lib.tests.ps1` -- the predicate, exhaustively: the exact U+F03A shape that reached
      `main`, both ends of the private-use range and the code points just outside it, all seven
      Windows-reserved characters, a newline and a bare control character, five ordinary paths that must
      stay silent, and the documented precedence when a path fails all three. 283 -> 304 asserts.
- [x] Lint gate green, and check 43 reports `checked 717 ... 0 finding(s)` -- born green, 0 exemptions.
- [x] Full suite gate green.

#### Why the gate half is tested through the predicate and not end to end

Check 43's query is `git ls-files`, which needs a live checkout; the four `check-plugin-integrity`
suites build their fixture as a plain directory, so the check skips there by its own `.git` guard. Making
that fixture a git repo would switch on the nested-worktree probe as well and pull two libs into a copy
list shared by four suites -- a change to all of them, to reach a ten-line loop. So the rule went where a
suite can already reach it, which is the split `pr-issues-lib` makes for exactly this reason, and the
coverage line (`checked 717`) is what proves the scan runs.

### DEPLOY: fix/stray-scratchpad-file

A 53 KB scratch artefact that reached `main` under a mangled filename is removed, and the lint gate grew
check 43 `[tracked-name]` so the class cannot land again.

**The file was green through every gate**, which is the part worth recording. A tool wrote its output to
an absolute path, Windows substituted U+F03A for the drive colon and flattened the separators, and the
result was a single file in the repo root named after the whole path. The lint gate, the test gate and CI
all passed it, because nothing in this tree had an opinion about what a path is *called*. Git cannot write
such a name into a Windows working tree, so on a public repo the next Windows `git clone` fails on
checkout.

**Check 43 asks what git tracks, not what is on disk** -- an untracked scratch file is what a scratchpad is
for, and a working-tree check would fire on every run made mid-task and be trained away. Three classes: a
Unicode private-use character (the one that bit), a Windows-reserved character, and a control character.
Born green over all 717 tracked paths with no exemptions. It is deliberately not a `.gitignore` pattern:
that would have to predict the mangled spelling, and not predicting it is the whole shape of the failure.

**The rule is a pure function in `check-report-lib.ps1`**, so the half that can be asserted is asserted --
including the exact U+F03A code point, both ends of the private-use range, and the two code points just
outside it. The pattern is composed from `[char]` code points rather than typed, because a private-use
character in a BOM-less `.ps1` decodes through the system ANSI code page and silently matches nothing.

**Score:** 3

#### What makes this deploy extra special

Anyone cloning this public repository on Windows after that commit would have hit a checkout failure on a
file nobody meant to publish. That is repaired for every clone made from here on; the name stays in
history, which no gate can reach, and check 43 says so rather than implying otherwise.

**Score:** 3

#### Pull Request

Remove a scratchpad artefact that a mangled absolute path put in the repo root, and gate the class
