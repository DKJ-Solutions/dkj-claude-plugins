---
name: open-pr
description: >-
  Push the current branch and open a Pull Request to main via the shared, centralized
  open-pr script from the plugin (single source of truth, issue #81) -- so a consumer does not have
  to duplicate this script locally. Runs the repo's own lint and test gate first; on an error,
  nothing is pushed and no PR is opened. Also forces the issue-closing decision: a branch that
  mentions an open issue must pass -Resolves or -NoResolves, so a repaired issue cannot stay open
  after the merge. And it refuses a changelog entry that still carries its scaffold wording, which
  would otherwise become permanent in the release notes and the consumer-facing plugin CHANGELOGs.
  Use this when a branch is ready and the repo's governance rule allows the PR to be opened.
disable-model-invocation: true
---

# open-pr — the shared PR opener for consumers

This is the **plugin mirror** of `open-pr.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it. Background in
[issue #81](https://github.com/DKJ-Solutions/claude-code-specialists/issues/81).

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1"
```

**In the source repo, run its own copy instead — `scripts/release/open-pr.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

**THE CALLER THROWS THIS RUN'S EXIT CODE AWAY, so read the LAST LINE instead**
([#2283](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2283)). `| tail -40` and
`| Select-Object -Last 150` report the *pipe's* exit status, which is `0` however the run ended — and this
script's output is long enough that reading it through one is the norm rather than the exception. So does
any wrapper ending in a second command, `... > log 2>&1; echo "EXIT=$?"` among them, which is why ruling out
a pipe is not the same as trusting the number. Since #2283 every refusal here ends with a `[REFUSED]` line
saying the run did not finish, and a run that gets all the way ends with the close-out receipt, so the last
line tells the two apart whatever the exit code says. The measurement that produced this is on ship-pr,
whose refusal came back to a backgrounded caller as `completed (exit code 0)`; the shape is identical here.

**No title is passed, and that is the change of August 7, 2026 ([#506](https://github.com/DKJ-Solutions/claude-code-specialists/issues/506)
+ [#505](https://github.com/DKJ-Solutions/claude-code-specialists/issues/505)).** The PR is called
`<branch type>: <the entry's Branch title>` — the type off the branch prefix, the words out of
the DEPLOY section of `dkj-policy/<branch>.md`. So the sentence is written **once**, when the branch is created
(`new-branch -Title`), and the PR, `CHANGELOG.md` and the release documents cannot disagree about what the
change is called. It also cannot lose its type prefix, which the five PRs before this change all had.

`-Title` is still **accepted and ignored** — passing one prints a warning naming the title the entry
actually gives. It was kept rather than removed because every branch in flight, here and in every
consumer, calls this script with `-Title` right now, and consumers receive the new script through a plugin
update rather than by choosing to; a removed parameter would turn all of those into a hard
"A parameter cannot be found" at the end of a finished branch. An **override** was the alternative and was
declined: an override is a second source of the title, which is the thing this change removes.

**One branch shape has no entry to derive from, and since
[#1962](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1962) it is named from its own commit
subject instead.** A branch whose prefix is listed in `Get-EntryGateExemptPrefixes` — `sync` by default —
**owes no changelog entry**, and [`check-branch-entry`](../check-branch-entry/SKILL.md) passes it for
exactly that reason. Deriving the title from the entry therefore left this script unable to name the one
branch shape the CI gate deliberately waves through: measured in a consumer on `sync/live-2026-09-13`, the
lint gate ran, all 27 suites passed, the branch was pushed, and only `gh pr create` never happened. Both
scripts now call the one function, `Get-BranchEntryExemptPrefix`.

On such a branch the title is, in order: **`-Title` if you passed one**, otherwise **the oldest commit
subject off the trunk** — the branch's own opening statement, which a mirror script already writes
descriptively (`sync: mirror in-flight third-party edits from live (47 file(s))`). `-Title` is honoured
**here and nowhere else**, and that is not a rollback of #506: what that change removed was a *second*
source of the title, and an exempt branch has no entry to be a second source **of**.

**Do not write an entry to satisfy the title.** The prefix is exempt precisely so that work this repo is
mirroring rather than authoring stays out of `CHANGELOG.md`; an entry would fold somebody else's edits in
as this repo's own. Where such a branch genuinely has nothing to be named after — no commit of its own off
the trunk — the refusal says so in those terms and asks for a commit or a `-Title`.

**A PR is never created nameless.** If the entry's title section is empty, the script stops and says so —
the emptiness gate normally catches that earlier, but `-Force` can wave that gate through, and an empty
title would otherwise reach `gh` as a complaint about a flag rather than about the entry.

That refusal has **two wordings**, because they are two situations: an entry-bearing branch is sent back
to its title section, and an entry-exempt one is asked for a commit or a `-Title` — telling its author to
fill in a title section would be telling them to write the entry their prefix exists to excuse.

The script:

1. Asks `gh` whether this branch **already has an open PR**, once, because two later steps need the
   answer. See [Resuming a branch whose PR is already open](#resuming-a-branch-whose-pr-is-already-open)
   below. A failed query is treated as "no existing PR" rather than as a blocker.
2. Runs the **resolves gate**, before the slow gates and before anything has left the machine. See
   [The resolves gate](#the-resolves-gate-which-issues-does-this-pr-close) below.
3. Runs the **entry gate** *first*: the branch's document must still have a DEPLOY section at all. See
   [The entry gate](#the-entry-gate-is-there-an-entry-at-all) below — it comes before the scaffold gate
   because the scaffold gate cannot ask this question.
   Then the **scaffold gate**: the branch's changelog entry must no longer carry the wording
   `new-branch.ps1` scaffolded it with. See
   [The scaffold gate](#the-scaffold-gate-has-the-entry-actually-been-written) below. On the same read of
   the same file it runs the **shape gate**: the document *around* the entry must still hold its form — its
   phase headings present, and nothing branch-specific in the generic block above the first one. See
   [The shape gate](#the-shape-gate-does-the-document-around-the-entry-still-hold-its-form) below.
   Then the **step-list gate**: the branch's own plan must be finished. See
   [The step-list gate](#the-step-list-gate-is-the-branchs-own-plan-finished) below.
   Then the **impact gate**, which prints the reach and significance it read. See
   [The impact gate](#the-impact-gate-how-far-does-this-change-reach-and-how-much-does-it-weigh) below.
   And the **link gate**: a relative link in the entry must resolve from the **repo root**, because that
   is where the entry's text lands. See
   [The link gate](#the-link-gate-do-the-entrys-links-survive-the-fold) below.
   And last the **label gate**: the label this PR would be given has to exist in your repository. See
   [The label gate](#the-label-gate-does-the-label-your-seam-names-still-exist) below.
   **This list is the order they actually run in, and it is not the whole set** — the run also carries an
   entry gate, a backing gate and a title gate, each of which refuses and none of which has a section on
   this page yet. Their refusals name themselves, so a message you meet here and cannot find above is one
   of those three rather than something undocumented in the script.
4. **Commits your development document**, if it differs from `HEAD` — that one file and nothing else.
   See [The document commit](#the-document-commit-what-the-pr-says-is-what-the-branch-carries) below.
5. Runs the **repo's own lint gate** (via `Get-LintScript` from `repo-config`) and then **all
   test suites** (`scripts/tests/*.tests.ps1`) -- exactly like CI. An error blocks: nothing is
   pushed and no PR is opened. `-SkipLint` / `-SkipTests` are the deliberate escape valves, and
   `-MaxParallel <n>` runs the suites *smaller* rather than not at all — see
   [When the test gate will not finish](#when-the-test-gate-will-not-finish--maxparallel-not--skiptests).
   The test half is skipped where **CI has already certified this exact commit** — see
   [The CI certificate](#the-ci-certificate-when-the-test-gate-does-not-run-at-all).
6. Pushes the current branch and opens a PR to `main` via `gh`, with a label based on the
   branch prefix and a pre-filled PR body from `.github/pull_request_template.md` +
   the changelog entry file. If the branch already had an open PR, the push **is** the update and
   the create is skipped.

## Just the gates, and nothing else: `-GatesOnly`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -GatesOnly
```

Runs step 5 above — the repo's lint gate, then every test suite — against the **working tree**, and stops
there. No branch check, no push, no PR. Exit 0 when both are green, 1 when either is not. It writes
nothing to the working tree and nothing to GitHub -- the one thing it records is gate evidence, below.
`-SkipLint` / `-SkipTests` still work and still mean what they mean everywhere else.

**It exists for the commits that are made on the trunk**
([#1156](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1156), August 30, 2026). Three changes
land directly on `main` under named exceptions — the fold, the release commit, and the release notes —
and the first two are made by scripts that gate themselves. The third is typed by hand, and the
`cut-release` page told its reader to run the gates *"exactly as `open-pr` would have run them for you"*.
They could not: **this script refuses on `main`**, six hundred lines before it reaches a gate. So the
instruction was right about the rule and unreachable as a route.

**What made that expensive is not the missing flag but the invocation that replaces it.** With no named
entry point, the reader assembles one — a fresh process dot-sourcing `native-capture-lib.ps1` and calling
`Invoke-TestSuiteGate` directly. It runs, it goes green, and it is quietly missing two things:
`Get-TestCommands` is not in scope, so a repo whose suites are not all PowerShell has the rest of them
skipped **without a word** (the failure [#644](https://github.com/DKJ-Solutions/claude-code-specialists/issues/644)
was filed about), and the lint half gets a hardcoded script rather than the repo's own `Get-LintScript`.
A consumer meets both harder than the source does. `-GatesOnly` calls the same `Invoke-WorkflowGates`
the PR path calls, through the same seams — the point of the flag is that the two **cannot** reach a
different verdict about the same tree.

**A green run records gate evidence like any other**, so a later `open-pr` on the identical tree skips what
this already proved. And it is placed *after* both pre-flights and *before* the branch check, deliberately:
everything below that check is about a branch, a push or a PR, and none of it applies here.

### `-NoteTreeOnly`: the one commit where the test gate can be deduced away

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -GatesOnly -NoteTreeOnly
```

Asks whether **every** path that differs from `HEAD` sits inside this repo's release-note tree —
`Get-ReleaseNoteRoot`, plus `Get-ReleaseInternalNotesRoot` where a repo still runs the two-document flow.
Where that is **proven**, the test gate is skipped and the lint gate runs as normal. Where it is not
proven — for any reason at all — every suite runs exactly as it does without the switch, and the run
prints which of the reasons it was.

**It is for the release-notes commit**
([#2102](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2102), September 18, 2026), the one
`-GatesOnly` was built for. On the `v5.5.0` cut that second gate leg cost **325s**, over one hand-written
markdown file — one of the two runs that together are 652s of a 1,166s release, **56%** of it spent on
the same 114 suites twice. What the switch leaves standing is the lint half, measured **here** at 27s
against 249s for the suites; that cut never broke its own 325s into the two halves, so neither figure is
credited to it.

**The deduction was measured, not argued.** The whole release tree was moved aside and all 114 suites were
run against the result. Four went red, and not one of them reads a release note:

| suite | why it went red |
|---|---|
| `repo-config.tests.ps1` | one **existence** assert over the path set `Get-MojibakePaths` returns. It reads the list, never a file in it — and a cut only ever *adds* notes, so the assert can only become more true |
| `bootstrap-drift.tests.ps1` | runs `check-plugin-integrity.ps1` over the live repo as a smoke assert |
| `fix-mojibake.tests.ps1` | the same |
| `subagent-shared.tests.ps1` | the same |

So the suites' entire coverage of that tree **is** the lint gate, run three more times. That is the
inversion worth stating plainly: lint-only here is not an *approximation* of the test gate's answer over a
release note, it is that answer.

**It proves; it does not filter.** #2102 declined a docs-only path predicate by name, on the grounds that a
wrong matcher is silent. This asks one question whose only affirmative answer is *"every changed path is
inside the exception's own bound"* — the same bound the release-notes commit already has to name in its own
commit message — and answers no to everything else: an unreadable `git`, a repo that names no note tree, a
**clean** tree, one stray path, a rename that drags a note *out* of the tree. The narrow case is proved and
the fallback is today's behaviour, so being wrong costs a full gate run rather than a skipped one.

**A clean tree is deliberately not proven**, which reads backwards and is not: the claim is about what
*changed*, and with nothing changed the run would be deducing a gate away on an empty set. The genuinely
unchanged tree is already the gate evidence above — consulted first, and costing a file read.

**It is not `-SkipTests`, and the difference is what the run records.** That switch says *"this run did not
measure"* and is the valve for a broken gate. This one says the measurement was made and had only one
possible answer. **Neither writes gate evidence** — nothing here earns the *next* run a skip.

**Scoped to `-GatesOnly`.** On the PR path it is named as ignored rather than silently dropped: a branch has
CI behind it, and the case this was measured on is the trunk commit that does not.

## The CI certificate: when the test gate does not run at all

The gate records what it proved and skips a tree it has already seen — that is the gate evidence above,
and it is keyed on a **local** fingerprint. Since
[#1715](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1715) there is a second thing it
consults, for the one case the fingerprint misses by construction:

**`ship-pr` calls this script, and in between the branch is routinely brought forward onto a moved
trunk.** `HEAD` is then a commit no local run has ever seen, so the fingerprint misses and every suite
runs again — on the very commit whose required check has just gone green. Measured on PR #1708: the
same 85 suites started for the **third** time, ~30 minutes each locally, while `lint-en-tests pass` was
already on the screen.

**Your repo names the check, and until it does nothing changes.** The certificate is granted on one
named check context — `Get-CiTestCheckName` in your `scripts/repo-config.ps1` — and not on "whatever
the trunk requires". A repo that has not named one keeps running its full local gate, which is what
makes this safe to arrive with a plugin update:

```powershell
function Get-CiTestCheckName { return 'lint-en-tests' }   # the check whose green proves YOUR suites
```

**Name a check your trunk actually requires.** The certificate is read from the required set, so a
check the merge does not depend on never certifies — deliberately: standing a local gate down on
something the merge ignores lowers the bar rather than moving it.

So before the gates, and **only where a PR already exists**, the script asks two questions of `gh`:

| | |
|---|---|
| `gh pr view <n> --json headRefOid` | which commit did CI actually run against? |
| `gh pr checks <n> --required --json name,bucket` | is the **named** check among the required ones, and green on it? |

Where the PR head **is** this `HEAD` and the named check is in the `pass` bucket, the test gate
reports what carried it and does not run:

```text
test gate: satisfied by CI -- lint-en-tests green on this exact commit (1e805d22). Not run again locally (#1715).
```

**The certificate is stronger evidence than the run it replaces**, which is what makes this a skip and
not a relaxation. CI ran the same suites on a clean checkout of that exact commit, and it is the
certificate the **merge** is gated on — the trunk's ruleset blocks the merge until that context passes.
A local re-run cannot change the merge decision; it can only delay it.

**Every ambiguity runs the gate.** No named check, no PR yet, a PR head that is not this `HEAD` (an
unpushed commit, a bring-forward, a moved trunk), an unreadable answer, an empty required set, the
named check missing from it, or the named check **red** — each of those prints its reason and the
suites run exactly as they always did:

```text
test gate: no CI certificate for this commit -- the PR head (7c1a44f0) is not this HEAD (1e805d22) -- the certificate is about a different commit. The suites run below.
```

### The check is still RUNNING: the gate waits instead of re-proving it (`-NoCiWait`)

**One of those refusals is not an ambiguity at all, and it used to be the commonest one**
([#2317](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2317), September 22, 2026). A named
check that has **failed** and one that is **still running** were the same refusal — *not green* — and
they are opposite facts. `ship-pr` calls this script immediately after the push, so the check has
typically just started: the certificate was refused for the one reason about to stop being true, and
the whole pool then re-proved locally the commit CI was proving at that moment on a clean checkout.

So where the check is registered and **pending on this exact `HEAD`**, the gate waits for it:

```text
test gate: 'lint-en-tests' is still running on this exact commit (1e805d22) -- waiting for it rather than re-proving the same tree locally (issue #2317).
           up to 30 min, one read every 30s. Past that, or on any other answer, the suites run below.
           still running -- read 1, 30s elapsed.
test gate: CI answered after 214s -- the local pool was not run (issue #2317).
```

**It cannot fail a gate, skip a suite or move a merge.** There are three ways out. *Certified*: the
caller takes the same skip it would have taken had the check been green when it first asked.
*Settled*: the check went red, the PR head moved under it, or the payload stopped being readable — the
suites run exactly as before. *Gave up*: the bound ran out while it was still pending — the suites run.
Two of the three are the old behaviour byte for byte.

**Measured, over the 98 most recent completed runs of this repo's own CI:** median 693s, four runs
between 900s and the 30-minute bound, two above it (3422s, 4273s). The tail is not suite runtime — it
is GitHub runner-queue contention, one shard starting late while its siblings run normally. That tail
is why the bound is **high** and not why it should be low: what decides the saving is whether a run
certifies *before* the bound, and all four in that band do.

**`-NoCiWait` turns it off** and runs the suites immediately, as this script did before #2317. The
mechanism is narrow enough to need no flag on the ordinary paths — no wait on a first `open-pr`, under
`-SkipTests`, on an unpushed commit, on an unregistered check, or on a red one. Reach for the switch
when you want the *local* verdict in your own hands: chasing a suite that is red under the pool and
green standalone, say, where CI's answer is precisely the one that will not help.

`ship-pr` takes the same switch and forwards it.

**Why it asks for the named check by name rather than counting greens.** `gh pr checks --required`
reports the required checks that have **registered**, so a workflow which has not created its check
run yet is simply absent from the answer — the race `Get-RequiredCheckContexts` documents. Its empty
shape is obvious and harmless. Its **partial** shape is neither: on a trunk requiring two contexts, the
unrelated one can register and go green while the test check has not started, leaving a payload that is
non-empty and holds no failure. Asking for one name closes both shapes at once, because a check that
has not registered cannot be found, and not found is a refusal:

```text
test gate: no CI certificate for this commit -- 'lint-en-tests' is not among this trunk's required checks on this commit (found: branch-entry). The suites run below.
```

A repo with no required check at all — the GitHub Free case — therefore keeps its full local gate
forever, which is the correct answer rather than a gap. Check names are printed through the same
sanitiser the remote-tip line uses, because a check's displayed name is chosen by whoever produced it.

**The lint gate is not skipped this way**, deliberately: it is seconds rather than half an hour, so
there is nothing to buy. And the certificate is **not** written into the gate-evidence record — that
record means *this machine proved this tree*, and filing a remote green in it would make the skip
outlive the certificate by up to four hours. It is re-read in seconds on the next run instead.

## When the test gate will not finish: `-MaxParallel`, not `-SkipTests`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -MaxParallel 4
```

The test gate runs the suites in parallel, and by default it works the lane count out for itself:
`ProcessorCount - 2`, floor 2. `-MaxParallel <n>` overrides that for this run; `0` — the default —
leaves the resolution exactly where it was, so passing nothing behaves as it always did. The gate
prints the number it used, so the run says how it was measured.

**It exists because the default can fail to *finish***
([#1443](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1443), September 5, 2026). Each
lane spawns a `powershell` child that spawns children of its own, and the reservation formula reasons
about **cores**, not memory. Measured on an 18-core machine, same 68 suites, same function: **16 lanes**
passed once in 716s and was then **killed twice** — *"the system is running low on memory"* — while
**`-MaxParallel 4`** passed in 888s. 24% slower, and it finishes. Intermittent rather than a ceiling:
16 lanes fits when the machine is otherwise quiet.

**Reach for it before `-SkipTests`, because the two are not near-equivalents.** `-SkipTests` is the
switch that says *this run did not measure* — use it to get past a memory limit and the branch is
afterwards indistinguishable from one that skipped its suites for a bad reason. A lane count keeps the
measurement inside the run that is supposed to make it.

**And a starved run can go false red, not only die.** The killed run's log above carried two `[FAIL]`
lines in a suite that is 108/108 green run alone — so a killed run's *failures* are no more trustworthy
than its verdict. Same class of untrustworthy red as the gate's own "the tree moved while this ran"
warning, reached by a different cause.

`ship-pr` takes the same flag and forwards it. **The default is deliberately unchanged**: whether the
formula should account for memory as well as cores is a separate question, on one machine's worth of
evidence, and #1443 did not measure it.

## A branch whose PR is already MERGED stops the run, and that is good news

**The lookup above asks for an *open* PR, and until [inbound
#1077](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1077) that was the only question
asked.** For a branch whose PR has been *merged* it answers "none", so the script took the create path
and GitHub refused it — and what the reader saw was a PowerShell error naming `gh` authentication, on a
branch that was in fact completely finished. `gh` had just listed PRs, pushed and read the issue list in
the same run: the one hypothesis offered was the one thing that was demonstrably fine.

So a merged PR is now its own outcome, asked for as a fallback when the open lookup finds nothing:

```text
PR #9 for 'docs/audience-note-v1' is already merged -- nothing to open. https://github.com/.../pull/9
A follow-up cycle on the same subject gets its own branch -- name it with a -v2 suffix by hand.
```

It exits **0** — nothing failed — and it stops **before** the gates, the push and the create, because
there is nothing to lint, push or open for work that has landed. The state is not exotic: a second
session, a hand-merge on github.com, or simply re-running `ship-pr` all produce it, and the local branch
survives a merge because `--delete-branch-on-merge` removes the remote one only.

**And where a create does still fail, the message is gh's own.** The old line replaced it with a fixed
`(is gh logged in?)` guess; that hint is kept only for the one case it is the best available answer — a
`gh` that printed nothing at all.

## Resuming a branch whose PR is already open

**Running this on a branch that already has an open PR is a normal, supported case** — it runs the
gates against the new commits, pushes them, and exits 0 with the PR number. Only the `gh pr create` is
skipped, because a push is what updates an existing PR.

That matters most for [`ship-pr`](../ship-pr/SKILL.md), which calls this script as its step 1. Until
August 4, 2026 the create was unconditional: a duplicate made `gh` return non-zero, step 1 failed, and
**steps 2-6 — the CI watch, the merge, the fold, and the issue verification — never ran.** A branch
whose PR had been opened in an earlier session therefore had to be merged and folded by hand, which is
the five-step sequence `ship-pr` exists to remove. Measured on
[PR #457](https://github.com/DKJ-Solutions/claude-code-specialists/pull/457).

**Title and body are left alone by default.** The body may have been edited on github.com since it was
opened, and overwriting someone's edits with a freshly generated template loses more than a stale title
costs — the title is at least visible on the PR. Use `gh pr edit` if you want the title changed. Since
[#506](https://github.com/DKJ-Solutions/claude-code-specialists/issues/506) that holds for every PR rather
than only a resumed one: the title is composed once, at creation, and no later run rewrites it. Rewriting
a rewritten entry's title into an open PR was weighed and left out — a title is what people refer to a PR
by, and quietly renaming one mid-review is the same class of surprise as overwriting the body.

**`-RefreshBody` rewrites the description from the entry, and only the description.** Pass it when you
extended the changelog entry after the PR was opened — routine on a branch that keeps growing, and
otherwise the PR keeps describing an earlier version of the work while the merged changelog gets the new
one. The `## Resolved issues` block, anything a reviewer added, and any section your template carries that
the script did not write — "Type of change" boxes, a checklist — all stay exactly as they are.

**Renaming a heading in your template needs no configuration** — the rule below reads a position, not a
name. One wrinkle worth knowing if you do rename one: a PR opened *before* the rename still holds the old
heading in its published body. The script therefore falls back to the headings it has shipped before
(`## What does this change do?` and its Dutch predecessor) when the current one is not found, so an older
PR stays refreshable instead of silently reporting that it already matches.

It is **opt-in** rather than automatic for the reason above: refreshing on every run would overwrite a
hand-edited body without being asked. And it is a no-op where there is nothing to do — no open PR, no
description in the entry, or a body that already matches, in which case nothing is sent to GitHub at all.

**The placeholder's position decides the description, in both directions.** The heading it replaces under
is the **last heading above the placeholder**, at any level (`#` through `######`); every heading **below**
the placeholder belongs to the form and is a boundary the description stops at. Where the placeholder comes
before any heading — the shipped reference's own shape — there is no description heading at all: the
description is the body's **leading section**, and every heading in the template is a boundary. A
heading-less template is a supported shape, not a broken one. **A missing one is the failure — and it
is the silent one**: the script builds no body at all and says nothing, which is why the adopter places
the file rather than telling you to. The warning further down fires on a placeholder that does not
*match*, which is the other failure.

**That rule arrived in two steps, and both are worth knowing if your own template's shape has moved.** The
match was `## ` exactly until August 9, 2026, which meant a template promoted to `#` silently lost the
whole feature. And the position read was "the first heading" until August 24, 2026
([#865](https://github.com/DKJ-Solutions/claude-code-specialists/issues/865)), which agreed with the placeholder
only while this family's template opened with an H1 — in a template of `<placeholder>` + `## Checklist` it
would have named the checklist as the description and overwritten it on every refresh.

## Your PR template — the one promise this script relies on

`.github/pull_request_template.md` is **your** file: GitHub reads it only from that path in your own
repo, so unlike the rest of this workflow it cannot live in the plugin and cannot be `@`-imported. What
the plugin ships instead is a **reference**, which `adopt-dkj-policy` Part 1 copies into place for you on
adoption and never overwrites afterwards ([#1843](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1843)) —
so it is there to read and to diff against, not a step you owe:

```text
${CLAUDE_PLUGIN_ROOT}/templates/pull_request_template.md
```

**If that path is empty in your repo, this script builds no body at all** — it wraps the whole
body-building block in a test for the file, with nothing on the other side, so you get a PR with no
description and no warning. Running the adopter is what fills it; the warning below is about a
placeholder that does not *match*, which is the other failure and the loud one.

Everything `open-pr` needs from that file is **one line**, and it is the whole interface: a **placeholder
line the matcher recognises, verbatim**, which is where the description is inserted when the PR is created
and what `-RefreshBody` replaces afterwards. Break it and nothing errors — you get a PR whose body has no
description. Everything else in the file is yours: add sections, checklists and headings freely, and the
script leaves them exactly as they are.

**The reference carries no heading of its own, and that is the shape to copy.** A heading is not part of
the contract — the lint gate in the source repo stopped requiring one with #865 — so a template that is
nothing but the placeholder line is correct and complete. What headings you add are the form's, and the
refresh treats each as a boundary it will not cross.

**Why the reference is only that one line — read the reasoning, not the answer.** This family's template
carried a "Type of change" block and a six-item checklist until August 9, 2026, and they were removed
after a measurement rather than on taste: over 60 PRs, "Type of change" had exactly one of four boxes
ticked *every single time* — a fact the changelog entry already states under `### Branch type`, and which
the GitHub label takes from `Get-BranchInfo` rather than from the tick — while two checklist items were
ticked 60/60 by the script itself and two were ticked 0/60 by anyone, ever, though both were already
enforced by gates that block the PR. A box that is always ticked and a box that is never ticked carry the
same information. The rule that survives is **"keep what is neither restated by the entry nor proven by a
gate"**, and in that repo nothing survived it.

**In yours something may.** The consumer who reported this ran the same measurement over their own 60
PRs and found one box of eight that genuinely varied: a preview-URL approval, on a repo whose result has
to be judged by eye and which no gate can prove. They kept it, correctly, and dropped the other seven. So
run the measurement on your own history — the method travels, the answer does not.

**No `## Specific to this repo` slot is pre-written**, unlike `CONTRIBUTING-portable.md`. The difference
is what the file is: a contributing guide is read once, while every heading in a PR template is repeated
in every PR body forever, so an empty slot would be a permanent empty section in your PR list. Add one
when you have something to put in it.

**If your template's placeholder LINE differs, define `Get-PrDescriptionPlaceholder`.** The description
is inserted by an exact whole-line match against the built-in strings — every placeholder this family has
ever shipped, oldest first, so a consumer who has not migrated keeps working — and a template one word away
from all of them gets a PR body with no description at all. Since
[#573](https://github.com/DKJ-Solutions/claude-code-specialists/issues/573) a run that matched no
placeholder **warns** and prints the strings it compared against — before that it was silent, and a
consumer merged 12 of 60 PRs with an empty description before anyone noticed. Your own line is the
answer: return it from `Get-PrDescriptionPlaceholder` in `scripts/repo-config.ps1`, or make the template
carry one of the built-in strings verbatim. `check-script-contract.ps1` cannot catch this for you — the
function is optional, so a repo that does not define it is correct.

**The one exception appends rather than replaces: a `-Resolves` the existing body does not carry yet.**
Dropping it would be the whole point of the resolves gate failing from the other side — GitHub closes
what the body says *at merge time*, so the issue would stay open, and `ship-pr`'s step 6 reads that
same body back and would confirm the same silence. The `Closes #<n>` line is appended (idempotent per
issue, so nothing is duplicated). If that append fails the script **stops with exit 1**: the branch is
pushed by then, and merging it would publish the loss.

An existing body that already says `Closes #332` also satisfies the resolves gate on its own, so you do
not have to repeat a decision that is already published on the PR.

## The document commit: what the PR says is what the branch carries

**Every reader of your development document inside this script reads the WORKING TREE — the gates above
and the PR body — and the push ships `HEAD`.** On a clean tree those are the same file. On a dirty one
they are not, and the three readers *downstream* all take the committed copy: the `branch-entry` CI
check, the fold, and `ship-pr`'s DEPLOY lock. So a document you had written but not committed produced
a PR body describing a DEPLOY section that was not on the branch, and a CI check that had to fail on
arrival.

**Measured in the source repo on September 3, 2026 ([#1269](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1269)),
from PR #1267.** The run printed `WARNING: the gates below run against a DIRTY tree`, passed every gate
against the filled-in working copy, pushed the empty scaffold, and published the filled-in body.
`branch-entry` failed immediately; recovering took a second commit and a re-push.

**So the script commits that file itself, just above the lint and test gates.** Bounded exactly as
`park-cycle`'s bound 1 is: the resolved document path(s) and nothing else, never `git add -A`, and
`git commit -- <paths>` leaves anything else you had staged staged and uncommitted. It prints one line
when it commits, and nothing at all when the document was already committed. `-GatesOnly` never commits
— that flag writes nothing by definition.

**Why it commits rather than refusing**, since a fifth refusal was the obvious alternative. This script
is the documented owner of the step that publishes this document, and `park-cycle` already commits
exactly this path automatically for the life of the branch — so this is an act the workflow already
performs, taken at the one moment it has to be true. A refusal would also charge you a full lint + test
gate re-run for it: committing moves `HEAD`, which changes the gate-evidence fingerprint, so the run
after the refusal cannot reuse what the refused one proved.

**Neither existing signal covered it.** The dirty-tree warning is deliberately not a refusal — a dirty
tree mid-flight is ordinary. And the backing gate refuses only when this document *is* the whole
branch: it requires nothing else committed, so a dirty document **alongside** committed code raised
nothing at all.

## The entry gate: is there an entry at all?

`Test-DevelopmentEntryMissing` refuses to push a `dkj-policy/<branch>.md` whose **DEPLOY section is
gone**. It runs ahead of the scaffold gate below, and it is a separate gate rather than a stricter version
of it — which is the whole reason it exists.

**The scaffold gate works by matching strings, so a deleted section defeats it by having none.** Delete the
DEPLOY section and `Get-DevelopmentEntryText` falls back to the whole document, handing the scaffold gate the
guidance **preamble** — which carries no scaffold marker, because nobody scaffolded it. **So the scaffold gate
passes by ABSENCE**: the branch pushes with no entry text whatsoever, and the PR title and description are
composed out of the guidance. The fallback cannot simply be narrowed either, and that is what forces a second
predicate: a legacy entry-only file genuinely *is* an entry from its first line, so a stricter fallback would
refuse documents consumers are carrying right now.

**How a document gets into that state is not a deliberate deletion.** It is an edit that anchors on the first
phase heading as a plain string and truncates the file there. In a document scaffolded before
[#1654](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1654), that string occurs **twice** —
once as the real heading, and once inside the guidance blockquote describing it, which comes *first* — so the
cut lands on the wrong one. Two documents shipped that way before this gate existed
([#1632](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1632) and #1644), and the failure is
silent because the file still *looks* plausible: the guidance block is long and reads like content. The
guidance names that heading by position now, so a document scaffolded since carries it once — but every branch
open across that change still carries both, which is why the refusal keeps naming the literal as a diagnosis
rather than dropping it.

**`-Force` is honoured**, matching the scaffold gate below rather than being absolute. There is no document
this workflow wants pushed in this state, but the predicate reads a *shape*, and a consumer holding a document
shape nobody upstream has seen needs a way past a gate that is wrong about them. Under `-Force` it warns and
says plainly what will happen: the fold will paste the guidance into the changelog as this change's
description.

**The remedy is `new-branch`, which is idempotent** — run it on the branch and the section is restored, then
write what the change does. The refusal says so.

**The same predicate runs in CI**, ahead of the same scaffold check in `check-branch-entry.ps1`, so there is
one definition in `entry-scaffold-lib.ps1` rather than two free to disagree.

## The scaffold gate: has the entry actually been written?

`new-branch` creates a changelog entry as a **scaffold** — a placeholder title, a
`**To do / where I left off:**` heading and a prompting body — for whoever finishes the branch to
replace. This gate refuses to push while that wording is still there.

**It is not a hypothetical.** In the source repo, three of one release's twenty-one entries kept that
heading with a status appended behind it (`**To do / where I left off:** done -- lint gate green`). A
progress note: correct on the branch, wrong the moment it is published. It reached the release notes
*and* the per-plugin `CHANGELOG.md` files that travel to consumers in the plugin cache.

**The window closes at the merge, and it closes invisibly.** The fold moves the entry into
`CHANGELOG.md`; the next release moves it on into `releases/` and empties the Pull-Requests section. So
by the time anyone would review it, the place they would look is the one place it no longer is.

The wording is **repo-owned** — whatever `Get-EntryTitlePlaceholder`, `Get-EntryBodyHeading` and
`Get-EntryBodyPlaceholder` say in your `scripts/repo-config.ps1`, or the English defaults. The gate and
the script that writes the scaffold read it from the same shared library, so they cannot disagree.

- **Fenced code is excluded**, so an entry that documents this mechanism is not accused of it.
- **`-Force` ships anyway** (a warning instead of a block), for the rare entry that legitimately quotes
  the wording outside a fence. Deliberately separate from `-SkipLint`/`-SkipTests`: those skip a tool,
  this overrules a judgement about content.

## The shape gate: does the document around the entry still hold its form?

The gate above reads the entry. This one reads the **document it sits in**: the phases that carry the step
list, and the generic block between the title and the first of them.

Two rules, and they are scoped differently on purpose:

- **Branch content above the first phase heading is refused, in every repo.** That region is the
  scaffolder's guidance and is meant to be identical in every branch document in every repo, so a status
  note there reads as guidance — and a reader who finds one branch's state inside it learns to distrust the
  whole region, including the rules that *do* apply everywhere. The check reads the **shape** and not the
  words: guidance is a blockquote in whatever language you translated it into, so a translated block passes
  and your own paragraph does not.
- **An extra heading at the phase level is refused only in the repo that authors this workflow.** Your
  repo's guarantee is the opposite one — the step gate reads step marks only, so a heading of any level is
  invisible to it — and refusing a heading you deliberately keep would break a document that worked
  yesterday. So this half never fires here.

**The level is read off your document, not pinned.** The first heading is the title and the phases sit
exactly one under it, so a document written before the levels shifted is judged by its own levels rather
than refused, and every finding quotes the level it actually read.

**Why it is a gate here and not only in CI** (source repo
[#1650](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1650), September 8, 2026). Both
rules used to live only in `check-branch-entry.ps1`, which **reports** rather than refuses. A document that
had lost its first phase heading — to an edit that anchored on the string `### PLAN`, which occurs inside
the guidance blockquote as well — then shipped through push, the required check, the merge and the fold,
with every other gate correctly green. And the fold **removes** `dkj-policy/<branch>.md` on success, so
afterwards the red check pointed at a path that no longer existed. Here the refusal lands while the file is
still on disk.

- **Fenced code is excluded**, so a document that quotes a phase heading is not accused of writing one.
- **`-Force` ships anyway** (a warning instead of a block), like the scaffold gate above: the check reads a
  shape, and a document nobody upstream has seen must have a way through a gate that is wrong about it.
- **The most common cause is not a hand-edit.** It is a tool or a splice that anchors on the first phase
  heading as a string. If you write one, anchor on the heading at the **start of a line**.

## The link gate: do the entry's links survive the fold?

The entry is the DEPLOY section of `dkj-policy/<branch>.md`, and the fold copies its text
**verbatim** into your `CHANGELOG.md`. So a relative link in it has to resolve from **that file's directory**,
which is not necessarily the one you are typing in — and where the two differ, the correct link looks wrong
until it moves.

**The base is your `Get-ChangelogPath`, read the same way the fold reads it.** Left unset, a repo that
publishes no plugin marketplace gets `dkj-policy/CHANGELOG.md` — the same directory as the
document — so there the link that already reads correctly in front of you is the correct one. The source repo
keeps its changelog at the root, and there it is the other way round:

```markdown
See [the lib](scripts/lib/release-lib.ps1).       <- correct where the changelog is at the ROOT
See [the lib](../scripts/lib/release-lib.ps1).    <- correct where it sits BESIDE the document
```

This gate refuses to push while a relative link in the entry does not resolve at that destination, and it
prints **the form the destination needs** rather than only the dead one. That second half is the point: a
finding that says only *"does not exist"* sends the author to add another `../`, which breaks a link that was
right.

**It tries two bases for that suggestion** — the document's own directory first, then the repo root. The
second exists for the author who followed the older wording: a root-relative link, correct everywhere until
the changelog isolated, would otherwise be the one finding with no way out named (inbound
[#967](https://github.com/DKJ-Solutions/claude-code-specialists/issues/967)).

**And the refusal names the two directories it actually compared**, rather than restating the convention.
Until #967 it named the repo root and `dkj-policy/branch/`, and on the shipped defaults neither
was in play: the first was the seam's old default, and the second was where the entry sat before it became a
section of the cycle document.

- **Only relative targets are judged.** `http(s):`, `mailto:`, a pure `#anchor` and an absolute `/path`
  are not resolved against a directory, so the move cannot break them.
- **Code and comments are excluded** — fenced blocks, inline backticks and HTML comments alike. Measured
  on the source repo's own entry file: across its last 80 revisions a scan without the *inline* exclusion
  produces exactly one finding, and it is false — `` `[PR #N](url)` `` in an entry explaining what the
  fold writes.
- **The anchor is dropped**, so `file.md#section` is judged as `file.md`. Whether the heading exists is a
  different question, and your own linter is the one that answers it.
- **Not `-Force`-able**, like the impact gate: `-Force` exists for text somebody legitimately wrote, and
  there is no legitimate dead link. The fix the message spells out is a one-line edit.
- **Refused here and not at the fold**, which is where inbound
  [#806](https://github.com/DKJ-Solutions/claude-code-specialists/issues/806) asked for it. A defect decidable
  before the merge is caught while the branch is still the only thing affected; refusing an
  already-merged branch's fold would leave an unfolded entry on the trunk with `main` looking finished. A
  fold-time *rewrite* is declined for a second reason — the fold copies the entry verbatim on purpose, and
  an author whose link is silently corrected writes the same link again into the next document, where
  nothing corrects it.

The convention is also stated in the guidance comment above the section you type the body into, so it
arrives before the gate does -- in the document itself since August 23, 2026, where it used to live in a
reference copy one directory away.

## The step-list gate: is the branch's own plan finished?

A branch carries one document with two halves. The DEPLOY section says what the change does; the PLAN,
CREATE and TEST phases above it say what still has to happen. **A branch reaches a PR when its own plan is
finished**, so this gate refuses to push while any step is unresolved -- counting only above the DEPLOY
heading, because a checkbox inside an entry's prose is prose. Three marks:

```text
- [ ] not done yet          -> blocks the PR
- [x] done
- [~] dropped -- <why it turned out not to be needed>
```

**The third mark is the reason the gate is safe to make unforceable.** A plan legitimately grows items
that stop making sense. A gate offering only "tick it" teaches people to tick boxes for work they did
not do — and then reports success, which is worse than no gate at all. A dropped step keeps its line and
its reason on the page, which is the half worth reading later.
- **A step still carrying the scaffold's placeholder is refused, ticked or not.** Ticking the
  scaffolded first step without replacing it reports a plan as finished that was never written — the
  same shape the scaffold gate above was measured on, one file over. **No mark resolves this one**, and
  the refusal now says so on the finding's own line: the fix is to replace the placeholder text with the
  step you actually took, or to delete the line if the plan grew past it. Both findings printed the same
  advice until [inbound #1081](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1081), which
  was measured on a virgin repo as a loop — the author followed the marks it offered, was refused again
  by the same gate, and read "there is no `-Force` for this gate" as *you are stuck* rather than as
  *you have used the wrong tool for this finding*.
- **No step list at all is not a finding.** A branch created by hand rather than by `new-branch` has no
  document at all, and so no steps. That is the one-commit typo fix; refusing it would
  make the mechanism ceremony rather than a tool.
- **Fenced code is excluded**, so a step list that quotes the convention is not accused of following it.
- **There is no `-Force`**, deliberately, unlike the scaffold gate. `-Force` exists for text somebody
  legitimately wrote and wants to keep; here `- [~]` already is the sanctioned way past a step that
  should not be done, and a second escape valve would only ever be used to skip the first. That reasoning
  covers an *open* step; a scaffolded one is not stuck behind a missing escape valve either, it simply
  needs its text rewritten rather than marked.

`ship-pr` runs this check **again** before the merge. Not belt-and-braces: the requirement is about the
merge, and a PR opened through `-Force`, by hand on github.com, or days ago and resumed would otherwise
land with an unfinished plan.

## The label gate: does the label your seam names still exist?

The PR is labelled from the branch prefix -- `fix/` -> `bug`, `feat/` -> `enhancement`, whatever your own
`scripts/lib/branch-info.ps1` says -- and that label used to go straight to `gh pr create --label`, with
`gh` as the one to discover it does not exist. `gh` refuses the **whole** create, so no PR is opened:

```text
resolves gate: this PR closes no issue.
could not add label: 'bug' not found
Creating the PR failed: could not add label: 'bug' not found
```

**What made that expensive is *when* it landed, not that it landed.** Every gate above had already
passed and the branch was already on `origin`, the remedy was outside the script (create a label, or
edit the seam table), and the state left behind -- a pushed branch with no PR -- reads exactly like a
parked branch. So one `gh label list` now runs **before the lint and test gates**, and a label that does
not exist is refused there:

```text
label gate: 'bug' is not a label in <owner>/<repo>, so 'gh pr create' would refuse this PR -- refused
HERE instead, before the push. The label comes from the branch prefix 'fix/' via
scripts\lib\branch-info.ps1, which is repo-owned: this script cannot validate it against a list of its
own, so it asked GitHub. Labels that do exist: 'documentation', 'inbound' and 'question'. Two remedies,
and this script takes neither: create the label (gh label create 'bug' --repo <owner>/<repo>), or point
the prefix at a label that exists (scripts\lib\branch-info.ps1). ...
```

**It is not your mistake, which is why it is a gate rather than a better error message.** Measured in a
consumer on September 1, 2026 (inbound
[#1221](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1221)): `bug` and `enhancement` were
deleted org-wide because the issue **type** now carries that classification. The seam table was correct
the day before and nothing in the consumer changed. Any repo that renames or retires a label breaks the
same way, and the first sign of it was a failed create after a push.

- **It refuses and does not fall back.** Substituting a default label would classify the PR wrongly, and
  a repo that **gates on the label** -- a `pr-guardrails.yml` reading it, say -- would go green on a
  label that says nothing. Dropping the label is worse: that gate would then go red *after* a successful
  create. Both silent options look like kindnesses; neither is taken, and the two real remedies are
  named instead.
- **The unknown-prefix fallback is checked too.** A branch whose prefix your table does not know is
  labelled `question`, which is a GitHub *default* label a repo may equally have deleted. The check is
  on the label that would be **sent**, whatever produced it.
- **Create path only.** A PR that already exists keeps its own labels and is never sent one, so a label
  retired after the PR was opened does not block an update.
- **Not `-Force`-able**, like the link and impact gates. `-Force` exists for text somebody legitimately
  wrote; a label that does not exist is a fact about the repository, and waving it through could only
  move the failure back to after the push.
- **A query it cannot read is not an answer.** An old `gh` without `--json`, a network hiccup, or a repo
  with no labels at all leaves you with the behaviour this script always had: a warning, and `gh`
  judging the label at the create. The gate never becomes the reason a PR cannot be opened.
- **A seam that names NO label is an answer, and the one case where this gate has nothing to do.** If your
  prefix table answers `Label = $null` -- a repo that has abolished PR labels entirely, because the issue
  **type** carries the classification now -- there is no lookup, no compare, and the create sends **no
  `--label` at all**. Read it against the first bullet rather than as an exception to it: that one is
  about a label your seam *named* and your repo does not have, where dropping it would sail a PR past a
  workflow gating on the label. This one is your repo saying there is no label, so sending none is the
  answer you gave. Inbound
  [#1395](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1395), measured in a consumer on
  September 4, 2026: `--label` was appended unconditionally, so an empty answer went out as
  `--label ''` -- a label named `''`, which `gh` cannot find and refuses the whole create over, after
  the push, with this gate green. The gate had always read an empty label as "nothing to check"; it was
  the create that had not.

## The impact gate: how far does this change reach, and how much does it weigh?

The **DEPLOY section holds the tiers** the repo asks about, each with a reason and a score from 1
to 5. That is **tier 0 plus the single audience tier** `Get-ReleaseAudienceTier` names — and since
August 19, 2026 neither says so out loud:

```text
### DEPLOY: feat/short-name

The routine version bump stops needing a developer.

**Score:** 4

#### What makes this deploy extra special

Consumers must re-add the marketplace under its new name.

**Score:** 5
```

**Tier 0 is in every entry and is the one tier that can never be `N/A`** — every change reaches the people
maintaining the repo at least a little. It answers directly under the DEPLOY heading; the `####` heading
beside it means whichever audience tier the repo stated. A repo that has stated **none** gets the
older shape instead, a `##### Tier N` sub-section per tier the model has, tier 0 among them. This block
showed `#### Tier 1` above `#### Tier 2` and no tier 0 at all until August 13, 2026, which is a shape the
scaffolder writes under no configuration.

The **tier** (`0` = only this repo's own developers notice, `1` = management and the employer/commissioner
get something out of it, `2` = a subscriber of the service notices it) decides which release documents the
entry appears in, and where the
repo's entries declare their impact at all the release cut refuses a bump the pending tiers have not earned.
The **significance** decides where *in* the list the entry sits — `CHANGELOG.md` is one flat ranked list, and
the release documents inherit the order the fold leaves — so the most consequential change leads.

**What it read is printed on every run**, including when nothing was declared and the default applied. That
line is the point: an entry still sitting at tier 0 is work that cannot carry a release on its own, and this
is the last moment to raise it cheaply — the fold ranks the entry as it lands, and after that a correction is
a re-insert on the main branch.

**A malformed table is refused; a missing score is only reported.** That split is by kind of fault, not by
convenience:

- **Refused** — a cell the model has no meaning for (`| 2 | 9 | … |`, `| 5 | 3 | … |`). It reads back as
  unscored, which would sink the entry to the bottom of the list it matters most in — correct-looking
  and silent. Here it is a one-cell fix; after the merge it is an edit on the main branch.
- **Reported, not refused** — a row or score that is simply missing. The score is a judgement about a
  finished change, and an author who has not settled it should not be blocked from merging over it. The
  **release cut** is the refusal point instead, and the message names every entry and every missing cell.
- **A low score is never refused.** Like `Tier: 0`, a significance of 1 is a legitimate, common and final
  answer, which is why this is a separate gate rather than part of the scaffold one.

- **Fenced code is excluded here too**, so an entry that documents the impact format is read by its real
  declaration rather than by the one it quotes.
- **`-Force` does not apply.** It exists for text somebody legitimately wrote; there is no legitimate
  `| 2 | 9 | … |`. Correct the cell — it is a one-character edit.
- **`Tier: N` is still read**, so an entry written before the table folds and ships exactly as it did.

## The resolves gate: which issues does this PR close?

**A plain `#332` in a PR body closes nothing.** GitHub only auto-closes an issue when the body uses a
*closing keyword* (`Closes #332`), so a PR that repairs an issue and merely mentions it leaves that
issue open — and the changelog then says "done" about something the tracker still lists as open. That
is not hypothetical: three consecutive PRs in the source repo did exactly this and left **eight**
repaired findings open.

So the decision is forced rather than remembered:

```powershell
# this PR resolves them -- each gets its own 'Closes #<n>' line in the body
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -Resolves "331,332"

# this PR resolves no issue (they are cited as context)
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -NoResolves
```

- **Neither flag, while the changelog entry mentions an issue that is currently open** → the script
  stops **before** the lint, the tests, and the push, and names the issues it saw.
- **PR references do not count.** `PR #341`, `PRs #341-#343` and `/pull/341` links are excluded, so
  citing the PR you follow on from does not trip the gate. A gate that fires on every branch gets
  bypassed, which is how it would quietly stop working.
- **A `-Body` you supply that already says `Closes #332`** satisfies the gate on its own, and so does
  the body of a PR that is **already open** for this branch — otherwise resuming a branch would be
  blocked for not repeating a decision GitHub already holds and will honour at the merge.
- **`-NoResolves` is remembered the same way**, since
  [#1912](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1912): it writes
  `<!-- resolves: none -->` into the body, which the gate reads back on a later run. **Pass it once,
  not once per command.** Before that it wrote nothing, so the two honest answers were not
  symmetrical — one published, one gone the moment the process ended — and the very next run refused
  the branch: measured on `feat/1843-portable-repo-settings-runner`, where `open-pr -NoResolves`
  opened PR #1909 and `ship-pr` (whose step 1 re-runs `open-pr`) was blocked for a question that had
  been answered minutes earlier. The cost was never the seconds; it is that the obvious way out —
  passing a flag again to get past a gate — is the reflex this gate exists to prevent. A later
  `-Resolves` on the same branch **strips** the marker, so a body never claims both.
- **If the open/closed state cannot be determined** (no `gh`, or it errors), the gate **warns and
  lets the PR through**. Wedging the PR flow on a network hiccup would be worse than the bookkeeping
  slip it guards against.
- `-Resolves` takes a **string** (`"331,332"`; a leading `#`, spaces or semicolons are fine).
  Deliberately not an array: across `powershell -File` a comma list is cast to a single number via
  the thousands separator, so `-Resolves 332,340` would silently become issue `332340`.

**An issue somebody else has to close by hand is `-NoResolves`, not `-Resolves`** — and the flag is
where that distinction is *made*, because `Closes #<n>` hands the decision to GitHub at the merge, where
no person is present. Whether it is also *checked* is the seam below. The measured case is
`dkj-policy-bwj`: an issue with a mirrored Asana task carries a paste-ready block that the shipping
session writes while the issue is **open**, and closing it is a person's confirmation that the block
reached Asana (inbound
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049)). A `Closes #<n>` bypasses
that silently — the issue closes at the merge, the confirmation never happens, and nothing reports it.
So such a branch ships with `-NoResolves` and cites the issue as context.

- **That is a real cost, not a free answer.** `-NoResolves` is also what a PR says when it resolves
  nothing at all, so the two are indistinguishable in the body, and this gate exists precisely because
  a repaired issue left open is a tracker that disagrees with the changelog. What makes it the right
  answer here is that a person closes the issue minutes later as a deliberate act, so the window is
  short and somebody owns it — rather than a keyword that decided it while nobody was looking.
- **Whether a third answer should exist is open**, and #2049 names it rather than assuming it: a flag
  that declares the citation deliberately, without a closing keyword, so the body can say *"this PR
  repairs #n and a person closes it"*. That is a larger change than a wording note and is not made
  here.

### `Get-ResolvesExemptMatchers` — naming the class of issue a merge must not close

**The rule above was enforced by memory alone until inbound
[#2120](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2120)**, and the measurement is what
that costs: an issue carrying an `asana-task:` marker shipped with `-Resolves`, the merge closed it, and
the mirror posted its fallback handover afterwards — the weaker route the rule exists to replace. No gate
objected, because none read the issue's body. The rule was followed correctly on other issues in the same
period, which is the point: the difference was whether the session remembered.

So a repo can state the class in `scripts/repo-config.ps1`:

```powershell
function Get-ResolvesExemptMatchers {
    return @(
        @{ Name    = 'an Asana task marker'
           Pattern = '<!--\s*asana-task:\s*[0-9]+\s*-->'
           Why     = 'the handover is pasted onto the issue while it is open, and closing it is a person''s confirmation that it landed.' },
        @{ Name    = 'an Asana task link'
           Pattern = 'https://app\.asana\.com/' }
    )
}
```

- **`Pattern` is required; `Name` and `Why` are not.** `Name` is what the refusal calls the thing it
  recognised, `Why` is the repo's own one-line reason. A bare string is read as a pattern named after
  itself, which is the shape most people write first.
- **Matched case-insensitively against the body of every issue the merge would close** — which is
  `-Resolves` *plus* any closing keyword already published on an open PR for this branch. That second
  half matters: `-NoResolves` does not strip a keyword the body already carries (this script only ever
  *adds* a closing block), so a gate reading the flag alone would be skipped by the very flag its own
  refusal recommends. Where the PR already carries one, the refusal says so and points at `gh pr edit`.
- **Most-authoritative first, and the first match wins.** One issue, one reason — a second matcher on the
  same body would add a sentence and no decision. Write the machine marker before the link a person typed,
  which is the order a ticket mirror already resolves them in.
- **Unstated is the default and costs nothing.** The seam is read *before* any lookup, so a repo with no
  second tracker makes no extra `gh` call, sees no message, and keeps exactly the gate it had before. This
  is a seam rather than a built-in rule for that reason: a matcher names another system's marker, so a
  canonical one would be one family's tracker imposed on everybody else's.
- **A pattern that does not compile is reported and skipped**, and the other matchers still apply. It is
  the one failure a repo cannot see from the outside — a silently dropped matcher is indistinguishable
  from the class not being there — so it is named rather than swallowed.
- **Every match is bounded at two seconds**, and a match that does not finish is reported rather than
  read as "no match". The two inputs are a pattern *your repo* wrote and a body *anybody who can open an
  issue* wrote, which is the catastrophic-backtracking pair exactly; unbounded, a pathological pattern
  and a crafted body hang `open-pr` for whoever resolves that issue. The remaining matchers still run,
  so one bad pattern is not a verdict about the rest of the list.
- **An issue whose body cannot be read is warned about and not blocked on**, the same direction every
  other lookup in this gate takes: wedging the PR flow on a network hiccup would be worse than the slip
  it guards against.

## The claim check: an issue this PR closes is not left unowned

**The gate above answers "which issues does this PR close". This asks who is holding them** — and it
exists because there is a way an issue enters a branch's scope that no pickup check can see
([#2284](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2284)). The
[`claim-issue`](../claim-issue/SKILL.md) step is bound to *starting* an issue ("fix issue 1234"); a
finding you file mid-branch and then repair on the branch you are already on is never started, so it is
never claimed, and on the tracker it reads exactly like an untouched issue.

**Measured, September 22, 2026:** #2272 was filed from `fix/2248-guard-raw-foreign-text-prints` and
repaired there. Another session read it as unowned — correctly — picked it up and shipped it as
PR #2275. The first branch's PR then went `CONFLICTING` on the file both had changed, and reconciling it
took a trunk merge, a hand conflict resolution, three corrected documents and a second ship.

So before the push, for each issue **this PR declares it closes**:

| what the tracker says | what happens |
|---|---|
| **held by this checkout's account** | nothing — the ordinary path |
| **unassigned** | **claimed**, and one line says so |
| **held by somebody else** | a warning naming the holder |
| **could not be read** | nothing said, nothing written |

- **The subject is the DECLARED set, never the mentioned one.** This workflow prescribes citing issues
  in prose, and claiming every mention would make the assignee field meaningless across a backlog nobody
  is on. `Closes #<n>` is the author stating that this branch repairs that issue — so claiming it writes
  strictly less than the body this run is about to publish already does.
- **It costs no round trip.** The assignees come off the open-issue list this gate already fetches; the
  query asks for one more field.
- **It claims under the account `claim-issue` would resolve, never `@me`.** `@me` binds to whatever `gh`
  is authenticated as, while the branch a second session correlates the claim with carries the *git*
  identity — so on a split checkout `@me` claims under the wrong name in silence
  ([#1315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1315)).
- **A read that did not answer is never read as "free".** An issue the open list could not account for
  is left alone; the opposite direction would hand out claims on other people's work.
- **It never blocks.** A claim that wedges a real PR costs the whole assignment
  ([#1485](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1485)), and this check cannot tell
  a rival from a colleague who is also on the thread. A foreign holder is a warning and the push goes on.
- **It is a backstop, not a substitute for claiming it yourself.** It fires at the push, which is the end
  of the branch, and it performs none of `claim-issue`'s scans — the parked fix, the title overlap, the
  branch weight — all of which are about work already under way somewhere else.

## Requirements in the consumer

The script is repo-agnostic, but reads its repo data from the **root** of the consumer
(dual-context via `${CLAUDE_PROJECT_DIR}`):

- `scripts/repo-config.ps1` with `Get-RepoName` (the `gh --repo` target) and `Get-LintScript`
  (repo-root-relative path to the repo's own lint gate). `Get-ResolvesExemptMatchers` is optional and
  unstated by default — see the section above.
- `scripts/lib/branch-info.ps1` (label/type from the branch prefix).
- `scripts/tests/*.tests.ps1` (the test gate; convention, not config).
- `.github/pull_request_template.md`, `git`, and a logged-in `gh` CLI.

The `specialists-init` bootstrap puts `repo-config.ps1` + `branch-info.ps1` in place as a `VUL-IN`
scaffold. If they are missing -- or still set to `VUL-IN` -- the script stops before the dot-source
with a clear pointer instead of a raw error (#86); fill them in first (see the source repo as a
model).

## Important

- **When a PR may be opened is governance, not script logic** -- the repo's own rule decides that;
  this script only executes. Under the shared rule a PR opens by default once the branch is done and
  the gates are green, and waits for the owner's word only for work with a visible result or work
  that is irreversible/outward-facing.
- This script is maintained in the source repo; do not modify it locally in the consumer. A
  change lands first in the source (`scripts/release/open-pr.ps1`) and then travels via a release to
  the plugin mirror -- guarded by the shared-scripts drift lint.
