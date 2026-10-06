# Changelog

## [Unreleased]

**32 / 34 minor entries** <!-- pending-tally -->

### DEPLOY: docs/2853-awaiting-more-info-colour · 20261006-095421Z

`adopt-bwj-development` now prescribes `5319E7` for the `awaiting-more-info` label, in both the rename and
the create line, which is the colour of the rest of the `awaiting-*` family. It prescribed `d4c5f9`, so
that one label stood out on every tracker that followed the page.

**Score:** 1

#### What makes this deploy extra special

A store repo adopted before this release has `awaiting-more-info` in pale lavender. Recolour it with
`gh label edit awaiting-more-info --color 5319E7 --repo <owner>/<repo>`; xoxowildhearts and
smartwatchbanden were recoloured by hand on October 6, 2026.

**Score:** 1

#### Pull Request

adopt-bwj-development prescribes 5319E7 for awaiting-more-info

Plugins: bwj-development

[PR #2858](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2858)

---

### DEPLOY: fix/2849-statusline-block-json · 20261006-093952Z

The `statusLine` block that `adopt-statusline` prints for placing by hand is now valid JSON. The
command's inner quotes around the `-File` path were printed unescaped, so the block broke the settings
file it was pasted into. It is printed on a dry run, beside an existing `statusLine`, and wherever the
command refuses to edit the file itself. The insert `-Apply` writes was always correct.

**Score:** 2

#### What makes this deploy extra special

If you placed the block by hand and your settings file then failed to parse, this was the cause: write
the inner quotes as `\"`, or run `adopt-statusline` again and paste the block it prints now.

**Score:** 2

#### Pull Request

adopt-statusline prints a statusLine block that is not valid JSON

Plugins: dkj-policy

[PR #2857](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2857)

---

### DEPLOY: feat/2854-asana-reopened-message · 20261006-091501Z

The reopened message on the Asana task is back, beside the closed message. The `asana-closed-message`
template now runs on `issues: reopened` as well, and on a reopen with a linked task it posts one comment:
the automation's header and *"GitHub issue <owner>/<repo>#<n> **reopened:** this Asana task is back in
development."*, the requester's fixed form from #2656. It posts whatever the issue was closed as, reads no
go-live block, moves no card and un-completes nothing. The template keeps its name, so a re-adopt replaces
it instead of adding a second copy. The pages that said a reopen posts nothing now say it does.

**Score:** 3

#### What makes this deploy extra special

When a store's issue is reopened, the requester's Asana task hears about it again, so nobody goes on
testing a result that is being reworked. To turn it on in a store, run `adopt-bwj-development` after the
update: the two files already exist there, so it stops and shows the difference, and the maintainer copies
the new `.github/workflows/asana-closed-message.yml` and `.github/scripts/asana-closed-message.ps1` over
the old ones. Nothing else is needed: the same `ASANA_PAT` secret serves both messages.

**Score:** 3

#### Pull Request

Bring back the reopened message on the Asana task

Plugins: bwj-development

[PR #2855](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2855)

---

### DEPLOY: fix/2848-anchor-statusline-path · 20261006-085425Z

`adopt-statusline` now writes the status line's shim path as
`${CLAUDE_PROJECT_DIR}/.claude/statusline/dkj-progress.ps1`, anchored like the hook commands in the same settings file.
The relative path it wrote before resolved against the status line's working directory, so from below
the repo root it missed the shim, or ran a different file at the same relative path.

**Score:** 2

#### What makes this deploy extra special

A repo that already ran Part 5 keeps its relative line; `adopt-statusline` never replaces an existing
`statusLine`. To anchor it, change the `command` in `.claude/settings.json` by hand to
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/.claude/statusline/dkj-progress.ps1"`.

**Score:** 2

#### Pull Request

adopt-statusline anchors the statusLine shim path on CLAUDE_PROJECT_DIR

Plugins: dkj-policy

[PR #2852](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2852)

---

### DEPLOY: docs/2833-sweep-ends-at-visible-park · 20261006-081600Z

The `sweep-issues` page now ends the sweep when it parks a result that has to be judged by eye. The
checkout stays on that branch, as the constitution requires, and the close-out names the branch and
the issues still `free`. Until now the page sent the sweep back to step 1, which meant leaving the
branch the owner still had to judge, against the constitution.

**Score:** 3

#### What makes this deploy extra special

If you run sweeps on a repo with visible work, a sweep no longer switches away from a branch you still
have to look at. It stops there and tells you which issues it left for the next run.

**Score:** 3

#### Pull Request

sweep-issues ends the sweep at a visible park instead of going back to step 1

Plugins: dkj-policy

[PR #2847](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2847)

---

### DEPLOY: docs/2843-sweep-parks-waiting-issues · 20261006-074110Z

The `sweep-issues` page now says what to do with a `free` issue that turns out to be waiting on a live
push, a release, another issue's pull request, an external event or the owner's choice. Set the
matching `awaiting-*` label and leave a one-line comment saying what it waits on. Until now the page
held such an issue out with `-SkipIssue`, which lasts one run, so every sweep judged it again.
`-SkipIssue` remains for a hold-out that is not a wait.

**Score:** 3

#### What makes this deploy extra special

If you run sweeps, an issue that waits on you is now labelled the first time a sweep meets it, and the
next sweep skips it instead of judging it again and listing it in its close-out once more.

**Score:** 3

#### Pull Request

sweep-issues parks a waiting issue with its awaiting-* label instead of holding it out with -SkipIssue

Plugins: dkj-policy

[PR #2846](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2846)

---

### DEPLOY: fix/2842-owner-act-label-length · 20261006-072755Z

The `awaiting-owner-act` label's canonical description is now 86 characters:
`Waiting on an act only the owner performs -- parks the issue so no session picks it up`. The old
text was 123 characters, so the `gh label create` line that `adopt-triage-labels` prints failed on
every tracker with HTTP 422. A test now holds every canonical label to GitHub's limits of 50 characters
for a name and 100 for a description.

**Score:** 2

#### What makes this deploy extra special

If you adopt the triage labels, the printed command for `awaiting-owner-act` now creates the label
instead of failing. A tracker where you already created it with a text of your own is left alone.

**Score:** 2

#### Pull Request

Shorten awaiting-owner-act description to GitHub's 100-character limit

Plugins: dkj-policy

[PR #2844](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2844)

---

### DEPLOY: docs/2831-shopify-readme-skills · 20261006-070957Z

The `dkj-subagents-shopify` README no longer states a skill count, which had gone stale at five, and
its table now lists all seven skills the plugin ships, adding `theme-lifecycle` and `live-preflight`
([#2831](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2831)).

**Score:** 1

#### What makes this deploy extra special

For someone opening the Shopify team's README for the first time: it now names the backup-and-sweep
skill and the live-push preflight, which it used to leave out.

**Score:** 1

#### Pull Request

The shopify README lists all seven skills

Plugins: dkj-subagents-shopify

[PR #2839](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2839)

---

### DEPLOY: fix/2836-claim-tag-checkout · 20261005-142837Z

A sweep's claim tag now names the checkout as well as the machine and the account:
`machine:checkout/account`, where the checkout is the first 8 hex digits of a hash of its root path.
Two sweeps on one machine under one account, in two checkouts or worktree lanes, now claim apart, and
`-Candidates` no longer reads the other's claim as `mine`.

**Score:** 3

#### What makes this deploy extra special

If you run more than one sweep on a machine, each one now claims under its own tag, so it can no longer
pick up and rebuild an issue the other sweep is still working on. A claim written by an older version
names no checkout and shows as `held`, with a note that it belongs to this machine and account. Read its
branch, and run `claim-issue <n> -Tag -TakeOver` if the work is yours.

**Score:** 3

#### Pull Request

A claim tag names the checkout, so two sweeps on one machine no longer read each other's claim as mine

Plugins: dkj-policy

[PR #2840](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2840)

---

### DEPLOY: fix/2829-sync-branch-name-pr-heads · 20261005-141821Z

`sync-main.ps1` now treats a name as taken when it is already the head of a pull request in any state, as
well as when a ref for it exists. A second sync on the same day therefore gets `-2` even after the first
one's PR has merged and its branch is deleted. Where `gh` cannot answer, the name is chosen from refs
alone, as before, and the run says so.

**Score:** 2

#### What makes this deploy extra special

A Shopify repo that syncs twice in one day no longer gets a branch that `ship-pr` refuses with "PR #...
is already merged", so the hand rename to `-2` is no longer needed.

**Score:** 2

#### Pull Request

sync-main: skip a same-day name that is already a PR's head

Plugins: dkj-subagents-shopify

[PR #2835](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2835)

---

### DEPLOY: feat/2830-golive-language-seam · 20261005-140547Z

`build-golive-block` now reads an optional `Get-GoLiveBlockLanguage` seam from `scripts/repo-config.ps1`
when `-Language` is not passed. An explicit `-Language` still wins, an answer other than `nl` or `en` is
refused, and without the seam the default stays `nl`.

**Score:** 2

#### What makes this deploy extra special

A store that writes GitHub in English can state that once: add
`function Get-GoLiveBlockLanguage { 'en' }` to `scripts/repo-config.ps1`, and every go-live block is
English without remembering `-Language en` on each call.

**Score:** 2

#### Pull Request

build-golive-block reads its language from an optional repo seam

Plugins: bwj-development

[PR #2837](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2837)

---

### DEPLOY: feat/2828-awaiting-owner-act-label · 20261005-135738Z

New parking label `awaiting-owner-act`, purple like the rest of the awaiting-* family. It is for an
issue whose decision is already made and whose only remaining step is an act the owner performs
in person, such as a live push, a release or a deletion the session may not run
([#2828](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2828)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue names the act, and the label
comes off once it is done.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-owner-act`. A sweep no longer has to read an issue that only the owner can move and hold it
out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A sixth parking label: awaiting-owner-act

Plugins: dkj-policy

[PR #2834](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2834)

---

### DEPLOY: feat/2812-release-note-form-check · 20261005-134511Z

`check-release-note-form.ps1` compares the newest audience release note with what `cut-release` drafts for
the repo: the title line, the header labels, and the section headings in order. It takes the expected form
from the draft function, using the repo's own `Get-ReleaseNoteWording`, `Get-ReleaseNoteSections` and
audience tier. `open-pr -GatesOnly -NoteTreeOnly`, the cut's release-notes gate run, now runs it too. Older
notes are records and are not judged.

**Score:** 2

#### What makes this deploy extra special

At the release-notes step the gate run now refuses a note whose labels or section headings drifted from the
drafted form. So a translated label or an extra section is caught before the commit, rather than found
later by comparing two notes by eye. To change the form, answer `Get-ReleaseNoteWording` once.

**Score:** 2

#### Pull Request

A check that flags an audience release note whose headings differ from the shared form

Plugins: dkj-policy

[PR #2832](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2832)

---

### DEPLOY: fix/2825-resume-line-plugin-path · 20261005-105214Z

The resume command the unshipped-PR and stranded-sweep session checks print now names a `ship-pr.ps1` that
exists. In the source repo that is still `scripts/release/ship-pr.ps1`; in a consumer, which has no copy
there, it is the plugin's own copy, as a quoted full path.

**Score:** 2

#### What makes this deploy extra special

When a session check says a green pull request is waiting to ship, the command it prints works as pasted.
Before, it named `scripts/release/ship-pr.ps1`, which no consumer has, and failed with "the argument to the
-File parameter does not exist".

**Score:** 2

#### Pull Request

The unshipped-PR resume line names a ship-pr that exists in the consumer

Plugins: dkj-policy

[PR #2827](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2827)

---

### DEPLOY: fix/2824-register-bwj-development · 20261005-104352Z

The connector register now names the BWJ extension by its current id, `bwj-development`, in the
entries for both BWJ store repos. Both entries still listed `dkj-policy-bwj` after the rename in #2788,
so `check-connectors` read the plugin both stores really enable as unlisted.

**Score:** 2

#### What makes this deploy extra special

In smartwatchbanden and xoxowildhearts, `connector-sessioncheck` stops reporting
`bwj-development@dkj-claude-plugins` as a plugin the register does not list, once the marketplace
clone is updated.

**Score:** 2

#### Pull Request

Connector register: follow the dkj-policy-bwj rename to bwj-development

[PR #2826](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2826)

---

### DEPLOY: feat/2818-asana-closed-message · 20261005-103226Z

The closed message on the Asana task is back, and it is the only part of the retired `asana-mirror`
workflow that is. A new template, `asana-closed-message`, runs on `issues: closed` only. On a close as
completed it posts one comment on the linked task: the automation's header, the closed line, and the
go-live block the shipping session left on the issue. On a close as not planned or as a duplicate it
posts nothing. It needs `ASANA_PAT` alone, moves no card and completes no task. The go-live block's
framing sentence and the pages that said the block is pasted by hand say again that the close carries
it. `adopt-bwj-development` copies the template into the two store repos.

**Score:** 3

#### What makes this deploy extra special

When a store's issue closes as completed, the requester's Asana task hears about it again, with the
go-live block in it, and nobody pastes anything. To turn it on in a store, run `adopt-bwj-development`
after the update (it copies `.github/workflows/asana-closed-message.yml` and its script) and keep the
`ASANA_PAT` secret. A store that still has the old `asana-mirror` files should delete them, or the closed
message is posted twice.

**Score:** 4

#### Pull Request

The closed message on the Asana task is back, and it is the only automation

Plugins: bwj-development

[PR #2823](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2823)

---

### DEPLOY: fix/2816-runner-group-verdict · 20261005-102208Z

`adopt-ci-floor` now reports a `[group]` advisory when an existing `fold-on-merge.yml` or
`verify-resolved.yml` still carries the single `github.ref`-keyed concurrency group #2813 replaced,
beside the `[pin]` line it already printed. The scaffolder still never rewrites a placed runner, so
this re-run is the one moment that shape gets noticed (#2816).

**Score:** 2

#### What makes this deploy extra special

A consumer re-running `adopt-ci-floor` is told, file by file, whether its fold and resolves runners
still carry the concurrency group that can cancel a merge's pending run, and how to fix it: replace
the `group:` line, or delete the file and re-run with `-Apply`.

**Score:** 2

#### Pull Request

adopt-ci-floor says when an existing fold or resolves runner still carries the concurrency group #2813 replaced

Plugins: dkj-policy

[PR #2822](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2822)

---

### DEPLOY: fix/2815-plugin-tree-separator · 20261005-100955Z

The plugin-root lookup now works under pwsh on Linux. Its containment check had hard-coded the Windows
separator, so on the Linux fold runner every local plugin in `marketplace.json` was refused as "points
outside the repo" and fold-on-merge went red (run 37289296605). A new `fold-changelog` block declares a
local plugin, so the Linux leg of CI now exercises this path.

**Score:** 3

#### What makes this deploy extra special

A consumer whose own `marketplace.json` declares local plugins would have seen the same red
fold-on-merge on any merge the runner resolves to a pull request, because the CI-floor runners execute on Linux. That
failure is now prevented. It had not yet been reported in a consumer.

**Score:** 1

#### Pull Request

plugin-tree-lib containment check works on Linux

Plugins: dkj-policy

[PR #2821](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2821)

---

### DEPLOY: fix/2813-fold-only-own-group · 20261005-095833Z

`fold-on-merge.yml` and `verify-resolved.yml` put a fold-only push in a concurrency group of its own,
keyed per commit, so it can no longer cancel a merge's pending run and leave the fold and the resolves
check undone (#2813). `cancel-in-progress: false` only ever protected the *running* job; a third arrival
drops the pending one regardless, and a skipped fold-only run was the worst possible survivor. Measured
October 5, 2026: the merge of #2811 lost both its fold and its resolves check this way.

**Score:** 3

#### What makes this deploy extra special

A repo whose CI floor was placed by `adopt-ci-floor` keeps the old group lines: re-running it leaves an
existing runner as it is. There, two sessions shipping seconds apart can still leave an entry unfolded
on the trunk and a merge's closing keywords unverified. To take the fix, copy the new `group:` line
into `.github/workflows/fold-on-merge.yml` and `verify-resolved.yml`, or delete both files and re-run
`adopt-ci-floor -Apply`, which places them fresh.

**Score:** 2

#### Pull Request

A fold-only push no longer displaces a pending merge run in fold-on-merge and verify-resolved

Plugins: dkj-policy

[PR #2819](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2819)

---

### DEPLOY: docs/2802-release-note-form-shared · 20261005-094845Z

The `cut-release` skill now says whose the audience release note's form is. The title line, the `Date` /
`Type` / `For whom` labels and the section headings are what the cut drafts, and `Get-ReleaseNoteWording`
is the only route to change them. A lens or comment that restates or translates them is drift. The note's
language is a per-repo content answer, translated once through that seam. `adopt-bwj-development` now
proposes `Get-ReleaseNoteTaskLink` to both stores, so their drafts arrive as solved tasks.

**Score:** 2

#### What makes this deploy extra special

A store writes its release note in the plugin's form, not in one a local page invented. To use other
labels or another language, answer `Get-ReleaseNoteWording` once and drop the lens section or comment that
restated the form. The BWJ stores are offered the task form of the note at adoption, so the cut drafts
which Asana tasks were solved and nobody rewrites the entries by hand.

**Score:** 3

#### Pull Request

The audience release note's form is the plugin's, and only Get-ReleaseNoteWording changes it

Plugins: bwj-development, dkj-policy

[PR #2820](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2820)

---

### DEPLOY: fix/2810-rename-carries-colour · 20261005-094004Z

`adopt-triage-labels` now prints a rename of a former label name with the canonical colour as well as the
new name and description. A label found under an older name, such as `needs-decision`, moves into its
family's colour in the same `gh label edit` that renames it. The `needs-info` rename on the
`adopt-bwj-development` page does the same.

**Score:** 2

#### What makes this deploy extra special

Pasting the rename that `adopt-triage-labels` prints now also gives the label its new colour, so a renamed
`awaiting-decision` turns purple beside the other parking labels instead of keeping its old orange.

**Score:** 2

#### Pull Request

adopt-triage-labels' rename line carries the canonical colour

Plugins: bwj-development, dkj-policy

[PR #2817](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2817)

---

### DEPLOY: fix/2805-foreign-checkout-guard · 20261005-093112Z

`new-branch` now refuses to cut a branch in another repository's primary checkout. When `-RepoRoot` names
the main working tree of a repository other than the session's project, and that tree was cloned from a
host, the run stops before creating anything and names the worktree route. A session in one repository can
no longer switch a branch under a session working in another.

**Score:** 3

#### What makes this deploy extra special

A session that carries a change into a sibling repository is stopped at `new-branch` and told to open a
worktree of it, rather than switching that repository's own checkout. Before, the checkout moved under
whoever was working there, and on October 5, 2026 that put one store's fold commit on another session's
branch.

**Score:** 2

#### Pull Request

new-branch refuses a foreign repo's primary checkout and points at a worktree

Plugins: dkj-policy

[PR #2814](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2814)

---

### DEPLOY: feat/2801-cut-release-page-step · 20261005-091940Z

`cut-release` now names the release-notes page as a step. Where a repo answers `Get-ReleasePageWorkerName`,
the cut's closing block prints the `build-release-notes-page.ps1 -Worker` command after the GitHub Release
line, with the instruction to verify the bytes the URL serves. The `cut-release` skill carries it as step 5b.

**Score:** 2

#### What makes this deploy extra special

A repo that publishes a release-notes page is told to rebuild and redeploy it at every cut. Before, nothing
named the step, so the page could stay on the previous release until somebody asked.

**Score:** 3

#### Pull Request

cut-release names the release-notes page step where a repo publishes one

Plugins: dkj-policy

[PR #2811](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2811)

---

### DEPLOY: fix/2800-light-pin-drops-dark-block · 20261005-091938Z

**A `'color-scheme' = 'light'` answer from `Get-ReleasePageTheme` now actually pins the release-notes
page light** ([#2800](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2800)). The property
alone never stopped the template's `@media (prefers-color-scheme: dark)` block matching, because that
query follows the OS rather than `color-scheme`; so on a dark-mode browser every token the repo did not
name turned dark while the ones it did name stayed light. `build-release-notes-page.ps1` now removes the
template's dark block when the theme names `light` and not `dark` (`Test-ReleasePageLightPin`,
`Remove-ReleasePageDarkBlock`), and warns if the block is no longer in the shape it looks for. The
template comment and the `release-notes-page` skill page are corrected, and the suite asserts a pin
leaves no dark override behind.

**Score:** 2

#### What makes this deploy extra special

A repo that pins its release-notes page light and names only some colours no longer gets an unreadable
page -- dark text on the template's dark background -- for every reader whose browser is in dark mode.
The hand-pinning of every token that repo did as a workaround can come out after the update.

**Score:** 3

#### Pull Request

release-notes page: a 'color-scheme: light' pin removes the template's dark block

Plugins: dkj-policy

[PR #2809](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2809)

---

### DEPLOY: fix/2803-fold-head-check · 20261005-090710Z

`fold-changelog-entry.ps1` now refuses to write a fold commit anywhere but where it started. With `-Commit`
or `-Push` it reads the branch and HEAD three times: at the start, before the commit, and before the push.
It refuses on any movement, so a second session switching a shared working tree mid-run no longer takes the
fold commit onto its own branch. A new `-ExpectBranch` parameter refuses before anything is folded when the
checkout is not on the named branch, and `ship-pr` passes `main`.

**Score:** 3

#### What makes this deploy extra special

When another session switches the working tree under `ship-pr`, the fold now stops with the merge done and
the fold still owed, and it says why. Before, the `fold:` commit was written and pushed onto that session's
branch, and `ship-pr` still reported "folded on main".

**Score:** 2

#### Pull Request

The fold refuses to commit or push off the trunk

Plugins: dkj-policy

[PR #2808](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2808)

---

### DEPLOY: fix/2798-preflight-live-role · 20261005-085454Z

`live-preflight`'s step 5 now reads the live theme's role as either `live` or `main`. Shopify CLI 4.8.x
reports `live`, so the `main`-only compare never matched, and the refusal for a configured live theme id
that disagrees with the store's own live theme could not fire. A source pin in `live-push-rules.tests.ps1`
holds the preflight and both theme rules libs to accepting both spellings.

**Score:** 2

#### What makes this deploy extra special

`live-preflight` once again refuses when `Get-ShopifyLiveThemeId` names a theme the store does not
report as live. Before, a stale id that still pointed at an existing unpublished theme passed step 5, and
the preflight printed a push aimed at a theme no customer sees.

**Score:** 1

#### Pull Request

live-preflight's role check accepts 'live' as well as 'main'

Plugins: dkj-subagents-shopify

[PR #2807](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2807)

---

### DEPLOY: feat/remove-asana-mirror · 20261005-082732Z

The `asana-mirror` CI workflow is retired from `dkj-policy-bwj` (Dave, October 5, 2026): the two
templates are gone, and `adopt-bwj-development` no longer copies them. The helpers `build-backlog-page`
and `build-golive-block` still use now live in `scripts/lib/asana-task-lib.ps1`. The template's
self-containment suite went with it, and the tests, docs, skills and lenses describe the new state.

**Score:** 3

#### What makes this deploy extra special

Closing a GitHub issue in a BWJ store no longer posts anything on the Asana task, and the card is no longer
moved through the board. The go-live block stays on the GitHub issue, and you paste it into the task by
hand where the task needs it. To finish the job in a store repo, delete `.github/workflows/asana-mirror.yml`
and `.github/scripts/asana-mirror.ps1`, and drop `Get-GithubStatusMap` from `scripts/repo-config.ps1`.
`report-issue` still files the card in `Filed`.

**Score:** 4

#### Pull Request

Retire the asana-mirror CI workflow from dkj-policy-bwj

Plugins: bwj-development, dkj-policy, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2804](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2804)

---

### DEPLOY: docs/2796-parking-labels-at-filing · 20261004-101059Z

An issue whose next step waits on something other than work now carries its `awaiting-*` parking label
from the moment it is filed, for all five labels rather than `awaiting-decision` alone. The rule now
sits beside the `prio-N` and `minor` filing rules in Chris's lens, which every session here loads, so it
is read when an issue is filed. Before, a waiting issue could be filed unparked and look like free work
to both pickup routes.

**Score:** 2

#### What makes this deploy extra special

`CONTRIBUTING-portable.md` now says once that every parking label (`awaiting-decision`, `awaiting-pull`,
`awaiting-event`, `awaiting-first-recurrence`, `awaiting-more-recurrences`) goes on in the same
`gh issue create` as the `prio-N`. Before, it said that only for `awaiting-decision`. A consumer's
waiting issues are parked from the start rather than picked up by a sweep that has nothing to build.

**Score:** 2

#### Pull Request


Every parking label goes on at filing, not only awaiting-decision

Plugins: dkj-policy

[PR #2797](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2797)

---

### DEPLOY: feat/2793-drop-live-lint-smokes · 20261004-094241Z

The test suites no longer run the whole lint gate over the live repo just to check that it passes. `bootstrap-drift` drops that run entirely, which is ~70% of the heaviest suite. `fix-mojibake` now runs only the encoding tool behind check 14, and checks the gate's own parse of its file count against what the tool prints. `subagent-shared` keeps its run for the two coverage lines it reads, and no longer asserts the exit code. The CI lint job and `open-pr`'s local gate already run that command in every PR. Locally, `bootstrap-drift` went from 76.8 s to 23 s and `fix-mojibake` lost a 45.8 s gate run. The CI before/after with `measure-suites` comes from the runs after the merge.

**Score:** 2

#### What makes this deploy extra special

Nothing a consumer runs changes: these are this repo's own suites and gate notes.

**Score:** N/A

#### Pull Request

bootstrap-drift and fix-mojibake no longer rerun the full lint over the live repo

Plugins: dkj-policy

[PR #2794](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2794)

---

### DEPLOY: docs/2791-english-tracker-always-on · 20261004-083650Z

The rule that issue titles and bodies, PR bodies and commit messages are English, whatever language a
session replies in, now sits in the shared filing rules every persona and subagent carries, rather
than only in the technical writer's on-demand manual. The manual keeps the reasoning and points there.

**Score:** 2

#### What makes this deploy extra special

A consumer's tracker stops filling with issues, PR bodies and commits in the session-reply language,
because the session that files them now carries the rule on every turn.

**Score:** 3

#### Pull Request

Put the English-tracker rule on the always-on filing path

Plugins: dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2792](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2792)

---

### DEPLOY: feat/2788-rename-policy-extensions · 20261004-080146Z

The two `dkj-policy` extensions were renamed after their organisation:
`dkj-policy-bwj` is `bwj-development` and `dkj-policy-dkjs` is `dkj-solutions`
([#2788](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2788)). An extension is now
recognised by a list in `claude-md-import-lib.ps1` rather than by its name prefix. A retired name is
mapped to its current one, so the adopters still owe and write the current import line, and the
integrity gate fails until the list matches the plugin folders.

**Score:** 3

#### What makes this deploy extra special

A migration is required for a repo that enables either extension. The marketplace no longer declares
the old ids, so after this release nothing of the extension loads until `.claude/settings.json` enables
the new name and it is installed. The old `CLAUDE.md` import points at a folder that is gone, and nothing
fails loudly. The session-start check warns once for each old name, `adopt-workflow-folder.ps1 -Apply`
rewrites the old import line in place, and [ADOPTION.md](../plugins/ADOPTION.md#consumption) gives the
three steps.

**Score:** 5

#### Pull Request

Rename the dkj-policy extensions to bwj-development and dkj-solutions

Plugins: bwj-development, dkj-policy, dkj-solutions, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2790](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2790)

---

### DEPLOY: fix/2786-docs-prefix-no-documentation-label · 20261004-074745Z

A `docs/` pull request in this repo now goes out without a label, because the `documentation` label is
retired here too: an issue is always a `feature` or a `bug`
([#2786](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2786), following
[#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 1

#### What makes this deploy extra special

For a new consumer running `specialists-init`: the commented example prefix table no longer proposes a
`documentation` label for `docs/` or `chore/` branches, so it no longer suggests the label #2783
retired.

**Score:** 1

#### Pull Request

This repo's docs/ prefix stops labelling PRs 'documentation'

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2789](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2789)

---

### DEPLOY: feat/2784-awaiting-event-label · 20261003-143652Z

New parking label `awaiting-event`, purple like the rest of the awaiting-* family, for an issue that
waits on an external event or date, such as a launch or a third party's release
([#2784](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2784)). The claim and sweep routes
skip it by default and the issue dashboard shows it as parked. The issue states the event or date, and
the label comes off once it has happened.

**Score:** 2

#### What makes this deploy extra special

For a consumer who runs `adopt-triage-labels`: it now offers one more `gh label create` line, for
`awaiting-event`. A sweep no longer has to hold a date-bound issue out by hand with `-SkipIssue`.

**Score:** 2

#### Pull Request

A fifth parking label: awaiting-event

Plugins: dkj-policy

[PR #2787](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2787)

---

### DEPLOY: docs/2783-bwj-no-documentation-label · 20261003-141409Z

In a BWJ store repo every issue is now filed as either a `feature` (something new being added) or a
`bug` (something that exists and has to change), doc findings included. There is no third kind any
more, and the `documentation` label is no longer set or created. The adoption skill (step 4) shows how
to give the open issues still carrying `documentation` their kind and take it off, and a `docs/` pull
request goes out without a label
([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)).

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

BWJ: every issue is a bug or a feature, and the documentation label goes

Plugins: bwj-development

[PR #2785](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2785)

---

