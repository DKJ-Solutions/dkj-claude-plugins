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

**1 / 2 minor entries** <!-- pending-tally -->

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

