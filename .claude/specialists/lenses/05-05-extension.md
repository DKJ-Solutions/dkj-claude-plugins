---
id: 05
group: 05
---

# Derek 🐙 — the DevOps Engineer (*DevOps Engineer Derek*)

> Repo-lens (lens-only persona) — the portable body lives in the plugin source:
> `~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-subagents/dkj-subagents-alpha/personas/05-05-persona.md`.
> Derek's body is read on demand from this path when Chris brings him in (no fixed `@` import).

## Specific to this repo (claude-code-specialists)

> *Everything above is Derek's git craft and travels with him to every repo. This part is the claude-code-specialists lens: if you copy Derek to another repo, this is the part you replace — the concrete branch conventions, scripts, and account this house chose.*

A DevOps engineer does the same thing everywhere — manage branches, PRs, and merges, protect the
main branch, and guard a clean history. **What is repo-specific in claude-code-specialists is not that
Derek runs the git flow, but the specific conventions, scripts, and account of this house.** Below is
the concrete implementation — this is what you rewrite when copying. The **changelog and versioning**
are [Rendall #06](05-06-extension.md)'s domain; Derek handles everything up to and including the
merge.

### Classifying, naming, and creating a branch

Every change starts with the right branch — this is Derek's canonical explanation.

**Step 1 — check the branch before you touch a single file.** Run `git status` + `git branch`.
Non-negotiable: not a single file (not even a script or manifest) is written before this check.
- **On `main`** → create the right branch first, then make changes. Never commit directly on `main`
  (except the fold exception in [the safety rules](../../../CLAUDE.md#safety-rules)).
- **On a feature branch** → continue on that branch.

**Step 2 — classify the work and name the branch.** Choose the prefix by type of work. The canonical
table lives in [`scripts/lib/branch-info.ps1`](../../../scripts/lib/branch-info.ps1):

| Type of work | Branch name | GitHub label | Changelog type |
|---|---|---|---|
| New or extended capability (new plugin/specialist, migrated manual, new script) | `feat/<description>` | `enhancement` | Feat |
| Correction of an error in an existing agent def/manual/script/manifest | `fix/<description>` | `bug` | Fix |
| Documentation: `README.md`, `CLAUDE.md`, workflow explanation, manual content | `docs/<description>` | `documentation` | Docs |

**There is no `chore/` row, and that is the point** (Dave, August 7, 2026). Chore is the name for work
that lands **directly on the trunk** under one of the named exceptions — the fold commit, the release
commit — so a chore *branch* is a contradiction and `Test-BranchName` refuses the prefix outright. Where
maintenance genuinely needs a branch, it is one of the three above: `fix/` if something was broken,
`feat/` if the tooling can now do something it could not, `docs/` if the change is text.

`Chore` stays a recognised changelog **type**: entries already written under it must still validate, and
it is still what an unknown prefix falls back to. Recognise both, write one.

**The rule always held; the tooling never said so.** Measured on the day it was written down: `chore/` had
been used as a branch prefix 12 times, against 70 `docs/`, 58 `fix/` and 51 `feat/`. Dave's answer on
seeing that count was that all twelve were wrong at the time too — he had simply never noticed. Twelve is
what a rule costs when it lives only in someone's head.

Edge cases — classify by **what actually changes**, not which files happen to move along:
- **`docs/` vs `feat/`**: `docs/` is purely documentation/text; `feat/` is a new or extended
  capability (even when docs come with it — the docs follow the capability).
- Unknown prefix → label `question` (to be classified later).

**A `-v<N>` suffix is optional, and `new-branch` no longer adds one** (Dave, September 3, 2026 — it
completed `-v1` unconditionally from August 23, 2026 until then). In 209 branches that reached a merge
carrying the suffix, none was ever bumped to `-v2`, and the completion was the direct cause of inbound
#1224. So a branch is named verbatim; a second development cycle on the same subject is a `-v2` **typed by
hand**, which nothing rejects. **Never "final" in a branch name** — `Test-BranchName` refuses it because a
name claiming to be the last word is a prediction, and a hand-typed version number is the honest form it
points you at.

**Step 3 — create the branch (its changelog entry comes along in the same move):**
```sh
.\scripts\task\new-branch.ps1 -Name <branch-name> -Title "<short title>"
```
**`-Title` is the one place the title is typed**, and since August 7, 2026 it is also the PR title —
`open-pr` composes `<branch-type>: <this>` from it. Write it without a type prefix; the branch already
carries the type.

Creating the branch and creating its changelog entry file are no longer two separate manual steps —
**a branch is never entry-less.** `new-branch.ps1` checks out the branch (idempotently — running it
again on an existing branch simply resumes it) and writes `dkj-policy/<branch>.md` in the
same run — one document holding both jobs: the step phases, and the `### DEPLOY:` section that is the entry.
It uses the name **exactly as given** — it does not complete a `-v<N>` suffix (see above), so a caller
wrapping it for a branch whose name it does not own gets that name. **One script since August 7, 2026** —
the file writing used to live in a sibling called `new-changelog-entry.ps1`, invoked as a child process,
and that name described one of four outputs by the end. Mechanism ownership of the entry FORMAT stays with
[Rendall #06](05-06-extension.md#changelog); Derek's `new-branch` is what writes it at the moment the
branch is born. The assigned specialist then fills in
the description and keeps the step list current while building. As soon as that work is finished and committed, the PR follows in
the same motion: Chris reports each step but asks nothing first, unless the work falls under one of the
two exceptions in [Opening a pull request](#opening-a-pull-request) below.

### Opening a pull request

**By default Derek opens it himself, without asking** — the work is finished, committed, and the gates
are green, so the PR is the next step rather than a decision. The test is the one in
[the safety rules](../../../CLAUDE.md#never-directly-on-the-main-branch--via-branch--pr): *does
Dave's own look add something the gates cannot?* Almost never in this repo, whose diffs are tooling,
config, docs, and agent defs. He **stops and reports instead** for a **visible result** (a frontend,
styling, rendered output, an artifact — no gate proves that something looks right) or for
**irreversible/outward-facing** work (a release, version bump, tag, repo settings/rulesets, publishing
beyond the PR flow), and whenever Dave pulled that specific job under the exception when assigning it.
An explicit "open the PR" still counts as approval for the whole movement, so a waiting branch resumes
in one motion. The lint gate in `open-pr.ps1` is the guard that makes the default safe. Use the script:

```sh
.\scripts\release\open-pr.ps1
```

This pushes the branch and opens the PR with `.github/pull_request_template.md` as the body — walk
through the checklist. The script also automatically sets the right GitHub label (see the prefix→label
table above).

**The title is no longer typed here — it is composed** (Dave, August 7, 2026;
[#506](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/506) +
[#505](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/505)). The PR is called
`<branch-type>: <the entry's Branch title>`, so the prefix mirrors the branch type by construction and the
words are the ones already in the DEPLOY section of `dkj-policy/<branch>.md`. `-Title` is still accepted and ignored, with a
warning naming the title the entry gives.

**That rule used to live in this very paragraph, and was violated five PRs in a row.** It read "the title
prefix mirrors the branch type" and nothing measured it: [#499](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/499)
through [#503](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/503) all merged without one, while
every commit and every merge line in the graph carried its type. Same shape as `chore/` and the `final`
rule — a rule that lives in a document, is never measured, and is therefore silently broken. The repair was
to stop asking for the title twice rather than to add a third check on the second answer.

**Reach for `open-pr` on its own only when you are stopping at the PR** — work waiting under one of the
two exceptions, or a branch you want reviewed before it lands. **When the work is going all the way
through, run [`ship-pr`](#merging-to-main) instead**: its first step *is* this script, so running both
puts the lint and every suite through a second time for no added coverage.

**Name the issues the PR closes — the gate now insists.** A PR that repairs an issue passes
`-Resolves "331,332"`; a PR that repairs none passes `-NoResolves`. Leave both off while the changelog
entry mentions an **open** issue and `open-pr.ps1` stops before the lint, the tests, and the push,
naming what it saw.

```sh
.\scripts\release\open-pr.ps1 -Resolves "331,332"
```

**Why this is a gate and not a habit (lesson of August 1, 2026).** A plain `#332` in a PR body closes
nothing: GitHub auto-closes only on a *closing keyword*, and `gh issue close` afterwards is a separate
manual act. PRs [#341](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/341),
[#342](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/342) and
[#343](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/343) each repaired real findings, each
referenced them as plain mentions, and the manual close was skipped **three times running** — leaving
**eight** repaired issues open while `CHANGELOG.md` reported them done. Dave spotted it from the
outside ("a lot of new things in the changelog but all 20 issues are still open"), which is the tell
that the tracker had stopped being trustworthy. The eight were closed by hand; the gate is what makes
a fourth time impossible. Two details worth keeping:
- **One keyword per issue, one per line.** GitHub does not distribute a keyword over a list, so
  `Closes #331, #332` closes only #331 and leaves the second silently open — the exact failure being
  gated. `New-ResolvesBlock` writes one line each, and the suite asserts the shape, not just the text.
- **PR references are not issue mentions.** `PR #341`, `PRs #341-#343` and `/pull/341` are excluded on
  purpose: a gate that fires on every branch gets bypassed, and then it guards nothing.

`ship-pr.ps1` closes the loop after the merge: it reads the closing keywords back **out of the merged
body** and verifies each issue really went to `CLOSED`, closing any that did not. Reading them back
rather than re-using the parameter is deliberate — a second tally is how the #275 preview/apply drift
started.

**The PR body fills itself in** via `open-pr.ps1` — simply leave out `-Body`. The script ticks the
right "Type of change" box (from the branch prefix), fills "What does this change do?" with the
description from the changelog entry (the DEPLOY section of `dkj-policy/<branch>.md`), and ticks the two checklist items
it can honestly verify ("Changelog entry written" + "Requested by Dave"). The first is judged on the file
actually **holding** an entry, not on its existing — a branch cut before August 23, 2026 carries the trunk's
old empty copy, so a self-ticking box keyed on existence would tick for a branch that wrote nothing. Only
pass `-Body` if you want to override the auto-fill; do that via `--body-file`, never inline — see
[the quoting lesson](#the-quoting-lesson-where-it-was-measured).

#### `Resolves #N (in part)` is not a hedge — the parenthetical is not read

**A closing keyword in a COMMIT message closes the issue when that commit lands on the trunk, and
qualifying it in prose changes nothing.** GitHub matches `Resolves #1843` and stops; `(in part)`,
`partially`, or a following sentence explaining the scope are not parsed and do not weaken it. This
repo merges with a **true merge** by default (`Get-PrMergeMethod`, `'merge'`), so every branch commit
arrives on `main` with its message intact — the keyword fires there, not only from a PR body.

**So the `-Resolves` / `-NoResolves` gate on `open-pr` is not the whole guard.** That gate reads the
*PR*, and it is the reason this was caught at all: it refused to guess, which sent somebody to look at
what the branch actually said. A commit written earlier in the same branch had already answered the
question the other way, and nothing had asked.

**Write the number without a keyword when the work is one step of a larger issue** — `one step of
#1843`, `part of #1843`, `see #1843` — and keep the keyword for the PR, where `-Resolves` states it
deliberately and `verify-resolved-issues.ps1` checks it afterwards.

**And once the commit is pushed, this is not repairable on the branch.** Rewording needs a
force-push, which is on the never-without-Dave list for any branch whatsoever, so the honest remedy is
to let the merge close the issue and **reopen it**, with a comment saying why it closed. Measured
September 11, 2026, on `feat/1843-portable-pr-template`: the commit said `Resolves #1843 (in part)`
while the branch deliberately built one step of four.

### Merging to main

No separate merge approval is needed — the default covers it, as does Dave's "open the PR" when the
work was waiting under an exception.

**`ship-pr` is the whole chain, and running it is the whole job:**

```sh
.\scripts\release\ship-pr.ps1
```

It runs `open-pr` (gate → push → PR), waits for the required CI check, merges, checks out `main`, and
folds the entry. One command, one gate run.

**Do NOT run `open-pr` first and then `ship-pr`** — measured August 7, 2026 and it cost about 91 minutes
in a single day. `ship-pr`'s step 1 *is* `open-pr`, so running both puts the lint and every suite through
a second time for no added coverage, on top of what CI spends on the same commit. This section used to show
a bare `gh pr merge` and never named `ship-pr`, which is what led into that route.

**That waste is now a fraction of what it was, and the advice is unchanged.** Later the same day the gate
started running its suites in parallel ([#512](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/512)),
taking it from **510s sequential to 128–263s** over six runs on the same machine in the same session — so a
duplicate run costs two to four minutes rather than thirteen. Worth knowing for a second reason: a gate
that is cheap is a gate nobody has an excuse to `-SkipTests`.

The by-hand route below is the **fallback**, for when `ship-pr` cannot finish — a CI check that never
reports, or a PR opened from the GitHub UI. The order is fixed either way: **first the PR open, then
check the body on GitHub, only then merge**, never the other way around.

```sh
git checkout main
gh pr merge <branch> --merge --delete-branch --subject "merge: <branch> (#<PR-number>)"
```

**That `--subject` is the same string `ship-pr` writes**, and it has to be: two formats for one line is
how the graph stops being scannable. Written down here because it was invented twice on August 7, 2026 —
`ship-pr` briefly shipped `merge: PR #NN <branch>` because this line was not read first.

`--merge` creates a **merge commit** (no squash/rebase — preserves the individual commits).
`--subject` gives the merge commit the `merge:` prefix. `--delete-branch` cleans up the branch
(remote + local). Then synchronize with `git checkout main` followed by
`git merge --ff-only origin/main` (two statements — see the `&&` note just below), preceded by a
`git fetch --prune` if you have not already fetched.

**Three CI and sync rules now live in the `ship-pr` skill, which is where a consumer meets them —
what stays here is where they were measured.** The skill carries the reasoning and the commands; this
lens carries the local evidence and the two names that are only true here.

- **`git merge --ff-only origin/main`, never a bare `git pull --ff-only`.** Measured July 29, 2026 on
  [PR #257](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/257): the bare pull failed with
  `fatal: Cannot fast-forward to multiple branches` on a clean `main` right after
  `gh pr merge --delete-branch` plus a `git fetch --prune` that removed two remote refs. **Why the pull
  got more than one ref was never established** and is deliberately not recorded as a mechanism note —
  this repo's config is ordinary (one `remote.origin.fetch` refspec, `branch.main.merge` naming one ref,
  `pull.rebase=false`) and a later inspection showed a single `for-merge` line in `FETCH_HEAD`. The rule
  stands on reasoning rather than on that unknown, which is why it survived being made portable.
- **Never chain `gh pr checks --watch` onto a merge in one command.** Measured July 29, 2026. Two
  details are local: the check that goes unevaluated is **`lint-en-tests`**, and the thing that blocks
  the merge is the **`main-ci-gate` ruleset** (see [Tooling & account](#tooling--account)). One more is
  local to the shell rather than the repo: **PowerShell 5.1 has no `&&`**, so a chain here is `;` or
  `if ($?) { ... }` — both of which happily run the merge regardless of what the watch concluded.
- **When the required check never appears, close and reopen the PR — after confirming no run exists.**
  Measured July 23, 2026 on [PR #152](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/152)
  (`mergeStateStatus` at `UNKNOWN`, no rollup at all, a prior PR having triggered normally moments
  before) and sharpened the same day on
  [PR #155](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/155), which is where the two
  concurrent runs and the `BLOCKED` window were seen. The unrelated check suite that can fool the
  head-SHA count was `netlify`. And the reason `gh` phrases its refusal as a *base branch policy* and
  offers `--admin`: `main` here is guarded by a **ruleset**, not classic branch protection — that
  suggestion is exactly the bypass to refuse.

Folding the changelog entry on `main` (`fold-changelog-entry.ps1`) is then
[Rendall #06](05-06-extension.md#changelog)'s work. `main` thus keeps a growing record of everything that
has been merged — since August 5, 2026 as **one flat list, ranked** by each entry's own impact table rather
than grouped by its branch prefix. Derek's part of that is only this: the tier and the significance are set
while the branch is still open, so they belong in the entry before the PR — the fold is the only moment the
order can be decided, and after that a correction is a re-insert on `main`.

### The quoting lesson: where it was measured

**The rule itself is Derek's craft and now travels with him** — *never pass a body inline to `git` or
`gh`; write it to a file* — see his portable persona. It is stated there without the numbers, because
the trap is the shell's, not this repo's. What stays here is the local evidence:

- **Quotes mangled, July 16, 2026 — and again on August 10, 2026, in a session that could quote this
  rule.** PowerShell 5.1 broke the argument boundaries on a `"` inside a commit message, so
  `git commit -m` read the rest of the message as a pathspec and the commit bounced. The recurrence is
  the more useful half: the rule was already written in Derek's portable body *and* here, and it was
  broken anyway — by reasoning that a **single-quoted here-string** (`@'…'@`) is literal and therefore
  safe. It is literal, and that is the wrong axis.

  **Measured that day rather than argued, because the mechanism is what the portable rule now states.**
  One argument carrying `"names a migration"` was handed to a native command three ways; the child
  printed its own `argv`:

  ```text
  single-quoted here-string:  argv = 3  ->  <no gate -- recognising names> <a> <migration in prose is the trap>
  plain single-quoted string: argv = 3  ->  identical, to the character
  same text, no double quotes: argv = 1
  ```

  The two quoting forms are **indistinguishable** downstream, and `argv[2]` is literally `a` — which is
  exactly the `pathspec 'a' did not match any file(s)` git reported. So the split is not a property of
  the here-string, of PowerShell's parser, or of "some shells": it is where the argument is serialised
  for the executable. Nothing you do on the PowerShell side reaches it.
- **Newlines split, July 30, 2026.** `gh` answered `accepts 1 arg(s), received 4` on a multiline
  `--comment`. The half-success that makes this a hard rule was measured the same day:
  `gh issue close 275 --comment "<multiline>"` **closed the issue and dropped the comment**, reporting
  only the close.
- **`open-pr.ps1` already does it right** — it delivers the PR body via a temporary file rather than
  inline, which is the shape to copy rather than re-derive.

### Branch & repo hygiene

- Everything goes through a `feat/`/`fix/`/`docs/` branch + PR to `main` — **no direct
  commits on `main`** except the fold exception in [the safety rules](../../../CLAUDE.md#safety-rules).
  There is no second reviewer; the PR opens by default as soon as the branch is done, after which
  opening → merging → folding runs through in one motion, guarded by the lint gate and transparently
  reported by Chris. Only the two exceptions in
  [the safety rules](../../../CLAUDE.md#never-directly-on-the-main-branch--via-branch--pr) — a
  visible result, or irreversible/outward-facing work — stop and wait for Dave's word first. In this
  repo that is rare: the work here is tooling, config, docs, and agent defs, which the gates prove.
- **A `-v<N>` suffix is optional and typed by hand**, never completed by `new-branch` (it did, until
  September 3, 2026). A second cycle on the same subject is a hand-typed `-v2`.
- **Never "final" in a branch name.** A hand-typed version suffix is what to use instead — see above.
- After a merge the remote branch is removed by the repo's **`deleteBranchOnMerge` setting**,
  switched on July 27, 2026. Until then it was **off** while this lens claimed the cleanup came from
  `gh pr merge --delete-branch` and Derek's persona claimed it came from the setting — two different
  mechanisms, neither actually in force. Nothing errored, so seven merged branches had quietly piled
  up on the remote before anyone looked at the branch list. Note that `ship-pr.ps1` merges with a
  plain `gh pr merge --merge` (no `--delete-branch`), so the setting is the *only* thing doing this
  work: turn it off and cleanup stops silently all over again. **Since August 21, 2026 `ship-pr.ps1`
  reads that setting after the merge and says so when it is off**, with the `gh api` command — inbound
  [#815](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/815), whose reason turned out to be
  the interesting half: it reported the setting as undocumented, and it is named in **three** places in
  the plugins, one with a paste-ready command. All three are setup checklists read once at init. The gap
  was reach, not documentation, so the repair is a read at the moment it is true rather than a fourth
  document. Then tidy the local clone — **`scripts/task/prune-merged.ps1` since the same day**, which
  fast-forwards the trunk, prunes stale refs, and deletes only what it can prove is merged (ancestor of
  the trunk, or a merged PR; `-DryRun` looks first). By hand it is `git fetch --prune` +
  `git branch -d <branch>` — and be aware that pruning
  only drops tracking refs for branches *already* gone from the remote, so a clean local list is no
  evidence at all that the remote is clean. Verifying means `git ls-remote --heads origin`. See the
  portable rule (and what each command is for) in the `fold-changelog` skill (#163) and the
  `prune-merged` skill.
- **Deleting a *remote* branch stays a manual action for Dave — deliberately, don't propose
  otherwise.** The auto-mode classifier blocks `git push origin --delete`, and that block is not
  worked around. Dave weighed adding a permission for it on July 27, 2026 and declined, for a reason
  worth keeping: with `deleteBranchOnMerge` on, merged branches disappear by themselves, so the
  permission would only ever apply to branches that are *not* merged — a parked branch
  (`park-branch.ps1`), unfinished work, or a branch pushed from the other machine. Those are exactly
  the ones whose loss is unrecoverable, so the permission would carry all of the risk and almost
  none of the benefit. Backlog cleanup (as with the seven branches that had piled up before the
  setting was switched on) is therefore handed to Dave as a paste-ready command, not attempted.
  **`prune-merged.ps1` does not weaken this and was built not to** (August 21, 2026): it touches no
  remote branch at all, and its test suite asserts that structurally — no git call in it carries a
  `--delete` argument. Its local deletions are the mirror image of the declined permission: every one
  requires positive proof of a merge, so the set it can reach is exactly the set the permission could
  *not* have reached safely.
  **Since August 28, 2026 that script also *composes* the paste-ready command, under `-IncludeRemote`**
  ([#1042](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1042)) — which is this bullet
  being carried out rather than worked around, since handing the command over is what the decision says
  should happen. It reads `git ls-remote --heads`, puts every head that is not the trunk through the
  same two proofs, prints `git push <remote> --delete <branch>` for one it can prove and
  `Kept <remote>/<branch> -- live work` for one it cannot, and runs neither. The structural assert was
  widened in the same movement to a quote of **either** kind, because the file now contains those words
  in a double-quoted string on purpose. The reason it was built: the classification had been
  re-derived by hand three times in two days (#992, #1035, #1039), and twice the session also had to
  hand-write a *don't sweep this one* warning about a live head — which is the `Kept` line's whole job.
- **A parked branch can be silently overtaken, and exactly one command shows it exists.** The mechanism,
  the pick-up check and the measurement are in the **portable** `park` skill, which is where a consumer
  meets this too — a parked branch has no PR by design, so `git ls-remote --heads origin` is the only
  command that surfaces it, and a park note knows nothing about what happened after it was written.
  Local instance (August 4, 2026): `docs/split-quickstart-and-adoption`, parked August 3 at 16:49, was
  overtaken by `d151b6e` at 18:32 the same day. Repo-specific half: `git ls-remote` is now named in
  Chris's stand-verification list in [`01-01-extension.md`](01-01-extension.md#the-dave-rules), and the
  remote delete stays Dave's manual act per the bullet above.
- **And a parked branch's ticks are not evidence that the work exists** — read its park commit before
  rebuilding a line of it. The mechanism is portable and lives in
  [`DEVELOPMENT-portable.md`](../../../plugins/dkj-policy/DEVELOPMENT-portable.md):
  every automatic park stamps a `Backing:` line saying how many steps are resolved, how much is committed
  on the branch besides the document, and how much is uncommitted in the working copy the park came from
  -- plus an explicit alarm where the plan reads as finished with nothing behind it. Repo-specific half:
  this is the shape [#960](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/960) was measured
  on here, `feat/adopt-act-on-this-skills-v1` (August 27, 2026) -- three `park:` commits, eight resolved
  CREATE steps naming edits to three agent defs, three manuals and two lenses, and a diff against `main`
  consisting of the cycle document alone. The work was uncommitted on the other device; every commit on
  the branch was `davekokbwj` while this checkout is `DaveKJohn`, which is the tell to look for when the
  numbers and the ticks disagree. Read the note with `git log -1 --pretty=%B origin/<branch>`: the reporter
  that used to print it under each parked branch went with `/lock` and `/handover` on August 27, 2026
  ([#957](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/957)).

  **THAT TELL HAS A PRECONDITION, AND THE MACHINE IT WAS MEASURED ON DOES NOT MEET IT**
  ([#1315](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1315), September 3, 2026). It
  reads a difference between the commits' account and "this checkout" as evidence of a *second device* --
  which holds only where this checkout's own two identities agree. On DAVE-KOK-BWJ they do not: `gh` is
  authenticated as `DaveKJohn` while `git config user.name` reads `davekokbwj`, so a branch built there --
  same machine, same session -- produces exactly the signature above, and a later session applying the tell
  reads "built elsewhere" off a branch that never left the room. Note which half of the sentence names
  which: the account it calls "this checkout" is the **gh** one, and the `git` one is what every commit
  carries. So establish the precondition before using the tell --
  [`check-git-identity.ps1`](../../../scripts/lint/check-git-identity.ps1) answers it and reports a split
  from a SessionStart hook, so where it is silent the tell is diagnostic and where it fires the tell proves
  nothing until the two are reconciled. What survives on a split machine is the rest of the bullet, which
  never depended on an account: the `Backing:` line's own numbers, and the park commit you read before
  rebuilding a line.
- **Working in parallel from multiple machines** (lesson of July 16, 2026, when PR #46 and #47
  crossed each other): merging different branches in parallel is safe — the lint gate and CI protect
  `main` independently of which machine merges. Two rules keep it that way: **never the same branch
  on two machines** (push/pull races), and **a fresh `git pull` before every new branch and before
  every fold**. The fold collision point itself is [Rendall #06](05-06-extension.md#lifecycle)'s
  part of this lesson.
- **On ONE machine the same parallelism needs a worktree, and the direction is the opposite of the
  obvious one** (August 23, 2026). The bullet above says merging different branches in parallel is
  safe; what stops a single session from doing it is not policy but the working tree. `ship-pr.ps1`
  blocks on `gh pr checks --watch` — **median 8m 01s over 65 blocking runs, 9h 45m per week at 73 PRs**
  ([Nolan #25](06-25-extension.md#wall-clock-here--the-gates-and-the-baseline-measured-at-v420-august-10-2026)) —
  and then, at step 5, runs `git checkout main` to fold. Background the ship and start the next branch
  in the same checkout, and that checkout yanks HEAD out from under the work in progress.
  **Shipping from a worktree instead fails harder**, and this was probed rather than reasoned about:
  git refuses one branch in two worktrees (`fatal: 'main' is already used by worktree at ...`), and
  that refusal lands *after* the merge — landing you in the exact half-state `ship-pr.ps1` warns about
  at that line, where the PR is merged, the entry is unfolded, and every gate stays green until a
  release trips over it. So the rule runs the other way around: **the worktree is where you build, the
  primary checkout is where you ship.** One shipping lane, N building lanes.
  `worktree-lane.ps1` (`-Name` to open, `-HandBack` to release the branch again) does both ends and
  never touches the primary's HEAD when opening; the portable half, the measurement, and the declined
  one-line alternative to `ship-pr.ps1` are in the
  [`worktree-lane` skill](../../../plugins/dkj-policy/skills/worktree-lane/SKILL.md).
  Two things learned building it that are easy to rediscover the expensive way: pointing
  `CLAUDE_PROJECT_DIR` at another tree **breaks the source-repo guard**, correctly — that variable says
  which repo the session is on, and the tree one call writes to is `-RepoRoot`'s job (the #101
  precedent, now on `new-branch.ps1` too) — and **`git worktree remove` is not atomic**: on a
  Permission-denied it had already emptied the tree and deregistered the worktree, so a non-zero exit
  there is not evidence that nothing happened.
  **AND SINCE #985 THE BACKGROUNDED SHIP IS THE DEFAULT, NOT A THING THAT SOMETIMES HAPPENS** (Dave,
  August 27, 2026). `ship-pr.ps1` is started as a background command and the session carries straight on
  — so a lane is the ordinary next move after every ship rather than the answer to an occasional
  collision. The two halves only work together: backgrounding without a lane is what yanks HEAD, and a
  lane with a foreground ship saves nothing. The script now prints both at the moment it begins to wait,
  and the rule with its measurements is in
  [`dkj-policy/CONTRIBUTING.md`](../../../dkj-policy/CONTRIBUTING.md#34-merge-the-pr)
  and the [`ship-pr` skill](../../../plugins/dkj-policy/skills/ship-pr/SKILL.md#the-wait-runs-in-the-background-and-that-is-the-default).
  Two bigger shapes were named and declined there rather than overlooked; #985 stays open as their home.
- **`main` moves under a long branch, and the green gate you ran proves nothing about the merged
  result.** The bullet above is about the *fold* and about two machines; this is the same collision
  arriving one step earlier, at the *branch*, and it bites hardest on the work that takes longest —
  precisely the work whose author is least likely to look up. **Measured August 6, 2026**: during a
  single branch's build, **six** PRs (#481–#486) merged from a concurrent session. The branch had to
  take `main` in **twice**, the second time after its own suites had already gone green once.
  So: `git fetch` + merge `main` **immediately before pushing**, then re-run the lint and test gates
  on the merged tree, not on the base you started from. `open-pr.ps1` runs both gates, but it runs
  them on whatever your working copy holds — a stale base included.
  **And the conflict shape is worth recognising, because the wrong resolution looks tidy.** The one
  real conflict that day was in the dead-link scan set: both sides had widened it, the other session
  towards `plugins/` and this branch towards `branch/`, each closing a genuine gap the other knew
  nothing about. Taking either side whole would have re-opened the other's gap silently, with a clean
  merge and a green gate to say so. **Two sides editing the same list usually both belong** — read what
  each was for before choosing, and keep both unless they actually contradict.
  **And a rename-detected merge is silent about the retired names *inside* the lines the branch
  adds.** A branch cut before a repo-wide rename and merged after it gets half the rename for free:
  git's rename detection moves and merges the *files* cleanly — `git merge-tree` reports a clean merge
  and the merged tree holds only new paths — while saying nothing about a plugin, path or `agent_type`
  name that the branch's own **added** lines still spell the old way. **Measured landing PR #1733**
  ([#1757](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1757)), whose merge base
  predated the [#1698](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1698)
  `dkj-team-*` → `dkj-subagents-*` rename by about four hours: six brand-new files it added still
  named the retired plugins, in comments, docstrings and an `agent_type` test fixture. **No gate
  catches it** — `check-plugin-integrity.ps1` reads links, manifests and frontmatter, not prose; the
  suites only echo the fixture back into a refusal message; and a parked branch has no PR, so not even
  the advisory CI runs against it. This is not the dead-name sweep two sections up in
  [Tessa #16](06-16-extension.md#a-dated-measurement-keeps-the-name-it-was-written-with-and-a-rename-sweep-is-where-that-is-lost):
  that one over-corrects an existing dated citation; this one under-corrects, carrying a
  correct-on-the-day name onto a trunk that no longer has it. So when you take `main` into a branch
  whose base predates a rename, read the lines the branch **adds**, not the whole file:
  ```sh
  git diff origin/main...origin/<branch> | grep '^+' | grep -v '^+++' | grep '<retired-name>'
  ```
  **The narrow reading is the whole point, and there is deliberately no gate.** Grepping every file a
  branch touches over-counted pre-existing text more than fiftyfold on the two branches measured (47
  and 6 hits against an honest signal of **1 line across 1053 commits of drift**) — a check built on
  that reading is the stale-path check declined at 124 false findings, rebuilt. It stays a by-hand
  one-liner at the one moment it matters. The one live instance at filing:
  `feat/plugin-version-overview-review-b` carries `@('dkj-team-alpha')` as a parameter default —
  whether that fails loudly or silently on resume was not verified, so verify it before repairing it
  when that branch finally takes `main` in.

### Issue labels — every issue carries a priority

**Every issue in this tracker carries exactly one of `prio-1` … `prio-4`, and 4 is the highest**
(Dave, September 9, 2026, [#1685](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1685)).
The four exist in the repo since that day:

| Label | Colour | What the rung means |
|---|---|---|
| `prio-4` | `B60205` | Highest — takes precedence over other work. A broken gate, or a wrong answer a gate reports as authority. |
| `prio-3` | `D93F0B` | Ahead of the ordinary backlog. Real, and it costs something every time it is met. |
| `prio-2` | `FBCA04` | Worth doing, no pressure. The ordinary backlog, and the common answer. |
| `prio-1` | `006B75` | Lowest — nobody is waiting for it. A question parked for the owner, or a tidy-up. |

**Exactly one, which is a property the obvious command does not give you.** Set it with `--label` on
the `gh issue create` that files the finding. On an issue that already carries a rung, `--add-label`
alone leaves **both** on it — `gh` adds, it does not replace — so a re-rank names the one it displaces:

```sh
gh issue edit <n> --add-label prio-4 --remove-label prio-2   # a re-rank, both halves in one call
gh issue edit <n> --add-label prio-2                         # only for one that arrived without a rung
```

That is the same rule `dkj-policy-bwj` states for its own four buckets, where the Asana sweep removes
the other three as it sets one — **and since September 11, 2026 it is the same four NAMES as well**
(Dave, [#1842](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1842)), on the same four
colour codes. `prio-1`…`prio-4` is one vocabulary across the whole family now.

**The two MOTORS are still two motors, and that is the part a shared vocabulary no longer says out
loud.** A rung in a BWJ store repo is **derived** from the Asana `Prio-Score` the sweep reads, and is
never typed; a rung here is **typed** by whoever files, because there is no board behind this tracker
to derive one from. So a session moving between the two repo families now gets an accepted label where
it used to get a refusal from `gh` — the axis is shared, the mechanism is not, and nothing mechanical
separates them any more.

**What separates them is the label's DESCRIPTION, which a rename leaves untouched.** `prio-4` here
reads `Priority 4 of 4 (highest)`; in a BWJ repo it reads `Asana Prio-Score 4.00-5.00`. That is the
one place a badge still says which motor set it, and it is why the BWJ side's descriptions stay
score-shaped.

**This reverses half 1 of
[#1686](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1686)**, which had held the two
sets deliberately disjoint two days earlier. Two of that decision's three grounds survive intact and
are still worth knowing:

1. **The BWJ names are not a convention, they are code** — which is exactly why the reversal arrived as
   an inbound issue rather than as a label rename somebody typed.
   `plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1` holds them as a literal
   (`$script:PrioLabels`), `Get-PrioLabelForScore` returns those exact strings from a score band, and
   `scripts/tests/dkj-policy-bwj.tests.ps1` asserts every boundary from both sides. Unifying was an
   edit to a shipped CI mechanism that runs daily against two live stores, a re-pinning of its suite,
   and a label rename on two live trackers.
2. **The collision could never mis-file anything.** Measured on all three trackers with
   `gh label list` on the day of #1686: this one carried `prio-1`…`prio-4` and **none** of the four
   words, while both `BWJ-Development/smartwatchbanden` and `BWJ-ecommerce/xoxowildhearts` carried the
   four words and **no** `prio-N`. So this was never a bug report and unification is not a fix for a
   measured failure — it is one vocabulary because Dave wants one vocabulary. The
   `gh`-refuses-an-unknown-label shape that ground relied on is the same one the **label gate** in
   `scripts/release/open-pr.ps1` is built on; that gate is cited to the script rather than linked from
   here on purpose, since its behaviour is recorded in its own comment block (inbound #1221) and the
   toolbox entry further down names `open-pr.ps1` without describing the gate.

**The third ground is the one Dave overrode**, and it was paid rather than argued away: *"the names are
the only thing that says which motor owns the rung."* The description paragraph above is what replaces
it. The residual risk is worth naming plainly — a single vocabulary reads as a single mechanism, so a
session that assumes the Asana sweep applies here, or that a rung over there was typed by somebody, is
making exactly the mistake #1686 predicted. **Read the description, not just the name**, wherever it
matters which motor set the rung.

**What was NOT weighed either time: how recently anything was created.** #1686 was committed 32 minutes
after `feat/1685-prio-labels` merged, and #1842 reversed half of it two days after that. Neither
interval is an argument — an owner changing their mind is a decision rather than a regression, and
*"this was just settled"* states a fact about the calendar, not about the merits.

**And the rule stays repo-local rather than moving into `dkj-policy`** (same decision, the issue's
second half). **Nothing in the workflow reads a priority**: searched across `scripts/`, `plugins/` and
`.github/` on the day of the decision, `prio-` appears in no gate, no script and no runner here — only
on the BWJ side, where a shipped script owns it. A portable version would therefore prescribe to every
consumer a convention no gate enforces and nothing reads, which is the enforced-by-memory shape
[#1665](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1665) was filed against, and it
would owe `adopt-dkj-policy` a label-creation step for four labels the consumer never asked for. That
is worse than the prescription-a-consumer-cannot-follow trap of
[#1540](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1540): here they *could* follow
it and would gain nothing for it.

**The seam is the shape if that ever changes.** The day something needs to read the axis, the portable
half is one `scripts/repo-config.ps1` function stating this repo's own scheme — or that it has none —
exactly like `Get-ReleaseAudienceTier` and `Get-ShopifyRepoHasNoStore`. Nothing reads it today, so
nothing is built today.

**THE COLOURS DISAGREED ON THE BOTTOM HALF UNTIL SEPTEMBER 9, 2026, AND THE FIX CAME FROM THIS SIDE**
([#1691](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1691)). Raised by the
conclusion red-team on the deciding branch, and measured with `gh label list --json name,color` on all
three trackers rather than read off the table above — then re-measured on pickup, where it held exactly
and turned out to be one label worse than filed:

| Colour | Here | In a BWJ repo | Same rung? |
|---|---|---|---|
| `B60205` | `prio-4` — top of four | `prio-4` — top of four | yes, deliberately |
| `D93F0B` | `prio-3` — third of four | `prio-3` — third of four | yes, deliberately |
| `FBCA04` | `prio-2` — second of four | `prio-2` — second of four, **and `tier-1`** | yes — but see the collision below |
| `006B75` | `prio-1` — the floor | `prio-1` — the floor | yes, deliberately |
| `0E8A16` | *(no counterpart any more)* | *(no prio label any more; in xoxowildhearts still `sync`)* | — |
| `c2e0c6` | *(no counterpart)* | *(no counterpart any more)* | — |

**The whole column is now a mirror, and that is #1842 rather than #1691** — the rename carries the hex
codes with it, so every rung agrees on both halves across the family. The rows still marked *yes,
deliberately* are the two that already agreed; the other two agree because they were made to.

**`prio-1` was `0E8A16` and is now `006B75`.** The green a reader trained here knew as *"nobody is
waiting for it"* was, before the unification, one rung **above** the floor over there, where the floor
wore a pale mint this repo does not use. Left as it was, that would have been a badge meaning two
different rungs in two repos of one family. And in **one** of the two BWJ repos — `xoxowildhearts` —
`0E8A16` carried a second label as well, `sync`, which the filing had not caught; in
`smartwatchbanden` that same label is grey (`6e7781`), so the doubling is that one store's alone.
**Nothing refuses a colour**: `gh` judges a label's NAME, and a badge is read by a person scanning an
issue list with no command in it to fail. That is
[#1686](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1686)'s own
*goes-wrong-silently* shape, moved onto an axis its reasoning does not reach.

**Why the repair came from this side in September, and why #1842 then did the other half anyway.**
Re-colouring BWJ's `low` was an edit to live labels in **two repos this one does not own**, and doing
only the half that lives here — the hex codes `adopt-dkj-policy-bwj`'s step 4 prescribes — would have
left the fleet in a third state, since that skill is additive and never rewrites an existing label.
Both halves belonged to one change and to Dave; moving **`prio-1`** instead was one `gh label edit` in
the repo in front of you, and `006B75` was verified unused across all three trackers before it was
taken. #1842 is Dave taking the other half, which is why the whole column agrees now: the rename runs
`gh label edit --name ... --color ...`, so it settles the name and the hex in the same command.

**`FBCA04` NOW CARRIES TWO LABELS INSIDE ONE BWJ REPO, AND THAT IS A NEW COLLISION RATHER THAN THE OLD
ONE.** Before #1842 the clash was across the family — `prio-2` here, `tier-1` there — and the reason it
was left alone was that the two are not answers to the same question: `tier-1` is a **reach** label,
not a rung. That argument is untouched and is also no longer the whole story. `prio-2` is now `FBCA04`
in a BWJ repo too, where `tier-1` has been `FBCA04` since it was created, so both can sit on **one row
of one issue** as two identical yellow badges on two different axes. The misread still cannot make a
*rung* wrong, only a *kind*, and nothing refuses it — so this is named here and filed rather than
repaired on this branch: changing either hex is an edit to live labels, which is Dave's to take, and
the mapping in [#1842](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1842) names `FBCA04`
explicitly. Filed as
[#1844](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1844). This repo's own ramp is
unaffected and stays teal → yellow → orange → red. No instance of either misread has been observed.

**And `006B75` was chosen on exact-hex uniqueness, which is not perceptual distinctness** — the same
red-team's other catch. It sits 14 degrees of hue and 0.03 of lightness from `help wanted`'s `008672`,
so at badge size the two dark teals are close, and one means *"nobody is waiting for it"* while the
other means the opposite. Accepted rather than churned, and measured first: `help wanted` has been used
**once** in this repo's whole history, on the closed #1215, and never on a pull request. The costs of
moving again are real — a third colour for `prio-1` inside one day would re-stale this block, the
changelog entry above it and the badge on every issue already labelled. What is also given up, and is
worth stating because it was not free: the floor no longer wears green, so the traffic-light reading
every sighted reader brings to a badge is one rung off in this repo. **Read the name, not the badge**,
remains the standing rule for anything but the two rows marked deliberate.

**It is a separate axis from the prefix→label mapping in
[step 2](#classifying-naming-and-creating-a-branch), which is about a PULL REQUEST.** `enhancement`,
`bug` and `documentation` say what *kind* of change a branch carries and are written by `open-pr.ps1`
from the branch prefix; a `prio-N` says how much an *issue* weighs and is written by whoever files it.
An issue therefore normally carries both, and neither can be derived from the other: a `documentation`
issue can be the one that has to be repaired first, and a `bug` can be the one nobody is waiting for.

**The one route that lands without a rung is the inbound template**, and that is correct rather than a
gap: `.github/ISSUE_TEMPLATE/inbound-improvement.md` can only set a fixed `labels:` line, and the
reporter is a session in *another* repo, which is not the party who can rank this backlog. It asks for
urgency in prose instead, and the rung is set here when the item is picked up — the same moment the
[`triage-inbound`](../../skills/triage-inbound/SKILL.md) checks are run.

**Nothing enforces any of it, deliberately — the same shape as the `inbound` label.** A gate would have
to ask GitHub on every run, which puts the tracker on the critical path of a local check for a field
only a person can fill in. So this is prose, exactly like the `inbound` route in
[`CLAUDE.md`](../../../CLAUDE.md#never-without-daves-explicit-permission), and the always-on half of it
lives in [Chris's lens](01-01-extension.md#the-dave-rules) so a session filing a finding reads it
without loading this page. **What that costs is measured elsewhere in this very file**: the `chore/`
prefix rule also held only in someone's head and was broken twelve times before anybody counted.

**Reading the tracker by priority** — the one command worth knowing, since the label is only useful if
it is what somebody sorts on:

```sh
gh issue list --state open --label prio-4 --label prio-3   # what actually comes first
```

**The ten issues open on the day the labels were introduced were labelled in the same movement**, which
is the half of #1685 that had a deadline: a taxonomy applied only to new issues splits the tracker in
two, and the older half is where the backlog actually is. Two came out at `prio-4` (#1678, #1679), three
at `prio-3` (#1685 itself among them), four at `prio-2` and one at `prio-1`.

### The reach label — `minor`, and it is a second axis, not a fifth rung

**`minor` is the reach label, and it answers a different question from `prio-N`.** Priority says *when
somebody should do this*; reach says *who will notice once it lands* — and the two are independent, so an
issue may carry both, either, or neither. A `prio-4` tier-0 defect is ordinary here (a broken gate nobody
outside this repo sees), and so is a `prio-1` issue carrying `minor` (a cosmetic change a consumer will
nonetheless read about in a release note).

| | what it says | who sets it |
|---|---|---|
| `prio-1` … `prio-4` | when this should be picked up | whoever files, by judgement |
| `minor` | the landing will be written at tier 1 or 2, so the release carrying it is a minor | whoever files, from the same scale the entry will be scored on |

**It is not this repo's own convention** — it is the tier model read on an issue instead of on a changelog
entry, prescribed for every repo running this workflow
([#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870), Dave, September 11, 2026), and
defined in [`RELEASES-portable.md`](../../../plugins/dkj-policy/RELEASES-portable.md#the-same-scale-on-an-issue--the-reach-label).
**Why this and not the prio axis, stated carefully, because the obvious version of the argument is
wrong.** [#1686](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1686) half 2 kept the prio
axis repo-local on the ground that *nothing in the workflow reads a priority*. The tempting reply is
*"but the reach scale IS read"* — and held against the LABEL, that reply does not survive: no gate, no
script and no runner reads `minor` either. Two skills consult it, which is the same enforcement class as
zero scripts consulting `prio-`, not a stronger one. Found by the conclusion red-team on the branch that
wrote the rule, against that branch's own contract comment, which says in as many words that no script
reads the seam.

**The difference that does hold is one level up: the AXIS, not the label.** A prio axis exists nowhere in
this workflow, so making it portable would have introduced a scale a consumer had never been asked about.
The reach axis is already theirs — every changelog entry they write scores it, and `cut-release.ps1`
refuses a minor that no tier-1-or-higher entry earned. The label adds no axis; it reads one the consumer
already answers, one step earlier. That is a claim about what the repo already carries rather than about
what enforces it, and it is the only version of this argument that is true.

**Absence is the answer, not a missing field.** Tier 0 — only this repo's own developers notice — carries
no label, and doubt resolves there. A filter that matches everything filters nothing, so the point of the
label is that `is:open label:minor` is a short list somebody can actually work.

**This repo's label reads the tier-2 wording**, because `Get-ReleaseAudienceTier = 2` here: *"Reaches
beyond tier 0: subscribers of this service notice it."* A store repo answering tier 1 carries the same
name with the management wording. The name is deliberately the same in both — it is named after what the
landing does to the release, which is the one thing true at either audience tier — and `Get-ReachLabel`
states the string for a repo whose colleagues know the axis by another word. This repo does not answer it
and does not need to: `minor` is the default.

### Tooling & account

- **GitHub CLI (`gh`)** is used for PRs. This repo lives under the **`DKJ-Solutions`** org and is
  **public** — a deliberate choice, so the remote `github` marketplace source can be read without gh auth.
  If you get `Repository not found`, first run `gh auth setup-git`.
- This repo is **public**: nothing confidential belongs in it (no personal information, credentials,
  or secrets). See the general guidelines in [`CLAUDE.md`](../../../CLAUDE.md#claude-code-specialistss-safety-implementation).

### Derek is lazy — so he scripted everything

**First, where these scripts live for everyone else.** The paths below are this repo's own
`scripts/`, which stays the canonical source and is unchanged. What changed on August 8, 2026 is the
**mirror**: every script in this section now travels in `dkj-policy`, the opt-in
pack, instead of in the core. So in a consuming repo Derek has this toolbox **only if that repo
enabled the workflow** — and if it did not, he opens branches and PRs with plain `git` and `gh`,
following that repo's own conventions. That is the intended outcome rather than a degraded one:
branches and PRs are Derek's craft, the scripted way of doing them is Dave's method, and a repo is
entitled to its own. Do not read a consumer without these scripts as misconfigured.

Derek prefers not to touch the git commands by hand. His toolbox:

- `scripts/task/new-branch.ps1 -Name <branch-name> [-Title "…"] [-Intent "…"] [-NoPush]` — create (or
  idempotently resume) the branch and, in the same move, write its `dkj-policy/<branch>.md`.
  `-Intent` records where you left off / what is next **as the opening paragraph of `PLAN`, without a
  heading** — above the phases until #908/#925 (August 26, 2026), which is the one region the preamble
  rule refuses, so the scaffolder wrote a document its own branch-entry gate rejected. Deliberately not in
  the DEPLOY section, whose text folds verbatim into `CHANGELOG.md`.
  **And it pushes, by default, since #900 (August 26, 2026)** — the document is committed and the branch
  goes to `origin`, **still no PR** (#162). That ran behind `-Park` for nineteen days and the switch was
  typed six times in the whole history, against a measured median of **22 minutes** invisible on `origin`
  per merged branch (worst 365). `-NoPush` is the escape valve; `-Park` is still accepted, says it changed
  nothing, and is there so a consumer's typed habit does not fail on a missing parameter. A repo with no
  `origin` creates the branch as before and says why nothing was pushed. See
  [Step 3 above](#classifying-naming-and-creating-a-branch).
- `scripts/task/park-cycle.ps1 [-Quiet]` — **Derek does not run this**, and it is here so he recognises its
  commits. A Stop hook (`cycle-autopark.ps1`) invokes it after every turn and it pushes
  `dkj-policy/<branch>.md`, and only that file, for the life of the branch — the plan
  and the phase state being what another device actually needs. **It stops PUSHING the moment a PR
  exists**, because the DEPLOY lock (#884) refuses the merge once that document diverges from what the PR
  published; a pusher that kept going would block every merge in the repo. Same reason its fail-safe runs
  that way: `gh` unable to answer means no push. So a branch with a PR on it shows no further `park:`
  commits, by design. **It is not a no-op there, and calling it one is what
  [#1953](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1953) repaired**: on an open PR it
  still reads `origin/<branch>` and reports a collision, naming the other side's author and subject.
  Whether it may WRITE is the DEPLOY lock's question; whether somebody else is on this branch is a read,
  and it owes the lock nothing.
- `scripts/task/park-branch.ps1 [-Intent "…"]` — **park** an existing branch mid-work: commit
  everything outstanding (`git add -A` + commit) and `git push -u origin <branch>`, so the exact
  state is immediately continuable on another device. Refuses on `main`, opens **no PR**, and does
  **no live/deploy action** — git only. Already committed locally but not pushed? It skips the
  commit and just pushes. Self-contained (no repo-owned config). `-Intent` records where you left
  off in the park commit message. Runs via the `park` skill (#175). **Three parking moments, and this is the
  only deliberate one:** `new-branch` pushes *at creation* and commits *only the branch document*,
  `park-cycle` keeps that document current *on a hook*, and `park-branch` is the one you invoke — an
  *existing* branch, *everything* outstanding. **The commit
  subject tells the scope apart** since August 7, 2026 (#507): `(all outstanding work)` against `(the branch files
  only)`. Both used to write the same sentence while committing different things, so the log could not
  answer the one question a park is asked later — which half of my work is on origin? One implementation
  now (`Invoke-GitPark`), with the scope choosing the pathspec and the words together.
- `scripts/release/open-pr.ps1 [-Body "…"] [-SkipLint] [-SkipTests]` — push the branch +
  open the PR, with the right label from the prefix. Without `-Body` **the script fills in the
  template itself**. **Lint gate:** before the push, `scripts/lint/check-plugin-integrity.ps1`
  (Sylvester) runs; if it finds an **error** — an invalid `marketplace.json`/`plugin.json`, missing
  or non-matching agent-def/manual frontmatter, or a dead link — then **nothing is pushed and no
  PR is opened**. **Test gate** (lesson of PR #54, where a red suite only surfaced on CI): after
  that, all test suites run (`scripts/tests/*.tests.ps1`), exactly like CI; a failing suite
  blocks as well. `-SkipLint`/`-SkipTests` are the deliberate escape valves.
- `scripts/lib/branch-info.ps1` (dot-sourced, not run standalone) — single source of truth for the
  branch conventions: the prefix table (prefix → GitHub label + changelog type) and the branch name →
  entry-filename conversion (`/` → `-`). Changing the mapping? Here, nowhere else.

`new-branch.ps1` is mechanism-owned by [Rendall #06](05-06-extension.md); it is now shared
(mirrored to the plugin, [issue #81](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/81))
and normally reached indirectly, via Derek's `new-branch.ps1` above. `fold-changelog-entry.ps1`
remains [Rendall #06](05-06-extension.md)'s tool, run on `main` after the merge. A new recurring
GitHub chore? Derek builds a script for it.

In short: the **how** (branching, PRs, merging, cleanup, automation) is portable; the **what** (this
prefix table, the `scripts/release/*` pipeline with the plugin lint gate, the public `DKJ-Solutions` repo,
and the fold exception) belongs to this repo.
