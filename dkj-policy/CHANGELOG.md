# Changelog

## [Unreleased]

**7 / 27 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2516-paste-safe-case-sensitive · 20260926-095203Z

The two shared "safe to paste" guards no longer let a look-alike letter through
([#2516](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2516)). `Test-RefPasteSafe` and
`Test-PathPasteSafe` matched their ASCII allowlists case-insensitively. Under case folding the Kelvin
sign (U+212A) matches `k`, so a branch name or path carrying it was judged safe to print into a command
line. Git accepts that character in a branch name. Both guards now match case-sensitively, like
`live-preflight`'s newer check already did. Every plain-ASCII value that passed before still passes.

**Score:** 1

#### What makes this deploy extra special

N/A -- an internal guard in the workflow scripts; no subscriber of a service runs anything new.

**Score:** N/A

#### Pull Request

The paste-safe guards match case-sensitively, so the Kelvin sign is refused

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2522](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2522)

---

### DEPLOY: fix/2518-claim-issue-reads-parking-label · 20260926-094216Z

`claim-issue` on a single issue now reads the issue's labels. Where one parks the issue with somebody
else -- `needs-info` by default, the label `sweep-issues` already skips on; `-SkipLabel` replaces the
default -- it prints a `PARKED:` verdict, and the closing `[OK]` points at that verdict instead of
saying *the work starts here*. It still claims: a label can be stale, so this warns and never refuses
([#2518](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2518)). Which label an owner's
open choice should carry when it is filed is
[#2519](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2519).

**Score:** 3

#### What makes this deploy extra special

N/A -- a pickup step inside the workflow; no subscriber of a service sees it.

**Score:** N/A

#### Pull Request

claim-issue warns when the named issue carries a parking label

Plugins: dkj-policy

[PR #2521](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2521)

---

### DEPLOY: fix/2514-live-push-paths-paste-safe · 20260926-085714Z

The live push command `live-preflight` prints can no longer carry a theme path that runs something
when the line is pasted. Step 3 now refuses a push list holding a path outside letters (Latin accents
included), digits, `.`, `_`, `/` and `-`, and names each such path with its control characters
stripped. That happens before the backup, so a refused run costs no theme slot.
`Format-LivePushCommand` throws on such a path too, so no other caller can print one. The check is
`Get-LivePushUnsafePaths` in `live-push-rules.ps1`
([#2514](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2514)).

**Score:** 3

#### What makes this deploy extra special

A store running `live-preflight` is no longer handed a push command that could run a crafted theme
filename such as `assets/$(calc.exe).css` when somebody pastes it. That filename can arrive through a
theme-editor sync without anyone having push rights. Nothing has exploited this yet, and ordinary and
accented filenames push exactly as before.

**Score:** 1

#### Pull Request

live-preflight refuses a push list whose paths are not safe to paste

Plugins: dkj-subagents-shopify

[PR #2517](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2517)

---

### DEPLOY: docs/2508-asana-delete-reads-state · 20260926-081811Z

An agent no longer offers or deletes an Asana task on the strength of the GitHub issue alone
([#2508](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2508)). The ticket chapter now
requires it to read the task first: whether it is completed, whether it has human comments, which
projects it sits in, and who created it. A task that is completed or carries a human comment is never
offered for deletion. The card is unlinked from the issue instead. Every other offer shows that state
beside the title. `report-issue` points to the rule where it used to say that a wrong card is deleted
by hand. This prevents a repeat of the `smartwatchbanden` case, where a colleague's completed request was
deleted and nobody noticed for two days.

**Score:** 2

#### What makes this deploy extra special

N/A -- a working rule for the agent in a BWJ repo; no subscriber of a service runs anything new.

**Score:** N/A

#### Pull Request

An Asana task is read before it is offered for deletion

Plugins: dkj-policy-bwj

[PR #2512](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2512)

---

### DEPLOY: fix/2505-statusline-additive-write · 20260925-150200Z

`adopt-statusline -Apply` now adds the `statusLine` key to `.claude/settings.json` without touching the
rest of the file ([#2505](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2505)). It used to
parse the file and write it back. Windows PowerShell 5.1 re-padded every line and dropped blank ones, so
a one-key addition became a diff of the whole file. Now the member is inserted in the file's own indent
and line ending, and a BOM is kept. The run also warns when git ignores the shim it places, for example
under a `.claude/*` rule, and names the `!.claude/statusline/` exception. Without that exception, other
checkouts got a status line pointing at a file they never received. An empty `{}` settings file no
longer crashes the run.

**Score:** 3

#### What makes this deploy extra special

N/A -- a setup command a repo's maintainer runs; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

adopt-statusline writes additively and reports an ignored shim

Plugins: dkj-policy

[PR #2510](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2510)

---

### DEPLOY: fix/2502-oem-encoding-helper · 20260925-142909Z

The test gate's three readers of a suite's capture files (the print, the silent-suite check and the
retention decision) now take their decode from one helper, `Get-NativeCaptureOemEncoding`, instead of
three copies of the same OEM-codepage lookup
([#2502](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2502)). This changes no behaviour.
It prevents a later edit from changing one decode and not the other two, which would bring back the
print-versus-retention disagreement #2295 repaired. A suite assert refuses a second lookup.

**Score:** 1

#### What makes this deploy extra special

N/A -- an internal refactor of the test gate; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

native-capture-lib: one helper for the capture files' OEM decode

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2506](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2506)

---

### DEPLOY: fix/2500-silent-suite-failure · 20260925-140938Z

The test gate no longer reports a suite that exited non-zero **without writing a single byte** as a
plain `FAILED`, with no output shown and none kept. Such a suite never reached its own first line, so
the gate now marks it `SILENT`, re-runs it alone once (as it already does for a crash), and names it
on the verdict: as cleared on a green run, or as having written nothing to keep on a red one. A suite
silent on its re-run too is red. A suite that printed anything at all is judged exactly as before and
never re-run ([#2500](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2500)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the test gate runs inside the repos that adopt this workflow; no subscriber of a service sees it.

**Score:** N/A

#### Pull Request

A suite that exits non-zero without writing a byte is re-run alone and reported as SILENT, instead of FAILED with no output

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2504](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2504)

---

### DEPLOY: fix/2483-empty-native-output-null-cast · 20260925-135943Z

`push-preview` no longer crashes on Windows PowerShell 5.1 on a branch's first preview push
([#2483](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2483)). Under 5.1 a `[string]`
cast of a git read that prints nothing is `$null`, not `''`, so the `.Trim()` on the remembered theme id
threw before anything was printed -- on exactly the lazy-creation path the script exists for, with no
workaround for a new branch. Every such read in the three shipped Shopify scripts now interpolates
instead, and a suite assert refuses the old idiom coming back.

**Score:** 4

#### What makes this deploy extra special

N/A -- a store's own customers never see a preview push.

**Score:** N/A

#### Pull Request

push-preview no longer crashes on PS 5.1 when a git read prints nothing

Plugins: dkj-subagents-shopify

[PR #2503](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2503)

---

### DEPLOY: fix/2481-fixture-git-transport-retry · 20260925-132744Z

The test gate retries a fixture `git push` or `git fetch` once when its transport breaks mid-transfer
(`unexpected sideband packet`, a remote that hung up, early EOF), instead of failing a suite whose
asserts all passed. The retry is printed as `[FIXTURE GIT RETRY]` and counted in the suite's fixture
summary, separately from failures. A commit, a clone, or a push that git refused is never retried, and a
second break is judged as a failure exactly as before
([#2481](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2481)).

**Score:** 2

#### What makes this deploy extra special

N/A -- the test fixtures live in this repo only and ship to no consumer.

**Score:** N/A

#### Pull Request

A fixture git push that breaks in transport under the parallel gate is retried once, instead of failing the suite

[PR #2501](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2501)

---

### DEPLOY: fix/2497-lifehub-brain-layout · 20260925-131018Z

The lifehub information architect and ontologist no longer tell a dispatched agent to write
README indexes and RAW/PRETTY mirror copies. They read and follow the brain's own navigation files
(a `NEURON.md` per folder, as the repo lens names them) and never add a layout the brain does not
already have.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Closes #2497

Plugins: dkj-subagents-lifehub

[PR #2499](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2499)

---

### DEPLOY: fix/2487-ci-floor-metered-minutes · 20260925-125507Z

The CI-floor runners no longer spend Actions minutes on pushes that have nothing to do
([#2487](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2487)). `fold-on-merge` and
`verify-resolved` skip, at job level, a push carrying exactly one commit whose subject starts with
`fold:`. A job skipped by `if:` is not billed, and about half of a trunk's pushes are folds. This
applies to both the source's own workflows and the templates `adopt-ci-floor` places. Anything
else, a batch under a fold head included, still runs. The `merge-on-green` template now sweeps
every 3 hours instead of every 30 minutes (8 jobs a day instead of 48), and `workflow_run` stays
the ordinary path. `adopt-ci-floor` now prints what each runner it places costs on a metered
repo. The "half-hourly" wording in the sweep's shared scripts now fits either cadence
([#2492](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2492)). Moving the runners to
`ubuntu-latest` + `pwsh` is left to
[#2488](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2488).

**Score:** 3

#### What makes this deploy extra special

A private consumer's CI floor stops using up the plan's included Actions minutes. The consumer that
reported it lost every Actions job to the spending limit. `adopt-ci-floor` never overwrites a runner
that is already there, so a consumer that placed the floor before this release must apply the new
`if:` and schedule by hand. The other way is to remove the three files and re-run the adoption.

**Score:** 4

#### Pull Request

The CI floor stops spending a private repo's Actions minutes on fold pushes and a half-hourly sweep

Plugins: dkj-policy

[PR #2498](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2498)

---

### DEPLOY: fix/2493-step4-refusals-lead-with-checkout · 20260925-122924Z

When `ship-pr` refuses a merge at the DEPLOY lock or the step-list gate, its remedy now leads with the
`git checkout <branch>` the fix needs. Both refusals fire after `ship-pr` has already moved the checkout
back to `main`, so their remedies -- a commit, and for the DEPLOY lock also `open-pr.ps1 -RefreshBody` --
failed with "You are on main" until the branch was checked out by hand.

**Score:** 2 -- a refusal's own remedy failed on first use; noticed only by somebody who hits the lock.

#### What makes this deploy extra special

N/A -- nothing changes for a subscriber.

**Score:** N/A

#### Pull Request

ship-pr's step-4 refusals lead with the checkout the fix needs

Plugins: dkj-policy

[PR #2496](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2496)

---

### DEPLOY: fix/2491-drop-notes-date-type · 20260925-120740Z

The changelog release note a cut writes (`releases/changelog/<X>.x/<X.Y.Z>.md`) no longer carries the
`**Date:**` and `**Type:**` lines under `# Changelog Releases`: the `## Version X.Y.Z (Mon dd, yyyy)`
heading already says both. Where those lines are missing, `new-internal-note.ps1` takes the date from that
heading and the type from the release history's row, falling back to the version's shape, so the internal
note it builds is unchanged, including for a cut run with `-Type`. Notes published before this still read
exactly as they did. `Build-ReleaseNotes` no longer takes `-Type`.

**Score:** 1 -- prevents a duplicate that could disagree with its own heading; nothing has broken yet.

#### What makes this deploy extra special

From your next release, the changelog release note goes from its `# Changelog Releases` heading straight
to its title and version heading, without the two metadata lines between them. Nothing to do: the
internal note still fills in its date and type.

**Score:** 2

#### Pull Request

The changelog release note drops its Date and Type lines

Plugins: dkj-policy

[PR #2495](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2495)

---

### DEPLOY: fix/2489-fixed-release-history-head · 20260925-112932Z

The release list (`dkj-policy/releases/history.md` unless repointed) now has one fixed head:
`# Release history` and nothing else above the first `<n>.x` section. The cut re-applies it where it
inserts the new row, and the adopt output prints it instead of leaving the head to each repo. In this repo
the list's 85-line intro is gone. The structure it explained is on `RELEASES-portable.md`.

**Score:** 2

#### What makes this deploy extra special

At your next release cut, anything you wrote above the first `<n>.x` section of your release list
disappears and is replaced by the title `# Release history`. If something written there mattered, move it
to a page you own before you cut. The sections, their tables and every row are untouched.

**Score:** 3

#### Pull Request

The release list carries one fixed head, with no intro prose

Plugins: dkj-policy

[PR #2494](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2494)

---

### DEPLOY: fix/2486-empty-changelog-intro · 20260925-110208Z

`CHANGELOG.md` now has one fixed head -- `# Changelog` and the `## [Unreleased]` heading, no intro prose --
and the fold, the cut and the adopt scaffold all write exactly that. Whatever a repo had written above the
pending heading is replaced on the next fold, so every repo's head is identical.

In this repo the changelog's intro paragraphs are gone. The fold also stops being able to place an entry
inside a code fence quoted in an intro, because it re-applies the head before it looks for the list.

**Score:** 2

#### What makes this deploy extra special

On the first merge after updating the plugin, the text you wrote under `# Changelog` in
`dkj-policy/CHANGELOG.md` disappears and does not come back. It is replaced by the same two lines every other
repo has. If something written there mattered, move it to a page you own before you update. Nothing else in
the file changes, and no entry is touched.

**Score:** 3

#### Pull Request

CHANGELOG.md carries one fixed head, with no intro prose

Plugins: dkj-policy

[PR #2490](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2490)

---

### DEPLOY: fix/2482-asana-mirror-reach-gate · 20260925-095235Z

`dkj-policy-bwj` now ships a hook, `hooks/guard-asana-mirror.ps1`, that enforces `report-issue`'s rule
that only an issue carrying the reach label gets an Asana task. It fires on every Asana create-task
call, reads the labels of each GitHub issue the task cites on an admitted repo, and refuses the call
where the reach label (`Get-ReachLabel`, default `minor`) is missing. Where `gh` cannot answer, it lets
the call through with a warning naming the issue it did not check. Until now the rule was a sentence,
and `smartwatchbanden#770`, a developer-only issue, got a card on the version that carried it.

**Score:** 3 -- a session in a store repo is stopped the moment it tries to mirror a tier-0 issue, where before nothing stopped it.

#### What makes this deploy extra special

Colleagues on the Asana board stop receiving cards for developer-only work, and a fix for such an issue
closes it at the merge again rather than waiting for somebody to paste a block into a card that should
never have existed.

**Score:** 2

#### Pull Request


A hook refuses an Asana task for an issue without the reach label

Plugins: dkj-policy, dkj-policy-bwj

[PR #2484](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2484)

---

### DEPLOY: fix/2477-golive-live-urls-pinned · 20260925-090324Z

`golive-block`'s live URLs are now pinned to the live theme id wherever the store names one
(`-LiveThemeId`, or `Get-ShopifyLiveThemeId` in `scripts/repo-config.ps1`). A bare storefront URL
renders the preview in any browser that opened the result link first, so both tabs agreed and the
change could look live before the release. Where no id resolves, the URLs stay bare and the block tells
the requester to open them in a private window until the release.

**Score:** 2 -- one script and its label; nothing a developer here calls changes.

#### What makes this deploy extra special

A store running `golive-block` hands its requester live links that show what is live now, even after
they opened the preview, and the same links show the change once it ships. A store with no live-id seam
gets a label saying how to read them instead.

**Score:** 2

#### Pull Request

golive-block pins the block's live URLs to the live theme id

Plugins: dkj-policy-bwj

[PR #2480](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2480)

---

### DEPLOY: fix/2476-asana-automated-comment-header · 20260925-085442Z

Every comment the `asana-mirror` CI posts on an Asana task now opens with an `[Automated message]`
line, and the workflow page now requires the same of a session writing a comment through the Asana
MCP. Both post under a person's account, so without that line a colleague read a machine update as
that person's own words. De-duplication is unchanged, so tasks that already carry an update do not get
a second one.

A store repo posts the header once its `.github/scripts/asana-mirror.ps1` copy is refreshed from the
release. Until then it keeps posting the old text, and the session rule applies as soon as the page
is installed.

**Score:** 3

#### What makes this deploy extra special

N/A -- the colleagues who read the Asana board are not subscribers of this plugin.

**Score:** N/A

#### Pull Request

Agent-written Asana comments open with an automated-message header

Plugins: dkj-policy-bwj

[PR #2479](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2479)

---

### DEPLOY: docs/2474-handover-asana-paste-block · 20260925-082903Z

A preview handover page now carries a fourth block: the Asana paste-ready block from
`golive-block`, embedded as printed, with a copy button. The requester reads the Asana task and cannot
open the private page, so the page now holds the message they actually get, from the same run that
posts it on the issue. The page also says which URLs that block may carry: storefront URLs only, never
the handover link.

**Score:** 2 -- a handover session gets one step fewer to do by hand; the block's wording is unchanged.

#### What makes this deploy extra special

N/A -- the requester reads the same block as before; only where the session copies it from changes.

**Score:** N/A

#### Pull Request

The handover page carries the Asana paste-ready block as its fourth block

Plugins: dkj-policy-bwj

[PR #2478](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2478)

---

### DEPLOY: docs/2471-cut-order-in-repo-rule · 20260925-081859Z

`cut-release`'s cut-order block now tells a repo that pushes live before it cuts to write that order in
an always-on repo rule (`.claude/rules/<name>.md`) or the release manager's lens, not in `CLAUDE.md`,
which since #2374 carries only `@`-imports. It now agrees with the constitution and with
`CONTRIBUTING-portable.md`.

**Score:** 2 -- removes a contradiction a push-then-cut consumer hit while bringing its `CLAUDE.md` down to imports only (#2471).

#### What makes this deploy extra special

N/A -- a wording fix in a skill page; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

cut-release points the cut order at a repo rule, not CLAUDE.md

Plugins: dkj-policy

[PR #2475](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2475)

---

### DEPLOY: fix/2470-stranded-sweep-fake-gh-timeout · 20260925-080053Z

`stranded-sweep-gate.tests.ps1` no longer refuses a push when the parallel test gate is under
load. Its fake `gh` launches a fresh `powershell.exe`, and under 22 lanes that could outrun the
check's 15 s per-call timeout. The suite now gives every run a 120 s bound, because none of its
cases tests that timeout.

**Score:** 2 -- removes a spurious red from `open-pr`'s gate (#2470), in the same class as #2077 and #2458.

#### What makes this deploy extra special

N/A -- a test-suite change; nothing a subscriber runs is touched.

**Score:** N/A

#### Pull Request

stranded-sweep-gate suite gives its fake gh a per-call timeout no load can reach

[PR #2473](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2473)

---

### DEPLOY: docs/2464-drop-shared-block-narrative · 20260925-074054Z

The shared "findings become issues" block in every agent def and persona loses two sentences
that only told the story behind a rule. The rules stay word for word. That saves ~0.4 KB per
copy, across 30 files, and Chris's always-on persona is one of them.

**Score:** 1 -- trims the per-dispatch and always-on cost. No behaviour changes.

#### What makes this deploy extra special

N/A -- a subscriber sees the same rules; only the anecdotes are gone.

**Score:** N/A

#### Pull Request

Drop the two pure-narrative sentences from the findings-become-issues shared block

Plugins: dkj-subagents-alpha, dkj-subagents-ecomm, dkj-subagents-lifehub, dkj-subagents-shopify

[PR #2472](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2472)

---

### DEPLOY: fix/2463-resolves-refuses-dossier · 20260924-213506Z

`open-pr` now refuses a PR that would close an issue carrying the `dossier` label, whether the close
comes from `-Resolves` or from a `Closes` already on the PR body. The rule that a repair of one instance
does not close a collecting issue (#2462) used to hold only as long as somebody remembered it. The
refusal names `-NoResolves` as the way through. The check is shared rather than seam-gated, so every PR
that closes anything now pays one `gh issue view` per closing issue, asking for the body and the labels
in one call. A closing keyword in a commit message is still not read by any gate.

Tier 0 is scored for a session shipping a repair of one instance of a dossier.

**Score:** 3

#### What makes this deploy extra special

N/A. It is a workflow gate and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

open-pr refuses -Resolves on an issue carrying the dossier label

Plugins: dkj-policy

[PR #2468](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2468)

---

### DEPLOY: fix/2459-update-plugins-user-shadow · 20260924-205923Z

`update-plugins` now also updates a plugin's path-less user-scope record when that record sits beside
this checkout's own. Until now one run moved the checkout's records and left those behind, so its own
receipt reported them behind (a session can load the older one, #2442) while its summary said
`0 failed`. Measured on v5.7.0 -> v5.8.0: 5 of 7 plugins behind straight after the run, closed by hand
with five `--scope user` commands. The extra update is not gated on the version, because both records
matched before the run. A path-less `managed` record is left alone.

Tier 0 is scored for a session that runs `update-plugins` on a machine carrying such a shadow.

**Score:** 3

#### What makes this deploy extra special

N/A. It is a maintenance script and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

update-plugins also updates the path-less user-scope shadow

Plugins: dkj-policy

[PR #2467](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2467)

---

### DEPLOY: feat/2462-shared-dossier-label · 20260924-201053Z

`adopt-triage-labels` now prints a `gh label create` line for `dossier` next to the four `prio-N` rungs.
A dossier is a collecting issue: every instance of one recurring problem goes onto it as a comment, and
only the repair of the root cause closes it. `CONTRIBUTING-portable.md` now has the rule for handling
one: a new instance is a comment, a partial repair writes `part of #<n>` with no closing keyword, and the
issue closes only when the root cause is fixed.

Tier 0 is scored for a session filing or repairing against a recurring problem. Until now the label had
no definition in the tree.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a label definition and a tracker convention, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

'dossier' ships as a shared triage label, with the rule for handling a collecting issue

Plugins: dkj-policy

[PR #2466](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2466)

---

### DEPLOY: docs/2461-split-chris-always-on · 20260924-193506Z

Chris's always-on pair is 9.4 KB smaller (51,104 -> 41,693 B), about 3,000 tokens less per session.
Every per-turn rule stays in the persona and the lens, in its tightest form. The dated measurements,
the history behind step 6, the waiting incidents and the reasoning behind the claim step moved to
[Chris's manual](../plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-01-01-manual.md),
which loads on demand. The repo's briefing and branch-check mechanics moved to Derek's lens. Headings
that other files cite stay where they are. The two GENERATED shared blocks, ~8.2 KB of what remains,
are left for #2464.

Tier 0 is scored for every session in every consumer. The lens saving lands here now, and the persona
saving reaches each consumer with the next release.

**Score:** 2

#### What makes this deploy extra special

N/A. It is instruction text for sessions, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Split Chris's always-on persona and lens by when each part is needed

Plugins: dkj-subagents-alpha

[PR #2465](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2465)

---

### DEPLOY: fix/2444-warn-missing-repo-facts-rule · 20260924-185917Z

A consumer whose root `CLAUDE.md` is imports-only now hears about it at session start when no unscoped
`.claude/rules/*.md` exists. `consumer-prose-sessioncheck` prints a `[WARNING]` saying the repo's
trunk, visibility, owner and purpose are stated nowhere a session loads, and where to put them. A
`paths:`-scoped rule does not silence it, because that rule is gone on every turn that does not touch
its files. The finding the report measured was made by hand, and this makes it automatic.

Tier 0 is scored for a session in a consumer that has just done the #2374 cut. It closes the one gap
the cut's own checks could not see.

**Score:** 3

#### What makes this deploy extra special

N/A. It is an advisory session check and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

A consumer's imports-only CLAUDE.md now warns when no unscoped rule carries the repo's facts

Plugins: dkj-policy

[PR #2460](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2460)

---

