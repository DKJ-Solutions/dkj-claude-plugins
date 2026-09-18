## fix/2109-tracked-name-code-page

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

Hold the wire to ASCII (core.quotePath=true) and decode it here, so the tracked-name check fires on the machine where the name is created rather than only in CI.

#### What was measured first, before anything was changed

On this checkout (cp850), against commit `18fcaa94` -- the commit that carries the mangled name and
the one CI failed:

- the read as it stood, `ls-files -z` through `Invoke-NativeCapture`: the path came back as
  `U+0043 U+00B4 U+00C7 U+2551 ...` and `Get-UncheckoutableNameClass` returned `''`. No finding.
- the same read with `-c core.quotePath=true` and `Convert-GitQuotedPath`: `U+0043 U+F03A ...`,
  verdict `private-use`. The finding CI produced, on the machine that produced the name.

And the one thing the old comment was right to worry about, measured rather than assumed: a path
holding a newline, built with `git mktree -z`, comes back as `"bad\nname.txt"` -- quoted, the newline
escaped -- under BOTH `core.quotePath` settings, because git C-quotes a control character regardless.
So dropping `-z` costs that guarantee nothing.

### CREATE

- [x] `scripts/lint/check-plugin-integrity.ps1` -- check 43 reads `git -c core.quotePath=true ls-files`
      and decodes each line with `Convert-GitQuotedPath`; `-z` is gone, because it suppresses the
      quoting that makes the wire ASCII. The lib is dot-sourced beside `native-capture-lib.ps1`, inside
      the same `.git` guard, so the fixture suites -- which build a tree with no `.git` -- never reach
      it. That is the position `native-capture-lib` already occupies, and the reason neither needs a
      fixture copy.
- [x] The coverage note records the blindness and the repair, so the check's own line carries its
      second measurement the way it already carries its first.

### TEST

- [x] `scripts/tests/check-report-lib.tests.ps1` -- six asserts on the QUERY half, which had none. The
      judgement half was pinned exhaustively and every one of its asserts stayed green throughout the
      defect. That is the reason these exist: a suite that pins only the judgement cannot tell a check
      that is silent from a check that is never consulted.
  1. the cp850 decode of the mangled name's UTF-8 bytes is SILENT -- the defect itself, pinned. Done
     with an explicit `GetEncoding(850)` and never by touching `[Console]::OutputEncoding`, which is
     console-wide and is how inbound #821 stayed invisible under the shared test gate.
  2. and 3. the forced-flag wire form `"C\357\200\272Usersx.txt"` decodes to U+F03A, and THEN classes
     as `private-use`.
  4. to 6. a source pin on the call site: the flag is forced, `-z` is absent, the output is decoded.
     The asserts above prove the mechanism; only a source read can prove check 43 uses it, since the
     query needs a live checkout and has no fixture.
- [x] The stale sentence in that block -- *a newline ... is why check 43 reads `git ls-files -z`* -- is
      corrected rather than left, and now names the route that guarantee travels by instead.
- [x] `check-report-lib.tests.ps1`: 314 pass, 0 fail.
- [x] The full lint gate: 0 error(s); `[tracked-name] checked 761 -- 0 finding(s)`.

#### Filed, not folded in

[#2110](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2110) answers the **Not verified**
note #2109 left open. Swept `scripts/**` for a git call returning a PATH that neither forces the flag
nor passes `-Utf8`: two survive -- `fold-changelog-entry.ps1:1180`, where a mis-decoded tracked path
falls into the untracked list, so the fold drops it from its own commit and prints a false line about
it, and `find-specialist-mentions.ps1:191`, a bare `git ls-files` where a mis-decoded name silently
leaves the scan set. Every other reader is already correct. Both sit outside #2109's stated scope and
the second is a transport change as well as a decoding one.

### DEPLOY: fix/2109-tracked-name-code-page

The `[tracked-name]` check now reads git's path list as ASCII on the wire and decodes it itself, so it
fires on the machine where a mangled name is created instead of only in CI after the push.

It read `git ls-files -z` and let Windows PowerShell 5.1 decode the bytes with
`[Console]::OutputEncoding`. The whole subject of the check is a name made of bytes no ordinary code
page has an opinion about -- so on cp850 the U+F03A it exists to catch arrived as three unrelated
characters in no class at all. Measured on the commit that produced the case: the local gate reported
`checked 761 -- 0 finding(s)` and CI, on a console whose code page differs, failed the SAME commit with
the finding. That inverts the guard -- it went blind on the developer machine where such a name is
created and spoke only once the object was in the remote's store forever.

The repair is the one [`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md) already
prescribes for this class: `core.quotePath=true` plus `Convert-GitQuotedPath`, because every candidate
code page agrees below 0x80. Dropping `-z` costs the newline guarantee nothing -- git C-quotes a
control character in every `core.quotePath` setting, so such a path is still one record.

Resolves [#2109](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2109).

A guard that only fires in CI reports damage instead of preventing it. Anyone running the lint gate on
a non-UTF-8 console -- the default on a Dutch or German Windows box -- now gets the answer at the point
where it is still free, and notices it the moment they touch that part.

**Score:** 3

#### What makes this deploy extra special

Internal to this repo's own lint gate. Nothing a subscriber runs or upgrades changes.

**Score:** N/A

#### Pull Request

check 43 reads git's path list through the console code page
