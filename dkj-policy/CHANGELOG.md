# Changelog

Everything merged since the last release sits under **`## [Unreleased]`**, **newest first**: **one `###` per
change**, and under it two named `####` sections. The `###` heading is the change's own —
`` DEPLOY: `<branch>` `` and the moment it
landed — and the text directly beneath it answers what a reader arrives with: what the change deploys to
`main`. Then `#### What makes this deploy extra special` for the second audience, and `#### Pull Request`.
Every level here moved one deeper on August 26, 2026, when the pending section above them was introduced and
the development cycle beside them shifted to match; entries written before that day carry the whole set one
level shallower and are read exactly as they always were.
The tier numbers live in the parser rather than in any heading. That second heading said `PR` rather than
`deploy` for one day, August 24 to 25, 2026, and `change` for the four days before that; every wording it
has ever carried is still read, so an entry below written under any of them is parsed exactly as it always
was — including the four written under `PR`, which are in the list below right now. Entries written
before August 23, 2026 carry that first answer under a `###` question of its own with the second nested
at `####` beneath it; entries before August 16 carry the longer set of headings that shape replaced, and
every earlier shape is read exactly as it always was. Every release ever cut is listed in
[`releases/history.md`](releases/history.md) — each with its date, type and title, and a link to what that
release was worth. How the mechanism works (entry files, the Significance sections, folding) is described in
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

Each change declares its own **reach**, and per audience how much it **weighs** there — one `##### Tier N`
sub-section per tier where a repo writes them numbered, each closing with its score; here the audience tier
carries a named heading beside the others instead. This list does not order on it: it is a record of what
landed, so it reads in the order things landed. What the declaration decides is what the **release
documents** lead with — they rank themselves on it — and what may be released at all, because **the bump
follows the highest tier pending**: **tier 0 only earns a patch**, **tier 1 or higher earns a minor**, and
a **major** recaps ten minors. So a changelog holding nothing but tier 0 is a patch waiting to be cut, not
a release with nobody to announce it to.

**The line directly under `## [Unreleased]` is a tally, and nobody types it.** It reads
`**4 / 9 minor entries**`: how many of the pending entries reach the audience this repo publishes to, out of
how many are waiting for the next release, and which bump that work has earned. The two numbers answer
different questions and may differ — the fraction counts tier 2 and above, the bump follows tier 1 and
above — so `**0 / 8 minor entries**` says nothing reaches a subscriber while the version still owes a minor
for what reaches management. It is
**derived from the entries below it every time it is written**, by the fold that adds one and the cut that
removes them all, so it holds no state of its own and a hand-edited count is simply corrected on the next
fold. It ends with an HTML comment that marks it as machine-written; that marker is what the next run
replaces, so anything else written in this space is left alone.

---

## [Unreleased]

**21 / 26 minor entries** <!-- pending-tally -->

### DEPLOY: feat/1941-gate-suite-deadline-and-focus-mode · 20260913-134214

**No test suite runs unbounded any more, and one suite can now be put under the pool's real
contention.** Two changes to `Invoke-TestSuiteGate`, the gate `open-pr.ps1`, `cut-release.ps1` and CI
all run.

**The deadline (#1941).** The reap loop had no deadline of any kind: it slept 100 ms and went round
again for as long as a lane took, whatever had stopped that lane progressing. One wedged suite
therefore wedged the whole gate, and did it in **silence**, because the pool buffers a suite's output
until that suite exits -- so a suite that never exits prints nothing after its opening `started` line.
Measured: **141 minutes**, 61 `powershell.exe` and 29 `git.exe` alive, 0.23 s of CPU between all 29
git children, no output, no error, no red, and nothing stopping a later gate on that machine starting
its own 30 lanes on top. Each lane now carries a bound (`$GateSuiteTimeoutSeconds`, 1800s -- about 6x
the slowest suite this repo has ever recorded); past it the process **tree** is killed, and past a
further grace window a lane that did not die is **abandoned** rather than waited on, which is the half
that actually makes the loop terminate under every condition.

**A timeout is a fourth verdict and it is deliberately NOT re-run.** #1723's crash path re-runs a
suite alone because a killed process measured nothing. A timeout *has* measured something, so
re-running it alone would remove the contention that is the likeliest cause, pass, and hand back a
green gate over a run that cost the machine 90 processes -- the exact silence #1941 was filed about.

**What it does not claim.** #1941's own inferred cause -- a blocked-pipe deadlock in the
`Start-Process` capture -- is marked unverified in the issue and nothing here repairs it. This bounds
it, names which suite it was, and keeps its capture files. That is also what closes the residual
[#1704](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1704) was left with: a degraded run
that keeps no per-suite table.

**Focus mode (#1944).** This repo has a class of defect visible only under the pool -- `#1915` and
`#1939`, three days apart, different files, different causes, identical discovery path: the gate
refusing a push on a branch that touched neither suite. Repairing one meant running the whole
~19-minute gate, because a standalone run is green *by definition of the bug*, and a synthetic
imitation does not substitute -- measured at 0.47-0.95s launch-to-print against the real gate's 3.25s,
~3.4x short, with the suite staying green under it. `-FocusSuite` / `-FocusRepeat` now run one named
suite N times while **real sibling suites** fill every other lane: same pool, same console, same spawn
model. Only the named suite's repeats decide the verdict, the load's headers say so, and every line
the run prints says it is a reproduction rather than a gate.
`scripts/maintenance/reproduce-suite-contention.ps1` is the front door, because a capability reachable
only by dot-sourcing a lib is one nobody uses -- which is the complaint #1944 actually made.

**Score:** 3

#### What makes this deploy extra special

**`native-capture-lib.ps1` is mirrored into `dkj-policy` and `dkj-subagents-shopify`, so every
consuming repo runs this same parallel gate** and inherited both gaps. Nothing is asked of anybody --
no config, no migration, no new call site: the bound is on by default and the ordinary run is
byte-identical in every line it prints.

**The asymmetry with `$NativeCaptureNetworkTimeoutSeconds` is the argument for that default.** That
bound is opt-in because `gh pr checks --watch` is legitimately unbounded, and a default would turn the
longest correct call in the workflow into a failure. There is no such call here: **no test suite is
ever legitimately infinite**, so the safe default is the bounded one and the escape valve is the flag
(`-SuiteTimeoutSeconds -1`).

The half a consumer will actually notice is the silence ending. A wedged gate cost one machine 90
processes and two and a half hours without printing a character; it now prints a red line naming the
suite, keeps that suite's output at a path the verdict states, and returns. The focus knob is the
quieter half and the one that changes a workflow: a consumer repairing a flaky-under-load suite no
longer has to run their whole gate to find out whether the repair held.

**Score:** 3

#### Pull Request

A test suite that never returns is bounded and named, and one suite can be put under the pool's real contention

Plugins: dkj-policy, dkj-subagents-shopify

[PR #1949](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1949)

---

### DEPLOY: fix/1936-overridename-default-honest · 20260913-125446

`Resolve-RepoRootOrFail`'s refusal no longer offers `-RepoRoot` to the 15 of 27 callers that have no
such flag. That parameter exists because the lib cannot know which seam a caller spells -- and it
defaulted to `-RepoRoot`, right for the two scripts the docstring names and wrong for every script
meant to be run from inside the checkout, handed out to whoever did not think about it. Reproduced on
`tidy-machine.ps1`: of the three remedies printed, the middle one was rejected by PowerShell as an
unknown parameter, and it is the one that reads as the direct fix.

The default is now `''`, so an unnamed seam prints no seam. That closes the **class** rather than the
15 instances: a caller that says nothing can no longer be given a wrong answer, only a shorter one.
The two callers that really do expose `-RepoRoot` now pass it explicitly, which is what the
parameter's own docstring always said it was for.

**Score:** 2

#### What makes this deploy extra special

**Fourteen of the fifteen are plugin-carried** (all but `build-config-blueprint`, which is
source-only), so this is a refusal a consumer meets in their own tree, on their own machine, with no
source checkout to check it against -- `ship-pr`, `open-pr`, `prune-merged`, `tidy-machine`,
`park-branch`, `worktree-lane`, `cut-release` and the four `adopt-*` scripts among them. Every one
of them told a reader standing outside a work tree to pass a flag it does not have. Nothing is asked
of anybody: no re-install, no config, no migration. The remedy simply stops being a dead end, and
because the fix is a default rather than fifteen edits, the sixteenth script inherits it for free.

**Score:** 2

#### Pull Request

Resolve-RepoRootOrFail no longer names a flag the caller does not expose

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1946](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1946)

---

### DEPLOY: fix/1939-native-capture-flaky-at-16-lanes · 20260913-124204

`native-capture.tests.ps1`'s flushed-before-the-kill case no longer races `powershell.exe` bring-up
against a fixed 2s bound. The bound is now measured on the machine at that moment -- one cold startup
to first output, the same calibration shape the grandchild bounds further down the file already use
-- and derived at 4x, floored at the old 2s so an idle run pays exactly what it always paid and
capped at 20s so a pathological reading cannot hang the gate behind one suite. The child's sleep is
derived from the bound rather than fixed at 30, so the preceding assert's property holds however wide
the calibration goes, and the failing assert now names the calibrated figure so a reader can tell a
slow machine from a broken capture.

**The repair is smaller than the report asked for, because one half of its reasoning did not
survive the check.** #1939's 0.5s and 3.25s are read out of a calibration that times **two** cold
startups; the quantity this case actually spends is one, so the contended figure is ~1.6s against a
2s bound rather than 3.25s. Budgeting the reported number would have over-sized this bound by about
2x. That correction is recorded at the call site, where the next reader of these figures is.

**Score:** 2

#### What makes this deploy extra special

N/A. The suite does not travel: only `native-capture-lib.ps1` is mirrored into the plugin payload,
and the lib is untouched here. No consumer runs this file, no scaffolded CI runner reaches it, and
nothing is asked of anybody. The cost is paid entirely by this repo's own gate, which is also where
the flake was.

**Score:** N/A

#### Pull Request

The flushed-before-the-kill case no longer races PowerShell bring-up against a fixed 2s bound

[PR #1943](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1943)

---

### DEPLOY: fix/1926-machineonly-without-checkout · 20260913-123237

`tidy-machine -MachineOnly` now runs with no checkout at all -- from a home directory, a scratch
directory, anywhere. It never did, despite a fallback that read exactly as though it did: the old
`if (-not $repoRoot) { $repoRoot = (Get-Location).Path }` could only fire on an empty string, and the
line above it threw on `$null` first, so the guard caught a state that could not occur. #1917 removed
that dead line and left the question standing; this answers it.

The root is now resolved per half rather than once up front -- the refusing resolver for the six
per-checkout lanes, whose subject a checkout genuinely is, and the tolerant one otherwise. Five of the
six machine lanes need no repo, which was measured rather than assumed: lane 7 delegates to a script
that already resolves tolerantly, lanes 8, 11 and 12 hand `Get-InstallRecord` a root only to read the
one field of its answer that is not filtered by it, and lane 10 walks the scratch root. The sixth,
lane 9, asks how far behind *this checkout's* plugins are, so it is skipped by name and says why --
rather than left to refuse inside `plugin-versions.ps1`, where the refusal is worded for somebody who
ran that script directly and would read, from here, as the whole run having failed.

Every other invocation refuses exactly as before, and the suite now pins both directions.

**Score:** 2

#### What makes this deploy extra special

A consumer's closing tidy-up no longer has to be run from inside a repository to answer the questions
that were never about one. `tidy-machine` ships in `dkj-policy`, and `-MachineOnly` is the mode whose
whole subject is the machine -- stale install records, plugin staleness, extracted payload nothing
points at, leftover fixture trees. Standing in a home directory and asking for them used to end in a
raw `You cannot call a method on a null-valued expression`; since #1917 it ended in a stated refusal;
now it answers.

**Score:** 2

#### Pull Request

tidy-machine -MachineOnly runs without a checkout

Plugins: dkj-policy

[PR #1942](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1942)

---

### DEPLOY: fix/1931-exit-code-unknown-audit · 20260913-122617

`Invoke-NativeCapture` (`scripts/lib/native-capture-lib.ps1`) could return an `ExitCode` of `$null` --
not from a crash, not a `0`, and no exception -- when its own documented "proven pattern"
(`Start-Process -PassThru`, read `.Handle`, `WaitForExit()`, read `.ExitCode`) still lost a race in the
first `Start-Process` call of a fresh process (issue #1931: 27 in 960 captures, 2.8%, under 16 lanes;
reproduced independently here at 1 in 300). Both comparisons a caller could write, `-eq 0` and `-ne 0`,
read a `$null` as failure, so an unmeasured code was indistinguishable from a measured one everywhere it
was read.

This adds `ExitCodeUnknown` to both arms of `Invoke-NativeCapture`, on the `ShortRead` precedent (#1679):
a boolean a caller can consult, rather than a change to what `ExitCode` itself returns. #1931's own
premise -- that #1920 had already added this field -- did not match the tree (verified by grep and by
reading #1920's actual commit, which narrowed one caller's refusal to a specific git exit code instead);
this branch builds the field #1931 actually needed.

An audit of the ~256 `.ExitCode` comparison sites outside `scripts/tests/` found most of this codebase
already defends against exactly this ambiguity, via a `Known`/`Measured`/`Fresh` tri-state pattern this
lib's own `Get-TrunkGap`, `park-lib.ps1` and `git-porcelain-lib.ps1` already use, or via a fail-closed
`Write-Error; exit 1` that halts rather than draws a wrong conclusion. Two sites did not, and both are in
this same file:

- **`Get-GitFileTextAtRef`**, whose one caller (`ship-pr.ps1`'s step-list gate and DEPLOY lock, #884)
  read an unmeasurable exit code as "the document is absent -- nothing to check" and silently skipped
  both merge-time content gates. It now throws instead, which is a hard stop under that script's
  `$ErrorActionPreference = 'Stop'` rather than a silent pass.
- **`Invoke-TestSuiteGate`'s own suite-judging loop**, which reads a raw `Start-Process` child's
  `.ExitCode` directly (not through `Invoke-NativeCapture`) and is exposed to the identical race: a
  passing suite whose exit code raced to `$null` was recorded and printed as `FAILED`, which would fail
  the whole gate -- and by extension block every push and merge in this repo -- on a suite that actually
  passed. It now routes an unmeasured read through the same "no verdict yet, re-run alone" path issue
  #1723 already built for a genuine process crash, and treats a second unmeasurable read (on the retry)
  as a second crash, fail-closed.

Every other family was reviewed and left as is, with the reasoning recorded in the CREATE section's
table above -- this was an audit with a documented decision per family, not a blanket sweep.

**Score:** 3

#### What makes this deploy extra special

A repo running this workflow's shared scripts (native-capture-lib.ps1 is mirrored to every consumer)
gets a more reliable test gate and a merge-time content gate that no longer has a silent skip path on
an unmeasurable git read. No action is required to receive it -- it lands with the next plugin update
-- and nothing about how a subscriber writes their own branch document or runs their own gate changes.

**Score:** 2

#### Pull Request

Audit ExitCode comparison sites for absent-code false verdicts

Plugins: dkj-policy, dkj-subagents-shopify

[PR #1940](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1940)

---

### DEPLOY: fix/1932-identity-refusal-128-derived · 20260913-121854

`new-branch`'s no-identity refusal now takes its exit code from the constant its guard actually gated
on, instead of carrying a third hand-typed copy of `128` -- and says no number at all where a
plugin payload predating #1920 supplies no constant to read. The call site records why the number is
sound, which is what a reader could not tell before: `Test-GitCanCommit` returns a bool, so the
message looked like an assertion about a measurement it never made.

**Score:** 2

#### What makes this deploy extra special

A consumer running this script from the plugin cache sees the refusal state the code its own guard
matched on. It matters most on the payload nobody is watching: a mirror built between inbound #1867
and #1920 refuses on **any** non-zero exit, and there the old sentence sent the reader to
`user.name`/`user.email` for a state that has nothing to do with either. Nothing is asked of anybody
-- no re-install, no config -- and the failure this prevents has not happened yet.

**Score:** 1

#### Pull Request

Say at the call site why the no-identity refusal may state exit 128

Plugins: dkj-policy

[PR #1938](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1938)

---

### DEPLOY: fix/1924-fixture-dep-seed-from-script · 20260913-120914

The fixture dependency gate now reads the **script** a fixture copies, not only the libs -- closing the
one-word gap that let it report 26 green asserts while six suites were broken by exactly the class it
exists to catch. A copied script is held to its **load-time** dot-sources only, which is measured rather
than tidy: the wider rule reports ten subjects on a clean tree and all ten are conditional dependencies a
fixture is right not to carry.

**Score:** 3

#### What makes this deploy extra special

The widening was measured before it was written, and the measurement changed it twice -- first from every
dot-source to load-time ones, then from a raw text match to the parser's comment tokens, when the opt-out
reader counted this suite's own fixtures and reported 3 declarations where the tree holds 1. Both reds are
written into the file as asserts rather than into a commit message. And the opt-out it needed was
specified in advance, under #1693, by the docstring of the reader it sits beside: this is the first
instance of a case that was described two issues before it appeared.

**Score:** N/A

#### Pull Request

Seed the fixture dependency walk from the copied SCRIPT, not only the copied libs

Plugins: dkj-policy

[PR #1937](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1937)

---

### DEPLOY: docs/1933-gitcancommit-docstring-wrong-cause · 20260913-115551

`Test-GitCanCommit` refuses only on git's own `128`, and the reasoning recorded beside that narrowing
named a cause nobody measured: a git child transiently failing under the parallel gate, cited to
#1915. #1915 is a different flake -- the capped-tip case, whose mechanism was a fetch-attempt record
suppressing a retry. What was measured on #1920's branch is the opposite of a failure: at 16 lanes
the git child **succeeded**, exited, and printed the correct author ident, while `$proc.ExitCode`
from `Start-Process -PassThru` came back absent in 27 of 960 captures.

That distinction is what the narrowing's safety rests on. A reader who believes it only screens out
*failed* children may reasonably conclude that a more precise probe, a retry or a `-Utf8` removal
makes it unnecessary -- and remove it. So the four passages carrying the old cause now state the
measured one, including the three repairs that were tried and do nothing (the position-1
confinement, `.Refresh()`, and re-reading the code twenty times over 200ms), and the comparison's
own shape is written down: `$null -ne 128` is what lets an unreadable capture through, so any
rewrite to "is it non-zero" silently restores the refusal #1930 removed.

`git-identity-gate.tests.ps1` now pins that state as well. It had asserts for every state around it
-- `0`, `128`, four non-zero codes, a timeout, a `$null` result -- and none for an absent exit code,
which is the one the narrowing was written for; both spellings it arrives as (`$null` and `''`) are
asserted to read as can-commit.

**Score:** 3

#### What makes this deploy extra special

The corrected reasoning ships with the plugin, so a consumer reading the lib their own `new-branch`
runs no longer receives an explanation that argues for removing a guard they depend on. Nothing they
do changes; the failure it prevents has not happened yet, which is the whole of its weight.

**Score:** 1

#### Pull Request

Correct the cause recorded beside Test-GitCanCommit's 128 narrowing

Plugins: dkj-policy

[PR #1935](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1935)

---

### DEPLOY: fix/1916-gh-mutation-5xx-not-hard-fail · 20260913-113457

Fixes a correctness gap in the shared `open-pr`/`ship-pr` scripts every consumer of `dkj-policy` runs:
a 5xx or transport failure on the PR-create or PR-merge call was reported as a hard failure even where
it had actually landed, which for the merge case meant the fold never ran and the branch's changelog
entry was left stranded on the trunk beside an already-merged PR. Operators reading a false "failed"
either re-ran into a duplicate-shaped situation or gave up on work that had already shipped.

**Score:** 3 -- a clear improvement, noticed the moment an operator hits exactly this GitHub API hiccup;
before this fix the reported failure was actively misleading about work that had already succeeded.

#### What makes this deploy extra special

Nothing operationally special -- both scripts keep every existing behavior for the ordinary path and
for a real 4xx refusal. The only reader-visible change is that a 5xx/transport failure is no longer
silently treated as a plain failure: it triggers one extra read before either continuing (state
confirms it landed) or reporting the true "this run does not know" instead of a confident wrong answer.

**Score:** 1 -- prevents a failure that has already happened at least once in the field (inbound #1916)
rather than one that has not happened yet.

#### Pull Request

gh mutation 5xx niet direct als harde mislukking behandelen

Resolves #1916.

Plugins: dkj-policy

[PR #1928](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1928)

---

### DEPLOY: fix/1920-new-branch-tests-flaky-at-16-lanes · 20260913-112401

`Test-GitCanCommit` refused on any non-zero exit from its `git var GIT_AUTHOR_IDENT` probe, while its
own docstring promised the opposite -- that an answer it could not measure is treated as can-commit,
because "a refusal built on a failure to measure would wedge a run for the wrong reason". Only a throw
and a `$null` result were honoured; a probe that was killed, timed out, or failed for any other reason
was read as a checkout that cannot commit.

That probe runs on every `new-branch.ps1` run, before the checkout, and its refusal exits 1 with
nothing created -- no branch, no document, nothing on origin. Under the parallel test gate
`new-branch.tests.ps1` invokes that script some forty times per run across sixteen lanes, and there
the git child *succeeds* while its exit code goes missing -- `$proc.ExitCode` from `Start-Process
-PassThru` came back absent in 27 of 960 captures, git's output complete and correct in every one.
An absent code is not 0, so one unreadable capture turned into a red gate that had measured nothing,
and a red gate that measured nothing is what teaches people to reach for `-SkipTests`.

A refusal is now gated on `128`, which is how git's `die()` reports an unknown author identity and the
number this suite already pins from git's own side. Everything else -- including a bounded call that
expired -- is the "unknown" the contract always described. `check-git-identity.ps1` reads the same
function and stops reporting a broken identity on a probe that never answered.

**Score:** 3

#### What makes this deploy extra special

N/A -- a probe's exit-code reading inside this workflow's own scripts. A consumer sees no change in
behaviour except the one they should never have seen: a branch refused because a git call under load
did not answer.

**Score:** N/A

#### Pull Request

new-branch.tests.ps1 no longer false-reds under the parallel test gate at high lane counts

Plugins: dkj-policy

[PR #1930](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1930)

---

### DEPLOY: feat/1925-plugin-own-lib-gate · 20260913-111649

The lint gate now proves that a script a plugin SHIPS can actually load the libs it names -- closes
#1925. Check 8 holds a registered mirror byte-identical to its source and check 39 holds a
depth-crossing `$PSScriptRoot` resolution to a declared suite; between them sat the class where the
text is right, the folder is right, and the file is simply not there. A lib registered for two
plugins and dot-sourced by a script that mirrors into a third resolves inside that third plugin and
finds nothing -- check 8 has no entry to compare against, and check 39's subject is a two-hop ascent
while `..\lib\` is one hop. Measured on the `fix/1917-judge-repo-root-resolution` branch:
`adopt-shopify-floor.ps1`, `archive-theme.ps1`, `push-preview.ps1` and `sync-main.ps1` each gained
`. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')`, that lib was registered for `dkj-policy`
and `dkj-subagents-alpha`, and all four mirror into `dkj-subagents-shopify`, which ships no such file. Four
scripts dead ON LOAD in a consumer, at their first statement, and this gate reported `0 error(s)`.

Two arms, because they fail differently and only one of them is visible from here. The file must
EXIST, and the path must stay INSIDE the plugin root -- an escaping path resolves in this tree,
which holds every path a plugin script could climb to, and is gone in the installed copy where the
`plugins/` level, the family level and every sibling plugin are stripped away. That is check 30's
lesson one layer over, and existence alone is structurally blind to it. The second arm was found by
probing rather than by measuring, which is check 35's own rule applied to its neighbour.

A load GUARDED by `Test-Path` is counted and not judged: that is the author declaring the absence
expected, and this tree means it -- `release-lib`'s `branch-info` sibling is repo-owned and travels
in no mirror. 70 of the 224 references are guarded, so judging them would have arrived needing an
exemption list on day one, the shape this repo declined at 124. Only `$PSScriptRoot` is a subject,
bound through the AST: a `$repoRoot`-relative path names a file in the consumer's own root by design,
and reading those as plugin-relative reports 14 findings here, all 14 false and all 14 that same
seam. Born green at 154 unguarded loads across 104 plugin scripts, 0 findings -- and born green by
one hour, since it had four an hour earlier.
**Score:** 3

#### What makes this deploy extra special

A subscriber notices nothing on the day, and that is the point: the gate runs here, on the repo that
SHIPS the plugins, and what it buys them is that a script which would die at its first statement in
their install can no longer reach a release. The failure it prevents is not hypothetical -- it was
sitting on a branch when this was written, four scripts deep, with every existing gate green over it.
Nothing to migrate, nothing to run, no new refusal in any consumer-side script.
**Score:** 2

#### Pull Request

A plugin script may only dot-source a lib its own plugin ships

[PR #1929](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1929)

---

### DEPLOY: fix/1917-judge-repo-root-resolution · 20260913-110717

Every workflow script that could not find its repository used to die on
`You cannot call a method on a null-valued expression.` -- exit 1, no cause, from the first statement
of the script. That is the line a consumer meets when a skill runs the plugin mirror from a worktree,
or with the working directory somewhere unexpected, which is exactly where `rev-parse` does not
answer. It now refuses in words, naming git's exit code, what git said, and the three ways out.

**Score:** 3

#### What makes this deploy extra special

It removes a spelling rather than adding one. The report asked for a new shared helper; the tree
already had four dual-context resolvers and the repair is the **verdict** the fourth was missing, not
a fifth resolver. `Resolve-CheckRoot` had described this exact bug in its own docstring for weeks
while 37 call sites went on committing it -- the correct shape existed and simply was not the one
that got copied.

Two of the six inbound pickup checks caught something: the model the report told us to lift from
never landed (#1913 is still open, so `new-branch.ps1` carried the defect, not the cure), and the
count was low by one file and silently omitted a whole layer.

**Score:** 2

#### Pull Request

Judge the repo-root resolution instead of dereferencing a null

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1927](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1927)

---

### DEPLOY: fix/1912-noresolves-persists-in-body · 20260913-103500

`open-pr.ps1 -NoResolves` now WRITES ITS ANSWER DOWN, as `<!-- resolves: none -->` in the PR body, and
the resolves gate reads it back the same way it already reads a published `Closes #<n>` -- closes #1912.
The gate folds an open PR's body into what it judges precisely so a resumed branch is not asked to repeat
a decision GitHub already holds; that recognition was keyed on a closing keyword, which `-NoResolves` by
definition never writes, so of the two answers the gate's own refusal text calls honest, one was durable
and the other lasted only as long as the process. Measured on
`feat/1843-portable-repo-settings-runner`: `open-pr -NoResolves` opened PR #1909, and `ship-pr` -- whose
step 1 re-runs `open-pr` -- refused the same branch minutes later for a question that had been answered.

A later `-Resolves` on the same branch strips the marker rather than leaving a body that both closes an
issue and states it closes none, and the marker is re-appended after a `-RefreshBody` for the reason
#919 gives for the closing block one step up. Recognition ignores code spans and fences, because a
document explaining the marker necessarily writes the marker and this entry does.

For this repo's maintainers it removes a refusal that cost seconds and taught the wrong reflex: the
obvious way past it is to pass the flag again, which is how a session learns to pass `-Resolves`
reflexively -- the exact failure this gate exists to prevent. It lands hardest where it matters most, on
a PR delivering one step of a multi-step issue, which is the shape #1843 had and which has already been
closed by accident once.
**Score:** 3

#### What makes this deploy extra special

A subscriber running this workflow meets it as one fewer refusal in the two-command flow the skill pages
prescribe -- `open-pr`, then `ship-pr` -- which is the flow a consumer follows most. Nothing to migrate
and nothing to undo: a branch whose PR predates this simply gets the marker on its next run. They notice
it the first time they ship a PR that closes nothing, and are told on the page rather than by a gate.
**Score:** 2

#### Pull Request

The -NoResolves decision persists in the PR body

Plugins: dkj-policy

[PR #1923](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1923)

---

### DEPLOY: fix/1915-capped-tip-flaky-in-gate · 20260913-102052

`new-branch`'s branch-divergence warning (#1439) could report the shape of a clean branch on a run where
it was blind. `Get-RemoteAheadNote` returns an empty note both for *"origin has nothing you do not have"*
and for *"the ref I counted against is whatever the last fetch left"*, and `new-branch` printed the second
as the first. Since #1860 the window is not one run but ninety seconds: the script opts into the freshness
seam's `-RecentFailureSeconds`, so a single transient fetch failure suppresses the next retry -- which is
the interval a claim, a cut and a resume all live in. A run whose own fetch did not refresh the ref now
says so and hands over `git fetch origin <branch>`; the ordinary run, where the fetch succeeded, is
unchanged and silent. The trunk-level `Base: ...` line does not cover this, because it speaks about the
trunk and is printed on a skip only.

That same blindness is what made `new-branch.tests.ps1`'s capped-tip case flaky in the 16-lane test gate
(#1915): the case is two `new-branch` runs seconds apart on one fixture, so a fetch that failed in the
first silently disarmed the probe the second was asserting on. `Invoke-NewBranch` now clears the
fetch-attempt record before every run -- which removes no coverage, since the seam has its own suite, and
can mask no regression, since clearing only ever makes the run fetch. Case (y6) also gains the premise
assert it was missing, so a warning that never fires reports itself instead of reading as a broken cap.

**Score:** 3

#### What makes this deploy extra special

Every consumer of `dkj-policy` runs this `new-branch`. The guard whose whole job is to catch another
session's push to the branch you are resuming could go quiet for ninety seconds after one bad fetch, and
say nothing about having gone quiet -- the duplicate-work hazard #1439 exists to prevent, arriving through
the one route that reports nothing.

**Score:** 3

#### Pull Request

A stale remote-tracking ref no longer makes the branch-divergence warning read as silence

Plugins: dkj-policy

[PR #1922](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1922)

---

### DEPLOY: fix/1913-gate-only-suite-failures · 20260913-101309

`new-branch.tests.ps1` can now say WHY it went red, and the one call in `new-branch.ps1` that could
make it go red in silence is judged -- closes #1913. The suite runs the script as a CHILD PROCESS and
asserted its exit code through `Assert-Equal`, which reports two numbers and discards the result
object: a red lane said `expected: '0' / got: '1'` about a child whose stdout and stderr were already
captured two lines away. That is why #1913 could be filed but not diagnosed, and why the same suite
going red again on September 13 -- in a DIFFERENT place, which is itself evidence that this is not a
fixture defect -- reported exactly as little. All 49 exit-code asserts go through `Assert-ExitCode`,
which prints the child's output whole.

**And the one unjudged call that reproduces that signature exactly is repaired.** The script's first
statement resolved the repo root with `(git rev-parse --show-toplevel).Trim()`: where git answers
nothing that is `$null.Trim()` -- exit 1, nothing created, and the only thing printed a PowerShell
error naming a line in a script the reader did not write. Measured directly by running it outside a
repository. It now names git's exit code, what git said, and that nothing was created. Whether that
line was #1913's own cause is **not** claimed here and cannot be from what was measured; what is
claimed is that it produces that exact signature, and that after this the next occurrence names
itself either way.

The closeout half of #1913 is fixed and is **#1910's**, not this branch's -- diagnosed here
independently, landed there first and wider, and taken whole. The 36 other scripts carrying the
unjudged repo-root spelling are #1917.

For this repo's maintainers the change is that a red gate stops being a reason to re-run the gate.
Noticed the next time one goes red, invisible otherwise.
**Score:** 3

#### What makes this deploy extra special

A subscriber running this workflow meets the `new-branch` refusal directly: run from a worktree, from
the wrong directory, or from a skill page whose working directory is not what they assumed, they used
to get a PowerShell null-dereference naming a line number in a script they did not write. They now get
a sentence naming git's exit code, what git said, that nothing was created, and the two ways through.
Nothing to migrate; it arrives with the next plugin update.
**Score:** 2

#### Pull Request

The gate-only suite failure names its cause

Plugins: dkj-policy

[PR #1921](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1921)

---

### DEPLOY: fix/1906-xoxowildhearts-plugin-ids · 20260913-095835

The consumer register recorded five plugin ids the live `xoxowildhearts` repo does not enable. They
were measured against the repo it replaced, so `check-connectors` would have reported five false
`[ERROR]`s reading "is NOT (or no longer) enabled" about five plugins that are enabled -- and the
unlisted-plugin check would have skipped all five as a third-party catalogue, staying silent on
exactly what it was built to catch. Latent only because no machine currently holds that checkout.

**Score:** 2

#### What makes this deploy extra special

It is the second field of one fact -- the consumer moved repositories -- and the half that decides
which way a register follows a consumer that has NOT migrated. Decision A says the register records
what a consumer has, so this writes the retired marketplace name deliberately, and says in the file
that it may flip back.

**Score:** 2

#### Pull Request

connectors/xoxowildhearts.json records the plugin ids the live consumer actually enables

[PR #1919](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1919)

---

### DEPLOY: fix/1910-closeout-suppression-leaks-into-gate · 20260913-094658

A gate run no longer inherits the close-out suppression a conductor sets, so `closeout-lib.tests.ps1`
stops crashing inside every ship that re-runs `open-pr` with something to push -- closes #1910.
`Invoke-WorkflowGates` suspends the flag around both gates and restores it in a `finally`; the suite
also clears it for its own duration and says so, because a test asserting on an ambient global is its
own defect.

For this repo's maintainers it removes a blocker that sat on the recovery path the staleness guard
(#1292) itself prescribes: when `main` moves under a certified run, the way out is to bring the branch
forward and re-run `ship-pr` -- and that re-run is precisely the one where `open-pr` has something to
push, so it reaches its test gate. The failure also pointed the operator at their own tests while CI
stayed green, which is the most confusing place for the two gates to disagree.
**Score:** 4

#### What makes this deploy extra special

Every consumer running this workflow ships through the same `ship-pr` → `open-pr` → gate path, and both
changed libs travel to them as plugin mirrors, so they meet this defect on the same recovery step and
with the same green CI beside it. They do not have to act: the repair arrives with the next release and
nothing on their side changes shape -- no new switch, no new file, no behaviour they have to adopt. What
they get back is the one route out of a stale-base refusal, which is a route they cannot work around
locally, since `-SkipTests` is the only alternative and that is the switch that says the run did not
measure.
**Score:** 3

#### Pull Request

Clear the close-out suppression around a gate run, and make the suite state its own precondition

Plugins: dkj-policy

[PR #1918](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1918)

---

### DEPLOY: fix/1903-adopt-ci-floor-rename · 20260913-071749

`adopt-merge-queue.ps1` is now `adopt-ci-floor.ps1`, in both copies, with the test suite, the
shared-scripts registry entry, the durations key and the tree's prose following it -- closes #1903.
The queue stopped being this workflow's policy on September 7 (#1546) and came off the source's own
ruleset on September 9 (#1720); most repos running this workflow cannot have one at all (#1540). The
name was the last part that still promised it. No shim: the old path is gone rather than forwarded,
and the reasoning for that is in the script's own header rather than here.

**And the docstring's runner count went with it**, which is #1903's other half. #1843 landed while this
branch was in review, so `$targets` now holds three entries carrying a `QueueRelated` flag -- while the
header still read *"THE TWO RUNNERS ARE EVERY REPO'S"* and the section comment *"The two runners,
consumer-shaped"*. The claim was only ever about the fold and resolves pair; the third runner is a
scheduled drift check that has nothing to do with a queue, and the text now says so.

For this repo's maintainers the change is a name that finally matches the file plus a registry comment
that no longer states retired policy as current -- noticed the moment somebody reaches for the Part 3
adopter, and invisible otherwise.
**Score:** 2

#### What makes this deploy extra special

A subscriber running this workflow types this command about once per repo, and they type it off the
skill page -- which travels in the same release as the script, so following the page they notice
nothing at all. The one who must act is the consumer who wrote the old path into a note or a wrapper:
for them this is a breaking rename with a loud failure and no silent fallback, which is the trade the
branch deliberately took. Named on the page and in the release note so it is not met first as an
error.
**Score:** 3

#### Pull Request

The CI-floor adopter is named for the floor, not for the merge queue

Plugins: dkj-policy

[PR #1914](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1914)

---

### DEPLOY: fix/1904-pin-checkout-in-scaffolded-runners · 20260913-063623

The two write-capable runners this workflow scaffolds into a consumer -- `fold-on-merge.yml`, which spends a
366-day `FOLD_PUSH_TOKEN`, and `verify-resolved.yml`, which holds `issues: write` -- were composed with a
mutable `actions/checkout@v5`, while this repo's own committed copies of the same two jobs have always been
SHA-pinned against exactly that risk. The repo that wrote the warning was protected; the repos that took its
advice were not. All four composed checkout lines are now pinned to `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`
(`v5`) through a single `$checkoutPin` seam, and `pin-parity.tests.ps1` asserts that seam still equals the SHA
in this repo's own fold runner -- so a bump here that forgets the generator fails a gate instead of quietly
leaving every consumer's floor behind. Both steps of each job are pinned, not only the one carrying the
credential, because `persist-credentials` puts the token in the workspace for the whole job; a read-only
runner stays unpinned for the same reason this repo's own does.

**Score:** 3

#### What makes this deploy extra special

It closes a gap that pointed the wrong way round: the hardening was written down, implemented and enforced
here, and the generator handed every adopting consumer the weaker template of the same job. And it answers
the follow-up #1904 raised rather than leaving it -- a pin in a *generated* file has no maintainer, so the
refresh point was made singular and put under a parity gate in the same change.

**Score:** 2

#### Pull Request

Pin actions/checkout by SHA in the fold and resolves runners the scaffolder writes

Plugins: dkj-policy

[PR #1911](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1911)

---

### DEPLOY: fix/1902-xoxowildhearts-live-repo · 20260913-053851

`connectors/xoxowildhearts.json` now names `BWJ-Development/xoxowildhearts`, the repository this
consumer actually works in. The old slug is **not archived** and still resolves, so nothing was
failing and nothing would have started failing -- which is the hazard: a register pointing at an
abandoned repo reads healthy indefinitely. Two checks have learned to *resolve* this field since the
last such correction was made (`-RemoteRunners` reads that repository's CI over the API, #1850; check
1b compares it against a checkout's own `origin`, #1821), so it is no longer the display-only
bookkeeping #1553 measured it as.

**Score:** 2 -- one data field in the consumer register, plus its note. Nobody outside this repo's
own maintenance runs into it, and it is latent even here: no machine currently resolves a
`localCheckout` for this consumer, so the connector block is a `[SKIP]` either way. It is noticed the
moment somebody registers a checkout path, or runs `-RemoteRunners`.

#### What makes this deploy extra special

N/A -- the consumer register is this repo's own bookkeeping about who consumes the plugins. Nothing
here ships, and nobody running an upgrade takes anything from it.

**Score:** N/A

#### Pull Request

connectors/xoxowildhearts.json points at the live repo

[PR #1908](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1908)

---

### DEPLOY: feat/1843-portable-repo-settings-runner · 20260913-053153

The repo-settings drift detector stops being this repo's private tool. `check-repo-settings.ps1` is now
a shared script in `dkj-policy`, `Get-ExpectedRepoSettings` is a contract record marked `decide` -- the
comparison travels, the values stay the consumer's own -- and Part 3 of the adoption scaffolds
`.github/workflows/repo-settings.yml` over the second-checkout mechanism the fold and resolves runners
already use. It reads `gh api` and reports; it never writes a setting, because repo settings are the
owner's surface. `-Trunk` now comes from `Get-TrunkBranchName`, which is what makes the check usable at
all in a repo whose trunk is not `main`: every read was previously aimed at a branch that does not exist
there, and `-RequireRead` turned that into a red run naming the wrong cause. Adding the third target also
exposed that the `FOLD_PUSH_TOKEN` reminder and the queue-defect count both hung on one generic
"something is missing" counter, so each now keys on the thing it is actually about.

**Score:** 3

#### What makes this deploy extra special

A consumer's ruleset, its bypass actors and its merge switches are GitHub-side state: nothing in their
tree changes when one moves, so a record and the live state can disagree indefinitely with nothing saying
so. This repo learned that the expensive way -- three drifts in eight days, two of them with mechanical
consequences: the org transfer emptied `bypass_actors` and every fold was dead for a day (#1244), and
`merge_queue` was added and removed with no trace at all (#1499, #1720). Until now the detector built from
that experience ran here and nowhere else. After the next release an adopting repo gets the same dated,
daily answer about its own settings, against its own declared values.

What it deliberately does not get is enforcement. Rulesets and required checks remain the repo owner's
surface, so the runner reports and stops -- the reachable goal being identical scripts available, not
identical rules enforced.

**Score:** 3

#### Pull Request

The repo-settings drift detector travels: check-repo-settings into the plugin, a Get-ExpectedRepoSettings seam, and a scaffolded repo-settings.yml

Plugins: dkj-policy

[PR #1909](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1909)

---

### DEPLOY: fix/1848-retire-legacy-prio-labels · 20260913-052224

Removes dead code from the BWJ Asana-mirror template: `$script:LegacyPrioLabels` existed only to
bridge the window while `smartwatchbanden` and `xoxowildhearts` still carried the pre-#1842 label
names. Both have now migrated and carry no legacy name at all, so the array guards a state that can
no longer arise -- closes #1848.

Only this repo's own maintainers notice: a reader of the sweep logic no longer has to reason about a
legacy-name bridge that no BWJ store still needs, and a future consumer adopting dkj-policy-bwj fresh
never sees the old names at all. Internal script hygiene.
**Score:** 1

#### What makes this deploy extra special

No subscriber of a service is affected -- this is internal script hygiene in a template two already-
migrated consumer repos already run their own copy of; nothing here reaches past this repo's own
maintainers.
**Score:** N/A

#### Pull Request

Retire the legacy BWJ prio-label sweep now that both stores are migrated

Plugins: dkj-policy-bwj

[PR #1907](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1907)

---

### DEPLOY: feat/1886-shopify-theme-archive · 20260913-043419

`dkj-subagents-shopify` now owns the theme archive: `scripts/task/archive-theme.ps1`, the pure
`scripts/lib/theme-archive-rules.ps1` behind it, and an `archive-theme` skill. Candidate 4 of #1886,
and the third of the four to land.

**The ownership question this bullet was filed with had two candidate answers and the right one was
neither.** #1886 weighed `dkj-policy-bwj` against `dkj-subagents-shopify` under the #1881 ruling --
*what the two BWJ stores share goes to `dkj-policy-bwj` unless it is obviously universal*. The
ruling's exception asks for a demonstrated reader outside the two stores, and this bullet does not
need that test, because the ruling's axis is the wrong axis for it: archiving a theme is not a BWJ
practice, it is a Shopify one. The plugin that owns the live theme already owns `push-preview`,
`sync-main`, `preview-theme`, `sync-rules`, `shopify-cli-lib` and the live-theme guard -- and two of
those ship with exactly the same two readers. The precedent is the plugin's *subject*, not its reader
count.

**For `smartwatchbanden` this is a guard repair, not a relocation** -- the same shape candidate 1
turned out to have. That store's copy removes a theme from inside a `.ps1` with `-Execute`, and this
plugin's live-theme guard is a `PreToolUse` hook that reads the *command string* of a tool call: a
destructive theme command buried in a script is invisible to it, because the call reads
`powershell -File ... -Execute`. That store enables the plugin, so the bypass is live there today. The
converged script never removes anything; it prints the command, with the marker where the seam is
answered, for somebody to run as its own visible act.

**One behaviour is new, and it is the place NEITHER copy was right.** `smartwatchbanden` refused to
archive a third party's theme without `-AllowExternal`; `xoxowildhearts` dropped that gate with a
sound reason -- it never removes anything, so a read-only local backup harms nobody and the gate had
no subject. Both are right about the archive and both miss the *printed command*, which for a store
with third-party themes is the exact line that breaks a live integration, handed over without a word
under a heading saying the archive makes the removal recoverable. So the archive is never gated, the
command is never suppressed, and `Get-ExternalThemeWarning` tells the caller whose theme it is at the
moment they are about to paste it. The prefixes are a seam, unanswered by default.

**Two real defects in the inherited code, both found by writing the first assert against them**, not
by reading:

- `Get-ThemeArchiveVerdict -Id ''` was rejected by the **parameter binder**, so its own
  `'no theme id given'` refusal was unreachable -- a guardrail that reads as one and is dead code.
  Worse in the caller's direction: a binder failure under the script's `Stop` is terminating, so it
  would have killed a whole multi-theme run where the verdict it stood in for skips one theme.
- `Get-ThemeArchiveContentDigest -Records $null` returned a **real-looking SHA-256 for an archive with
  no files** -- the same unroll at a parameter boundary that `Merge-ThemeArchiveEvent`'s own banner
  documents, one function over and unguarded. That is precisely the "fingerprint of something" its
  *empty in, empty out* contract exists to forbid, on the path that reaches it with nothing.
  `Format-ThemeArchiveManifest` carried it too, where it would have written a phantom file line into a
  **committed** receipt and counted it in `files:`.

The `ALIASED` finding itself dissolves rather than being renamed: `Get-ThemeListJson`, the one function
the sibling check could match on, is gone -- both calls go through the plugin's own
`Invoke-ShopifyCli`.

153 asserts in `scripts/tests/theme-archive-rules.tests.ps1`, including the round trip that renders a
receipt, reads it back and re-merges -- the shape no unit assert can see, and the one that caught the
phantom event.

Candidate 4 of [#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886), which stays
open: candidate 2 (`lint-brain.ps1`, a translation plus a merge) and candidate 3 (`plugin-scripts.ps1`,
whose question is now *what kind of artefact* rather than *which plugin*) are each still their own
pickup.

**Score:** 3

#### What makes this deploy extra special

A Shopify consumer gets the step that makes removing a spent preview theme *recoverable* -- and gets it
as a mechanism with a suite rather than as something to write again. A Shopify store has a hard ceiling
of 20 themes, so spent previews have to leave, and both existing consumers had independently built this
by hand under two different filenames with neither able to find the other.

What they actually receive differs by store, which is the point of converging rather than moving:
`smartwatchbanden` gains multi-theme runs, committed receipts and the closing of a live guard bypass;
`xoxowildhearts` can delete roughly 1,400 lines of local script and lib and dot-source the shipped one
instead. A third-party store gains the warning neither copy had.

Scored 3 rather than higher because nothing changes for them on the upgrade alone: the plugin ships the
mechanism, and the repair lands when they adopt it. Scored 3 rather than `N/A` because the thing shipped
is a script they run, not an internal rearrangement -- and because one of the two subscribers is running
a guard bypass until they do.

**Score:** 3

#### Pull Request

dkj-subagents-shopify owns the theme-archive rules

Plugins: dkj-subagents-shopify

[PR #1901](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1901)

---

### DEPLOY: docs/1896-tier2-subscriber-reader · 20260912-210218

The tier model now says **whose** service. *Subscriber of a service* names a role, and a role does not say
which party fills it -- so in a repo whose subscribers are themselves businesses the phrase reads two ways,
and the wrong reading is the more vivid one, because that party is a real customer somebody can picture.
The rule added is **one hop and no further**: the tier-2 reader is whoever takes what this repo ships, and
that party's own customers are one hop further out and are never this reader.

It is written in two places and deliberately not in the other twenty. `RELEASES-portable.md` carries the
rule and the measurement, because that is where the tier model is defined. The guidance block in
`entry-scaffold-lib.ps1` carries a three-line version, because that block is rendered into every
development document and is the line an author is looking at *while* scoring -- the report named it for
exactly that reason. Everywhere else the phrase appears it is a name for the tier, not a definition of it,
and a name is not where this gets fixed.

The guidance version is deliberately tier-agnostic, so it stays correct under a tier-1 repo's `{0}` too: a
commissioner who resells has customers of their own, one hop past the repo just the same.

**It is a continuation of the reader sentence rather than a paragraph of its own, and that is issue #928
one clause further down.** `Remove-EntryAudienceGuidance` drops the whole paragraph carrying `{0}` in a repo
that states no audience tier, fenced by separator lines. Written as its own paragraph -- which is how it was
written first -- the clause survives that removal and opens with "that reader" after the clause naming that
reader has gone: exactly the mid-sentence paragraph #928 was filed for, reappearing in the same consumers,
and invisible here because this repo's `repo-config.ps1` states tier 2. Keeping it inside the paragraph is
also the right answer on the merits, since a repo asked about every tier has no single "that reader" for the
clause to qualify. Caught by rendering both states rather than by a gate, so the new assert is what makes
the next split fail loudly: the existing #928 asserts derive the paragraph from the seam and would simply
see a shorter one.

Resolves [#1896](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1896).

**Score:** 3

#### What makes this deploy extra special

Every consumer writes this question into every branch document they open, and answers it on every entry --
so the ambiguity is not this repo's alone, and the repos most exposed to it are precisely those whose own
subscribers are businesses: both BWJ store repos, and the webshop that filed #620 and gave the model its
two-kinds-of-audience shape in the first place. They get the sharpened question the next time `new-branch`
runs after this release, and the reasoning behind it in `RELEASES-portable.md`.

Scoring this 3 rather than `N/A` is the rule being applied to its own entry. The reading it corrects would
have reached past the consuming repos to their customers, found nobody, and written `N/A` -- which is the
exact move that cost a required migration its place on the `v5.1.0` audience note.

**Score:** 3

#### Pull Request

Name the tier-2 subscriber explicitly: the consuming repo, never its own customers

Plugins: dkj-policy

[PR #1900](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1900)

---

### DEPLOY: feat/1895-triage-label-adopter · 20260912-141115

`dkj-policy` shipped no machinery for the triage-priority label set this repo's own orchestrator
already prescribes on every issue (`prio-1`..`prio-4`) -- the scale existed only as prose in
`.claude/specialists/lenses/01-01-extension.md`, so any other dkj-policy consumer adopting the
convention had to retype four names and four colours by hand, with no gate to catch a typo before
`gh label create` refused it. `Get-MissingLabelNote` already established the precedent for this class
of problem on a PR label (compose the exact `gh label create` and stop, never substitute, never drop),
and `Get-ReachLabel` already established the precedent for sharing a label's SPELLING as a `copy`
seam across dkj-policy consumers. This closes the gap between the two for the priority axis: a new
`Get-TriageLabels` seam states the canonical four (`Adopt = 'copy'`, since the rungs are a shared
convention rather than a fact about the adopting repo -- unlike `Get-BranchInfo`, which is `decide`),
and a new print-only script, `adopt-triage-labels.ps1`, reads a repo's `gh label list` and prints a
paste-ready create command for whatever it is missing -- never creating one itself. Split from #1843
per its own red-team review; the three open questions it left (apply-or-print, is there a shared set,
where does it live) are answered by this branch: print, yes one set, and in its own seam rather than in
`branch-info.ps1`. This does not touch `#1686`'s BWJ-versus-source disjointness, or `#1841`/`#1870`'s
reach-label machinery -- it is the neighbouring axis, for ordinary dkj-policy consumers only.

**Score:** 2

#### What makes this deploy extra special

A dkj-policy consumer that has adopted the shared triage convention (or wants to) now has a single
command that tells them exactly which of the four canonical labels their tracker is missing and hands
them the paste-ready fix -- one command instead of four hand-typed ones, and no risk of a typo'd hex
colour or a `gh label create` failing after the fact. It never writes anything on its own.

**Score:** 2

#### Pull Request

Print-only adopter for the shared triage-priority labels

Resolves #1895.

`dkj-policy` prescribes the four `prio-1`..`prio-4` labels on every issue this repo files, but shipped
no machinery for a consumer to adopt them -- the scale was prose in one family's page, and creating a
label is a GitHub-side write nothing here should do silently. This gives the axis its own `copy` seam
(`Get-TriageLabels`, next to `Get-ReachLabel`) and a print-only adopter script,
`adopt-triage-labels.ps1`, that composes a paste-ready `gh label create` for whatever a repo's tracker
is missing and never runs it -- the same compose-and-stop shape `Get-MissingLabelNote` already
established for a PR label. Mirrored into the plugin, wired into the script contract and the
shared-scripts registry, with a new dedicated test suite plus additions to `repo-config.tests.ps1` and
`script-contract.tests.ps1`. Lint and the full test suite are green.

Not in scope, per the issue: `Get-BranchInfo`, the BWJ reach labels/buckets (#1686, #1841, #1870), any
colour/description drift detection on an existing label, and a new skill page or a fifth "Part" of
`adopt-dkj-policy` (documented instead via `plugins/dkj-policy/scripts/README.md` and one sentence in
`CONTRIBUTING-portable.md`).

Plugins: dkj-policy

[PR #1899](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1899)

---

### DEPLOY: fix/1897-reupload-stale-attachment · 20260912-123206

The `cut-release` checklist now says to re-upload the release attachment the timing pass edits. Step 0a
prescribes a second timing pass *after* step 5, and step 5 is where the hand-written documents are
attached — so the published asset was one revision behind the tree by construction and permanently
lacked the end-to-end duration that step exists to capture. Measured at `v5.1.0`: 11,487 bytes published
against 12,275 committed, caught only because somebody was watching the byte count. The step now carries
the `gh release upload --clobber` line, names which document is the stale one in each flow (the consumer
note in the merged flow, the internal note in the two-document flow), and rules the generated development
notes out with the reason — it is the editing that creates the exposure, not the attaching.

**Score:** 3

#### What makes this deploy extra special

A consumer running this workflow publishes a Release whose attached note is missing the one figure the
checklist told them to measure, and nothing reports it — the tree, the tag and the commit are all
correct. They find out when somebody downloads the note and the total is not in it.

**Score:** 3

#### Pull Request

The second timing pass re-uploads the attachment it just edited

Plugins: dkj-policy

[PR #1898](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1898)

---

