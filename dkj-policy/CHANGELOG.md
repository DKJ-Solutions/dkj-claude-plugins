# Changelog

## [Unreleased]

**23 / 34 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2616-placed-workflows-linux-runners · 20260929-100014Z

`merge-on-green` and the gates `adopt-dkj-policy` places now run on `ubuntu-latest` under `pwsh`, with
#2488's one-line shim that makes `powershell` resolve to `pwsh`. The gates are `branch-entry`,
`always-on-budget` and `unfolded-entry`, including the reusable copies consumers call. That covers this
repo's copies and the `merge-on-green` template `adopt-ci-floor` places. A consumer calling the reusable
gates at `@main` moves at this merge. A `merge-on-green.yml` it already has is left alone, like every file
the floor places, so it stays on Windows until it is re-scaffolded. The `branch-entry-gate` and
`always-on-budget` suites join CI's Linux leg. `merge-on-green` runs the default branch's copy, so its
first Linux run is the first sweep after this merge. If that breaks, the fold and the resolves still land
through `fold-on-merge` and `verify-resolved`, which have run on Linux since #2488. Issue #2616.

Every CI job that judges this repo's tree stays on `windows-latest`. The move is to the runners around it.
**Score:** 3

#### What makes this deploy extra special

On a private consumer, the gate that runs on every PR event (`Branch entry`: 137 runs in one consumer in
September, #2487) and the merge sweep now bill Linux minutes instead of Windows ones. Nothing changes in
what they check.
**Score:** 2

#### Pull Request

Move merge-on-green and the other placed Windows-only workflows to ubuntu-latest + pwsh

Plugins: dkj-policy

[PR #2626](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2626)

---

### DEPLOY: fix/2619-golive-bare-live-urls · 20260929-094828Z

The go-live block's live-URL list now shows plain storefront URLs. They were pinned to the live theme
id, so every "live" link read `?preview_theme_id=...` and looked like a preview link to the colleague
reading it. Beside a result link, the label now tells the reader to open the links in a private window
until the release, since a browser that opened the preview keeps showing it. `-LiveThemeId` is gone
from `build-golive-block.ps1` (#2619).

**Score:** 2

#### What makes this deploy extra special

In a store repo running `dkj-policy-bwj`, the block pasted into Asana no longer has to be rewritten by
hand before it goes out: the live links are the plain URLs a colleague recognises. A session that still
passes `-LiveThemeId` to `build-golive-block.ps1` is refused by parameter binding, so drop the argument.

**Score:** 2

#### Pull Request

golive-block: the live-URL list is bare, with the private-window caveat

Plugins: dkj-policy-bwj

[PR #2625](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2625)

---

### DEPLOY: fix/2488-ci-floor-linux-runners · 20260929-084404Z

Three of the four CI-floor runners now run on `ubuntu-latest` under `pwsh`: `fold-on-merge`,
`verify-resolved` and `repo-settings`. That covers both this repo's own copies and the templates
`adopt-ci-floor` places. Each gets a one-line shim that makes `powershell` resolve to `pwsh`, because the
scripts launch their children under that name. `merge-on-green` stays on `windows-latest`, since it drives
`ship-pr`'s whole merge path and cannot be proved on its own PR (#2616). The move was measured before it
was made: a probe ran the runner-path suites on the runner itself. Making those suites OS-portable then
exposed four real Linux defects in `native-capture-lib.ps1`, all repaired here:

- an absent environment variable was restored as `''`;
- a timeout left grandchildren alive, because `taskkill` does not exist there;
- a refused launch escaped the `-Utf8` arm's catch;
- pwsh 7's Unix `Start-Process` redirect dropped every empty line of a capture, which would have handed
  `Get-GitFileTextAtRef` a wrong document. Off Windows, that arm now copies the child's pipes byte for
  byte.

A new `linux-runner-path` job in CI runs the nine runner-path suites under `pwsh` on Linux. It is now
part of the required `lint-en-tests` check (#2488).

**Score:** 3

#### What makes this deploy extra special

A private repo that adopts the CI floor now pays the Linux minute rate for the two runners that fire on
every push to the trunk ($0.006 against $0.010 a minute). In the consumer behind #2487 those two ran 265
times each in September. A repo that already placed the runners keeps its `windows-latest` copies, since
`adopt-ci-floor` never overwrites one. To take the saving there, move the runner by hand, or delete it
and adopt again.

**Score:** 3

#### Pull Request

Move fold-on-merge, verify-resolved and repo-settings to ubuntu-latest + pwsh

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2618](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2618)

---

### DEPLOY: fix/2601-adopt-ci-floor-oom · 20260929-073829Z

`adopt-ci-floor.tests.ps1` now fails when an `adopt-ci-floor.ps1` child dies on an exception. Before
this, such a run could still finish green, because the child's error went to stderr, which nothing read,
and the negative asserts passed on the output it left behind. The intermittent `OutOfMemoryException`
the report was about did not reproduce here or in CI (#2601).

**Score:** 1

#### What makes this deploy extra special

N/A. The test suite stays in this repo, and nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

adopt-ci-floor suite fails on a child that died on an exception, instead of passing on its truncated output

[PR #2617](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2617)

---

### DEPLOY: fix/2609-claim-refuses-pull-request · 20260928-203133Z

`claim-issue` now refuses a pull request's number instead of claiming it. `gh issue view` answers for
a PR too, and a merged one reads as `MERGED`, a state the old check did not refuse, so the claim went
through and put an assignee on the merged PR. The refusal names the issue the PR closes, and any state
other than `OPEN` is now refused (#2609).

**Score:** 2

#### What makes this deploy extra special

If you type a PR number where you meant an issue, `claim-issue` now stops. It does not print `[OK]` and
does not assign you to the pull request. It names the issue that PR closes, so you can re-run on that
number.

**Score:** 2

#### Pull Request

claim-issue refuses a pull request's number and names the issue it closes

Plugins: dkj-policy

[PR #2615](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2615)

---

### DEPLOY: feat/prio-label-colors · 20260928-202125Z

The four `prio-` labels now read as two yellows and two reds, on Dave's request: `prio-1` is yellow
(`FFE033`), `prio-2` a yellow leaning to orange (`F9A825`), `prio-3` a red leaning to orange (`E0321A`)
and `prio-4` stays red (`B60205`). They replace the teal → yellow → orange → red ramp. The canonical set
`adopt-triage-labels` prints and the BWJ adopt skill's step 4 carry the new hexes, and this repo's live
labels were re-coloured. Moving `prio-2` off `FBCA04` also ends its shared badge colour with `tier-1`
in a BWJ repo (#1844). A repo that already has the labels keeps its old colours until someone runs
`gh label edit --color`, because the adopt steps never rewrite an existing label.

**Score:** 2

#### What makes this deploy extra special

N/A -- a badge colour on the issue tracker. No release document reader acts on it.

**Score:** N/A

#### Pull Request

Re-colour the prio labels: yellow for 1-2, red for 3-4

Plugins: dkj-policy, dkj-policy-bwj

[PR #2614](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2614)

---

### DEPLOY: fix/2600-lens-naming-retired-spelling · 20260928-201122Z

`check-roster-sync` no longer tells a repo whose lens is still named `<g>-<id>-extension.md` that
nothing needs changing. No reader has resolved that spelling since #2292, so the check now reports the
specialist as running without its lens, and prints the `git mv` to the current name (#2600).

**Score:** 2

#### What makes this deploy extra special

If your repo still has a lens file named like `06-24-extension.md`, the session-start check now shows
it as an error with the exact rename to run, instead of a yellow line asking you to update the plugins.
Updating the plugins never fixed that file. Renaming it is what gives that specialist its repo lens back.

**Score:** 2

#### Pull Request

check-roster-sync names the rename for a lens under the retired spelling, instead of saying nothing needs changing

Plugins: dkj-subagents-alpha

[PR #2613](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2613)

---

### DEPLOY: feat/allow-git-stash · 20260928-195354Z

A session in this repo can now stash uncommitted work without a permission prompt, so retiring or
switching away from a branch with a draft on it no longer stops for a question. A stash is reversible,
unlike the destructive verbs the safety rules name, which stay unlisted.

**Score:** 2

#### What makes this deploy extra special

N/A: `.claude/settings.json` is this repo's own harness config and reaches no consumer through a plugin
update.

**Score:** N/A

#### Pull Request

git stash is allowed without a permission prompt

[PR #2612](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2612)

---

### DEPLOY: fix/2604-parking-label-shares-dossier-color · 20260928-193357Z

The `awaiting-recurrence` parking label now has `dossier`'s colour (`5319E7`) instead of its own grey. An
issue meant to stay open for a while now looks the same on the tracker, whichever of the two it carries (#2604).

**Score:** 1

#### What makes this deploy extra special

A repo that runs `adopt-triage-labels` now gets `awaiting-recurrence` printed with `dossier`'s colour.
The script does not compare the colours of labels that already exist, so if you already have the label
and want the same look, run `gh label edit awaiting-recurrence --color 5319E7`.

**Score:** 1

#### Pull Request

awaiting-recurrence takes dossier's colour, so the labels that keep an issue open look alike

Plugins: dkj-policy

[PR #2611](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2611)

---

### DEPLOY: fix/2605-connector-notes-english · 20260928-191948Z

The `#1769` migration passage in five connector records' `notes` is now in English, as the repo's
content-language rule requires. It was the Dutch passage #2605 named, and the word check in TEST finds no other Dutch under `connectors/`.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Five connector records carry their #1769 migration note in English

[PR #2610](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2610)

---

### DEPLOY: fix/2602-merge-on-green-pr-branch-identity · 20260928-185959Z

This repo's merge-on-green runner now gives the `pr-branch` checkout a commit identity too, so an `open-pr` commit of a dirty branch document during a CI ship cannot fail with *Please tell me who you are*. Latent until now, since `pr-branch` is a fresh checkout; it brings the runner level with the consumer template.

**Score:** 1

#### What makes this deploy extra special

N/A -- this is the source repo's own CI runner; nothing a consumer takes changes.

**Score:** N/A

#### Pull Request

merge-on-green sets the commit identity in pr-branch as well as trusted-main

[PR #2608](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2608)

---

### DEPLOY: fix/2449-consumer-merge-on-green-trusted-seams · 20260928-185015Z

The `merge-on-green.yml` that `adopt-ci-floor.ps1` scaffolds into a consumer now uses three sibling
checkouts:
- the pinned plugin tree;
- a token-free `trusted-main`, where ship-pr reads the consumer's two repo-owned seams through
  `-TrustedRoot` and commits the fold;
- a token-free `pr-branch`.

Before, it used one token-bearing workspace that was switched to the picked branch in place. The push
credential is an ephemeral `GIT_CONFIG_*` overlay in the ship step. A re-run of `adopt-ci-floor` names
an existing runner of the old shape with a `[shape]` line, because the scaffolder never rewrites one.
For the same reason, the shared picker's `.workflow-scripts/` refusal (#2553) is now documented as
permanent. This is the structural fix for what #2553 could only denylist (#2449).

**Score:** 2

#### What makes this deploy extra special

If you adopted the CI floor before this release, your `.github/workflows/merge-on-green.yml` still has
the old single-workspace shape, and nothing rewrites it for you. Re-run `adopt-ci-floor` (Part 3 of
`adopt-dkj-policy`). If it prints a `[shape]` line, delete that one file and re-run with `-Apply`. Until
you do, the shared picker's standing refusal covers the worst case. The new shape also stops a pull
request's own copy of `scripts/repo-config.ps1` or `scripts/lib/branch-info.ps1` from running beside
your `FOLD_PUSH_TOKEN`.

**Score:** 3

#### Pull Request

The consumer merge-on-green runner runs from three sibling checkouts, none holding a credential

Plugins: dkj-policy

[PR #2607](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2607)

---

### DEPLOY: fix/2592-djcylow-connector-org · 20260928-183820Z

The djcylow-react connector record now names its current owner, `DKJ-Solutions/djcylow-react`. The
record still named the pre-transfer `DaveKJohn` slug, so on any machine with that checkout
`check-connectors` skipped the whole block with an `[ERROR]` that nobody could clear (#2592).

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

The djcylow-react connector record names the repo's new owner

[PR #2606](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2606)

---

### DEPLOY: feat/2591-lens-retired-spelling-finding · 20260928-181727Z

`check-connectors` check 7 now reports a consumer lens still named `<g>-<id>-extension.md`. It is an
error when that specialist has no current-spelling lens, because since #2292 no reader loads the old
name and the lens is silently gone. It is a note when a current copy sits beside it. The
`[LENS-RETIREMENT]` roll-up that led up to the retirement is removed, which closes
[#2591](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2591).

**Score:** 2

#### What makes this deploy extra special

A repo that keeps a lens under the old name now gets a red line at session start with the `git mv`
that fixes it, where before its specialist quietly ran without that lens. All six registered consumers
are already over, so this reaches nobody we know of.

**Score:** 1

#### Pull Request

check-connectors reports a lens under the retired spelling instead of the retirement roll-up

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2603](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2603)

---

### DEPLOY: fix/2595-plugin-link-illegal-path-chars · 20260928-162145Z

A link target holding `<`, `>`, `"` or `|` no longer crashes `check-plugin-integrity.ps1`. Under Windows PowerShell 5.1 the
path calls in check 4 and `[plugin-link]` threw on those characters. That ended the whole lint with an error that named no
file. Both scans now report such a target as a finding, and `[plugin-link]` gives its line. The measured trigger was a
placeholder `(<url>)` inside a code span that opened on the line before (#2595).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

A link target with illegal path characters is a finding, not a lint crash

[PR #2599](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2599)

---

### DEPLOY: fix/2594-contract-count-message · 20260928-160645Z

The record-count assert in `script-contract.tests.ps1` no longer names stale inner figures in its message. It said the
table pins 25 records and the test file names 26 of 43, against a real 27 and 28 of 46. Nothing asserts prose, so the
figures fell one further behind with every new record. Both are now computed from the table and the record count (#2594).

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

The script-contract record-count message computes its inner figures instead of naming stale ones

[PR #2598](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2598)

---

### DEPLOY: feat/2292-retire-lens-alsoread · 20260928-153758Z

The lens file of a specialist has one name now: `specialist-<g>-<id>-lens.md`. The old
`<g>-<id>-extension.md` spelling that readers had tolerated since the #2130 rename is retired, which
closes [#2292](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2292). Every registered
consumer had already migrated when this was measured on September 28, 2026. The manual, persona and
subagent spellings are untouched.

**Score:** 2

#### What makes this deploy extra special

A consumer that still keeps a lens under `<g>-<id>-extension.md` will find that no check or scaffold
reads it any more, and has to `git mv` it to `specialist-<g>-<id>-lens.md`. All six registered consumers
were already over, so this reaches nobody we know of.

**Score:** 1

#### Pull Request

Retire the '<g>-<id>-extension.md' lens spelling now that every consumer is over the rename

Plugins: dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2597](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2597)

---

### DEPLOY: feat/2586-audience-note-solved-tasks · 20260928-152810Z

In a repo with a live stage, the cut can now be told what the live push actually carried.
`live-preflight` writes a live-push record, one `live` or `hold` line per theme file, and a person
changes `live` to `hold` for anything they held back. `cut-release -LivePushRecord <file>` reads it. The
GitHub Release body moves an entry that touched a held file from *What landed* to a new `## Not live
yet` section (#2570). The audience note leaves that entry out, so the note and the body can no longer
contradict each other the way they did at a BWJ store's v1.3.0. A new optional seam,
`Get-ReleaseNoteTaskLink`, drafts the audience section as solved tasks instead. It lists one item per
issue that carries a task marker, and only for a storefront change that is live. It has no PR links
(#2586).

**Score:** 2

#### What makes this deploy extra special

Both documents are decided from one input rather than two, which is what the v1.3.0 contradiction
required. A store answering the seam gets an audience note that needs rewording but not pruning. Until
now every cut left the developer prose and PR links to delete by hand.

**Score:** 3

#### Pull Request

The audience note drafts from solved Asana tasks, and the GitHub body separates what is not live yet

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-shopify

[PR #2596](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2596)

---

### DEPLOY: fix/2589-live-backup-restore · 20260928-144047Z

A live-theme backup now comes with a written way back. A person publishes the backup theme. A backup that passed WITH EXCEPTIONS first gets its missing paths back from the exact commit it was verified against, and the backup run now prints that commit instead of "HEAD" ([#2589](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2589)). The rotation step also no longer plans a restored (now live) backup for deletion.

**Score:** 3

#### What makes this deploy extra special

A store owner whose live push went wrong now has written steps to go back. Until now "rollback point" had no instructions behind it.

**Score:** 3

#### Pull Request

Restore procedure for the live-theme backup

Plugins: dkj-policy-bwj, dkj-subagents-shopify

[PR #2593](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2593)

---

### DEPLOY: fix/2568-backup-trunk-held-shortfall · 20260928-140456Z

`backup-live-theme` no longer refuses a copy that is short only on files the trunk holds exactly as
live holds them. After the wait it names each path live has and the copy lacks, and compares it with
the trunk at HEAD. It passes as verified WITH EXCEPTIONS only when all of them match and there are at
most 10. Any other state still refuses, as before. (#2568)

**Score:** 3

#### What makes this deploy extra special

In a store whose duplicates Shopify always leaves a few templates short, the backup step, and with it
`live-preflight`, could never pass. They now can, path by path, and a missing file the repo cannot
restore still stops the push.

**Score:** 4

#### Pull Request

backup-live-theme: accept a short copy whose missing paths the trunk holds exactly as live does

Plugins: dkj-policy-bwj, dkj-subagents-shopify

[PR #2590](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2590)

---

### DEPLOY: feat/2587-awaiting-recurrence-label · 20260928-134414Z

`adopt-triage-labels` now also prints a `gh label create` line for `awaiting-recurrence`, a parking label
for an issue whose only remaining step is its first reproducible occurrence. `claim-issue <n>` skips it
by default next to `needs-info` and `needs-decision`, and `sweep-issues` skips all three.
`CONTRIBUTING-portable.md` says when to set the label and when it comes off. It is not `dossier`: a
dossier collects a problem that demonstrably recurs, so it stays sweepable.

Tier 0 is scored for a session running a sweep. An n=1 flake with nothing left to build (#2572) was picked
up four times in one day, and each pickup ended in *nothing to do*.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a label definition, a filing convention and a default skip list, and nothing reaches a
subscriber.

**Score:** N/A

#### Pull Request

An awaiting-recurrence parking label for an issue waiting on its first reproducible occurrence

Plugins: dkj-policy

[PR #2588](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2588)

---

### DEPLOY: feat/2564-audience-note-sections · 20260928-125646Z

Inside this repo: `Build-ReleaseNoteDraft` takes `-Sections`, and `cut-release.ps1` fills it from a new
optional seam, `Get-ReleaseNoteSections`, validated by `Resolve-ReleaseNoteSections` before the cut writes
anything. This repo states all three sections, so its own notes do not change.

**Score:** 2

#### What makes this deploy extra special

A repo whose release-note readers only want to know what changed can now say so once, in
`Get-ReleaseNoteSections`, for example `@('Audience')`. The drafted note then leaves out *What it is
worth* and *What was still open at this release*, heading and hint, so nobody deletes the two headings
by hand at every cut. A misspelt section name stops the cut before anything is written. A repo that
states nothing keeps all three sections
([#2564](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2564)).

**Score:** 3

#### Pull Request

Let a consumer choose which sections the audience release note carries

Plugins: dkj-policy

[PR #2585](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2585)

---

### DEPLOY: fix/2572-roster-sync-child-stderr · 20260928-120317Z

`roster-sync.tests.ps1` now keeps its child's stderr, and when 11ua's or 11ub's finding is missing it
prints that stderr with the exit code. A failure under a loaded gate then shows whether the check threw
or its line was lost. That is the evidence #2572 lacked. This is a diagnostic, not a fix, so the issue
stays open. (#2572)

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

roster-sync.tests: keep the child's stderr, and show it when 11ua/11ub's finding is missing

[PR #2584](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2584)

---

### DEPLOY: fix/2581-untrack-wrangler-cache · 20260928-112224Z

Wrangler's own account cache (`.wrangler/cache/wrangler-account.json`, holding a Cloudflare account id
and an account e-mail) was tracked on `main` in this public repo. It is untracked now, and an anchored
`/.wrangler/` rule in `.gitignore` keeps a wrangler run from the repo root from adding it again. The
copy in history is a separate decision for the owner, #2582. (#2581)

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Untrack the root .wrangler/ cache and ignore it

[PR #2583](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2583)

---

### DEPLOY: fix/2574-progress-bar-per-checkout · 20260928-110844Z

The statusline's progress bar now shows only the runs of the checkout the session is in (inbound
[#2574](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2574)). Records sit in one directory
per machine, so a ship in another repo's window used to draw in every session, and read as a gate running
in the repo in front of you. Each record now carries its writer's working directory, and the statusline
draws a record only when that path and the session's workspace contain each other. A record from an
older writer, or a session whose payload names no workspace, is shown as before.

**Score:** 2

#### What makes this deploy extra special

Anyone working in two repos at once sees only their own repo's gate and ship in each window, instead of a
bar that looks like work running where it is not.

**Score:** 2

#### Pull Request

The statusline draws only the progress of runs in this session's own checkout

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2580](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2580)

---

### DEPLOY: fix/2566-live-push-list-skips-deletions · 20260928-105429Z

Inside this repo: `Get-LivePushRows` in `scripts/lib/live-push-rules.ps1` gained a `-DeletedPaths` set and a
`deleted` verdict, and `live-preflight.ps1` and dkj-policy-bwj's `prepare-release.ps1` now feed it from a
`--diff-filter=D` read, with rename detection off in every range read.

**Score:** 2

#### What makes this deploy extra special

For whoever prepares a store's live push: a theme file deleted since the last release is no longer
offered as a `push` row. That row claimed a change `--only` cannot make, and the file stayed on live
unnoticed. Each such file is now listed under `held` as deleted and still on live, with its own step
saying the store delete is a separate decision. A renamed file's old path, which used to be in no list
at all, is reported the same way.

**Score:** 3

#### Pull Request

live push list lists files deleted in the range as push rows

Plugins: dkj-policy-bwj, dkj-subagents-shopify

[PR #2576](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2576)

---

### DEPLOY: docs/2558-visible-result-stays-on-branch · 20260928-104254Z

A branch parked for the owner's visual review now keeps the checkout on that branch. The constitution's visible-result rule says so, and Chris's "it ends on the trunk" rule no longer fires on a park: that chain is not finished, since its next step is the owner looking at the working copy. The trunk follows the merge. A session that moves on to other work in the same checkout, like a sweep, hands over through the repo's own preview route instead ([#2558](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2558), [#2559](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2559)).

**Score:** 2

#### What makes this deploy extra special

An owner reviewing a UI change can look at it straight away. The session no longer switches to the trunk after parking, which reverted the running app to the old screen and left them nothing to judge.

**Score:** 3

#### Pull Request

A branch parked for the owner's visual review keeps the checkout on that branch, in the constitution and in Chris's trunk rule

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2579](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2579)

---

### DEPLOY: fix/2569-publish-page-wrangler-oauth · 20260928-103105Z

Inside this repo: `publish-page.ps1` gained a second publish route for when `CLOUDFLARE_API_TOKEN`
is absent, with two small functions in `page-publish-rules.ps1` and end-to-end tests against an
`npx.cmd` shim.

**Score:** 2

#### What makes this deploy extra special

For whoever publishes a BWJ page from a machine that is logged in with `npx wrangler login`: the
publish now works without an API token. It goes through `wrangler kv key put/get --remote` and is
proved with the same SHA-256 read-back. A login to a different account is refused, and the message
names both routes.

**Score:** 3

#### Pull Request

publish-page publishes through a wrangler OAuth session when CLOUDFLARE_API_TOKEN is absent

Plugins: dkj-policy-bwj

[PR #2578](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2578)

---

### DEPLOY: docs/2567-audience-asana-link-from-marker · 20260928-102112Z

The BWJ ticket-handling page now says which Asana task an audience release item links to (inbound
[#2567](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2567)). It is the task the mirror's
three matchers resolve, marker first, and never the first Asana URL in the issue body. A reference line
naming the CRO test a build came from is context, not the ticket.

**Score:** 2

#### What makes this deploy extra special

A colleague reading a store's release notes finds their own development ticket linked, and not the CRO
test it came out of.

**Score:** 2

#### Pull Request

An audience item's Asana link is resolved by the mirror's matchers, never the first URL

Plugins: dkj-policy-bwj

[PR #2577](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2577)

---

### DEPLOY: fix/2565-prepare-release-reads-repo-config · 20260928-100738Z

`prepare-release` reads the store's `scripts/repo-config.ps1` again (inbound
[#2565](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2565)). Since the #2509 hardening it had
dropped the dot-source, so every seam read its default: no store domain, no live theme id, the changelog
looked for at `CHANGELOG.md`, and each step then reported a plausible skip instead of a fault. A fixture run
now pins that the repo's own seams are read, and that a config which throws degrades to a warning naming
only the exception's type.

**Score:** 2

#### What makes this deploy extra special

A store running `prepare-release` on 5.9.0 got a runbook with no push command and every scoped step
skipped, in a repo that had answered every seam. After this release the skill works as documented there.

**Score:** 3

#### Pull Request

prepare-release dot-sources repo-config.ps1 again

Plugins: dkj-policy-bwj

[PR #2575](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2575)

---

### DEPLOY: docs/2562-sweep-stop-condition · 20260928-095412Z

Inside this repo: the `sweep-issues` skill page gains a short section naming when the loop ends.

**Score:** 1

#### What makes this deploy extra special

For whoever runs `/dkj-policy:sweep-issues`: the skill now states that the sweep goes on until no
`free` issue is left, and that the close-out `ship-pr` prints after each issue is not the end of the
sweep. It used to stop after the first shipped issue.

**Score:** 3

#### Pull Request

sweep-issues states its stop condition, so one shipped issue is not the sweep's close-out

Plugins: dkj-policy

[PR #2573](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2573)

---

### DEPLOY: fix/2560-update-plugins-install-when-no-record · 20260928-093321Z

Inside this repo: `update-plugins.ps1` step 2 no longer hands `claude plugin update --scope project`
to a plugin with no install record for this checkout. It runs `claude plugin install <id> --scope
project` instead, which is the command `plugin-versions.ps1` already prescribes for that state, and the
summary counts it as installed. The test suite's older scenarios gained a record for this checkout,
since they were written against the state this fixes.

**Score:** 2

#### What makes this deploy extra special

For whoever runs `update-plugins` in a checkout where the plugins are enabled but were never installed
there: the run used to move **another checkout's** install record and then report success. It now
installs into the checkout it was run from, so the receipt at the end agrees with the summary above it.

**Score:** 3

#### Pull Request

update-plugins installs where this checkout has no install record, instead of updating another checkout's

Plugins: dkj-policy

[PR #2571](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2571)

---

### DEPLOY: docs/2557-audience-tier-by-purpose · 20260928-060229Z

The two audience tiers now come with a test a repo can apply to itself: what the repo is **for**. A repo that is a means of selling or delivering something else answers 1. A repo that is the product its user relies on answers 2, and that user counts even when they are its own maintainer: as user they are tier 2, as developer tier 0. The same wording is in the tier model, the scaffold's reader sentence and the `Get-ReleaseAudienceTier` contract record ([#2557](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2557), answering [#2556](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2556)).

**Score:** 2

#### What makes this deploy extra special

A repo whose only user is its maintainer, such as a local single-user tool, can now see from the text that it has a tier-2 audience. Before this, every entry there honestly answered N/A for both tiers and earned a patch. Each new entry's guidance now names that reader, and the adoption question names it too.

**Score:** 3

#### Pull Request

Audience tiers: the test is what the repo is for, so a tool's own maintainer-as-user is tier 2

Plugins: dkj-policy

[PR #2563](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2563)

---

### DEPLOY: fix/2555-unanswered-decide-seams · 20260927-230034Z

`check-script-contract` now tells an unanswered `decide` seam apart from a harmless optional one. A `decide` seam states what the repo IS, so its fallback is an answer nobody chose; until now it printed the same `[INFO]` as a `copy` seam, and the session check called the repo `in sync`. It now adds one non-counting `[UNANSWERED]` line naming every such seam, and the session check forwards it in place of the in-sync verdict. Exit codes and tallies are unchanged. This repo now states the four `decide` seams it used to leave undefined on purpose, each returning its fallback, so a considered answer can be told from an unasked one here too ([#2555](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2555)).

**Score:** 3

#### What makes this deploy extra special

A repo on this workflow now sees, at session start, the questions only it can answer that it never has -- named in one line, such as `Get-ReleaseAudienceTier`, whose silence costs every changelog entry two empty tier sections. Answering each one, with any value including the fallback, clears the line.

**Score:** 3

#### Pull Request

check-script-contract: report unanswered 'decide' seams as their own class, and stop the session check calling that state in sync

Plugins: dkj-policy

[PR #2561](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2561)

---

