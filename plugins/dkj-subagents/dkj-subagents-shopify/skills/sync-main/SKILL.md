---
name: sync-main
description: Mirror the live Shopify theme into this repo's trunk without letting live overwrite the trunk's own work -- the sync that captures third-party drift, with the content rule that makes it safe. Run it before a live push, and before work that will edit theme files, since a live theme has no locking and third parties edit it through the theme editor while you work; NOT before a branch that cannot touch a theme file, where it buys nothing and can refuse on a standing predecessor. Reads from live into a mirror outside the repo and writes to git only: it never pushes to live, publishes a theme, or deletes one. Run it with -DryRun first to see every verdict without writing anything. Stops before the merge by default, so somebody sees what changed on live before it becomes the base of new branches.
---

# sync-main -- mirror live into the trunk, without losing what the trunk did

A live theme has **no locking, no merge and no conflict detection**. Third parties edit it through the
theme editor and the last write wins, silently. So work in a Shopify repo starts by mirroring live into
the trunk -- and the obvious implementation of that, a wholesale pull committed straight onto the trunk,
knows nothing about what the trunk has done since and therefore **overwrites it**.

This command is that step with the rule that fixes it:

> Has this path ever held live's content in the trunk's history? Then the **trunk** wins. Otherwise
> **live** wins -- and if the trunk also changed it, **nobody** wins and a human looks.

## When to run it

**Before a live push, and before work that will edit theme files. Not otherwise.**

The step has two jobs, and they do not fire at the same moment:

- **Capturing third-party drift into the trunk.** This is the half that becomes *safety-critical*, and it
  does so at the **live push**: the per-file `--only` push carries the trunk's copy of exactly those paths
  to live, so drift the trunk never captured is drift the push silently reverts.
- **Not cutting a branch from a stale base.** This one can only bite a branch that **edits a theme file**,
  and it costs rework rather than data.

So a branch that cannot touch `assets/ blocks/ config/ layout/ locales/ sections/ snippets/ templates/` --
documentation, tooling, CI, permissions, the workflow folder -- has neither failure to avoid. Running the
sync there pulls a whole theme over the network, compares every file, and can **refuse outright**, in
exchange for nothing.

**And that refusal is why *"run it anyway, it only takes a minute"* is not the safe default it sounds
like.** [A standing sync branch stops the run](#why-a-standing-sync-branch-stops-the-run), and that refusal
is right *while the sync is a step in theme work*: the drift is already sitting on the predecessor, so
refusing costs nothing. Mandate the sync before **every** task and the same refusal becomes a gate on the
start of all work in the repo -- one unmerged sync PR blocking a documentation branch that could not
conflict with it under any circumstances. The cheap-to-be-wrong-on side of that argument stops being
cheap.

Measured in a consumer on September 1, 2026 (inbound
[#1196](https://github.com/DaveKJohn/claude-code-specialists/issues/1196)): a session picked up an issue
whose entire content was a paste of `.claude/settings.json` -- a permission list. Its `CLAUDE.md` said to
sync before *any* task, so it did: it pulled the live theme, classified **25 paths held back** and **4 to
take from live**, and reported that a real run **would have refused**, because a sync branch from a
previous run was still standing. None of it had any relationship to a JSON permission file. The owner's
answer: *"the live sync is actually only relevant at the moment I push main to live."*

**This is the same narrowing [`start-task`](../start-task/SKILL.md) already took**, for the same reason
(inbound [#805](https://github.com/DaveKJohn/claude-code-specialists/issues/805)): a preview theme is now
created by the first push rather than by starting work, because 6 of 12 real branch previews belonged to
branches that never needed one. A preview theme is a consequence of *"I want to show this"* rather than of
*"I am starting work"* -- and this sync is a consequence of *"I am about to touch the theme"* rather than
of the same thing.

**The name is older than the rule, and it is not the trigger.** It is called the *pre-task sync*
throughout this plugin, which reads as *before every task* and is exactly the paraphrase this section
exists to end. Read the name as what it is -- a label for the step -- and this section as when it fires.

**Where the trigger is stated, and where it is not.** Here, and nowhere else. Everything else in this
plugin that has to mention when the sync fires -- [Sandra's
manual](../../manuals/05-21-manual.md#the-pre-task-sync--and-why-the-obvious-version-of-it-destroys-work),
[`start-task`](../start-task/SKILL.md) -- links to this section instead of restating it, and a consumer's
own `CLAUDE.md` should do the same. Three paraphrases inside this plugin had drifted into three different
triggers before anybody compared them, and two consumers of one owner then read the step as
mandatory-always, mandatory-for-theme-work and optional. **A trigger that is restated is a trigger that
forks** -- and none of the three forks looked wrong from where it sat.

## Run it

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/sync-main.ps1" -DryRun
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/sync-main.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

**Run `-DryRun` first.** It pulls live into a mirror, prints the verdict for every differing path, and
writes nothing at all -- no branch, no commit, no push, and the working tree untouched. It is deliberately
allowed on a **dirty** tree, because a dirty tree is exactly when somebody wants to ask what the sync
would do to it.

## What it does, in order

1. **Refuses unless the working tree is clean.** A sync must not carry your work into it. `-DryRun` is
   exempt: it writes nothing.
2. **Switches to the trunk and fast-forwards** from `origin`.
3. **Reads the conflict-check reference point** -- *before* the pull, on the state the pull is about to
   change. Reading it afterwards would read it off a tree that already holds live's version of
   everything, which is the one ordering mistake that leaves the check useless while looking fine.
   The commit it prints here is the repo's most recent sync; **the base each path is actually judged
   against is asked per path in step 6**, and the two are the same commit only for the paths that sync
   happened to take.
4. **Decides the sync branch's name**, before anything is pulled. A name that cannot be created is a
   reason to stop while the tree is still clean, not after several hundred files have been written.
   **Then asks `origin` whether a sync branch from a PREVIOUS run is still standing, and refuses if one
   is** -- see [Why a standing sync branch stops the run](#why-a-standing-sync-branch-stops-the-run).
   Still before the pull, so a refused run costs no network.
5. **Pulls the live theme into a mirror outside the repo** and compares it against the trunk. Two stages,
   for speed: an in-process object-id comparison first, then the same comparison with CR bytes ignored --
   which is how the CLI's line-ending rewrites (measured at **37 of 712 files** on one real store) drop
   out before any rule sees them. Both halves are in
   [Steven's manual](../../manuals/05-22-manual.md#the-cli-rewrites-line-endings-and-that-is-a-property-of-the-tool)
   with the measurements (inbound
   [#788](https://github.com/DaveKJohn/claude-code-specialists/issues/788)).
6. **Decides a verdict per differing path** -- `keep-trunk`, `take-live` or `conflict` -- and prints all
   three lists. What it held back is the half a reviewer cannot see from the diff: the diff shows what
   came in, not what was kept out.
7. **Writes, commits and pushes only the `take-live` paths** on a sync branch. Whether it then merges is a
   seam answer, and the default is no.
8. **Composes the PR body**, on both paths -- the record of what a third party did, and in a repo whose
   policy is that the sync PR does not wait for a review, the *only* one. It names both halves and gives
   every path its kind in words: `changed on live`, `new on live`, `gone from live`. The non-merging path
   writes it to a file and hands you `gh pr create ... --body-file <path>`; the merging path passes it
   straight to `gh`. `Get-ShopifySyncPrBody` replaces it with your own (inbound
   [#1000](https://github.com/DaveKJohn/claude-code-specialists/issues/1000)).
9. **Labels the PR, on both paths, if you asked for any** -- `Get-ShopifySyncPrLabels` answers what goes
   on it, and nothing does by default. Answer it if a guardrail workflow of yours **fails an unlabelled
   PR**: the merging path would otherwise open one that goes red on CI and cannot merge, and the printed
   line would hand you the same failure one paste later. The labels go on the `gh pr create` itself
   rather than a `gh pr edit` afterwards, so the first check run already sees them (inbound
   [#1023](https://github.com/DaveKJohn/claude-code-specialists/issues/1023)).

## The three things that make it unable to destroy work

Not "unlikely to" -- these are structural, and each one replaces a specific way the wholesale version
lost work:

- **Live is pulled into a mirror outside the repo, never over your working tree**, and the tree is written
  only for the paths whose verdict is `take-live`. The wholesale version pulled over the tree first and
  then restored what it should not have taken -- so every bug in the rule was a bug that had **already**
  overwritten the file, and any failure in between left the damage standing. Not theoretical: the run that
  exposed the floor bug died at `git checkout -b` with 31 files staged.
- **It never deletes.** A path the trunk has and live does not is either a file the trunk added and never
  pushed, or one a third party deleted on live -- indistinguishable, and deleting is the irreversible
  option. It is reported, not acted on.
- **Both sides changed the same path is a refusal, not a choice.** Nothing is written at all, and you get
  the `git diff --no-index` line that compares your copy with the mirror's.

## Why content replaced the time window

The rule used to be *"has the trunk touched this file since the last sync? then the trunk wins"*, and that
was the **wrong measurement** rather than a buggy one. Nothing pushes the trunk *to* live except the
per-file release step, and a deletion cannot be pushed that way at all -- so the trunk's changes are
permanently invisible to live and sink below the floor as soon as one more sync commit lands. After that,
**every future sync tries to overwrite them again, forever.**

Content answers the question exactly. If live's bytes are bytes this repo has held for that path before,
live is holding an older version of *our own* file and the trunk has moved on: the trunk wins, however
long ago that was. If they appear nowhere in our history for that path, somebody outside this repo wrote
them -- which is the drift the sync exists to capture.

**Measured both ways in a consumer before it was built** (inbound
[#807](https://github.com/DaveKJohn/claude-code-specialists/issues/807)), because a rule that is safe by
capturing nothing is useless:

| | |
|---|---|
| against live that day | **31** differing files, all 31 content that repo has held. The new rule captures **zero**, correctly -- there was no third-party drift, only the trunk having moved forward. The old rule captured all 31 and was about to revert three merged PRs. |
| replayed over every past "from live" commit | **10 of 11** real third-party drift files come back foreign and are captured. The 11th reverted a single trailing blank line. |

**The floor survives, demoted.** Its only remaining job is to notice that live's content is foreign *and*
the trunk changed the same path recently -- both sides moved -- and refuse. So a wrong floor now costs an
extra conflict report, never silent data loss, which is a far better failure mode for the piece of this
that is hardest to get right.

**And the floor is asked PER PATH, not once per run** (inbound
[#1535](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1535)). The paragraph above is
only true of a floor that is too *old*. A floor taken once for the whole run is systematically too
*recent* for every path the last sync did not take -- because a sync commit establishes agreement with
live only for the paths it actually **took**, and for any other path it is just a trunk commit newer than
the trunk's own work there. Measured from such a base the trunk looks stationary, the both-sides-moved
arm cannot fire, and the conflict is taken silently.

| | |
|---|---|
| what it cost, measured in a consumer | **six** paths verdicted `take-live` where the trunk was a strict **superset** of live. Across five locale files, **0** keys would have come in from live against **6** key-deletions and **7** string reversions -- including four strings reverted from English back to Dutch in the *default* locale -- plus a canonical-URL rewrite deleted from `layout/theme.liquid`. The sync it measured from had taken 167 files and none of those six. |
| the repair | each differing path is judged against **its own** base: the most recent sync commit that touched *that* path. |
| a path no sync has ever taken | has **no** agreement point, so nothing can prove live moved alone -- that is a **conflict** to reconcile by hand, not a take. This is the arm that would have held back all six. |

**No tag fallback per path, deliberately.** A tag is a release marker and says nothing about agreement
with live; the repo-wide answer uses one only as a deliberately wide heuristic window. Reading a tag as
one path's agreement point would reintroduce this same defect by a second route, and silently, which is
how the first one survived.

**The two conflicts are reported separately**, because they lead you to different work: *both sides
moved* means there are two sets of changes to merge, and *nothing is known to have agreed* means the
path has never been reconciled at all.

## Why it stops before the merge

The whole point of the step is a moment where somebody **looks** at what third parties changed on live
before it becomes the base of new branches. Auto-merging removes exactly the review the step exists to
add. The two Shopify consumers this shipped from answer it differently -- one merges once CI is green,
one stops at the push -- which is why it is a seam rather than a decision made for you.

## Why a standing sync branch stops the run

**Stopping before the merge only works while somebody then merges.** That is the hole in the section
above, and it is the other half of the same argument rather than an exception to it. Every run measures
live against the **trunk**. A sync branch that is pushed and never merged leaves the trunk unchanged --
so the next run re-measures against the same trunk, re-captures the same drift onto a new branch, and so
does the one after that. Nothing in the script used to look at its own previous output, so the pile grew
in silence and **each new branch looked exactly like a normal successful run**.

Measured in a consumer over seven days, from four runs (inbound
[#1021](https://github.com/DaveKJohn/claude-code-specialists/issues/1021)):

| PR | branch | files captured | state |
|---|---|---|---|
| #55 | `sync/live-2026-08-21` | 3 | open |
| #56 | `sync/live-2026-08-27` | 15 | open |
| #60 | `sync/live-2026-08-27-2` | 15 | open |
| -- | `sync/live-2026-08-28` | 21 | pushed, no PR |

The newest was a **strict superset of all three** on both axes; #56 and #60 captured the identical
15-file set and were byte-identical, which is what the same-day `-2` suffix produces when the first one
is never merged. A `-DryRun` then named the fifth before anything stopped it. **The exclusion rule was
working correctly throughout** -- it declined 31 files whose content the repo had held before. The gap
was downstream of it entirely.

**It matters more than tidiness.** The whole justification for stopping before the merge is a moment
where somebody *looks*. Four competing candidates for one set of edits is not that moment -- it is the
signal-always-present failure, where a thing that is always there stops being read.

**It refuses rather than warns, because refusing costs nothing.** The drift a refused run would have
captured is already sitting on the predecessor; the trunk lacks it either way. All the push adds is a
second candidate for the same content.

So step 4 asks `git ls-remote` -- not the local `origin/*` refs, which are only as fresh as your last
fetch and hold nothing at all for a branch pushed from another machine. Anything under **your**
`Get-ShopifySyncBranchPrefix` counts, so a consumer who set that seam to `theme-drift/` is scanned for
`theme-drift/` branches. A branch is *standing* unless it is an ancestor of the trunk, **or** its current
tip is the tip a merged PR carried -- both halves, so a repo without `delete_branch_on_merge`, where a
squash-merged ref lingers forever, is answered too. Where `gh` cannot answer, a branch reads as standing:
a refusal costs nothing, so that is the cheap side to be wrong on.

**The second half asks about the ref, not the branch NAME**, and that distinction is the whole of inbound
[#1190](https://github.com/DaveKJohn/claude-code-specialists/issues/1190). These names carry a date, so
the same one comes round again: a `sync/live-<date>` branch merges, gets deleted, and a later run the
same day picks that name for a **new** branch. Matching the name alone let the merged one vouch for the
new one -- so the guard reported *"all merged"*, found nothing standing, and pushed a `-2` branch onto
exactly the pile it exists to prevent. Measured in a consumer on September 1, 2026:
`sync/live-2026-09-01` merged as PR #141 and deleted, re-created the same day with open PR #159, and
`4.27.0` reported `1 found on origin, all merged`. The tip is compared now, which also declines a branch
somebody pushed one more commit to after its PR merged.

Two rows come out of it, and the verdict runs wherever the take set is complete -- the dry-run report,
the pre-push report, and the "nothing to sync" exit, which is the most misleading place to stop quietly:

| the report says | what to do |
|---|---|
| *N file(s), all of them in this run* | this run supersedes it. Close that PR, re-run, merge this one. |
| *N file(s), M NOT in this run* | neither supersedes the other, and the uncovered paths are named. |

**Supersession is measured on paths, never content**, and that is stated rather than assumed: each run
writes live's *current* bytes, so a path both runs captured is fresher here by construction. The case it
does not cover is the second row -- a path a third party **reverted** on live between the runs is no
longer drift, so this run never captures it and that branch holds the only copy. That is what
`-AllowStacking` exists for.

**A dry run is exempt from the refusal**, for the reason it is exempt from the clean-tree check: it
writes nothing, and *"does today's drift already contain that open PR?"* is exactly the question somebody
staring at four sync PRs needs answered. A refusal there would withhold it.

## Parameters

| parameter | what it does |
|---|---|
| `-DryRun` | pull into a mirror, print the verdict for every differing path, and **write nothing at all**: no branch, no commit, no push, and the working tree is not touched. Allowed on a dirty tree, deliberately -- refusing there would make the check unavailable at the one moment it is worth running. Run this first. |
| `-Store` | store domain to pull from, overriding `Get-ShopifyStoreDomain`. For a repo whose seam is not answered yet, or a one-off against a second store. |
| `-MirrorPath` | use a live mirror you already have instead of pulling one, for rehearsing the rule offline. The mirror is read and never modified. |
| `-KeepMirror` | do not delete the pulled mirror afterwards. A **refused** run keeps it regardless, because the conflict report names files inside it. |
| `-StopBeforeMerge` | push the sync branch and stop, even where `Get-ShopifySyncMerges` says to merge. The escape valve runs in the **safe direction only**: there is no switch that forces a merge the seam has not asked for. |
| `-AllowStacking` | run even though a sync branch from a previous run is still standing. Without it such a run is refused before the pull. What it is *for* is the one case where the two branches are genuinely independent -- a path a third party **reverted on live** between the runs is no longer drift, so this run never captures it and that branch holds the only copy. The run then still prints the per-branch verdict, so a second candidate is a decision rather than an accident. See [Why a standing sync branch stops the run](#why-a-standing-sync-branch-stops-the-run). |
| `-ReconcileBase` | on a run that **refuses for conflicts**, write the reconciliation base for those paths instead of only printing the diff commands: a sync branch carrying live's bytes verbatim and then the trunk's own bytes straight back on top. No file changes, and the run still exits 1 -- nothing was taken from live. See [A conflict you reconcile by hand](#a-conflict-you-reconcile-by-hand) for why one commit cannot do this. Under `-DryRun` it reports the base it would write and writes nothing. |
| `-ChecksTimeoutMinutes` | how long to wait for CI on the sync PR before giving up and leaving it unmerged. Only used when the seam says to merge. Default: `15`. |
| `-SkipPull` | **retired.** It meant "run the rule over the working tree", which cannot mean anything now that the pull goes to a mirror and the tree is written only for `take-live` paths. It is still accepted, purely so the refusal can name what replaced it: `-DryRun` or `-MirrorPath`. |

## The seam answers it reads

All from your own `scripts/repo-config.ps1`, all read defensively -- an absent function falls back to the
default beside it. `adopt-shopify-floor` writes the block; the two required ones refuse rather than guess.

| seam | default | what it decides |
|---|---|---|
| `Get-ShopifyLiveThemeId` | **required** | which theme is live. A non-numeric answer counts as no answer, exactly as the guard reads it -- a `VUL-IN` left in place would otherwise read as answered. |
| `Get-ShopifyStoreDomain` | **required** | the store the pull reads from. `-Store` gets you through one run; answering the seam is the durable fix. |
| `Get-ShopifySyncReferencePattern` | `^[Ss]ync` | the pattern that recognises a sync commit. It is matched against the commit **subject** read as its own field, so it is a .NET regex -- not git's `--grep`, which the lookup no longer uses. It applies to the repo-wide answer and to each path's own base alike. |
| `Get-ShopifySyncBranchPrefix` | `sync/live-` | the drift branch's prefix. It has to line up with whatever your PR guardrails and CI exempt, which is why it is yours to set. |
| `Get-ShopifySyncMerges` | `$false` | `$true` opens the PR and merges it once CI is green. |
| `Get-ShopifySyncPrBody` | *(none)* | the PR body. Called with `-Take`, `-Keep` (the classified rows, each carrying `Status`/`Path`/`Reason`) and `-Default` (the body the script composed), and it returns the body to use. |
| `Get-ShopifySyncPrLabels` | *(none)* | the label(s) the sync PR carries. Returns a string or an array of them; empty and absent both mean no label. Answer it where a guardrail workflow fails an unlabelled PR. |
| `Get-TrunkBranchName` | `main` | the trunk. |
| `Get-PrMergeMethod` | `merge` | read only when `Get-ShopifySyncMerges` is true. |

**Why the default pattern carries a capital.** The two consumers that wrote this script spell their sync
commits differently: one writes `sync: live theme drift <date>`, the other has written `Sync main with
live theme (<store>)` since May 2026 -- capital S, no colon. A pattern that matches one finds *nothing*
in the other, falls through to the tag lookup, finds nothing there either in a repo with no tags, and
**aborts on the first run**. `^[Ss]ync` is exactly the two spellings in use and nothing wider.

**And no pattern can fix a body line, which is why that one is handled in the lookup itself.** `--grep`
matches any *line* of a message, so it cannot tell "the subject starts with sync" from "a body line
starts with sync". A merge commit carries the merged commit's subject in its body, so right after a sync
PR lands the merge matches and the floor becomes `HEAD`; the lookup took `--no-merges` for that (inbound
[#801](https://github.com/DaveKJohn/claude-code-specialists/issues/801)).

**That flag was necessary and not sufficient, and the lookup no longer uses `--grep` at all** (inbound
[#819](https://github.com/DaveKJohn/claude-code-specialists/issues/819)). `--no-merges` removes merge
commits and nothing else, so an *ordinary* single-parent commit whose body happens to open a line with
`sync` still became the floor -- a commit message that merely **discusses** the sync script was enough.
Measured in a consumer that had already taken the `--no-merges` repair: the floor landed 48 minutes too
late, on a `fix:` commit, and `floor..HEAD` fell from 13 commits to 5 -- eight commits of trunk work
reading as untouched and about to be overwritten by live, on a run reporting a reference point and
looking green. So the pattern is now matched against the commit **subject**, read as its own field.

Nothing about the seam changed: `Get-SyncDefaultReferencePattern` and the pattern you pass still mean
exactly what they did, and still narrow. `--no-merges` stays because a merge's own subject is `merge:`
and keeping the flag makes the intent legible. The suite pins the true positive, the merge, the body
line, and both old shapes, so neither can come back as a cheaper equivalent.

**Which directories are compared is not a seam**, deliberately: the set is defined by the platform
(`assets`, `blocks`, `config`, `layout`, `locales`, `sections`, `snippets`, `templates`), not by your repo.
Naming them explicitly is what keeps everything of the repo's own -- `scripts/`, `CLAUDE.md`, the workflow
folder -- out of the comparison and therefore out of any commit. **Gitignored paths are skipped too**;
`config/settings_data.json` is the case that matters, since a repo that ignores live's settings file would
otherwise see it arrive as brand-new foreign content on every single run.

## When it refuses, and why each refusal is the safe answer

| it says | what to do |
|---|---|
| the working tree is not clean | commit or stash. Your work would otherwise be committed as third-party drift. Or pass `-DryRun`, which writes nothing. |
| `Get-ShopifyLiveThemeId` does not answer with a theme id | run `shopify theme list` and answer it -- see the `adopt-shopify-floor` skill. |
| no store domain | answer `Get-ShopifyStoreDomain`, or pass `-Store` for this run. |
| **no reference point: no matching commit and no tag** | this repo has no sync history at all, so no path has an agreement point with live and nothing can tell third-party drift from work the trunk has simply not pushed yet. Tag the current state, or sync by hand this once. **Kept as deliberate conservatism since #1535**, not as a guard against data loss: a path with no agreement point is now *reported* rather than taken, so such a run would conflict on everything foreign instead of overwriting it -- but a first-ever reconciliation is better done by a person than read off a hundred-path conflict list. |
| **REFUSING TO SYNC: both sides changed these paths** | the one case nothing can decide for you. Nothing was written. Run the `git diff --no-index` line it prints for each path -- and then read the next section before you commit the merge, because **the obvious single commit settles nothing**. |
| twenty sync branches already exist for today | something is wrong upstream of this; nothing was written. |
| **a sync branch from a previous run is still standing** | look at what it holds and merge or close it, then run this again. Nothing was pulled and nothing was written. `-DryRun` answers whether *this* run supersedes it without writing anything; `-AllowStacking` runs anyway where the two are genuinely independent. |
| this repo publishes plugins | you are in the repo this script is maintained in, not a Shopify consumer. There is no live theme here to mirror. |

## A conflict you reconcile by hand

**The refusal used to end at "merge them deliberately", and that is complete advice about the content
and silent about the shape.** Merge the two sides, commit once, and the path is not settled -- it is in
one of two failures, and which one you get is decided by nothing but the commit's subject. Reported from
a consumer as inbound
[#1945](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1945), measured there on seven
conflicted paths and reproduced against the rule's own functions:

| the reconciliation commit's subject | what the next run does |
|---|---|
| ordinary (`fix:`, `feat:` ...) | **`conflict`, for ever.** The base is where it was, the trunk has moved since it, and every future run reports the same path. Permanently unsyncable. |
| matching `Get-ShopifySyncReferencePattern` (`sync...`) | **`take-live` -- your reconciliation is deleted.** That commit becomes the path's own agreement point, so nothing has touched the path "since the base" and live wins silently. |

**Why neither works, in one sentence:** the rule asks whether this path has ever held live's *exact*
bytes, and merged bytes are neither side's -- so a hand-merge carries no provenance, and no commit
subject can give it any.

**The durable shape is two commits**, and `-ReconcileBase` writes them:

```powershell
powershell -NoProfile -File scripts/task/sync-main.ps1 -ReconcileBase
```

1. **live verbatim** -- the only thing that puts live's content into the path's history;
2. **the trunk's content straight back on top** -- so the branch changes no file at all.

Merge that branch and the path reads `keep-trunk` from then on: *"live holds a version this repo has had
before; the trunk has moved on since"* -- the same state every ordinary held-back file is in. **Your own
reconciliation is then ordinary work in an ordinary commit**, in any spelling, because the path's verdict
no longer depends on what a subject line says. A *new* third-party edit after that is caught as a fresh
conflict, exactly as it should be.

**Do not squash that branch.** A squash collapses both commits into one holding the trunk's content, so
live's bytes never enter the history and the conflict comes straight back. It costs the repair and not
the work -- the tree is identical either way -- and the run says so out loud when
`Get-PrMergeMethod` answers `squash`.

**And it is a sync branch like any other**, so until it is merged or closed the standing-predecessor
guard refuses the next run by name. That is deliberate rather than an oversight: a second way for a sync
branch to be invisible is the direction that loses work, and "merge or close it" is already the right
instruction here.

## Why this ships instead of being written per repo

Two Shopify consumers wrote this script independently, and the first version of it **destroyed work** --
one of them recorded the same wholesale procedure reverting merged work three times in one week. The
exposed party is the *next* consumer, who has no sibling repo to copy from and no reason to suspect that
the obvious implementation of "mirror live" is the one that eats their unpushed work. Inbound
[#787](https://github.com/DaveKJohn/claude-code-specialists/issues/787) is the report;
[#801](https://github.com/DaveKJohn/claude-code-specialists/issues/801) and
[#807](https://github.com/DaveKJohn/claude-code-specialists/issues/807) are the two repairs since.

**And the two halves of this marketplace interact, which nothing said before.** In a repo that has
adopted a changelog, *"merged into the trunk but not live yet"* is a **designed** state -- it is what an
entry sitting in `CHANGELOG.md` means. Every such entry names work a wholesale sync would have reverted.
So adopting the workflow plugin's changelog model makes the naive sync **strictly more dangerous** -- and
it is exactly the state a time window cannot protect, which is why the rule now reads content.

The rules live in `scripts/lib/sync-rules.ps1` as named, tested queries rather than inline, because the
risk is in the queries and not in the policy: the policy is one sentence, while *"has this path ever held
these bytes"* has to answer correctly **for a path the trunk deleted** -- and that is the case both
hand-written implementations got wrong, the second time by writing `--` inline into a native call where it
never reaches git.
