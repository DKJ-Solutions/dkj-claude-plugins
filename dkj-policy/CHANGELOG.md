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

**2 / 2 minor entries** <!-- pending-tally -->

### DEPLOY: fix/1972-compose-ruleset-call · 20260914-085815

`adopt-ci-floor.ps1` said in five places that it composes the exact `gh api` call for the ruleset it
refuses to apply, and composed none -- the only `gh api` line it ever printed was a read. The sentence
was load-bearing rather than decorative: `IT NEVER FLIPS THE SETTING, AND THAT IS A RULE RATHER THAN A
LIMITATION` rests on it, so refusing to write was proportionate *because* the reader was handed the call.
Without it the command refused to write and refused to say what to write, which is a weaker bargain than
the one its own docstring defends. Measured while working #1971: three sentences read, no call found, and
the payload reconstructed by reading another repo's live `main-ci-gate` through `gh api` and diffing it --
precisely the "went looking through the ruleset UI" failure that section exists to prevent.

The claim is now true where it carries the argument. The `[gap]` arm -- the one that fires when the trunk
has no required status check, which is #1971's own situation -- prints a paste-ready PowerShell block: a
here-string holding the ruleset JSON, piped into `gh api --method POST repos/<slug>/rulesets --input -`.
It targets `refs/heads/<trunk>` rather than `~DEFAULT_BRANCH`, because the trunk this run was told about
is the authority and need not be the default branch. Where exactly one job id exists across the workflows
that trigger on `pull_request`, that check is filled in; otherwise the placeholder stands and every
candidate is printed with the workflow it came from, so choosing is a copy from a list rather than a hunt.
It still never runs the call, and the strictly-additive, dry-run-by-default contract is untouched --
printing a command is not applying one.

**The merge-queue instruction deliberately stays a UI pointer, and the prose now says so.** That is not
the same rule said twice for two targets: the required-check payload has exactly one free choice, which
the tree can usually answer itself, while a `merge_queue` rule asserts seven scheduling parameters --
merge method, grouping strategy, three limits, two timeouts -- that are policy nobody here has chosen, on
a control GitHub does not even render outside the plans that may have one. All five citations were
reworded to name which instruction composes and why the other does not, including the one scaffolded into
every adopting consumer's `repo-settings.yml` header. **Two of the five were not in the report**: the lens
at `.claude/specialists/lenses/05-15-extension.md` carried the same claim, and separately the
`.SYNOPSIS` line carried a worse version of it -- it attributed the printed command to "a repo that has
CHOSEN a merge queue," which matched neither the old behaviour nor the new. Three from the issue plus
these two is five.

One thing the repair had to move out of the way: `$repoSlug` lived inside the `else` branch of the
rules-read block, so under `Set-StrictMode -Version Latest` it was undefined on the `-RulesJsonOverride`
path -- the path the suite takes and the one the printed call needs the slug on. It is hoisted; the `gh`
fallback stays inside the network-reading branch, because a run with an override file and no network has
no way to answer it and is owed a placeholder instead.

**The copy edit that followed found the claim had spread further than those five.** Four consumer-facing
pages attributed the composed call to the queue arm specifically -- the one arm that, after this branch,
composes nothing at all: the `adopt-dkj-policy` skill page, `CONTRIBUTING-portable.md`, the scripts
README's own table row, and this repo's own scaffolded `.github/workflows/repo-settings.yml`, which still
carried the sentence the `$repoSettingsRunner` template wrote before it was reworded here. Each is now
corrected to name the required-check arm as the one that composes and the queue as the one that stays a
UI pointer. **The real total this branch corrects is nine** -- the five citations above plus these four.

**Score:** 3

#### What makes this deploy extra special

A consumer adopting this workflow with no ruleset on their trunk is handed the call that creates one,
instead of a paragraph telling them a required check is what turns the staleness guard on. The same run
also stops telling them, in a comment it writes into their own repo, that a call it never composed is
waiting further down the file.

**Score:** 3

#### Pull Request

adopt-ci-floor composes the ruleset call its docstring promises

Plugins: dkj-policy

[PR #1975](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1975)

---

### DEPLOY: docs/1973-native-worktree-note · 20260914-082022

Adds an explicit "why not native worktrees" section to the `worktree-lane` skill, answering the
question issue #1973 asked directly from the skill a reader would already be looking at, instead of
only from a comment buried in the issue thread.

**Score:** 2 -- noticed only by a session or a person who goes looking for the reasoning; nothing
about how the skill runs changes.

#### What makes this deploy extra special

Consuming repos running `dkj-policy` get the same explanation inside their own copy of the skill
after the next release, so "why doesn't this use native worktrees" doesn't have to be re-asked (or
re-researched) per consumer.

**Score:** 1 -- cosmetic; no behavior changes for a consumer, only the explanation reaches them.

#### Pull Request

Document why worktree-lane skips native worktree placement

Plugins: dkj-policy

[PR #1974](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/1974)

---

