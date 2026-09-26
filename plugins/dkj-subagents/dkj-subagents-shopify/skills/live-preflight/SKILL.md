---
name: live-preflight
description: The step between a merged trunk and a live Shopify theme push, which used to be assembled by hand from prose every release. It verifies the stand, derives the push list from the range rather than from the changelog, hands that list to the repo's drift check AS AN ARRAY, takes one verified backup as the rollback point, and prints the push command. Use it on the trunk once a release is merged and green, before anything reaches live. Two things it never does, both by construction: it never runs `shopify theme push` -- the live guard reads command strings and cannot see inside a script -- and it never writes the authorisation marker, because green means the checklist is complete, never that the push is authorised.
---

# live-preflight -- the one step that can refuse the push

Everything else this plugin ships sits either **before** the merge (`push-preview`, `sync-main`) or
**after** the push (`backup-live-theme`, `archive-theme`, `sweep-preview-themes`). Nothing stood at
the push itself -- the one moment in the whole cycle where a mistake is visible to paying customers.
Inbound [#2228](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2228).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/live-preflight.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component**. From an ordinary shell,
spell the plugin cache path out.

| Parameter | What it is for |
|---|---|
| `-Store` | overrides `Get-ShopifyThemeEstateStore` for this run. |
| `-SinceTag` | derive the push list from this tag instead of the highest `vX.Y.Z` in the repo. For a re-cut, or where the last release was not the last tag. |
| `-DriftCheckPath` | the repo's drift check, relative to the root. Default `scripts/theme/live-snapshot.ps1`. |
| `-SkipGates` | do not re-run the repo's own lint and tests. For a second run where nothing has been committed since. |
| `-SkipBackup` | do not take the backup. Only correct when a **verified** backup of this same live stand already exists. |

## The two boundaries, and neither is negotiable

**1. It never runs `shopify theme push`.** This plugin's live guard is a **PreToolUse hook that reads
the command string** of a tool call, so it cannot see inside a script -- a push performed in here
would disable the last rail standing around live. The same reasoning
[`archive-theme`](../archive-theme/SKILL.md) gives for printing its delete rather than performing it.

**2. It never writes the authorisation marker.** A green run means *the checklist is complete and the
push is allowed to be made*. It never means the push is **authorised**. The marker authorises one
command, visibly, in the transcript, and it stays a human act -- so the command this prints is
**refused as it stands**, deliberately, until a person appends their own marker.

The rule that holds boundary 2 is in the code rather than in this page: `Format-LivePushCommand`
cannot produce a marker even if a later caller asked it to, and the script never reads
`Get-ShopifyLivePushMarker` at all. A run that held the marker in a variable is one edit away from
printing it onto the command it also prints.

## The three failures it mechanises

### 1. The push list is not the changelog

Measured in the consumer preparing v2.44.0: `v2.43.0..HEAD` held **61 changed files, of which 11**
lived in the eight theme directories. The other 50 were scripts, tests and docs that **do not exist on
a theme**. That repo's own `CLAUDE.md` warns about exactly this in words -- *"de pushlijst is niet de
changelog"* -- which is what a rule looks like when nothing enforces it.

So the list is **derived**, three verdicts, each its own refusal:

| verdict | what happens |
|---|---|
| `theme-file` | under one of the eight theme directories. It is pushed. |
| `not-a-theme-path` | it is not. The CLI has nowhere to put it, so pushing it is not "extra safety". |
| `sync-owned` | under a theme directory, but a sync mirrored it **from** live. Those bytes are already there, and pushing them back can revert a third party's later edit. |

**Every path gets a row, including the ones held back.** That is the design rather than verbosity, and
it is the same property the preview sweep's report has for the same reason: a list that printed only
the keepers would be unfalsifiable, because the files it must never push are exactly the rows it would
not print.

**The range starts at the highest tag compared as a VERSION**, which is why that is a function with a
suite behind it rather than a `sort`. `v2.9.0` sorts **above** `v2.44.0` lexically, and the consumer's
repo holds both -- a lexical pick hands the preflight a range starting far too early, and a push list
that is too long is the direction that overwrites live files nobody changed.

### 2. The list has to arrive as an array

The drift check takes `-Only`. At v2.39.0 that list reached it through `powershell -File`, which
delivers every argument as **one string that never splits on commas**. The check snapshotted **zero**
files and printed a green *"safe to push"*. The rollback artefact for that release did not exist and
nothing said so.

Step 6 calls the check **in this process** with a real `[string[]]`, which is a mistake a caller that
owns the list cannot make -- the defect is closed by construction rather than by remembering.

**DRIFT IS A REFUSAL, not a warning.** A file a third party has edited on live since this repo last
saw it is a file whose push destroys their work.

### 3. A path in the printed command is text a shell will parse

The push command is printed for a person to paste, and its paths come off `git diff`, so they may
come from a sync branch the theme editor wrote. Nobody in the repo typed them. Measured in
[#2514](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2514): `assets/$(calc.exe).css`
was printed as-is and the subexpression ran when the line was pasted, a `;` split it into two
statements, and a newline split the printed command itself. git's own quoting fires on none of the
three.

So **step 3 refuses** a push list holding any path outside letters, digits, `.`, `_`, `/` and `-`, and
names each refused path with its control characters stripped. It refuses at step 3 and not at the
command because of the cost ordering below: the backup is then skipped. **Latin accents
(U+00C0-U+017F) are admitted**, because a theme filename with one is real (#821 measured one through
`sync-main`) and refusing it would block that store's live push with nothing to do but rename a file
the theme editor made. Past that range are letters that display as punctuation, so they are refused.
`Format-LivePushCommand` throws on such a path as well, so no caller can print one.

## The nine steps, and why they are in this order

| # | step | refuses when |
|---|---|---|
| 1 | **trunk** -- clean, on the trunk, level with `origin` | anything else. A live push ships what is *merged*. |
| 2 | **gates** -- the repo's own lint and tests | one of them fails. |
| 3 | **push list** -- derived from the range | nothing in the range lives on a theme, or a theme path is not safe to paste (below). |
| 4 | **version** -- what the pending entries owe, and the target | never; it reports. |
| 5 | **live theme** -- by configured **id** and by the **role** the store reports | the two disagree, or the id is not in the list. |
| 6 | **drift** -- the check, with the list as an array | the check says the live files are not what this repo thinks. |
| 7 | **backup** -- one verified copy of live | the backup cannot be proven complete. |
| 8 | **the push command** -- without the marker | never; with no list there is simply no command. |
| 9 | **aftercare** -- what the sweep would take | never; the sweep's dry run is its default and no `-Execute` is passed. |

**The order is cost-ordered and that was asked for.** The backup polls until the copy is provably
complete, which took roughly **eight minutes** in that store, so it runs after every cheap gate has
passed. Failing a lint gate must not cost eight minutes first.

**And step 7 does not run at all once something above it has refused.** It is the only step that
*writes* to the store -- it duplicates a theme and **rotates the previous backup out** -- so spending
it on a push that is not going to happen costs a theme slot on a finite estate and replaces a good
backup with a rollback point for a stand nobody is pushing from. It reports as `SKIPPED` with that
reason, and the run carries on so you still get the whole picture.

**Step 5 asks the same question twice on purpose.** The configured id and the role the store reports
are the same theme today, and the day they differ one of them is the only guard left -- the same
pairing the preview sweep refuses on.

## What a `SKIPPED` line means, and why it is not a pass

A step whose seam the repo has not answered reports **`SKIPPED`** and the run stays allowed. Refusing
there would break a repo that never adopted the optional half on its next plugin update.

But it does not vanish either -- it is named in the verdict, because **a checklist that reads green
while a step sat inert** is the exact failure the drift check's own green *"safe to push"* already
demonstrated on this procedure, with nothing said.

## The backup's moment moved, and that changed what it is for

`backup-live-theme.ps1` needs **no behavioural change** and got none: `CREATE -> VERIFY -> ROTATE`
stands verbatim, the previous backup is dropped only once the copy is proven complete, and there is
never a window in which the store holds no backup. Moving *when* it runs is not licence to reorder it.

What changed is the **caller**, and therefore the purpose:

| moment | what the copy is |
|---|---|
| **after** the push (the closing step of a cut) | a **baseline of what shipped** -- the fixed point third-party drift is measured from. |
| **before** the push (from here) | a **rollback point** -- the stand to return to if the push goes wrong. |

**Why a store would choose the earlier moment**, recorded because it is the argument a second consumer
would want:

- A Shopify push is per file, has no locking, and **can arrive partially**. A backup taken *after* such
  a push has captured the broken state, so by construction it is not a rollback.
- The drift check's own rollback artefact covers **only the push list** -- 11 files of 61, that
  release. A theme-level duplicate covers everything, including whatever a third party has on live
  that nobody enumerated.
- Losing the after-the-push baseline costs little: the only difference between the two copies is this
  repo's own push list, and that is in git.

A repo that wants the baseline reading keeps calling it at the cut, unchanged. The shared script no
longer asserts either -- it states what it **guarantees** and names both moments.

**One thing to expect on the rotation**: it is guarded and runs only where the repo has answered
`Get-ShopifyThemeDeleteMarker`. Where that seam is unanswered the script **prints** the delete for a
person to run, which is a **completed step** rather than a failure -- see
[`theme-lifecycle`](../theme-lifecycle/SKILL.md).

## The seams

| seam | required? | what it answers |
|---|---|---|
| `Get-ShopifyThemeEstateStore` | **required** | the store this acts on. `-Store` gets you through one run. |
| `Get-ShopifyLiveThemeId` | **required** | which theme is live. Every step after 4 is about that theme, so it refuses rather than guessing. |
| `Get-TrunkBranchName` | optional | the trunk, default `main`. |
| `Get-ShopifySyncBranchPrefix` | optional | how a sync branch is spelled, default `sync/`. Unanswered in a repo that uses another spelling, no path is classified `sync-owned` -- which is the safe direction. |
| `Get-LintScript` / `Get-TestCommands` | optional | the repo's own gates. Neither answered, step 2 says so and runs nothing. |
| `Get-ChangelogPath` | optional | where the pending entries are, default `CHANGELOG.md`. |
| `Get-ShopifyDriftCheckPath` | optional | the drift check, default `scripts/theme/live-snapshot.ps1`. |

### `Get-ShopifyLivePushMarker` is deliberately absent from that table

The guard hook reads it; this does not, and that is boundary 2 held by construction rather than by
discipline.

### And `Get-ShopifyDriftCheckPath` is a bridge, named rather than smuggled in

#2228 argued for building this upstream partly because *"every seam it needs already exists"* -- and
that holds for every **fact** it needs. What did not exist is the **path** of the drift check, because
that script is still consumer-side. So the seam is optional with a conventional default. The same
issue calls `live-snapshot.ps1` *"a strong candidate to move in the same release"*; the day it moves,
this seam stops having a job.

## What the bump step does and does not decide

Step 4 reports what the pending entries owe **by calling the release workflow's own rule** where the
repo has a local copy of it, and says it could not read otherwise. It does **not** restate that rule:
which bump a pending set earns is one rule, owned by the workflow that cuts releases, and a second
copy of it inside a Shopify plugin would be free to drift from the gate that actually enforces it.

The arithmetic of adding one to a version component is local, because that is not a policy.

## What is tested, and what cannot be

`scripts/tests/live-push-rules.tests.ps1` pins the rules the script invokes: the eight theme
directories (**including that `sync-main.ps1` no longer carries its own copy**), the push-list
classification in all three verdicts with the near-miss and separator cases, the numeric tag pick that
lexical sorting gets wrong, the push command's shape and its refusal to produce one for an empty list,
the paste-safety check on its three measured shapes and on the accented paths it must still admit,
and the verdict fold -- including that a skip is not a pass and an unrecognised state is a refusal.

**The script itself is not driven**, for the reason [`push-preview`](../push-preview/SKILL.md) gives:
every path in it reaches git, the Shopify CLI against a real store, or a consumer's `repo-config.ps1`,
and a suite must not be able to reach a store. What therefore cannot be asserted here is the ordering
of the nine steps and the git derivation of sync provenance.
