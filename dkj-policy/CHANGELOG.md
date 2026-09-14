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
[`dkj-policy/CONTRIBUTING.md`](CONTRIBUTING.md).

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

**1 / 1 minor entry** <!-- pending-tally -->

### DEPLOY: fix/1985-bypass-in-printed-commands · 20260914-143406

Every command this repo prints for a person to run now carries `-ExecutionPolicy Bypass`, and a new gate
check keeps it that way. A fresh Windows profile sits at `Restricted`, which refuses every `.ps1`, so the
form 32 documents printed died with `running scripts is disabled on this system` before the script's first
line -- measured in this repo, where all five execution-policy scopes read `Undefined`
([#1985](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1985)).

**Nothing was ever red, and that is the part worth keeping.** Everywhere this tree controls the
invocation -- 8 hook entries, 7 CI workflows, every script-to-script call, the allowlist -- it already
passed `Bypass`. Only the lines a reader types were bare, and no gate executes those. So the session
start was green while the first command of the page it had just loaded could not run.

**Check 42 is narrowed to invocations that already carry `-NoProfile`**, and that is the rule rather
than a detail. Without it the check is born with 12 findings, every one correct prose naming the
invocation mode; with it, 85 subjects and zero exemptions. The value is deliberately not pinned --
`RemoteSigned` passes -- because the rule is that the policy be answered, not that a lint gate pick the
answer. Fences are not masked, unlike the other document checks: here the fenced block *is* the command.

**The `.ps1` layer is filed rather than swept**
([#1989](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1989)). The same rule over
comment-based help is born at 43
findings, which is a proposal to sweep and not a regression guard. Two sites there are repaired here
anyway because they are functional: `bootstrap.ps1` writes both an allowlist pattern and a stub hook
command into a **consumer's** `settings.json`, and a bare pattern stops matching the day the pages print
the other form.

**Score:** 3

#### What makes this deploy extra special

A consumer adopting these plugins on a Windows machine that has not been told otherwise can now paste
the commands off the pages and have them work. Before this, every printed command depended on an
`INSTALL.md` prerequisite no page named, and the failure arrived as a security exception with the
plugin's own script in it -- which reads as a broken plugin rather than as a machine setting. Nothing
to run on an existing machine: the change is in what the pages say and in what `specialists-init`
writes into a new consumer's allowlist.

**Score:** 2

#### Pull Request

Printed powershell commands carry -ExecutionPolicy Bypass

Plugins: dkj-policy, dkj-policy-bwj, dkj-subagents-alpha, dkj-subagents-shopify

[PR #1992](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1992)

---

