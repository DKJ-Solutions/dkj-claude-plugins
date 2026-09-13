---
name: new-branch
description: >-
  Create (or idempotently resume) a git branch AND its development document --
  dkj-policy/<branch>.md, the branch's plan and the DEPLOY section that becomes its
  changelog entry -- in one move, via the shared, centralized new-branch script from the plugin
  (single source of truth, issue #81), so a consumer does not have to duplicate this script locally.
  Use this whenever a new piece of work starts: a branch is never entry-less -- creating it brings that
  document to life in the same step, instead of a separate later scaffolding step.
---

# new-branch -- the shared branch+entry creator for consumers

This is the **plugin mirror** of `new-branch.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it. Background in
[issue #81](https://github.com/DaveKJohn/claude-code-specialists/issues/81).

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" -Name "<prefix>/<short-name>" -Title "short title"
```

**In the source repo, run its own copy instead -- `scripts/task/new-branch.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

The script:

1. Validates the branch name via the shared SSOT helper `Test-BranchName`
   (`scripts/lib/branch-info.ps1`) -- hard-rejects an empty name, `main`, or a name containing
   `final`; soft-warns (but proceeds) on an unknown prefix.
2. **Uses the name exactly as given** -- it does *not* complete a `-v<N>` suffix (it did, from
   August 23 to September 3, 2026; in 209 branches that reached a merge with it, none was ever bumped
   to `-v2`, and the completion was the direct cause of inbound #1224). A `-v<N>` suffix is still valid
   and still the honest way to say "another round of this" -- it is simply typed by hand now, and
   nothing rejects it. `new-branch` stays idempotent, so a second run on the same name *resumes* that
   branch instead of opening another one, which is what the `-Park` flow needs. The full reasoning is in
   [`DEVELOPMENT-portable.md`](../../DEVELOPMENT-portable.md#the-version-suffix).
3. **Asks whether this is a resume or a cut**, reading *both* ref namespaces -- `refs/heads/<name>` and
   `refs/remotes/origin/<name>`. That question comes first because the answer decides whether step 4 has
   a base to talk about at all.
4. **Measures the base it is about to cut from** and **refuses** if it is behind `origin/<trunk>`, naming
   the count and `-SkipStaleBase` -- see below. It does not move `HEAD` for you either way; refusing is
   how it avoids having to. Skipped on a resume: the count is `HEAD..origin/<trunk>` and on a resume
   `HEAD` is whatever you were standing on, so it would hand you the trunk's gap under the resumed
   branch's name -- which is also why a resume is never refused.
5. Creates or resumes the branch -- **idempotent**, in three shapes:
   - it exists locally -> `git checkout <name>`;
   - it exists **only on `origin`** -> `git checkout -b <name> --track origin/<name>`, i.e. created **at
     the remote tip**, carrying the parked work, and the run says in so many words that this is a resume
     rather than a new branch (issue #1139 -- see below);
   - neither -> `git checkout -b <name>` from the current base.
   Where it exists in **both** places and `origin` is **ahead**, the run warns with the count and the
   remote tip's author and subject -- another session's work on the branch you are about to build on
   (issue #1439 -- see below).
6. Immediately writes that branch's **`dkj-policy/<branch>.md`** -- so the branch and its
   document come into existence in a single step. Idempotent: a document that already belongs to this
   branch is left exactly as it is, and one belonging to somebody else is replaced with its owner named,
   unless it holds uncommitted work, which is kept and reported instead.

## The base a branch is cut from (inbound #1046, decided in #1417)

`new-branch` used to cut from whatever `HEAD` held and never look, in a run that reaches `origin`
moments later to push.

**What that cost, measured in a consumer with two sessions on one board:** a branch cut from a trunk 17
commits behind `origin/main`, to fix an issue the other session had closed by a merged PR four minutes
earlier. The result was a complete duplicate of already-merged work -- branch, commit, PR, and every
gate green on both -- found only when the PR sat without a CI check. The claim step does not catch this
and it looks like it should: `gh issue edit <n> --add-assignee @me` **succeeds silently on a closed
issue**.

So `new-branch` measures `HEAD..origin/<trunk>` and acts on what it found:

| what it reads | what it does |
|---|---|
| the base is behind by N | **refuses**, naming N, the local remedy (`git pull --ff-only`), the lane route, and `-SkipStaleBase` |
| the base is behind by N, and `-SkipStaleBase` was given | cuts anyway, warning with N -- **twice**, once before the checkout and once as the last line of the run |
| the base is current | one dim line saying so, so silence is never ambiguous |
| no `refs/remotes/origin/<trunk>` in the repo | one dim line saying the question could not be asked -- no fetch is attempted and no gap is claimed |

**It refuses, and the refusal costs nothing**, which is the argument for it. The check sits *before* the
checkout, so a refused run leaves the tree exactly as it found it: no branch, no document, no commit, no
push, nothing to unpick -- and one `git pull --ff-only` resumes the same command. That is the same
property `fold-changelog-entry.ps1` cites for its own refusal (#1405).

**It cannot reach a resume, and that is structural rather than a promise.** #1046 warned instead of
refusing, because this script is mirrored into every consumer's plugin cache and arrives by plugin
**update** rather than by choice -- landing a refusal nobody asked for on the script you are told to
re-run to resume a parked branch. #1417 held that against the code: the whole base block is gated on
*"not resuming"*, so a resume never reaches the question. What is refused is only a **new** cut from the
base you happened to be standing on, which is the case #1046 measured. The mirroring argument survives
as the **valve** -- one flag, not a hand-typed `git checkout -b`.

**And the lane was never the precedent it read as.** `worktree-lane.ps1` does not refuse a stale base;
it refuses a failed **fetch** and then bases its worktree at `origin/<trunk>` outright, so it has no
stale base to refuse. Its answer is to remove the choice, which this script cannot copy -- it does not
move `HEAD` for you. The lane therefore passes `-SkipStaleBase` when it delegates here: it chose the
base itself, seconds earlier, and there is no operator decision left to gate.

**No threshold.** Refusing only above N commits was considered and declined: the duplicate #1046 measured
was of a PR merged *four minutes* earlier, so the dangerous gap can be a single commit.

**Why the warning is said twice under the valve.** Everything this script prints after the check -- the
scaffold, the tier rubric, the commit, the push -- sits between the first copy and the end of the run, so
a single line at that depth is off-screen by the time you read anything. The bottom copy is the one that
gets read, and under the valve it is the whole record that the valve was used.

**`HEAD..origin/<trunk>`, not a trunk-versus-origin comparison**, deliberately: it answers *"what is my
base missing"*, so a branch intentionally stacked on another branch gets the gap it actually carries
rather than a reading about a trunk it was never cut from. **The local question gates the network one** --
the remote-tracking ref is read first, which is what keeps the script usable offline and costs nothing in
a repo that cannot answer. In a lane worktree (detached at `origin/<trunk>`) it reads 0, so the route that
already handles this hazard is never warned about.

## The already-done check (issue #1409)

`open-pr` already warns when the issue a PR declares turns out to be closed, or claimed by a rival PR
(`Get-TargetIssueWarnings`, from #1282) -- but that is the LAST step of a branch's life, after the
checkout, the commits, the reviews and the test runs. #1409 measured what that costs: a branch was cut
to fix an issue claimed correctly (open, unassigned, claimed by name), and only `open-pr` -- after two
commits, a full development document, two subagent reviews and 65 test suites -- reported that a rival
PR had already closed it seven minutes after the claim. The claim step cannot catch this either: the
other session never assigned itself, so the issue read as untouched rather than as someone else's live
work.

**`-Resolves "<n[,n...]>"`** runs the same check here, before the checkout, so the same duplicate is
caught before any of that cost is paid:

| what it reads | what it does |
|---|---|
| the target issue is CLOSED, or another open/merged PR already carries a closing keyword for it | **warns**, naming the issue and what it found -- twice, once before the checkout and once as the last line of the run |
| the target issue is open and unclaimed | nothing -- silence, same as the base check above when there is nothing to say |
| `scripts/repo-config.ps1` supplies no `Get-RepoName` | one line saying the check is skipped -- `gh` is never called |

**It warns and never refuses**, for the same reason #1282 chose that shape at `open-pr`: a shared
number, a reopened issue, or a rival PR abandoned mid-flight must not wedge a real branch.

**It narrows the window rather than closing it.** It only ever sees what `-Resolves` is given here --
an issue decided later, or only named in `-Intent` text, is invisible to it, because there is no PR
body yet to scan. This is a **separate declaration** from `open-pr`'s own `-Resolves`: that gate
answers a different question (does the PR body declare what it closes) at a different time (once the
PR exists) -- passing one here says nothing to the other, and both are typed independently.

**`gh` is optional, and this is the only place on this page that asks for it.** It is asked for only
once `-Resolves` is given -- the ordinary run, with no issue number, asks nothing of `gh` and stays
exactly as usable offline as the rest of this script.

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" `
  -Name "fix/1402-something" -Title "Fix something" -Resolves 1402
```

## Resuming a branch that exists only on `origin` (issue #1139)

**A parked branch IS this workflow's cross-device handoff**, which is what makes this more than an
ordinary local/remote slip. `new-branch` pushes by default so the branch is reachable from another
device, and the `cycle-autopark` Stop hook keeps it current on `origin` until a PR publishes it -- so the
flow *actively produces* branches whose only copy is on the remote. Until August 30, 2026 `new-branch`
asked one ref, `refs/heads/<name>`, and read the miss as *"create it"*: the script documented as
idempotent, the one you are told to re-run to resume, was the one blind to exactly those branches.

**And neither half of the run looked wrong.** A clean run is what idempotence promises, and the scaffold
written into the fork is byte-identical to the one already on the parked branch, because the same script
wrote both -- so even reading `<branch>.md` afterwards shows nothing. What is missing is the branch's
**work**, and nothing on screen is about work. `worktree-lane.ps1` inherited the whole failure through
its delegation, with its worktree already detached at `origin/<trunk>`, and reported `Lane open` exactly
as on a genuine new branch.

Both namespaces are read now, and the run names which of the three things it did:

| what it reads | what it does |
|---|---|
| `refs/heads/<name>` exists | `git checkout <name>` -- unchanged |
| only `refs/remotes/origin/<name>` exists | `git checkout -b <name> --track origin/<name>` -- created **at the remote tip**, with the parked work, reported as a **resume** and not as a new branch |
| neither | `git checkout -b <name>` from the current base |

**It resumes rather than refusing, and it is loud about it.** Refusing and printing the `git branch
--track` line would also be honest, but this script is the documented resume tool for a handoff the
workflow creates on its own, so refusing puts a hand-typed git command on the intended happy path. What
is ruled out is a *silent* adoption: an assignee is a claim rather than a locked door, and a script that
quietly takes over somebody else's remote branch makes that claim unreadable. So the run says the name
was already taken and what to type (`-v2`) if you meant a new branch instead.

**The local question gates the network one here too.** `refs/remotes/origin/<name>` is a remote-*tracking*
ref, read from disk; nothing is fetched on its account. It is fresh because the base check above has just
fetched wherever there was an `origin` to fetch from, and where there was not, this reads whatever the
last fetch left -- so the script stays usable offline.

## The branch you resume has moved on `origin` (issue #1439)

#1139 above is about the branch with **no** local ref. The mirror case is the branch that exists in
*both* places, with the local one pointing at an **older** tip -- and until September 5, 2026 that was
read as a plain `already existed -- checked out`.

**What it cost, measured in the source repo.** Two sessions built `feat/plugin-policy-precedence` end to
end from the same parked commit -- the same three deliverables, a 508-line script, a new test suite, the
full lint gate and all 69 suites on each side -- and neither learned of the other until `git push`:

```text
 ! [rejected]          feat/plugin-policy-precedence -> feat/plugin-policy-precedence (fetch first)
```

**Every other guard in this workflow looks somewhere else**, which is why this one is worth its own
line rather than being a case of an existing check:

| guard | why it misses this |
|---|---|
| the claim rule (`gh issue edit --add-assignee`) | needs an issue number, and most branches have none |
| the branch check (`git status` + `git branch`) | both are local; with no fetch, `## <branch>...origin/<branch>` is the same line for "in sync" and for "never looked" |
| `prune-merged -IncludeRemote` | it is for branches you are **not** standing on -- this is the one case it cannot help with |
| `cycle-autopark` | makes it **more** likely, not less: it is what puts the other session's work on the shared ref |

So the local-ref route now counts `refs/heads/<name>..refs/remotes/origin/<name>` and, where `origin` is
ahead, names the count **and the remote tip's author and subject**:

```text
WARNING: 'feat/x' is 1 commit(s) behind origin/feat/x, whose tip is:
         952e676e Other Session: park: feat/x (all outstanding work).
         Another session or another device has pushed work to this branch that this checkout does not
         have -- read it before you build on top of it.
```

**The author and the subject are the point, not the count.** `park: ... (all outstanding work)` under an
identity that is not yours is the line that separates a collision from a fast-forward of your own
autopark; "1 commit behind" reads identically in both.

**The tip line is stripped before it is printed, and capped.** It is the one piece of text this script
emits that somebody else wrote: `%an` and `%s` are free text chosen by whoever pushed that commit.
Control and format characters go -- an ANSI or OSC escape in a commit subject repaints the terminal it
lands in, and an RTL override or a zero-width run makes the printed line read as something other than
what it says, deceiving the reader by the very line that exists to tell them whose work this is. The
words stay, because the subject only has to be *recognisable*; quoting would keep the payload and add
noise. A subject over 120 characters is truncated, so the half of the sentence that says what to **do**
is never pushed off the screen.

**The neighbouring case points the other way, deliberately.** `new-branch` already takes adversarial free
text -- a malicious `-Title` -- and its rule there is the opposite: land *fully and unchanged*, asserted
on an exact compare. That text goes into a **file**, where truncation is the damage. A console is not a
file, and the rule flips with the destination rather than with the text.

**It is NOT the only console this workflow writes somebody else's words to** -- that claim stood here
and was false from the day `ship-pr` began relaying the sentence a failing workflow wrote about itself
(`Get-AuthoredFailureNote`, `scripts/lib/pr-issues-lib.ps1`, #1103). **There are five**, and the count
is worth stating precisely because the wrong one is what kept the second site unguarded:

1. **This one** -- the remote tip's `%an` and `%s`, printed by `new-branch` and `open-pr`
   (`Get-RemoteAheadNote`, `scripts/lib/remote-ahead-lib.ps1`, #1439 and #1446). Capped at 120.
2. **`ship-pr`'s relay** of a failing workflow's own `::error title=...::` annotation
   (`Get-AuthoredFailureNote`, `scripts/lib/pr-issues-lib.ps1`, #1103). Capped at 500, and stripping
   the same class since
   [#1612](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1612).
3. **The note printed when a branch name is refused for a paste-ready command** (`Get-PasteableRef`,
   `scripts/lib/ref-print-lib.ps1`, #1594) -- because a guard whose refusal path is itself an injection
   surface is worse than no guard. Not capped.
4. **Every sentence this workflow prints a REF NAME into** (`Get-DisplayRef`,
   `scripts/lib/ref-print-lib.ps1`,
   [#1623](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1623)) -- thirty-two of them
   across `ship-pr.ps1`, `sync-main.ps1`, `remote-ahead-lib.ps1` and `worktree-lib.ps1`. `git
   check-ref-format` enforces `\p{Cc}` and **accepts** `\p{Cf}`, so a branch created by hand, cloned or
   fetched carries U+202E or a zero-width run straight into those lines; `sync-main`'s come off `git
   ls-remote` and its seam answers, which git never validated at all. Not capped.
5. **`claim-issue`'s own report** -- the issue TITLE off the tracker, plus the commit subjects and
   branch names its parked-fix scan prints (`Format-ForConsole`, `scripts/lib/claim-issue-lib.ps1`,
   #1858). The title is the one entry here whose author needed no push access at all: on a public
   tracker anybody can open an issue. Not capped.

**This entry is why the count was worth stating.** It was three until September 8, 2026, four until
September 11, and each new one arrived as a counter-example to a sentence that had stopped being
checked. **The list is the thing that has to be kept true, not the number in front of it** -- entry 5
sat outside it for as long as the list existed, guarded by an ASCII-only strip nobody had re-read.

The class itself is hand-typed in **three** libs, on purpose and knowingly: this one,
`ref-print-lib.ps1` and `claim-issue-lib.ps1`. #1594 re-typed it with this site already in place and
recorded why; #1623 retired a copy rather than adding one -- `remote-ahead-lib.ps1` acquired a reason to
load `ref-print-lib.ps1` for its own sake (its branch label, printed raw beside the subject it already
sanitised), and once the lib was loaded a private copy was pure drift surface. #1858 added one back, for
the two reasons that keep the others apart and one more: no function in `ref-print-lib.ps1` fits an issue
title. `Get-DisplayRef` collapses runs of spaces and trims, and a title is quoted evidence that must not
be re-spaced; `Get-DisplayPath` answers the all-stripped case with `(no printable path)`, the wrong noun
for a title -- so reuse would have meant a fourth function there rather than one regex fewer. The three
share nothing else -- different bounds, different source processes, and none of them loaded by another's
callers -- so what is guarded is that they cannot DISAGREE, by an assert in `pr-issues.tests.ps1` that
compares the patterns themselves and pins **which** libs carry the class. A reader who needs every place
this workflow prints foreign text now has the list, which is what the retired sentence was for.

**It costs no network call.** The base measurement above already fetches *every* ref (that is what
`-FetchAllRefs` is for, and #1139 is why), so the remote-tracking ref is on disk and as fresh as this run
can make it. Where the fetch failed, the sentence says which ref the count came from -- the same
distinction the stale-base warning draws.

**And where it found NOTHING off an unrefreshed ref, it says that too** (issue #1915). Finding no
divergence and never having looked produce the same empty answer inside, and printing the second as the
first is silence -- the guard reporting the shape of a clean branch on the one run where it is blind. So
a run whose own fetch did not refresh the ref now says so and hands over `git fetch origin <branch>`.
**The window is wider than a single failed fetch**: this script opts into the freshness seam's
`-RecentFailureSeconds` (#1860), so one transient failure suppresses the retry for the next 90 seconds --
which is the interval a claim, a cut and a resume all live in. The trunk-level line above it
(`Base: ... may be behind origin/<trunk>`) does not cover this: it speaks about the trunk, and is printed
on a skip only. Nothing is said on the ordinary run, where the fetch did refresh.

**It warns and never refuses, and that is not a position waiting to be hardened** the way #1046's was.
The legitimate divergence sits on the intended happy path: your own autopark from another device, which
you then fast-forward. A refusal would land on the route this script exists to serve.

**Said twice, and the second copy comes out of whichever end the run reaches.** On a divergent branch the
creation push *cannot* succeed -- it is a non-fast-forward, which is the incident's own ending -- so the
note is printed from the failed-push branch as well as from the foot of a run that completes. There it is
not a repeat but the diagnosis: git says the push was rejected, and this says whose work is on the other
side of it. This script's own suite is what found that; a repeat placed only at the end would have been
dead code in exactly the case it was written for.

## The rest of the chain — the commands, written here because they are readable here

`new-branch` is the one step of this chain the model may reach for on its own. The four that follow
carry `disable-model-invocation: true`, and that flag removes their pages **from the model's context
entirely** — it does not gate the work behind them. The scripts are ordinary PowerShell in this
plugin, and they run exactly the same checks whoever types the line:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1"
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/ship-pr.ps1"
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/fold-changelog-entry.ps1" -Branch <prefix>/<short-name>
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/cut-release.ps1" -Bump <major|minor|patch> -Title "<one sentence>"
```

**In the source repo, run its own copy instead** — `scripts/release/<name>.ps1` — for the same reason
the line above gives for `new-branch`: the plugin cache holds the last *released* mirror.

**The flag decides who types the line. It does not decide whether the line may run.** That second
question is governance, and it is answered outside this plugin: a finished branch ships once the gates
are green, and waits for the owner's explicit word for work with a **visible result** or work that is
**irreversible or outward-facing**. `cut-release` is always in that second group. So this list is a
route, never a licence — read the page for the step you are on before running it, because each carries
its own flags, pre-flight requirements and refusals, and none of that is repeated here.

**Why the list exists at all.** Without it the flag hides the *instruction* rather than the
*capability*: the model can still run the script, it simply has no source in context saying where the
script is. The effect was an inversion — the moment the governance rule is built around, the owner
saying "merge it", was the one moment the documented route was unavailable while the undocumented one
was not. Reported from a consumer as
[#731](https://github.com/DaveKJohn/claude-code-specialists/issues/731). **No flag changed**; the
route moved to a page the model is allowed to read.

## The document, and its two halves

```text
dkj-policy/feat-x-v1.md
  ## feat/x-v1
  ### PLAN / ### CREATE / ### TEST      what still MUST HAPPEN -- the step list, gated before the PR
  ### DEPLOY: feat/x-v1            what the change DOES   -- folded verbatim into CHANGELOG.md
```

**One document per branch, named after it** -- `<branch>.md`, the branch name and nothing else, with its
slashes flattened, so two branches never write the same path. It was the fixed `development.md` until
September 3, 2026 ([#1255](https://github.com/DaveKJohn/claude-code-specialists/issues/1255)), on the
argument that git already tracks the file per branch. That is true of **checkout** and says nothing about
**merge**, which is where the collision actually lives: every merge to the trunk put the merged branch's
document there and left every *other* open pull request conflicting on that one path without anybody
touching those branches -- and a conflicting PR gets no check suite at all, so a required check can never
go green and the PR can never merge. What that cost, and why the fold is not the answer either, was
measured before the reversal rather than assumed; both are written up in
[`DEVELOPMENT-portable.md`](../../DEVELOPMENT-portable.md#why-the-name-carries-the-branch). **And it exists only
while a branch is open** (Dave, August 23, 2026): this script creates it, the fold removes it at the merge,
so on the trunk there is no copy at all. It used to be rewritten to an empty state carrying a warning not
to write there; that placeholder is gone, and `DEVELOPMENT-portable.md` is where the whole form can
be read without a branch open.

**Why one file and not two** (Dave, August 23, 2026). The two jobs are genuinely different, and for two
weeks they were two files — but the plan a branch is working through and the claim it will make were then
never on one screen. An author who has just ticked the last box is now looking at the paragraph they have
to write next. What makes that safe is that the separation is structural rather than a written
instruction: the entry is a NAMED SECTION with the branch in its heading, so the fold takes that section,
the step gate counts only above it, and the scaffold gate reads only inside it.

**The DEPLOY section holds the entry block and nothing around it** — no preamble, no warning. That is what
makes it pasteable in one go. Its heading names the **branch** (`### DEPLOY: feat/x-v1`), which is also
how the fold finds the PR.

**The guidance is in the document.** Every field carries an HTML comment saying what a good answer looks
like, and the fold strips comments on the way to `CHANGELOG.md` — so leaving one standing is not a defect.
There is no reference copy beside the file any more; the trunk's own copy is the reference.

**`new-branch` wrote two reference copies into your repo until August 23, 2026**, under
`dkj-policy/branch/templates/`, and refreshed one that had drifted. That existed because the file
a branch got was deliberately bare, and inbound
[#810](https://github.com/DaveKJohn/claude-code-specialists/issues/810) is what it cost: an author met the
guidance in the neighbouring file or not at all. Nothing is generated beside the document now — the
guidance travels inside it, through the same plugin update that carries the scripts.

Two sections, one of them filled in for you:

```text
### DEPLOY: <your branch>                      <- what this branch delivers to main
                                                <- tier 0 answers HERE, under no heading of its own
#### What makes this deploy extra special            <- your audience tier: the same, or N/A
#### Pull Request · <stamp>  <- the title you gave -Title; the fold adds the number and the moment it landed
```

**Two sections, and the headings carry what three more used to.** `Branch title`, `Branch ID` and
`Branch type` were sections of their own until August 16, 2026: the title moved into `Pull Request` (which is
what it always was — `open-pr` composes the PR title from it), the ID became a stamp in a heading, and
the type is the prefix of the branch the heading already names. All three are still **read** wherever an
older entry carries them, so nothing already written stops folding.

**One stamp, at the end of the branch's life** (Dave, September 3, 2026). There were two: a creation stamp
on the document's own heading and a landing stamp on the `### DEPLOY:` heading. The creation stamp is gone
with the rest of that heading — the document's own name says which branch it is, and nothing ever read the
moment it was created back. The landing stamp stays and is the one that matters: the fold writes it from
the PR's own merge timestamp, and it is what orders the changelog. Neither was ever typed by hand.

**`Branch title` is what the change is CALLED, everywhere.** Since
[#506](https://github.com/DaveKJohn/claude-code-specialists/issues/506) `open-pr` composes the PR title as
`<branch type>: <this section>` instead of taking one on the command line — so the sentence you give
`-Title` here is the one on the PR, in `CHANGELOG.md` and in the release documents, written once. Give it
**without** a `feat:`/`fix:`/`docs:` prefix: the branch name already carries the type and `open-pr` puts it
in front. The section was called `Branch description` until that day and is still read under that name, so
a branch created before the change folds unharmed.

**An empty field is refused.** There is no visible `TODO:` anywhere, so `open-pr` measures instead of
matching: it names the description, the body and any tier whose reason is still blank. That catches an
untouched entry *and* one whose prompt was deleted rather than answered.

**The step list is enforced, not decorative.** `open-pr` refuses to push and `ship-pr` refuses to merge
while anything is still `- [ ]`. Resolve each step as `- [x]` done or `- [~]` dropped, with the reason
kept on the line — that third mark exists so nobody is ever pushed into ticking a box for work they did
not do. There is no `-Force`. Full convention and reasoning: the `open-pr` skill, and
[`DEVELOPMENT-portable.md`](../../DEVELOPMENT-portable.md), which travels with this plugin.

**So work that happens AFTER the merge is not a step** — opening the PR, waiting for CI, merging, folding,
publishing a Release, any measurement that only exists once the run is over. It is what the DEPLOY section
**describes**, in prose, once it has happened -- there is no step for it and no section to park it in
(`### Where I left off` was retired with the merge, on the ground that an unticked box already says where
you left off). The reason is the gate's own timing rather than
a matter of taste: it reads the list *before* the push, so a post-merge step cannot be done yet, and
**neither mark fits** — `- [x]` reports work that has not happened, `- [~]` claims the step turned out not
to be needed when it is needed and merely comes later. The only way past the gate is to tick a box for
work you did not do, which is the failure the third mark exists to prevent, arriving through the front
door.

Measured in the source repo across the 105 branches that have carried a step list: **17** wrote a
post-merge step, **4** were blocked by it, and **14** ticked it in advance — provably in advance, since
the fold clears this file at the merge. One branch is in both counts: it hit the gate on
`- [ ] Lint + tests green, then PR + merge + fold`, and its next commit changed nothing but that box to
`- [x]`. **No gate enforces this and none should**: a check would have to spot a post-merge step by its
wording, and `open-pr`, `merge` and `fold` are also the subjects of ordinary steps (*"`open-pr.ps1`:
recognise the new placeholder"* is real work), so separating them needs an exclusion list. Run the same
count over your own branches if you want to know whether it bites here too.

## The entry declares its significance, one section per tier it asks about

The DEPLOY section's own text and the section beside it **are** the tiers your repo asks about, each
waiting for a reason and a score. In a repo whose audience is tier 2 that is these two — which tiers, and
why it is not three, is the knob further down:

```text
### DEPLOY: <your branch>

**Score:**

#### What makes this deploy extra special

**Score:**
```

**Neither tier names a number** (Dave, August 19, 2026), and both resolve to one when read: the DEPLOY
heading's own text is tier 0, and the section beside it means the single audience tier your repo has
stated. A repo that has stated **none** gets the older shape instead — a plain question as a heading with a
`##### Tier N` sub-section under it for every tier the model has, tier 0 among them — because a heading with
no tier to resolve to would read as tier 0 and empty its release documents.

Two questions, two audiences. **The tier says how far the change reaches**, and therefore which release
document the entry appears in:

| tier | who notices |
|---|---|
| `0` | only this repo's own developers -- docs, config, internal work |
| `1` | management and the employer/commissioner get something out of it |
| `2` | a subscriber of the service notices it |

Tiers 1 and 2 are two **kinds** of audience, not two rungs, and the webshop worked example is what
separates them: a webshop's customers buy a product and never read a release note, so its audience is `1`
even though its customers are literally "consumers" -- while a repo that IS the service somebody subscribes
to answers `2`.

**The significance says how much it weighs for that reader**, and therefore where in the document it sits --
the most consequential change leads instead of sitting third under whichever heading its branch prefix
produced. Score it 1 to 5 against this rubric:

| | |
|---|---|
| `5` | the reader must act -- a breaking change, a required migration, or a long-standing blocker that is now gone |
| `4` | materially changes how they work; they notice within a day without being told |
| `3` | a clear improvement, noticed the moment they touch that part |
| `2` | small; noticed if somebody points it out |
| `1` | cosmetic, or prevents a failure that has not happened yet -- then name the failure, because that is the only part a later reader can use |

**Two tiers are in the file: tier 0, and the one audience tier your repo has.** Tier 1 and tier 2 are not
two rungs of a ladder but two KINDS of reader, and a repo has exactly one -- fixed before any entry is
written. State it in `Get-ReleaseAudienceTier` in your own `scripts/repo-config.ps1`, and the scaffolder
writes only what it names. **A repo that has stated nothing is asked about every tier**, exactly as before
the knob existed, so three sections means your repo has not answered yet rather than that something is
broken.

**Each tier in the file is answered, and `N/A` is how one says the change reaches nobody there.** Put it in
the score with one line saying why -- that is an answer rather than a gap, and it is what lets a gate tell
"reaches no subscriber" from "nobody has got to that section yet". **The reach is the highest tier carrying a
number**, and **tier 0 is the one tier that can never be `N/A`**: every change reaches the people
maintaining the repo at least a little.

**Every tier needs a reason, `N/A` ones included.** What is no longer asked for is a second reading of the
same change for an audience the repo does not publish to. Until August 12, 2026 the ladder was cumulative --
a tier-2 entry OWED a tier-1 section -- and the source repo measured what that cost: of its 89 tier-1
sections, **81 existed only because a tier-2 section sat above them**, the same reach argued twice in a
second register for a reader who was the same person. A tier your repo does not ask about is still **read**
wherever an older entry carries one, so nothing already written stops folding.

Below is a finished pair. It looks the same whichever audience tier your repo answered — that is the point of
the second heading being a question rather than a number:

```text
### DEPLOY: <your branch>

The routine version bump stops needing a developer.

**Score:** 4

#### What makes this deploy extra special

Consumers must re-add the marketplace under its new name; installs break without it.

**Score:** 5
```

**`**Score:**` and the plain `Score:` are both read**, and only the bold form is written — the standing
"recognise both, write one" rule, because every entry written before this carries the plain one.

**What it costs to leave it at tier 0.** Nothing breaks, which is exactly why it is worth knowing: where the
repo's entries declare their impact at all, the release cut refuses a bump the entries have not earned -- a
bump follows the highest tier pending (tier 0 only is a patch, tier 1 or higher earns a minor) -- and it **also** refuses a release whose
tier-1-or-higher entries carry no significance, because an unscored entry cannot be placed. So an entry left at 0 is work that
cannot carry a release on its own. `open-pr` prints what it read and names anything still unsettled, so you
learn that before the PR rather than at the cut.

**The score is scaffolded empty on purpose.** The tier defaults to 0 because 0 is a harmless final answer;
a *score* has no harmless value, so any number scaffolded here would be a guess at a ranking. The rubric is
what makes it a measurement rather than a mood, and the reason above it is what makes the resulting order
auditable.

**There is no `-Tier` parameter, deliberately.** Whoever finishes the branch already has to answer the
description and the body before the PR (open-pr's gate refuses an empty one), so the Significance sections
are one more edit in a file that is being edited anyway.

**Older shapes keep working.** The impact table this replaced and the single `Tier: 0` line before it are
both still read everywhere -- "recognise both, write one" -- so entries written on either side of the change
keep folding correctly.

**Do not derive it from your branch prefix.** The prefix decides the entry's *type*, which the entry states
under its own heading -- it predicts nothing about impact: a `docs/` branch can carry a tier-2 change and a
`feat/` branch a tier-0 one. The source
repo measured this -- its single most consequential change for a consumer, a rename that broke every
existing install, arrived on a `chore/` branch.

The tier's word (`Tier`) is a machine-read key and is **not** translated, unlike the four scaffold strings
below: the writer, the PR gate and the fold all match on the literal, so a translated key would make an
entry unreadable to your own fold.

## Recording intent and parking a branch (#162)

Two optional parameters cover the "start now, continue later (maybe on another device)" case:

- **`-Intent "<what is next / where I left off>"`** -- recorded **inside the first phase** (`PLAN`), as its
  opening paragraph, with no heading of its own. Omit it and nothing is written there. The headinglessness
  is what separates it from the `Where I left off` section retired on August 23, 2026, which every branch
  had to answer: the marks say where you stopped, and this is for what you decided and have not written
  down anywhere else yet.
  **It moved out of the top of the document on August 26, 2026** ([#908](https://github.com/DaveKJohn/claude-code-specialists/issues/908),
  [#925](https://github.com/DaveKJohn/claude-code-specialists/issues/925)), where it had been a bare
  paragraph above the phases. That is the one region the preamble rule refuses, so this script wrote a
  document its own branch-entry gate rejected — on every parked branch and every lane, and only once the
  entry was written, which is at the PR. If you hold a branch scaffolded before that date, move the
  paragraph under `PLAN` by hand; nothing else about the document changes.
  **It deliberately does not touch the DEPLOY section.** An intent is a status, and that section's text folds
  verbatim into `CHANGELOG.md` -- this repo measured three released entries that shipped a progress
  note that way. The entry's body is left empty, and the PR gate keeps refusing it until somebody
  writes what the change does.
  **The prose in these files is repo-owned.** The guidance comments (which reach the templates rather
  than the working files), the section headings, the routing questions and the rubric can all be set from
  your own `scripts/repo-config.ps1`
  (`Get-EntryGuidanceOverrides`, `Get-EntrySectionHeadingOverrides`,
  `Get-EntrySignificanceWordingOverrides`, `Get-EntrySignificanceRubricLevels`,
  `Get-BranchFileWordingOverrides`), along with the type an unknown prefix falls back to
  (`Get-EntryFallbackType`; issue #410). Define none of them and you get exactly the English text above.
  **That now includes the trunk warning's opening sentence** (`TrunkWarningLead`, inbound #562): it used to
  be built by the formatter, so a repo that translated everything else still got
  `> **You are on \`main\`.**` in English as the first line its readers saw, and forking the script was the
  only way out. Put `{0}` where the trunk name belongs in your sentence — a translation rarely wants it in
  the English position — or leave it out and let the heading above carry the name.
  That exists so a repo whose changelog is not in English does not have to keep a private copy of the
  script -- which is the duplication this skill exists to prevent. The three retired placeholder strings
  (`Get-EntryTitlePlaceholder`, `Get-EntryBodyHeading`, `Get-EntryBodyPlaceholder`) are **no longer
  written by anything**; they survive only as wording `open-pr` still refuses wherever an older entry
  carries it.
- **`-NoPush`** -- leave the branch purely local: nothing committed, nothing on `origin`. The escape valve
  for the rare branch that must not be visible yet. **Since
  [#900](https://github.com/DaveKJohn/claude-code-specialists/issues/900) the push is the default**, so this
  is the only way to opt out of it.
- **`-Park`** -- **accepted and does nothing.** What it used to ask for is what now happens without it, and
  it prints one line saying so. Kept rather than removed because this script is mirrored into every
  consumer's plugin cache, where a `-Park` typed from a doc or a habit would otherwise fail on a parameter
  that is gone.
- **`-RepoRoot "<path>"`** -- create the branch and its document in a tree **other** than the one you
  are standing in. You almost certainly do not type this: it exists for the `worktree-lane` skill, which
  opens a branch inside a lane worktree. Same parameter, same name and same reasoning as
  `fold-changelog-entry.ps1` has carried since
  [#101](https://github.com/DaveKJohn/claude-code-specialists/issues/101). Omitted (the normal case):
  unchanged behaviour -- `${CLAUDE_PROJECT_DIR}`, else the git root.

  **Do not reach for `${CLAUDE_PROJECT_DIR}` instead.** That was tried first and the source-repo guard
  refused it, correctly: the guard resolves *"which repo is being operated on"* from that same variable,
  so pointing it at another tree makes this script look like a released copy run from outside the repo
  it maintains. The env var answers which repo the session is working on; `-RepoRoot` answers which tree
  one call writes to.

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/new-branch.ps1" `
  -Name "feat/spotify-dashboard" -Title "Spotify dashboard" `
  -Intent "Skeleton + routing done; next: wire the API client."
```

The push needs a configured, reachable `origin` (git only -- no `gh`, no PR). **A repo with no `origin` is
not an error**: the branch and its document are created exactly as before, and the script says why nothing
was pushed. That case is real -- every fixture in this script's own suite is such a repo, which is how it
was found.

## Requirements in the consumer

The script is repo-agnostic, but reads its repo data from the **root** of the consumer
(dual-context via `${CLAUDE_PROJECT_DIR}`):

- `scripts/lib/branch-info.ps1` (dot-sourced) -- the single source of truth for the branch-prefix
  table (`Get-BranchInfo`/`Test-BranchName`).
- `git`.
- `scripts/repo-config.ps1` -- **optional here**, unlike in `open-pr`/`fold-changelog-entry`, which
  pre-flight on it. If present, its four `Get-Entry*` functions set the stub wording (#410); if it
  is absent or fails to load, the entry is written with the built-in English defaults and a
  warning. This is the lightest script in the set, and every string it reads from there has a
  working fallback.

If `branch-info.ps1` is missing -- typical on a clean consumer -- the script stops before the
dot-source with a clear pointer instead of a raw error (#86); fill it in first (see the workshop
repo as a model, or use the `VUL-IN` scaffold the `specialists-init` bootstrap places).

## Important

- **A push by default, and still no PR -- ever.** The script commits the branch document and pushes the
  branch to `origin` with `git push -u`, and that is where it stops. **Push is not a PR**: it makes the
  branch reachable from another device while the PR rule stays intact and separate, and opening one remains
  a separate, explicit step (the `open-pr` skill). Reversed on
  [#900](https://github.com/DaveKJohn/claude-code-specialists/issues/900), August 26, 2026: this ran behind
  `-Park` for nineteen days and the switch was typed **six** times in the whole history, while the median
  merged branch sat invisible on `origin` for **22 minutes** and the worst for **365**. `-NoPush` is the way
  out; the document then stays uncommitted exactly as it did before.
- **The document stays current on the remote after that, and you do not do it.** A Stop hook runs
  `park-cycle.ps1` after every turn, pushing that one file until a PR publishes it -- see the `park` skill,
  which documents all three parking moments on one page.
- **Idempotent repetition, per file.** Running the script again on a branch that already exists does
  not fail or overwrite -- it resumes. The two branch files are judged **separately**, and on what
  each one says it belongs to rather than on whether it exists (both exist on the trunk by design):
  an entry that has been written stays written, and a step list you have been ticking off is never
  clobbered by a rerun.
- This script is maintained in the source repo; do not modify it locally in the consumer. A
  change lands first in the source (`scripts/task/new-branch.ps1`) and then travels via a release to
  the plugin mirror -- guarded by the shared-scripts drift lint.
