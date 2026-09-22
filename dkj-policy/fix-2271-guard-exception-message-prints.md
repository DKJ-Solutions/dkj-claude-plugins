## fix/2271-guard-exception-message-prints

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

#### What #2271 asked, and what the tree answered

The issue offered three answers and said the decision was somebody's: guard all 34 sites, guard only
the ones whose exception could carry foreign text, or declare the class out of scope and say so in
the registry. It also said which exceptions can carry foreign text "is not answerable by grep".

It is answerable by probe, and the probe decided it. Measured on this runtime:

- a dot-source of a `scripts/repo-config.ps1` that does not PARSE returns a message carrying the
  offending source line **verbatim, with real newlines** -- so a consumer who typos their own seam
  file can put `[ERROR]` and a line break into a `Write-Warning`;
- a dot-source of one that **throws** returns a message that is entirely the consumer's text;
- a file API given a foreign path interpolates that path, brackets and all, into its own sentence.

The dominant shape among the 34 -- about twenty of them -- is exactly the first: `. $repoConfig` in
shared scripts that run **in a consumer's checkout**. So the audit option 2 asked for resolves to
"nearly all of them", which makes option 1 the outcome, reached by argument rather than by policy.

#### Two things the issue's own measurement missed, both found by reading rather than grepping

- **The class already had a correctly guarded site.** `check-claude-home.ps1` prints a parse error
  through `Format-SafeProseToken`; the field is assigned `$_.Exception.Message` in `repo-root-lib.ps1`,
  two files away. The issue's grep required the strip on the same line, so it reported 0 guarded.
- **The eight SessionStart hook catch-alls are in the class and outside `scripts/**`.** They are the
  highest-severity members, because their output is what gets forwarded into session context. The
  `dkj-policy-bwj` template adds seven more. 34 was a floor, not a total; the count was 49 at filing
  and is 50 as landed -- the trunk added a ninth hook to the class while this branch was open.

### CREATE

- [x] Guard the 33 interpolated sites under `scripts/**` with `Format-SafeProseToken`, and the one
      bare print (`worktree-lane.ps1` L449) that wraps a delegated script whose throws carry `-Name`.
- [x] Dot-source `check-report-lib.ps1` in the three files that could not reach the guard --
      `check-branch-entry.ps1`, `check-unfolded-entry.ps1`, `new-internal-note.ps1` -- unguarded and
      `$PSScriptRoot`-relative, on that lib's own stated precedent.
- [x] Inline the three-pass strip in the eight hook catch-alls, deliberately NOT a call:
      `hook-check-lib.ps1` is dot-sourced inside their `try`, so "the lib did not load" is one of the
      failures landing in the catch and a call there would throw inside it and escape.
- [x] And a ninth, found by the merge rather than by the sweep: `guard-working-copy.ps1` arrived on the
      trunk under #2264 while this branch was open, printing its lib-load failure raw. Inlined for the
      same reason as the other eight, and the suite's hook scan widened from `*-sessioncheck.ps1` to
      every hook -- the narrower filter was one filename away from catching it, and what makes these
      sites what they are is the catch that may be holding "the lib did not load", not the file name.
- [x] Use `Format-ForConsole` -- the template's own hand-typed guard, stricter on control and format
      characters -- at the seven sites in `dkj-policy-bwj/templates/asana-mirror.ps1`.
- [x] Carry all 26 mirrored scripts into the plugin payloads, byte-identical.
- [x] Add registry entry 14 to `new-branch/SKILL.md`, and correct the three count sentences the
      registry's own rule requires to stay true.

### TEST

- [x] New suite `scripts/tests/exception-message-guard.tests.ps1`, 18 assertions: the three
      measurements above asserted as properties of the runtime (so the argument for the sweep stays
      re-derivable), what the guard does and does not neutralise, a tree scan over `scripts/` **and**
      `plugins/`, that every caller can reach its guard, and that every hook runs all three passes.
- [x] Verified the suite FAILS on a regression in both directions -- a reverted script site and a
      dropped whitespace pass in a hook -- and passes again when restored. A check that cannot fail
      is worth nothing.
- [x] Proved the widened hook scan discriminates, without weakening a live guard: ran its three
      `Contains` probes over the trunk's own text of `guard-working-copy.ps1` and over this branch's.
      Trunk flagged, branch not. Reverting the file to make it red was refused, correctly -- the check
      is the same either way, and the old text is one `git show` away.
- [x] Corrected two defects the suite found in itself: the caller check counted a comment naming
      `Format-SafeProseToken` as a call (which reported all eight hooks as missing a load they must
      not have), and the hook patterns were over-escaped and matched nothing. Both now match literally.
- [x] Ran the four hook-run checks after the change; all four still exit 0 with their normal output.
- [x] Runtime load check on the three files that gained a dot-source -- not just a parse check, since
      a missing function resolves at RUN time and these are all catch blocks.
- [x] Repaired the fixture debt the new dot-source created: `internal-note.tests.ps1` builds its fixture
      by copying `new-internal-note.ps1` and the libs it loads, and the guard's lib was not among them,
      so the child died at load and took four asserts plus `fixture-lib-deps.tests.ps1` with it.
      `check-report-lib.ps1` dot-sources only `repo-root-lib.ps1`, which that fixture already copies --
      on #2115, for this very lib -- so the repair is one copy line.
- [x] Full gate: `check-plugin-integrity.ps1` plus all suites.

#### Two live bugs this branch introduced and the review caught

Both were the same shape, and the second is why the first was not enough. The caller check in the
new suite originally accepted any **mention** of `check-report-lib.ps1` in a file's text, so a
comment naming the lib read as having loaded it:

- `native-capture-lib.ps1` names it twice in comments and dot-sources only `command-probe-lib`. It
  got the guard call and the assertion went green; the call would have thrown the first time that
  catch fired. Repaired by inlining the strip rather than adding the load -- it is a leaf lib nearly
  every script here pulls in, and `check-report-lib.ps1` is ~1,800 lines it needs for nothing else.
- `new-branch.ps1` had a **real** call and no load, direct or transitive. Confirmed by loading all
  six libs it dot-sources and asking for the function: undefined. Repaired with the load.

Tightening the check to look for an actual dot-source then exposed a third flaw in the check itself:
`hook-check-lib.ps1` names the function inside a `<# #>` docstring, which survives a line-comment
strip. The stripper now removes block comments first. All three defects were mine, and none of them
would have failed a parse check, a lint run or any existing suite.

#### One claim the suite refused to let me make

The objection #2271 raised against sweeping was that the guard "re-spaces text a reader may be
comparing against a live error". The tempting answer is that the line says so when it changed
anything -- and that is only half true. `Format-SafeProseToken` collapses whitespace **before** it
measures whether a control character was present, by its own documented design (a tab collapsed to a
space is cosmetic), so a multi-line parse error is flattened **silently**. The security property
holds unconditionally; the announcement fires only for a control character that is not whitespace.
Both directions are now asserted rather than assumed.

### DEPLOY: fix/2271-guard-exception-message-prints

A `$_.Exception.Message` reads like text this workflow wrote and is not: .NET composes the sentence
and then interpolates the offending input into it, which in these scripts is routinely somebody
else's. Measured here, a consuming repo whose `scripts/repo-config.ps1` fails to parse puts its own
source line -- newlines and square brackets intact -- straight into a `Write-Warning`, and one that
`throw`s supplies the whole message. That output is forwarded into session context by the
SessionStart hooks, which is the line-forging vector the foreign-text guards exist for. Every console
print of an exception message now passes a strip: 34 sites under `scripts/**` via
`Format-SafeProseToken`, seven in the `dkj-policy-bwj` template via its own `Format-ForConsole`, and
the nine hook catch-alls via an inlined chain, because there the lib may be the very thing that
failed to load. A new suite asserts the three measurements the sweep rests on and scans the tree so
the 51st site cannot be written unguarded.

**Score:** 3

#### What makes this deploy extra special

Nothing to migrate and nothing to run -- a consumer gets this with the next release, and the only
visible difference is on a day something was already broken: an error line is now one line, with
brackets shown as parentheses. What changes underneath is that a repo's own file can no longer put
a forged line or a counted `[ERROR]` marker into a session start it did not author.

The sweep also went further than the issue measured, in two directions worth knowing about. The
issue reported 34 sites from a `scripts/**` grep; the eight SessionStart hook catch-alls sit outside
that path and are the highest-severity members of the class, since their output is precisely what
reaches session context. And the class already had one correctly guarded site -- two files away from
its own capture, so a same-line grep reported none. Both are recorded as registry entry 15, which
also states the bound the new tree scan still has: it proves no site prints one inline unguarded, not
that the indirect route is clean. A ninth hook joined the class from the trunk while this branch was
open, which is why that scan now reads every hook rather than every `*-sessioncheck.ps1`.

**Score:** 2

#### Pull Request

Every console print of an exception message passes the prose guard
