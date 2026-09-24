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

**23 / 50 minor entries** <!-- pending-tally -->

### DEPLOY: fix/2420-thumbnail-generator-connector-owner · 20260924-131132Z

The connector register now names `thumbnail-generator` under the `DKJ-Solutions` org it moved to, so
that consumer's session check stops reporting its own origin as unregistered.

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping and ships to no subscriber.

**Score:** N/A

#### Pull Request

Register thumbnail-generator under its new owner

[PR #2440](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2440)

---

### DEPLOY: fix/2426-init-own-payload-subagents · 20260924-115135Z

`specialists-init` reads the subagent definitions of the payload that is actually running, rather than those
of the highest version in the plugin cache, and says so when a directory it found holds no definition it
recognises. Prevents a stale payload from scaffolding zero subagent lenses behind a closing count that read
as a clean result (#2426).

**Score:** 2

#### What makes this deploy extra special

A consumer running `specialists-init` from an older installed payload than the newest one cached now gets a
lens for every subagent it enables, instead of none and no word about it; where a directory still yields
nothing, a notice names the directory and what was looked for.

**Score:** 2

#### Pull Request

specialists-init reads its own payload's subagents and says when a found directory yields none

Plugins: dkj-subagents-alpha

[PR #2433](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2433)

---

### DEPLOY: fix/2429-consumer-deploy-lock · 20260924-112315Z

The branch-entry gate that `adopt-dkj-policy` places in a consumer now holds the DEPLOY lock, as this
repo's own gate does: it refuses a PR whose DEPLOY section changed after the PR opened, including one
merged from the GitHub UI. A caller placed before this change keeps working unchanged and says the lock
was not checked. To take the lock, add `pull-requests: read` and the `edited` trigger, or re-run Part 1.

**Score:** 3

#### What makes this deploy extra special

A consumer repo's own CI starts guarding the changelog text a PR was approved with, once its caller
carries the two lines. Callers placed before this change see nothing new until then.

**Score:** 2

#### Pull Request

The consumer's branch-entry gate holds the DEPLOY lock

Plugins: dkj-policy

[PR #2435](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2435)

---

### DEPLOY: fix/2428-life-hub-lifehub-lenses · 20260924-104630Z

The connector register no longer lists five `dkj-subagents-lifehub` lenses for `life-hub` that its
re-bootstrapped roster does not have, so the consumer check stops reporting them as missing. The plugin
itself stays registered, because the consumer's settings still enable it.

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping and ships to no subscriber.

**Score:** N/A

#### Pull Request

Register the lifehub lenses life-hub no longer has as absent

[PR #2434](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2434)

---

### DEPLOY: feat/2422-reusable-ci-gates · 20260924-101900Z

Part 1 of `adopt-dkj-policy` no longer copies the two PR gates into a consumer
([#2422](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2422)). `branch-entry.yml` and
`always-on-budget.yml` are now a few-line caller of a reusable workflow in this repo
(`reusable-branch-entry.yml`, `reusable-always-on-budget.yml`). A change to the runner, its steps or its
timeout therefore reaches every consumer on its next pull request, with no re-adopt, and the reasoning
sits in one place. `check-connectors` recognises the `uses:` line as a reference into this tree, so a
caller-only consumer still reads as adopted. A repo adopted earlier keeps its full copy until it deletes
the file and re-runs Part 1.

**Score:** 2

#### What makes this deploy extra special

A repo adopting the workflow gets two short callers instead of two 50-line runners, and later changes to
those gates arrive without anyone re-running the adoption. An already-adopted repo sees no change unless
it opts in.

**Score:** 2

#### Pull Request

Ship the two PR gates as reusable workflows

Plugins: dkj-policy

[PR #2432](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2432)

---

### DEPLOY: docs/remove-install-uninstall · 20260924-100317Z

The root `INSTALL.md` and `UNINSTALL.md` are gone. The install commands and the machine-side removal now
live in `plugins/ADOPTION.md`, and every link, printed script message and tooling list that named either
page points there instead. The archived release notes keep their text; their ten links to the pages now point at the last commit that still had them.

**Score:** 2

#### What makes this deploy extra special

A consumer's single entry is now `plugins/ADOPTION.md`, which carries the install commands in its own
*Installing it yourself* section. The old migration walkthroughs (old plugin names, `dkj-team-*` ids, the
`specialist-` filenames) went with `INSTALL.md` and survive only in the release notes that introduced them.

**Score:** 3

#### Pull Request

Remove INSTALL.md and UNINSTALL.md

Plugins: dkj-policy, dkj-subagents-alpha

[PR #2430](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2430)

---

### DEPLOY: fix/2424-ci-gate-shard-count · 20260924-095218Z

The CI gate's green line no longer states a shard count, which had gone stale at 4 while the
matrix runs 5.

**Score:** 1

#### What makes this deploy extra special

N/A -- a CI log line in this repo only; no subscriber sees it.

**Score:** N/A

#### Pull Request

ci.yml: the lint-en-tests green line no longer prints a stale shard count

[PR #2431](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2431)

---

### DEPLOY: fix/2425-life-hub-connector-owner · 20260924-093941Z

The connector register names `life-hub` under its new owner, `DKJ-Solutions/life-hub`, so the
origin-vs-register check no longer treats a repointed checkout as a clone of something else. Prevents a
false mismatch on the first `life-hub` checkout whose `origin` is set to the new owner.

**Score:** 1

#### What makes this deploy extra special

N/A -- the register is this repo's own bookkeeping and ships to no subscriber.

**Score:** N/A

#### Pull Request

Connector register names life-hub under its new owner DKJ-Solutions

[PR #2427](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2427)

---

### DEPLOY: fix/2405-open-pr-body-file · 20260924-091928Z

`open-pr` takes `-BodyFile <path>`: the PR body read from a UTF-8 file, treated exactly as `-Body`. Called
through `powershell -File`, Windows PowerShell 5.1 split a `-Body` carrying `"` characters across native
arguments, and a fragment bound to another parameter (`-MaxParallel`, on a consumer PR). A path carries no
quote, so it arrives intact. Passing both, naming a missing file, or an empty one is refused before anything
runs.

**Score:** 2

#### What makes this deploy extra special

A consumer whose own tooling shells out to `open-pr` with a template-derived body can now pass that body
without it being torn apart. Visible to whoever calls `open-pr` that way after the next plugin update.

**Score:** 1

#### Pull Request

open-pr takes -BodyFile so a quote-carrying body never crosses a native command line

Plugins: dkj-policy

[PR #2421](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2421)

---

### DEPLOY: feat/2414-retire-round-tooling · 20260924-090708Z

The two test-round generators `round-tally.measure.ps1` and `round-baseline.measure.ps1` are retired,
along with their suites
([#2414](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2414)). The test-round
methodology they served (#371) is no longer in use. They were the last suites guarding it, and CI loses
roughly 25 seconds of wall-clock with them.

**Score:** 1

#### What makes this deploy extra special

N/A. Both tools lived only in this repo's `scripts/tests/` and never shipped in a plugin.

**Score:** N/A

#### Pull Request

Retire the round-tally and round-baseline test-round tooling

Plugins: dkj-policy

[PR #2423](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2423)

---

### DEPLOY: fix/2350-backup-waits-through-short · 20260924-085451Z

`backup-live-theme` failed a backup the moment two file-count samples agreed below the live theme's count,
while `push-preview` waited such a reading out. A duplicate grows in bursts with pauses between them, so a
pause could fail a copy that was still filling. The backup now waits until its deadline like the preview
does, and still refuses a copy that is short when the wait is over.

**Score:** 2

#### What makes this deploy extra special

A Shopify store's release-cut backup no longer fails on a copy that was only pausing, which left a
half-copy standing and the cut step red. A copy that really stopped short is still refused, only later.

**Score:** 2

#### Pull Request

backup-live-theme waits through a 'short' fill verdict until its deadline, as push-preview does

Plugins: dkj-subagents-shopify

[PR #2419](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2419)

---

### DEPLOY: feat/2361-pr-bypass-note · 20260924-084152Z

A run of `open-pr` or `ship-pr` that skips a gate now records it in the PR body itself: a **Gate bypass**
section naming the switches, with the reason given by the new `-BypassNote`, or a line saying none was
given. The section is kept across `-RefreshBody`, and a later bypass is added beneath an earlier one. Until
now the workflow asked for that record and the tooling offered no way to write it, so it took a hand edit
of the body the DEPLOY lock reads; on PR #2357 that edit flattened the body and the merge was refused
after a full CI wait.

A body passed with `-Body` now gets the entry's description filled in at the template's placeholder, as
the default body does. A `-Body` that still lacks the DEPLOY section is refused before the gates, instead
of opening a PR the DEPLOY lock would refuse to merge after CI.

**Score:** 3

#### What makes this deploy extra special

A consumer whose session has to ship past a gate gets the record the workflow asks for without touching
the PR body by hand, which is the step that broke a merge here. Visible to whoever runs `open-pr`/`ship-pr`
with a skip switch after the next plugin update, and to anyone reviewing such a PR.

**Score:** 2

#### Pull Request

open-pr/ship-pr: record a gate bypass in its own PR-body section that survives -RefreshBody

Plugins: dkj-policy

[PR #2418](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2418)

---

### DEPLOY: docs/2416-report-issue-type-via-patch · 20260924-082111Z

`report-issue`'s step 1 prescribed `gh issue create --type`, which `gh 2.74.0` rejects as an unknown
flag, so the create failed and no issue was filed. The step now files with the labels only and sets
the type straight after with `gh api --method PATCH repos/<owner>/<repo>/issues/<n> -f type=<Type>` --
the route the page already used for an issue filed earlier, and one that works on old and new `gh`
alike. `WORKFLOW-portable.md`'s classification table names the same route. Closes #2416.

**Score:** 2

#### What makes this deploy extra special

A consumer filing through `report-issue` on an older `gh` no longer has the create fail outright; the
issue lands and is typed in the same step.

**Score:** 3

#### Pull Request

report-issue sets the issue type after creation, since gh 2.74.0 has no --type flag

Plugins: dkj-policy-bwj

[PR #2417](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2417)

---

### DEPLOY: docs/2411-integrity-family-placement-rule · 20260924-075648Z

The `check-plugin-integrity-*` test family now has a stated rule for where a new numbered check's
scenarios go. They join the existing file that owns their subject. A new file is justified only when
that file's CI median would exceed the gate's work bound (sum of suite medians over lanes, ~352s
today), which is the condition every past split was actually bought on. The second half of #2411 was
measured and does not hold: a file's own start costs ~0.3s, about 4s across fifteen files against
the family's 2,494.6s, so merging files would buy nothing. The family's 35.5% share is set by how
many times it runs the gate, not by how many files it has. The rule lives in the test engineer's repo
lens, with a pointer beside the membership table in the shared fixture. Closes #2411.

**Score:** 2

#### What makes this deploy extra special

N/A -- repo-internal test organisation; nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

Where a new check-plugin-integrity check's tests go, and why fewer files would not help

[PR #2413](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2413)

---

### DEPLOY: feat/2337-connector-runner-ref · 20260924-074131Z

`check-connectors.ps1` now reports a registered consumer's write runner that fetches this repo's scripts at
a moving ref, or pinned behind the current dkj-policy release
([#2337](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2337)). This is the source-side half of
#2333's pin: a consumer nobody re-runs `adopt-ci-floor` in no longer stays invisible on `ref: main` beside
`FOLD_PUSH_TOKEN`. Only runners holding a credential are judged, and the finding is an `[INFO]` naming the
file, the line and the release to pin to. Its first run found five such runners across the two BWJ
consumers.

**Score:** 2

#### What makes this deploy extra special

N/A: a maintainer-side register check, which never reaches a subscriber.

**Score:** N/A

#### Pull Request

check-connectors reports a consumer write runner on a moving or stale shared-scripts ref

[PR #2412](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2412)

---

### DEPLOY: docs/2409-tycho-owns-suite-population · 20260924-072644Z

The test engineer's manual now makes Tycho the owner of the test-suite **population**. Before this,
every rule in it pointed one way: add a test, add a regression test, flag a gap. Nothing covered
justifying, merging or retiring a suite, and this repo's gate grew from 43 to 141 suites in about six
weeks with nobody able to say why each one is needed. He now has to be able to name what every suite
protects. He proposes merges where suites overlap and retirements where a subject has gone, and each
retirement is stated as a trade of coverage for time. A new hard rule stops the one-suite-per-issue
shape: a regression case goes into the suite that already owns its subject. The performance
engineer's manual adds the matching line: the verdict is Tycho's, and Nolan supplies the per-suite
cost table it is made against. Closes #2409; the first audit of the 141 is #2408.

**Score:** 3

#### What makes this deploy extra special

Any consumer whose test gate is growing now has a named specialist who answers for its size. Asked why
the gate needs every suite it runs, the test engineer gives a per-suite answer and proposes merges or
retirements. Before, he added suites and never questioned them.

**Score:** 2

#### Pull Request

Tycho owns the test-suite population, and Nolan prices it

Plugins: dkj-subagents-alpha

[PR #2410](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2410)

---

### DEPLOY: docs/2372-sweep-no-gate-prerun · 20260924-071713Z

`sweep-issues` step 4 told a session that a `-GatesOnly` run before the ship costs nothing. It doubles
the wait: `open-pr` credits a recorded pass only on the identical tree (HEAD plus every uncommitted file)
in the same worktree, and a sweep's pre-run is almost always before the commit or in another lane, so
`ship-pr` ran the same gate again (1,400s twice on one commit, as measured). Step 4 now says to run nothing
before a branch that ships, and keeps `-GatesOnly` for the branch that stops at a visible result, where
it is the only gate that runs.

**Score:** 2

#### What makes this deploy extra special

A session sweeping a consumer's backlog stops paying for every gate twice on the issues it ships.

**Score:** 2

#### Pull Request

sweep-issues: no -GatesOnly pre-run, since ship-pr gates first and a pre-run is rarely credited

Plugins: dkj-policy

[PR #2407](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2407)

---

### DEPLOY: docs/remove-four-readmes · 20260924-070744Z

Removed three READMEs nothing reads: `plugins/README.md` and `assets/avatars/README.md` duplicated
the root README, and the width decisions on `plugins/dkj-subagents/subagent-shared/README.md` now live in
[Ravi's lens](../.claude/specialists/lenses/specialist-06-24-lens.md#why-each-circle-is-the-width-it-is),
where the lint's `[tool-block]` refusal points.

**Score:** 1 -- prevents a reader following the lint's printed pointer, or a link, to a page that no
longer exists.

#### What makes this deploy extra special

Nothing reaches a subscriber: the only plugin-visible change is one sentence in `dkj-policy`'s README.

**Score:** N/A

#### Pull Request

Remove three READMEs nothing needs

Plugins: dkj-policy

[PR #2363](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2363)

---

### DEPLOY: fix/2402-edited-claim-marker · 20260924-065127Z

`claim-issue.ps1 -Tag` no longer counts a claim marker that sits in an **edited** comment. A comment
keeps its original author and creation time when it is edited, so a marker edited into an old comment
of one's own used to win every claim race and hold the issue indefinitely. The tooling never edits a
claim comment, so a genuine claim is lost only if somebody edits it by hand. A marker whose author
has been deleted or suspended is still dropped, which means the issue it held reads as free. That
behaviour is now pinned by a test.

**Score:** 2

#### What makes this deploy extra special

A repo that sweeps its backlog with `claim-issue -Tag` could have an issue held by anybody who edited
a claim marker into an old comment of their own. That no longer works. If you edit a genuine claim
comment by hand, that claim is released.

**Score:** 2

#### Pull Request

claim-issue: a marker in an edited comment is not a claim

Plugins: dkj-policy

[PR #2406](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2406)

---

### DEPLOY: fix/2393-arm-merge-when-green-on-watch · 20260923-221545Z

`ship-pr` now labels a pull request `merge-when-green` once it is open and before it starts waiting on CI.
Until now it did that only when its own CI verdict refused. So a ship that dies mid-watch, or refuses at
step 3b on a timing state, still has its merge finished by the sweep. The sweep now takes over only a pull
request whose required checks have been green for ten minutes, so it never races a live ship. `ship-pr`
removes the label again at the refusals only a person can clear: the step-list gate, the DEPLOY lock, a merge
GitHub itself refuses, and a required check with no Actions run behind it. Leaving the label on would starve
every armed pull request numbered above it.

**Score:** 2

#### What makes this deploy extra special

A shipped pull request no longer sits green and unmerged because the session that shipped it ended early.

**Score:** 2

#### Pull Request

ship-pr: arm merge-when-green before the CI wait, with a settle window so the sweep never races a live ship

Plugins: dkj-policy

[PR #2403](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2403)

---

### DEPLOY: fix/2399-claim-marker-author-check · 20260923-220415Z

A claim marker was taken at its word. Anybody who could comment on an issue could write one naming
somebody else's tag, and `-Release`, the verdict, the sweep and the race all counted it. A marker now
counts only when the comment's author is the account its tag names (#2399).

**Score:** 2 -- closes a spoofing gap in tag-mode claims. Nothing changes for a genuine claim, because
gh always writes it as that account.

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

claim-issue: a claim marker counts only when its author is the tag's own account

Plugins: dkj-policy

[PR #2404](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2404)

---

### DEPLOY: feat/2394-resume-from-origin · 20260923-215115Z

`claim-issue.ps1 <n> -Tag -TakeOver` now also resumes an issue that carries **no claim marker**, which is
the common case: a session that never ran `-Tag` leaves only its branch on origin. There exactly one branch
for the issue must be on origin, and every commit on it off the trunk must be authored under one of this
checkout's names; one foreign author, or an author list that could not be read, refuses. A new user-level
variable, `DKJ_OWN_ACCOUNTS`, declares the other accounts one person works under, and both `-TakeOver` and
the parked-fix scan's `NOT YOURS` verdict count them as yours. That block now also names that route.
`-Candidates` reading such a branch as `branch` rather than `free` landed separately, in #2392.

**Score:** 3

#### What makes this deploy extra special

N/A -- this changes how a session picks up its own parked work, which no subscriber of a service sees.

**Score:** N/A

#### Pull Request

claim-issue -TakeOver: resume an untagged branch on origin, and count a person's declared other accounts as theirs

Plugins: dkj-policy

[PR #2397](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2397)

---

### DEPLOY: fix/2375-boardless-status-map-line · 20260923-214244Z

The `asana-mirror` run printed a repo's deliberate "no project board" declaration as an empty field and a
dangling comma, so its CI log could not tell that answer from a broken map. It now says the repo has no
project board and that stage floors come from the issue itself.

**Score:** 1

#### What makes this deploy extra special

Visible in a board-less store's `asana-mirror` CI log once its template copy is refreshed (xoxowildhearts
declared itself board-less the day this was filed); nothing it does changes.

**Score:** 1

#### Pull Request

asana-mirror: a board-less repo's status-map line says there is no board

Plugins: dkj-policy-bwj

[PR #2401](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2401)

---

### DEPLOY: feat/2395-release-all · 20260923-212655Z

`claim-issue.ps1 -Tag -ReleaseAll` releases every open issue this tag holds in one command: its own
claim markers, and this account's assignee where one of those markers sits beside it. Without `-Apply`
it only lists what it would release. Markers written by any other tag are never touched, including
another machine under the same account, and an assignee with no marker of this tag stays in place. A
marker only counts as this tag's when the comment was actually written by this tag's account, so a
comment somebody else posts with your tag in it cannot trigger a release.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

claim-issue -Tag -ReleaseAll

Plugins: dkj-policy

[PR #2400](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2400)

---

### DEPLOY: fix/2338-merge-on-green-trunk-code · 20260923-211820Z

The merge-on-green runner checked out an armed pull request's head with `FOLD_PUSH_TOKEN` in the workspace
and then ran code from that checkout, so being able to push a branch meant being able to run code with a
token that bypasses the trunk ruleset. The picker now refuses a pull request whose diff touches code the
runner executes, and the runner refuses any checkout other than the commit the picker judged (#2338).

**Score:** 3 -- closes a privilege widening on the one runner that holds the standing write token; a
pull request touching scripts now ships from a session instead.

#### What makes this deploy extra special

A consumer's scaffolded `merge-on-green.yml` ran the plugin's `ship-pr.ps1`, and that dot-sourced the
branch's `scripts/repo-config.ps1` with the consumer's `FOLD_PUSH_TOKEN` in place. The picker fix reaches
them as soon as their runner checks out the source's `main`. The SHA pin reaches them when
`adopt-ci-floor` reports their runner as drifted and they re-apply it.

**Score:** 3 -- a security fix to a runner consumers adopted; those who use merge-on-green will see
script-touching pull requests left for a session.

#### Pull Request

merge-on-green: never run code from an armed branch that changes what the ship executes

Plugins: dkj-policy

[PR #2346](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2346)

---

### DEPLOY: docs/2376-sweep-ship-resolves · 20260923-210524Z

`sweep-issues` told a session to ship with a bare `ship-pr.ps1`, which `open-pr`'s resolves gate refuses on
every sweep branch, because the branch and its entry always name the issue. Step 5 now prints
`ship-pr.ps1 -Resolves <n>`, names `-NoResolves` for a branch that is only one step of a larger issue, and
step 6 points at the same command.

**Score:** 2

#### What makes this deploy extra special

A session sweeping a consumer's backlog no longer loses a round trip on every issue to a refusal the
skill's own command caused.

**Score:** 2

#### Pull Request

sweep-issues: the ship lines name -Resolves, so a sweep branch passes open-pr's resolves gate

Plugins: dkj-policy

[PR #2398](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2398)

---

### DEPLOY: fix/2392-candidates-read-remote-branches · 20260923-205323Z

`claim-issue.ps1 -Candidates` now reads origin's branches once for the whole backlog. An open issue with
no claim marker but a `<prefix>/<n>-<name>` branch on origin reads `branch` instead of `free`, and the
reason names the branch, its author and how long ago it last moved. A claim marker still takes
precedence. If the branch listing cannot be read, the run still judges from the tracker and says that
`free` then means only "no claim marker".

**Score:** 3

#### What makes this deploy extra special

A sweep no longer offers you an issue somebody else is already building just because they did not
claim it by tag. Before this, the only warning came after the claim was written, one issue at a time.

**Score:** 2

#### Pull Request

claim-issue -Candidates: an unmarked issue with a branch on origin reads 'branch', not 'free'

Plugins: dkj-policy

[PR #2396](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2396)

---

### DEPLOY: feat/2374-global-claude-md · 20260923-204008Z

The rules a repo runs under now ship with `dkj-policy` itself: one [`CLAUDE.md`](../plugins/dkj-policy/CLAUDE.md)
holding the constitution and the general working practices, plus a
[`dkj-policy-bwj` extension](../plugins/dkj-policy/dkj-policy-bwj/CLAUDE.md) for the BWJ repos. A
consumer's own `CLAUDE.md` now holds **only** the `@`-import line(s) and nothing else -- no rules, no
facts, no repo block. A repo's own facts (trunk, public or not, owner, purpose) move to an unscoped
rule such as `.claude/rules/<name>.md`, loaded every session exactly as `CLAUDE.md` was; a fact that
belongs to one specialist alone moves to that specialist's own lens. The
`consumer-prose-sessioncheck` hook warns at session start where the import line is missing and prints
it for the consumer's own marketplace name; the `specialists-init` scaffold stops inviting a local
constitution. This repo runs the same model, one step further than the branch's original plan: its
constitution moved into the plugin, and its former repo slot -- everything specific to this repo that
used to sit inside `CLAUDE.md` -- moved whole into `.claude/rules/this-repo.md`. Root `CLAUDE.md` is
now a one-line title plus the three `@`-imports, and nothing else.

**Score:** 4

#### What makes this deploy extra special

N/A -- a repo-governance change; nothing a subscriber runs changes.

**Score:** N/A

#### Pull Request

One global CLAUDE.md shipped by dkj-policy, imported by consumers

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-alpha, dkj-subagents-shopify

[PR #2390](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2390)

---

### DEPLOY: feat/2387-claim-takeover · 20260923-193109Z

`claim-issue.ps1 <n> -Tag -TakeOver` hands a `held` issue over to this machine, deliberately and visibly,
when the holder is this same gh account on another machine and exactly one branch for the issue is on
origin. It removes the old marker, claims under this tag through the ordinary path, leaves a comment naming
the old tag, the new tag and the branch, and prints the checkout, so the old machine's `-Verify` reads
`[NO]`. A colleague's claim, an issue with no branch on origin, and one with several are each refused.

**Score:** 3

#### What makes this deploy extra special

A sweep run across several of your own machines no longer strands an issue on a machine you cannot reach:
the work parked on origin can be picked up from any of them in one command, without deleting a marker by
hand.

**Score:** 3

#### Pull Request

claim-issue -Tag -TakeOver: hand a held issue over to this machine when its branch is on origin

Plugins: dkj-policy

[PR #2391](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2391)

---

### DEPLOY: fix/2388-durations-merge-advice · 20260923-191439Z

`record-suite-durations.ps1`'s no-table refusal used to send the caller from a `fold:` run to the
`merge:` run beside it. Since the merge-commit certificate (#2303), that run normally has no suite table
either. The refusal and the `-RunId` docstring now name a PR run, the run that always has one. This prevents a
failure that already happened twice during #2304's duration re-reads: a maintainer following the throw's
advice to a second tableless run.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

record-suite-durations: the no-table refusal names a PR run, not a merge run

[PR #2389](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2389)

---

### DEPLOY: feat/2333-pin-write-runners · 20260923-183716Z

The three consumer runners that hold a write credential no longer run this repo's scripts at `main`.
`adopt-ci-floor` now checks the shared scripts out for the fold, the resolves verification and
merge-on-green at the commit the adopting plugin's release was tagged at, written as
`ref: <sha> # v<version>`. Until now a change landing on this repo's trunk reached `FOLD_PUSH_TOKEN`'s
contents and pull-request write in every adopted consumer on its next run, with no release in between.
The read-only gates keep `ref: main`, where the stale-convention argument still holds. The pin has to
move, so re-running `adopt-ci-floor` now reads every existing write runner and reports one still on
`main` or pinned behind the version it came from, with the value to put there. It never rewrites the
file.

**Score:** 3

#### What makes this deploy extra special

A consumer that adopted the CI floor before this release keeps `ref: main` in its write runners until
somebody edits them, because the scaffolder never rewrites a file. Re-running `adopt-ci-floor` is what
tells them, one `ref:` line per runner. A floor adopted from now on is pinned from the start.

**Score:** 2

#### Pull Request

The write runners adopt-ci-floor places now pin the shared scripts to a release

Plugins: dkj-policy

[PR #2345](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2345)

---

### DEPLOY: feat/2304-split-integrity-entries · 20260923-182014Z

`check-plugin-integrity-entries.tests.ps1` is three suites now, and CI runs on five shards instead of
four. The re-read durations showed the gate bound by total work (453.8s over 16 lanes) with `-entries`
(426.1s) the file a fifth shard would stop at, so both levers go in together: the expected floor is
`new-branch.tests.ps1` at 380.2s. All 86 asserts are preserved and were verified by running the three
parts. Step 4 of #2304.

**Score:** 3

#### What makes this deploy extra special

The first step of #2304 that moves the shard count, and the one where the issue's own ordering is
applied rather than quoted: a split alone would have bought nothing here, and a shard alone would have
stopped at the file this change splits. A sixth shard buys nothing until `new-branch` is split.

**Score:** N/A

#### Pull Request

Split check-plugin-integrity-entries and add a fifth CI shard: step 4 of the CI critical path

[PR #2385](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2385)

---

### DEPLOY: fix/2379-native-capture-exitcode-flake · 20260923-181117Z

`native-capture.tests.ps1` no longer goes red on #1931's 1-in-300 unmeasured exit code
([#2379](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2379)). The exact-exit asserts on the
Start-Process arm now re-ask a real child up to three times, and only while the lib itself reports
`ExitCodeUnknown`. The regression they guard is a dropped `.Handle` read, which empties every attempt, so
it still fails. The lib is unchanged: it was already reporting the race correctly. Nobody outside this
repo's CI notices.

**Score:** 1

#### What makes this deploy extra special

N/A: test-only, never reaches a subscriber.

**Score:** N/A

#### Pull Request

native-capture.tests: re-ask an -Utf8 exit-code assert only while the lib reports ExitCodeUnknown

[PR #2383](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2383)

---

### DEPLOY: fix/2384-run-progress-fixed-clock · 20260923-180053Z

`run-progress.tests.ps1` asserted two exact elapsed strings (`+6m12s`, `+11m48s`) while taking the
record's start and the reader's "now" from two separate clock reads. On a loaded CI runner two
seconds passed between them, and one red suite turned the required `lint-en-tests` check red on a PR
that never touched run-progress
([#2384](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2384)). Both sections now read
one instant and hand it to `Get-LiveRunProgress -NowUtc`, a parameter the lib already had. Test-only.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

run-progress tests: pin the clock the elapsed asserts read

[PR #2386](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2386)

---

### DEPLOY: fix/2381-merge-on-green-ps51-parse · 20260923-174821Z

The merge-on-green sweep could never pick an armed pull request under Windows PowerShell 5.1, which
is what its runner uses. `ConvertFrom-Json` wrote the whole `gh pr list` array as one record with no
number, and the sweep skipped that record without saying so. Every run then reported "0 armed pull
request(s), none eligible yet" while PR #2345 sat armed and green. The list is now enumerated
through a tested lib function (`ConvertFrom-MergeOnGreenListJson`). A skipped record prints a line,
and "armed but nothing evaluated" is reported as the contradiction it is, not as a wait
([#2381](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2381)). The script travels in
`dkj-policy` and consumer runners fetch it at `ref: main`, so every adopted consumer's sweep starts
merging on its next run.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

merge-on-green: enumerate the armed list under PowerShell 5.1 and say why a record is skipped

Plugins: dkj-policy

[PR #2382](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2382)

---

### DEPLOY: docs/2368-asana-mirror-write-comment · 20260923-152143Z

`dkj-policy-bwj`'s `asana-mirror.yml` template and its `WORKFLOW-portable.md` step 5 said the
workflow's `issues: write` only ever edits labels. Since 5.5.0 it also posts one comment, the
paste-block backstop on a closed issue that has no paste-ready block yet. Both passages now name the two
writes ([#2368](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2368)). The permission
does not change. The failure this prevents has not happened yet: a reviewer who takes the old comment at
its word and narrows the scope to labels would break the backstop without noticing.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

asana-mirror: the issues: write rationale names both GitHub writes

Plugins: dkj-policy-bwj

[PR #2380](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2380)

---

### DEPLOY: docs/2360-asana-task-only-with-reach-label · 20260923-151130Z

`report-issue` created a colleague-facing Asana task for every issue it filed, although step 1 had just
decided whether a colleague would notice the finding at all. Now only an issue carrying the reach label
gets a card; a tier-0 issue stays GitHub-only, and the report says so, so the missing card reads as a
decision. A ticket that came from Asana keeps its card, and an issue that gains the label later is
mirrored at that moment. The rule is stated in `WORKFLOW-portable.md` section 2.

**Score:** 2

#### What makes this deploy extra special

A BWJ store's board stops receiving cards for developer-only findings after the next plugin update: four
such cards were open in `smartwatchbanden` on the day the rule was written, one of them for a
comment-only fix whose card forced its pull request to ship without resolving the issue. Colleagues see
fewer cards, and every card that remains is one they can check in a preview.

**Score:** 3

#### Pull Request

report-issue: only an issue carrying the reach label gets an Asana task

Plugins: dkj-policy-bwj

[PR #2377](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2377)

---

### DEPLOY: fix/2304-rerecord-durations-after-split · 20260923-145307Z

Re-recorded `scripts/tests/suite-durations.json` from three CI runs carrying the split
`check-plugin-integrity-*` layout (#2304). The file still named the pre-split suites, so the nine new
ones were charged the largest recorded value and the gate packed shards off guesses. The reading:
the pool is 7,260.5 s over 16 lanes, a work bound of 453.8 s, and no single file reaches it any more
-- `-entries` is heaviest at 426.1 s -- so CI is now bound by total work, not by one file. The splits
were not free: the `check-plugin-integrity-*` family went from 2,084.3 s to 2,679.0 s of pool work
(+594.7 s), because each file builds its own fixture. That is what the next step has to weigh, since
another split raises the work bound it is meant to get under.

**Score:** 1 -- prevents the gate packing CI shards off maximum-charged guesses for nine suites; no
reader notices it except as CI wall-clock.

#### What makes this deploy extra special

N/A -- data file only; nothing to migrate.

**Score:** N/A

#### Pull Request

Re-record CI suite durations after the check-plugin-integrity splits

[PR #2378](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/2378)

---

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

