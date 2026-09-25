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

**0 / 10 patch entries** <!-- pending-tally -->

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

