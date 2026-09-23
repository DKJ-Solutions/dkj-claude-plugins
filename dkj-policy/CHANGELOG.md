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
[`CONTRIBUTING-portable.md`](../plugins/dkj-policy/CONTRIBUTING-portable.md), the page that ships with
the workflow.

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

**4 / 12 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2362-roster-sync-clean-hook-under-load · 20260923-143338Z

`roster-sync.tests.ps1` read a hook child that never finished as a hook that answered wrongly: the hook
exits 0 on every path, so its "exit 0 when clean" case failing with exit 1 under the parallel gate was a
run that did not complete, and the runner, which captured stdout only, kept nothing that said why. It
now captures stderr, prints that evidence on an off-contract exit, and runs the child once more. A hook
that really stops exiting 0 still fails every assert that reads it.

**Score:** 2

#### What makes this deploy extra special

N/A -- a test suite only; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

roster-sync: the clean-hook case tells a fixture failure from a verdict under the parallel gate

[PR #2373](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2373)

---

### DEPLOY: feat/2352-needs-info-message-form · 20260923-141637Z

`dkj-policy-bwj` now carries the requester message for an issue sent back with `needs-info`, and the
paste-ready block asks the requester for something. Both lived only in a consumer page that was deleted
on September 23 ([#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352)).
`WORKFLOW-portable.md` step 6 makes setting the label and writing the question one act, and gives the
comment's shape. The issue stays open and the label is left for whoever brings the answer. Step 4
gains the five rules for what the block asks and names the Asana task's assignee as the one who
carries it across and closes the issue. `build-golive-block.ps1` now ends the block with that ask
whenever it is given a result link.

**Score:** 3

#### What makes this deploy extra special

Every paste-ready block a BWJ store posts after the update ends by asking the colleague who filed the
ticket to look at the result themselves. An approval ticks off the task. A rejection names what is
wrong and what should change, and the issue reopens. The release happens either way. A ticket sent
back for more information now has a prescribed question on it rather than an empty card in the
blocked column.

**Score:** 3

#### Pull Request

The needs-info requester message and the paste-ready block's ask, carried in dkj-policy-bwj

Plugins: dkj-policy-bwj

[PR #2371](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2371)

---

### DEPLOY: feat/2304-split-integrity-commands · 20260923-140338Z

`check-plugin-integrity-commands.tests.ps1` was the CI gate's critical path once steps 1 and 2 had
split `-docs` and `-links`: 498.3s against a 391s work bound. It is now four suites, cut at check
boundaries and balanced on gate invocations, and side by side on one workstation the longest part took
64s against the original's 184s. All 132 asserts are preserved and were verified by running the four
parts. This is step 3 of #2304: the heaviest remaining file, `-entries` at 377.7s, is below the work
bound, so from here the gate is bound by total work rather than by one file.

**Score:** 3

#### What makes this deploy extra special

This is the step where the lever changes. Until now each split moved the critical path to the next
heaviest file; after this one no single file is above the 391s work bound, so the next saving comes from
a shard (or a split that goes with one), not from a split alone -- which is exactly what ci.yml's matrix
comment has said since #1358. The cut again surfaced state carried across a block boundary, this time a
variable rather than a file, and it is stated again in the suite that reads it.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-commands into parallel suites: step 3 of the CI critical path

[PR #2370](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2370)

---

### DEPLOY: fix/2364-parallel-gate-flaky-suites · 20260923-132216Z

Three causes behind "red under the parallel gate, green alone" in two test suites, repaired in the
suites and nowhere else. A one-line sibling in the deadline case was held to a 3s ceiling it cannot
meet under load (8.6s measured); six lane-count asserts refused the lane-hold note a memory-starved
run appends; and the integrity fixture read a child gate that stopped before its report as a gate
that found nothing. The fourth symptom the issue names, the nested-gate case, has no surviving
capture, so it now prints its own evidence when red instead of being given a guessed cause.

**Score:** 2

#### What makes this deploy extra special

N/A -- test suites only; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

Two suites fail under the parallel open-pr gate and pass alone

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2367](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2367)

---

### DEPLOY: feat/2304-split-integrity-links · 20260923-130118Z

`check-plugin-integrity-links.tests.ps1` was the CI gate's critical path once step 1 had split `-docs`:
539.2s against a 391s work bound. It is now four suites, cut at check boundaries and balanced on gate
invocations, and side by side on one workstation the longest part took 55s against the original's
159s. All 141 asserts are preserved and were verified by running the four parts. This is step 2 of
#2304; the critical path moves to `-commands` (498.3s), so the shard count does not change and the
issue stays open for steps 3 and 4.

**Score:** 3

#### What makes this deploy extra special

The cut surfaced the same class of defect step 1 did, one layer up: the fixture writes no root
documents, so checks 10, 28, 29, 30 and 32 had all been starting from the files check 4's scenario B
happened to leave behind. Two leaned on it outright -- check 28's file-relative proof needs a root
`CONTRIBUTING.md`, and check 32 reads that file back to restore it. It is now stated once in the fixture
instead of inherited, which is the second time a weight-based split has found state that only held
because two scenarios shared a file.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-links into parallel suites: step 2 of the CI critical path

[PR #2366](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2366)

---

### DEPLOY: fix/2358-claim-marker-comma-split · 20260923-120648Z

`claim-issue.ps1 -Marker` now splits a comma list into names. Under the documented
`powershell -File` route a list such as `-Marker claim-tag,xoxo-lane` arrived as one literal string,
was written as a compound marker name and read as one, so a machine passing a predecessor list could not
see ordinary `claim-tag` claims and its own claims were invisible to every other machine. Only the first
name is written now, every name is read, and a compound marker already written before this repair is
still recognised whenever one of its parts is a listed name
([#2358](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2358)). `-SkipLabel` and
`-SkipIssue` had the same defect and are split the same way; `-SkipIssue` was the sharper case, since an
`[int[]]` under `-File` read `12,34` as the single issue `1234`.

**Score:** 3

#### What makes this deploy extra special

A consumer sweeping one backlog from several machines with `-Tag` stops seeing claimed issues listed
as free after a plugin update, and the compound markers already on its issues keep holding.

**Score:** 4

#### Pull Request

claim-issue -Marker splits a comma list, so -File callers read every predecessor name

Plugins: dkj-policy

[PR #2365](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2365)

---

### DEPLOY: fix/2347-release-asset-reupload-by-id · 20260923-114927Z

The `cut-release` skill told the second pass to re-upload an edited release document with `gh release
upload --clobber`. At `v5.7.0`, on gh 2.101.0, that returned `HTTP 422 ... ReleaseAsset.name already
exists` and left the stale asset in place, and `gh release delete-asset` reported it *not found*. A new
shared script, `upload-release-asset.ps1`, now does both uploads: it reads the Release's assets from the
`releases/{id}/assets` endpoint (not `gh release view`, which listed none for `v5.7.0`), deletes a same-named asset **by id**, uploads without `--clobber`, and exits 1 unless the
published asset has the file's exact byte count. The skill page and `RELEASES-portable.md` call it at
step 5 and in the second pass (#2347).

**Score:** 2 -- the old one-liner failed loudly but left the published note one revision behind, and
the fallback a reader reached for failed too; the byte check replaces a size somebody had to watch.

#### What makes this deploy extra special

N/A -- the reader is whoever cuts a release in a repo running this workflow, and for them it is a
different command at two steps of the same checklist, nothing to migrate.

**Score:** N/A

#### Pull Request

cut-release: re-upload a Release attachment by asset id and verify its byte count

Plugins: dkj-policy

[PR #2357](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2357)

---

### DEPLOY: docs/specialists-update-commands · 20260923-113308Z

Added `.claude/specialists/UPDATE`: the bare PowerShell commands that update every plugin this repo
enables -- `claude plugin marketplace update dkj-claude-plugins`, then
`claude plugin update <plugin>@dkj-claude-plugins --scope project` for each of the six.

**Score:** 1 -- saves retyping seven commands by hand, and prevents an update run without
`--scope project` writing a machine-wide record instead of this checkout's.

#### What makes this deploy extra special

Nothing reaches a subscriber: the file lives in this repo's own `.claude/` and ships in no plugin.

**Score:** N/A

#### Pull Request

Add .claude/specialists/UPDATE with the plugin update commands

[PR #2359](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2359)

---

### DEPLOY: docs/remove-scripts-readme · 20260923-111221Z

Removed `scripts/README.md`. The rules and measured decisions that code and docs cited it for now live
in [Sylvester's lens](../.claude/specialists/lenses/specialist-05-15-lens.md#the-scripts-directory-is-the-source)
and [Tycho's lens](../.claude/specialists/lenses/specialist-04-18-lens.md#a-suites-fixture-path-carries-the-pid-and-a-fresh-guid);
the directory map and the entry-point table were dropped, because each skill page and each plugin's
`hooks/hooks.json` already answer them. The source-repo guard's refusal now points at the lens.

**Score:** 1 -- prevents a reader following the guard's printed pointer, or a code comment, to a page
that no longer exists.

#### What makes this deploy extra special

Nothing reaches a subscriber: the only consumer-visible change is wording in two plugin pages.

**Score:** N/A

#### Pull Request

Remove scripts/README.md; move its cited rules to the owners' lenses

Plugins: dkj-policy, dkj-subagents-shopify

[PR #2356](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2356)

---

### DEPLOY: fix/2343-ship-pr-unattended-trunk-return · 20260923-105742Z

When `ship-pr` runs inside GitHub Actions, as the merge-on-green runner, it now stops before the CI wait
unless step 2b got the checkout back onto the trunk. A second layer stops the forward lap from merging the
branch's live remote head into the working tree. Together they close the residual window #2338's security
review found: code pushed during the wait could land where a `FOLD_PUSH_TOKEN` checkout runs scripts
(#2343).

**Score:** 2 -- a narrow window, two failures deep; the attended path is unchanged.

#### What makes this deploy extra special

A consumer's merge-on-green runner runs the plugin's `ship-pr.ps1`, so it picks this up with the release
without any change to its workflow. A pull request whose runner cannot reach the trunk now stays armed for
the next sweep instead of merging.

**Score:** 2 -- invisible unless a runner's trunk return fails, and then the merge waits half an hour.

#### Pull Request

ship-pr: an unattended run stops unless it is back on the trunk, so a forward lap cannot bring in an unjudged head

Plugins: dkj-policy

[PR #2355](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2355)

---

### DEPLOY: docs/2353-bwj-ticket-form · 20260923-104615Z

`dkj-policy-bwj` now carries BWJ's ticket form, as step 8 of its ticket-handling page -- the form a
request arriving from Asana takes in both stores: the Asana assignee deciding whose ticket it is, the
seven-row header with `Reviewed` as the provenance boundary, the closed `State` and `Ball with`
vocabularies, the section route with its two dictated gate sentences, and what `### Testing` carries.
It lived only in `smartwatchbanden`'s tree until now, which left `xoxowildhearts` with no copy and
the assignee rule one deletion away from being lost (#2353).

**Score:** 3

#### What makes this deploy extra special

A BWJ store repo can now drop its own ticket-form page and point at the plugin, and both stores read
the same form from the version they loaded.

**Score:** 2

#### Pull Request

dkj-policy-bwj carries the BWJ ticket form

Plugins: dkj-policy, dkj-policy-bwj

[PR #2354](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2354)

---

### DEPLOY: fix/2348-preview-context-settings · 20260923-100607Z

`push-preview` created a new preview with `theme push --unpublished`, and no `theme push` uploads
`config/settings_data.context.<market>.json` -- the CLI lists the file, never sends it, and reports
success (CLI 4.8.0; no upload bucket matches a context file under `config/`). On a Markets store every
preview therefore rendered every market with the global settings. A new preview is now a
`shopify theme duplicate` of live, waited on until the copy has filled (`Get-ThemeFillVerdict`, with
`-PollSeconds` / `-TimeoutMinutes`), and only then pushed over -- so the first push of a branch takes
minutes longer. Where no live id is answered it falls back to the old create. A preview this checkout
has no record of copying gets a printed notice, and so does a branch that changes a context-settings
file, since no push can put those bytes on a theme. `Get-ThemeFileCount` moved from `backup-live-theme.ps1`
into `shopify-cli-lib.ps1` so both callers share it (#2348).

**Score:** 3 -- a Markets store's previews stop differing from live for reasons the branch did not
cause, noticed the first time somebody compares one; the first push per branch now waits for the copy.

#### What makes this deploy extra special

N/A -- nothing to migrate. Existing previews keep working and are named by the notice; removing one and
pushing again gets a copy of live.

**Score:** N/A

#### Pull Request

push-preview creates previews by duplicating live, so per-market context settings arrive

Plugins: dkj-subagents-shopify

[PR #2351](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2351)

---

