## fix/2280-strip-tree-paths-json-keys

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

#### What this branch is

Issue #2280. `scripts/tests/hook-stdin-guard.tests.ps1` prints two classes of value it did not author,
through neither a strip nor a cap: a tracked FILE PATH off a `Get-ChildItem -Recurse` over the whole
repo (group 1), and a JSON PROPERTY KEY read straight out of a parsed `hooks.json` (group 3, new with
#2276). The suite dot-sources none of `ref-print-lib.ps1` / `check-report-lib.ps1` and carries no
hand-typed copy of the class either. It runs in CI on every PR in a PUBLIC repository.

Four print sites, not the two the issue names: each class appears once in its group's enumeration line
and again in that group's per-item assert message.

#### The three decisions this branch had to make

1. **Dot-source or copy.** Dot-source `ref-print-lib.ps1`. The copy precedent -- `asana-mirror.ps1` --
   exists because that file SHIPS STANDALONE into a consumer where no lib of this repo exists (#2019);
   a suite in `scripts/tests` never leaves this repo. A copy would also be an edit to
   `pr-issues.tests.ps1`'s pin, which compares the copies character for character; a dot-source is not,
   because that pin counts files in `scripts/lib` that DEFINE `ConvertTo-ConsoleStrippedText`.
2. **Which function per value.** `Get-DisplayPath` for the paths (preserves spaces and length -- a path
   has to survive being read off the screen and typed back) and `Get-DisplayRef` for the event key (a
   single-line label, where collapse and trim are right and a path's `(no printable path)` is the wrong
   noun). Two contracts, two functions.
3. **Cap or no cap.** No cap, on entry 6's reasoning: this console is a CI log, which wraps rather than
   truncates, so a cap would buy no screen back and could cut the half of an assert message naming the
   file that failed.

#### One thing a later reader should know

The entry number collides with a parked branch. `fix/2271-guard-exception-message-prints` is on the
remote with no PR and claims entry **14** of the same list. This branch takes 14 because it is the
truth at ITS merge; whichever lands second renumbers on rebase. Nothing in the tree is inconsistent --
the collision is an ordinary merge conflict on an unmerged branch, not a finding.

### CREATE

- [x] Dot-source `scripts/lib/ref-print-lib.ps1` at the head of the suite, with the reasoning for the
      dot-source, for the lint that does NOT close this, and for why the load cannot perturb the tree
      scan it sits above.
- [x] Route all four print sites: group 1's enumeration (L195) and per-site assert, group 3's
      enumeration (L345) and per-wrapper assert.
- [x] Register the site as entry 14 of the print-site list in
      `../plugins/dkj-policy/skills/new-branch/SKILL.md`, and correct the count sentence and the two
      growth paragraphs that state it.

### TEST

- [x] `scripts/tests/hook-stdin-guard.tests.ps1` -- 24 passed / 0 failed before, 28 passed / 0 failed
      after. The two scanned counts are UNCHANGED across the repair (10 read sites, 2 draining
      wrappers), which is the measurement behind the claim that loading the lib perturbs no scan.
- [x] Group 4 added as the counter-case, on this file's own rule that a narrowing without one is a hole
      with a comment on it: U+202E in a path and U+200B in an event key both fail to reach the console,
      and the path keeps its length while the label collapses -- the contract difference that is why
      the two values take two functions.
- [x] Group 5 added after the security review found that group 4 guards the LIBRARY and not the
      WIRING: it would pass unchanged if a later edit put one of the four repaired lines back to a raw
      interpolation while leaving the dot-source alone. Group 5 scans this file's own source and
      asserts each line printing a scanned value names a strip. 41 passed / 0 failed.
- [x] **Group 5's own first form was wrong, and a fixture caught it rather than a reading.** It asked
      whether a line NAMED a strip anywhere on it, which passes a line that guards one of its two
      foreign values and prints the other raw -- exactly the shape group 3 carries, where a path and a
      JSON key share a line. So the check written to catch #2280 went green on #2280's own defect. It
      is now per VALUE, keyed on the argument position, and the partial case is one of the six fixtures
      the counter-case block holds it to across eight asserts.
- [x] Proven to go RED rather than only to pass: group 5's logic run against a fixture whose line 2
      prints both values raw and whose line 4 guards the path and prints the JSON key raw reports
      exactly those two and passes the two repaired shapes.
- [x] **A second review pass of group 5 alone reproduced four more holes in it, against working
      PowerShell rather than by reading**, all now closed and each with its own counter-case:
      `Join-Path -Path $s.Path` was certified GUARDED, because the check asked for a `-Path` parameter
      without asking which function it belonged to -- and `$GuardCallTokens` sat declared and unread
      beside it; the sentinel was a bare substring test, so a line whose printed MESSAGE carried the
      phrase left the scan entirely rather than merely passing; `Assert-Equal` was missing from the
      print-bearing call list although it prints raw values on failure; and the foreign-value list was
      an enumeration, so a later group reading a new scanned field would have been invisible. That last
      one is now inverted -- foreign by default, own by declaration -- which is the same fail-open
      enumeration that put this site on the print-site list to begin with.
- [x] Three FALSE failures closed in the same pass, and they matter as much: an abbreviated parameter
      (`-Pa`), the colon form (`-Path:$x`) and a positional call all genuinely strip, and reporting
      them would have put a red line beside a line that visibly calls the guard -- the shape that gets
      a check deleted rather than the code fixed. The residual, stated in the file: a call wrapped
      across two physical lines is still a loud false failure, which is the direction this file
      already chooses.
- [x] The own-value declaration verified complete against the tree: six distinct member accesses on
      the two scan-result variables, three declared own (`$s.Line`, `$s.Guarded`, `$w.HandsBack`) and
      three foreign (`$s.Path`, `$w.Path`, `$w.Event`). 47 passed / 0 failed.
- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors.
- [x] Full suite via `open-pr.ps1`'s gate.

### DEPLOY: fix/2280-strip-tree-paths-json-keys

`hook-stdin-guard.tests.ps1` printed a tracked file path and a `hooks.json` event key raw, at four
sites across two groups, into a CI log on a public repository. Both classes now pass
`ref-print-lib.ps1`'s strip -- `Get-DisplayPath` for the paths, `Get-DisplayRef` for the key -- and the
site is registered as entry 14 of the standing print-site list, which is the part that outlives the
repair. The suite is the first entry on that list that is not a script: a sweep looking for foreign-text
prints in the tooling read past it, because a test suite does not look like a place this workflow
prints.

A second guard came out of the branch's own review. Asserting that the strip FUNCTIONS work leaves the
four repaired lines free to be un-repaired by a later edit, so the suite now also scans its own source
and holds each line printing a scanned value to naming a strip -- per VALUE, not per line, because the
per-line form passed a line that guards its path and prints the JSON key beside it raw, which is the
reported defect itself.

**Score:** 2

#### What makes this deploy extra special

The list entry ships to every consumer of `dkj-policy`; the suite does not. So what a consumer receives
is one more entry on the page they read to find every place this workflow prints somebody else's words
-- and the reason it was missed, which is the reusable half. No behaviour of theirs changes, and there
is no live exploit to have been exposed to: the tree holds three `hooks.json` files, all at reviewed
paths. The failure this prevents is a tracked path or a JSON key carrying a `\p{Cf}` run -- an RTL
override or a zero-width sequence -- repainting a public CI log so it reads as something other than
what it says. `check-plugin-integrity.ps1`'s `tracked-name` check does not hold a path to that class,
and no lint has an opinion about a JSON key at all.

**Score:** 1

#### Pull Request

hook-stdin-guard.tests.ps1 routes its printed tree paths and JSON event keys through the console strip
