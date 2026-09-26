# BWJ ticket handling -- the portable rule

**This chapter applies in three repos, and the third is a narrower grant than the other two.**
`smartwatchbanden` and `xoxowildhearts` are named by store rather than by org, deliberately -- they are
not in the same organisation any more, `smartwatchbanden` moved to `BWJ-Development` on
September 7, 2026 and its `BWJ-ecommerce` predecessor is archived, with no redirect behind the old
name, so an org would be a fact with a shelf life rather than a scope. What has not changed is the
pair: one business (BWJ) running two Shopify stores that behave identically and differ only in brand,
so they handle a discovered issue the same way. This page is that way, written once so neither repo can
drift from the other.

**The third is `dkj-claude-plugins`, this plugin's own source repo, admitted for this chapter alone by
Dave on September 14, 2026 (commit `b9b2a65a`).** It is not a third store and gains nothing beyond
ticket handling: a finding surfaced there can now file through this chapter's GitHub-first,
Asana-mirrored procedure instead of a plain `gh issue create` against that repo's own tracker. The
other three chapters of this plugin -- [`SYNC-LOG-portable.md`](SYNC-LOG-portable.md),
[`PREVIEW-portable.md`](PREVIEW-portable.md) and
[`THEME-LIFECYCLE-portable.md`](THEME-LIFECYCLE-portable.md) -- are Shopify-store policy through and
through, and `dkj-claude-plugins` runs no store, so they stay at exactly the two names above; each says
so on its own opening line.

**Keep the two axes apart -- they read as one question and are not.** The org is left off the *store
pair's* name because an org can move out from under a repo while the repo itself does not; the *repo
count* differs by chapter because only this chapter's gate actually widened. `report-issue` and
`adopt-dkj-policy-bwj` both check the repo name against all three; this page is the reasoning their
guard enforces, not a second copy of the org-naming rule wearing a different number.

It is a layer on top of `dkj-policy`, not a replacement for it. It extends that
workflow's **ticket-work step -- the layer before the branch** -- and changes nothing else:
branch naming, what a change owes before a PR, and what a release is are still that workflow's
answers. Read this page after
[`dkj-policy`'s ticket-work section](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#ticket-work--the-layer-before-the-branch),
which this one sharpens rather than repeats.

**And "a layer on top" is a RANK, not a figure of speech.** Where a repo installs both plugins, this
page is the middle of three: the `dkj-policy` portable pages outrank it wherever the two
speak to the same question, and it in turn outranks the consuming repo's own always-on documents -- its
root `CLAUDE.md` and everything that document imports. It sharpens the ticket-work step; it does not get
to override `dkj-policy` itself.

**The order is stated once, over there, and this line only names which rung this page sits on.** The
binary choice a consumer actually makes is
[Precedence -- full adoption, or none](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#precedence--full-adoption-or-none);
the ranking worked out in detail, what it is scoped to, and the corollary that actually keeps it (a
consumer document may point at a shared law or answer a seam it names, but may not restate it) are in
[A third rank sits above both](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#a-third-rank-sits-above-both-and-nothing-named-it-until-inbound-1379).
Read both there rather than here: a second copy of a rank order is exactly the restatement that
corollary forbids.

**How to read this page.** It travels with the plugin, so a link that walks out of this plugin's own
folder is written as an absolute URL -- an installed plugin is read from its own cache directory,
where the repo tree around it does not exist. Measurements and issue numbers on this page are the
**source repo's** (claude-code-specialists); they are the evidence behind a rule, never your repo's
own record.

---

## The rule

### 1. GitHub first -- GitHub is the source of truth

A real issue found in a BWJ store repo -- a bug, a broken customer-facing behaviour, a stale or wrong
doc, a decision that is not yours to make -- is **filed on GitHub first**, in the repo it was found
in. Full technical detail; repo and code jargon are fine, because the reader is whoever picks the
work up.

**And it is written in English -- the title as much as the body** (Dave, September 11, 2026,
[#1875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1875)). Every consumer of
`dkj-policy` runs the same GitHub cycle, so an issue filed here is the workflow speaking and takes the
workflow's language -- the one the plugin's own pages, scripts and console output are already in. The
title carries it furthest: it is what shows up in every list, every `is:open` filter and every mirrored
card, so a Dutch title costs the search even when the body is bilingual. **The session-reply language is
untouched** -- a session answers Dave in Dutch and files in English in the same turn, exactly as it
writes English scripts while doing so.

Measured the day the rule was written: of the fifteen most recent issues in `smartwatchbanden`, three
carried Dutch titles (`559`, `554`, `547`), filed by sessions doing everything else on this page right,
in a repo where nothing had ever said the tracker was in scope. **They are not retitled by this rule.**
An issue is a record of what was reported and when; rewriting the backlog buys a tidy list and loses
that, and the rule is about what gets filed from here on. The rule itself is not this page's: it is
stated for every consumer of the workflow in
[`dkj-policy`'s step 1](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#1-new-issue-or-task--where-the-work-comes-from),
which requires one answer per repo and leaves the answer to the repo. **BWJ's answer is English**, and
that is what this section records.

The `dkj-subagents-alpha` orchestrator's filing bar applies **unchanged** -- this rule adds *where the issue
is mirrored*, it does not loosen *when or whether it is filed*:

- The question to answer first is *does it still stand?*, not *may I file it?* -- read the code, the
  script or the output that would have to be true for the finding to hold, and if it collapses, say
  so instead of filing a weakened version.
- Search the tracker first, so you add to an existing thread rather than open its duplicate.
- One subject per issue.
- Say what you **measured** and what you only **inferred**.
- Filing needs no permission, and asking for it is the same failure as not filing.

#### Classify it as you file it -- three fields, all set at creation

An issue that arrives typeless and unlabelled has to be classified by hand afterwards, and afterwards
never comes. Both BWJ trackers were brought to 100% type coverage by hand on September 1, 2026 -- 135
issues across the two -- and that state holds only if every filing from here on maintains it.

| field | what it carries | how |
|---|---|---|
| **issue type** | Bug / Feature / Task | `gh api --method PATCH repos/<owner>/<repo>/issues/<n> -f type=Bug`, straight after the create -- not `gh issue create --type`, which `gh 2.74.0` rejects as an unknown flag ([#2416](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2416)). A defect in behaviour that already exists is **Bug**, a capability the store does not have yet is **Feature**, and **Task** is everything else, which is most of it |
| **the reach label** | how far the issue reaches | one `--label`, and only where it reaches the audience tier. Absence is the answer for tier 0 and is not a missing field. Its **name** is `Get-ReachLabel`'s, default `minor` -- see below |
| **`documentation` label** | the one content distinction the type system cannot express here | `--label documentation` on a doc finding, on top of whatever type it has |
| **`CRO` label** | who raised it, not what it is -- store repos only | `--label CRO` on an issue filed by, or on behalf of, the CRO team (today: Johnno), on top of whatever type it has -- see below |

**The type is set directly, not derived from a label.** `bug` and `enhancement` were deleted from both
repos on September 1, 2026, because the type already carried them: all 28 `bug` issues held type `Bug`
and all 16 `enhancement` issues held `Feature`. Nothing was lost with them, and they are not re-added.

**`documentation` was deliberately kept** (Dave). Both BWJ orgs have exactly three issue types and none
of them is Documentation -- measured September 7, 2026: `gh api orgs/<org>/issue-types` returns Task,
Bug and Feature in `BWJ-ecommerce` and in `BWJ-Development` alike, so the store that moved took the
same three with it -- and the 42 doc issues sit on `Task` and `Feature`. Deleting the label
would have buried them in a 91-issue `Task` pile -- that is not *covered by the type*, that is lost. A
`Documentation` type was considered and not taken: issue types are **org-wide**, so adding one would put
it in every BWJ repo, which is a wider decision than these two.

#### The reach label -- the reach axis, carried onto issues

**The axis is not BWJ's own and is defined one layer up**, in
[`RELEASES-portable.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/RELEASES-portable.md#the-same-scale-on-an-issue--the-reach-label):
it is the tier model read on an issue instead of on a changelog entry, and every repo running this
workflow carries it ([#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870), Dave,
September 11, 2026). Read it there for what the label means, the test that decides it -- *does the reader
notice the **defect***, not whether the file renders to them -- why doubt resolves to tier 0, and why an
entry scores every tier while an issue labels only the exception. What is BWJ's is the rest of this
section.

**Both BWJ repos answer `Get-ReleaseAudienceTier = 1`**, so here:

- **the reach label present** -- management and the commissioner notice it.
- **the reach label absent** -- tier 0: only this repo's developers notice.

Tier 2 does not exist in these repos, so one label carries the whole axis and
`is:open label:<reach label>` is the business-facing worklist.

**The two stores do not currently spell it the same way, and that is what the seam is for.**
`smartwatchbanden` renamed it from `tier-1` to `minor` on September 11, 2026
([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)) -- GitHub's rename kept it on
all 24 issues that carried it -- and `minor` has since become this workflow's own default, because it
names what the landing does to the release rather than a tier number. `xoxowildhearts` still carries
`tier-1`, and either renames the label or answers `Get-ReachLabel` with that word; both are correct and
leaving it at neither is not. So **read `Get-ReachLabel` from your own `scripts/repo-config.ps1`, never a
literal**: `gh issue create` fails outright on a label the repo does not have, so a typed default gets you
an error instead of an issue.

#### The CRO label -- who reported it, not what it is

**A fourth, independent axis: not what the issue is, but who raised it.** `--label CRO` marks an issue
filed by, or on behalf of, the CRO team -- today that is Johnno. It is written from judgement at the
moment of filing, exactly like `documentation` and the reach label above: there is no automatic
detection from a GitHub account, and none is planned -- a session files every issue itself, so
`created_by` would read identically whether a CRO finding or anybody else's went through it, the same
trap `SubmitterPattern` elsewhere in this page warns against for a different field.

**This label exists ONLY in a repo that is an actual Shopify store**, because a CRO team measures
conversion on a live storefront and this plugin's own source repo, `dkj-claude-plugins`, has none --
admitted as a [`report-issue`](skills/report-issue/SKILL.md) target for the ticket-handling chapter
alone, not for this axis. Concretely:

- `smartwatchbanden` and `xoxowildhearts` -- create it, and set it where it applies.
- `dkj-claude-plugins` -- never create it, and never set it. A finding filed here has no CRO team
  behind it to attribute, whatever else the ticket-handling chapter permits there.

**It carries no seam and needs none** -- the same shape `Get-ReachLabel`'s own paragraph reasons from:
nobody has renamed this label, and which repos it applies to is a fixed list of two, stated here rather
than read from a function nothing else needs. [`adopt-dkj-policy-bwj`](skills/adopt-dkj-policy-bwj/SKILL.md)'s
labelling step creates it only where the repo is one of those two.

**It triggers nothing on its own, and it used to.** Until inbound
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049) this label was what
turned on the paste-ready block at the close. That block is now gated on the **Asana link** instead --
a mirrored task is a mirrored task -- and it is written before the close rather than at it. See
[step 4 below](#the-paste-ready-block----written-before-the-close-by-the-session-that-shipped-the-work).
This label is purely a filing axis again: who raised it, and nothing else.

### 2. Then Asana -- a translation, not a copy

**Only an issue carrying the reach label gets an Asana task** (Dave, September 23, 2026,
[#2360](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2360)). The board is where a colleague
follows work they can look at themselves, and the reach label is already the answer to whether they will
-- so the two are one decision, made once, in step 1. An issue without it is tier 0: GitHub-only, with no
card, and that absence is the answer rather than a mirror that failed. Measured the day the rule was
written, in `smartwatchbanden`: four open issues carried a card and no reach label, one of them a
comment-only fix whose own body said *developer-only; no customer impact*. Its card sat in `Filed`, and
the card then forced the pull request that fixed it to ship with `-NoResolves`. **Two cases are not new cards and the rule leaves them alone:** a
ticket that arrived from Asana already has one (section 8), and an issue that gains the label later is
mirrored at that moment.

**A hook holds this, because the sentence alone did not** (inbound
[#2482](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2482)). Two days after #2360,
`smartwatchbanden#770` got a card with only `documentation` on it, on the plugin version that carried the
rule. `hooks/guard-asana-mirror.ps1` now refuses any Asana create-task call whose task cites a GitHub
issue without the reach label. Where it cannot read the labels, it lets the call through with a warning.
The mechanics are in step 2 of [`report-issue`](skills/report-issue/SKILL.md).

Once the GitHub issue exists and carries the reach label, mirror it to Asana in the project
`Get-AsanaProjectGid` names. The Asana task is **not** a paste of the issue body. It is written for
a BWJ colleague who does not read code and does not know the repo:

- **Plain language, outcome-framed.** What a customer or colleague actually experiences, not what the
  code does.
- **No jargon** -- no file paths, no function names, no branch names, no GitHub label vocabulary.
- **A fixed skeleton**, so every mirrored task reads the same way:

  ```text
  What is wrong:   <one or two plain sentences -- what a visitor or colleague sees>
  Where:           <which store, and which page or flow>
  How urgent:      <blocking a sale / visible but not blocking / cosmetic / not customer-facing>
  Tracked on GitHub: <issue URL>
  ```

- The task's assignee, section and due date are for the BWJ team to set in Asana. This page does not
  prescribe them.

The colleague-facing wording is Claude's to draft; a colleague may refine it in Asana afterwards
**without touching GitHub**. GitHub stays leading -- if the two ever disagree on substance, the
GitHub issue is right and the Asana task is corrected to match.

**This is where the language turns over, and it is the ONLY place in this procedure that it does.**
The skeleton's four headings stay as written above -- they are the form, which is why the CI mirror's
own comments are English too -- while what you write under them is addressed to a colleague and
follows **that colleague**, not the repo. So one finding legitimately reads English on GitHub and the
colleague's own language on the board: that is the translation this step is named for, and not drift
between the two.

**And a ticket a person filed in Asana themselves is theirs entirely** (Dave, September 11, 2026,
[#1875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1875)) -- the one carve-out the
English rule in step 1 makes. Quote it into the issue as it was written rather than translating it,
because the wording is the evidence of what was actually reported, and write your own analysis around
it in English. Nobody corrects the language of a card a colleague wrote, in either direction.

**A board may also carry a `Github Issue` text custom field** -- that capitalization is the field's
literal, as-configured name in Asana, not a typo -- **and where it does, task creation is
where it gets set.** It is optional -- most Asana projects have no such field, and a repo whose
board carries none loses nothing by skipping it. Where it exists, it holds the **full issue URL,
`https://...`, never the bare issue number** (Dave, September 4, 2026): Asana only renders a text
custom field as a clickable link when its value is a complete URL, and a text field is the only type
on offer here -- Asana has no native URL field type
([source](https://forum.asana.com/t/new-you-can-now-use-links-in-custom-fields/24757)). The value is
the same URL already sitting in the `Tracked on GitHub:` line above, written once more into the field
so the board's own list and filter views can jump straight to the issue without opening the card
first.

**And a board may carry a `Github Type` select field beside it** -- again the field's literal,
as-configured name -- **whose options are exactly the three issue types
[step 1](#classify-it-as-you-file-it----three-fields-all-set-at-creation) chooses from**: `Bug`,
`Feature`, `Task`. Where it exists it is set on the same creation call, **from the value step 1
already decided**, never re-derived from the card. That is what makes it worth writing rather than
leaving to a colleague: the answer is not being composed here the way the issue URL is, it is being
carried one step forward -- so a ticket this workflow files cannot have a board type its own issue
contradicts.

**A card filled in by hand can, and on the BWJ board it did.** Measured September 4, 2026, while
nothing had ever written the field: of 23 cards, **5** carried a type the GitHub issue contradicted,
and in both directions -- `334` read `Task` against a **Bug** and `333` `Task` against a **Feature**,
while `478`, `479` and `480` read `Feature` against a `Task`. That is not a drift rate for this
procedure, because the procedure had never run; it is what a hand-fill costs, and it is the reason
the value is carried forward instead of re-typed. A hand-copied enum that has drifted is worse than
an empty one -- an empty field says *unknown*, a wrong one says *this* -- and the board reads as
authoritative to the colleague looking at it. GitHub stays leading here as everywhere above: the
card is corrected to match the issue, never the issue to match the card.

#### A comment an agent writes on a task says so in its FIRST line

**No agent writes a comment on an Asana task unless its very first line says it is an automated
message** (Dave, September 25, 2026, inbound
[#2476](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2476)). Asana shows a comment as
written by the account that posted it, and neither writer below posts under an account of its own: a
session writes through the Asana MCP as the person who connected it, and the CI mirror writes with
`ASANA_PAT`, which also belongs to a person. So a comment without that line reads to a colleague as
that person's own words, and they did not write it. Measured in `BWJ-Development/smartwatchbanden` the
day the rule was written: a session running `report-issue` on an existing ticket posted a
colleague-facing comment, and the story's author read as the owner's own name with nothing in the
text to say otherwise.

- **A session** writes the line in the colleague's language, [as everything addressed to them
  is](#2-then-asana----a-translation-not-a-copy), and it names both facts: automated, and not written
  by the account holder personally. For example, *"🤖 Automatische reactie (Claude) -- niet
  persoonlijk geschreven door Dave."* The content comes after it and never before.
- **The CI mirror** opens every update with `Get-MirrorCommentHeader`, above the marker sentence
  step 4's de-duplication reads. The header sits above the marker and does not replace it, so updates
  written before the header existed still de-duplicate.

**Write the line BEFORE you post, because you cannot add it afterwards.** The Asana MCP exposes adding
a comment but no tool to edit or delete one, although the API itself supports both. So a comment a
session posts without the line stays that way. **A block a person pastes by hand** (step 4's
paste-ready block, the `needs-info` question) is that person's own message once they post it, and it
takes no header: the rule covers what an agent writes, not what a person chooses to send.

#### A task is read before it is offered for deletion, and a task a person has worked is never deleted

**No agent offers or performs a delete on an Asana task until it has read that task's state on the
Asana side** (inbound [#2508](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2508)). The
GitHub side says whether a card *should* exist. It says nothing about what has happened to the card
since, and that is what a delete destroys. The read covers four things: whether the task is
`completed`, whether it carries comments a person wrote, which projects it is multi-homed in, and who
created it.

- **A task that is completed, or carries a human comment, is not offered for deletion at all.** It is
  the colleague's record of a request and what became of it, and a card that should not have existed
  is repaired by **unlinking** it: remove the `Asana:` line and the `asana-task` marker from the
  GitHub issue (step 3) and leave the task where it is. The same goes for a task a colleague created
  rather than the account the session or the mirror writes through, and for one that also sits in a
  project other than the board.
- **Any other task can be offered, and the offer shows the state it was read with.** Each option
  names the task's state (open, no comments, the board only, created by whom) beside its title. A
  question built from the issue's labels alone asks the owner to judge a card they cannot see.

**Deleting is irreversible from the agent's side, and the answer is only as good as the question.**
Measured in `smartwatchbanden` on September 23, 2026, while a session was tidying up after #2360: it
asked the owner which cards *"of issues without the minor label"* it could delete, then deleted three.
One had been completed by the owner, with a comment, as the record of a colleague's request. Its option
read only *"technical research into content_for_header placement, no label"*. The owner answered the
question as it was put. Nobody noticed for two days, until the task could not be found.

### 3. Cross-link both ways

The link is stored on both sides, and one half is machine-readable because the automation in step 4
matches on it:

- **On the GitHub issue** -- appended to the issue body:

  ```text
  Asana: <task URL>
  <!-- asana-task: <numeric task GID> -->
  ```

  The HTML-comment marker holds the bare numeric GID and nothing else, and it is what the CI workflow
  matches on **first and unconditionally**. Write it whenever you create the task yourself: it is the
  only form that cannot be misread, and an issue carrying one is never matched any other way.

- **On the Asana task** -- the `Tracked on GitHub:` line of the skeleton already carries the issue
  URL. Nothing else is required there.

### 4. Write the paste-ready block, THEN close the GitHub issue -> the Asana task gets an update

**Closing the GitHub issue is the signal that the work is BUILT, not that the ticket is DONE.** A
GitHub Actions workflow in the repo (`.github/workflows/asana-mirror.yml`, copied from this plugin's
`templates/`) carries that news across:

| GitHub event | what happens in Asana |
|---|---|
| issue **closed** | a comment on the linked task: the work is built and ready to test, with the issue URL **and the pull request that closed it** -- number, title and link. The task stays open |
| issue **closed as not planned** | the opposite comment: nothing was built, so there is nothing to test, and the reason is on the issue |
| issue **reopened** | a comment pointing to the issue for why -- it may be back with the requester, or it may have been picked up again -- and saying this is not a request to test |
| daily schedule | a reconciliation sweep in **both** directions, for events that never arrived: open tasks in the mirror project whose GitHub issue is closed, and issues closed in the last 30 days whose task has not been told yet |

**A reopen carries at least two opposite meanings, the event cannot tell them apart, and so the
comment asserts neither.** Either the work has been picked up again, or the issue is going back to
the requester because what was built was reverted or was never this workflow's to begin with -- and
in the second case a comment guessing "it is being worked on again, so hold off on testing" tells the
person who has to act to sit still. So the comment names both possibilities, points to the issue for
which one applies, and says plainly that it is not a request to test. That is the failure inbound
#2117 measured, 2026-09-18: on three real Asana cards the guessed line contradicted the true state
and outranked a colleague's own correction posted underneath it, because it carried the system's
authority.

**The task is never completed by any of this, and the script has no code path that can do it**
(Dave, September 1, 2026). Closing a GitHub issue is a statement by whoever built the thing; resolving
the ticket is a statement by whoever asked for it, and only that person can make it -- after they have
tested it. An automation that ticks the box takes the one decision the ticket exists to record and
replaces it with a guess, and it does so silently, so nobody can tell an accepted change from an
unverified one afterwards.

This is the shape after a measured mistake, and the mistake is worth the sentence: on
September 1, 2026 the sweep that had just learned to read imported tickets completed **six** Asana
tasks it should only have commented on -- five of them belonging to colleagues who had never been
asked whether the work was any good.

**The update names WHERE the change was made** (Dave, September 1, 2026), because that is the first
thing somebody about to test wants and the ticket is the only place they are looking. GitHub says it
as *"closed this as completed in #434"*; the update says the same, with the pull request's number,
title and URL. It comes from the GraphQL field built for that question
(`closedByPullRequestsReferences`) rather than from the timeline, where a merge commit, a manual
close and a passing cross-reference are easy to confuse. **An issue closed by hand says so**, and one
GitHub cannot be asked about still gets its update with no pull request named -- an invented
reference would be worse than a missing one.

**The de-duplication is the update's own opening sentence**, `GitHub issue <repo>#<n> is closed`, which
names the issue. Sweeps look for it and stay silent when it is already there; **an event never
de-duplicates**, because a close after a reopen is news again. A task somebody has already ticked off
is left alone by both.

**Which task an issue belongs to is answered by three matchers, tried in order** -- 'tier' is the reach
label above and means nothing here -- because a repo has two kinds of issue and only one of them was ever
written by this workflow:

1. **the marker** -- `<!-- asana-task: <gid> -->`, written in step 3 above. Authoritative.
2. **the header row** -- a `| **Asana** | ... |` row carrying a task URL. This is the shape of a
   ticket **imported from Asana**: a colleague filed it there, somebody copied it into an issue for
   analysis, and the link in its header was written for a reader rather than for a machine.
3. **a sole task URL** anywhere else in the body.

**The header-row matcher exists because of what the marker alone could not reach.** In
`BWJ-ecommerce/smartwatchbanden`,
[#388](https://github.com/BWJ-ecommerce/smartwatchbanden/issues/388) was closed on 2026-09-01 and its
Asana task stayed open; the workflow had run, and its log said why -- *"No `<!-- asana-task: ... -->`
marker ... nothing to mirror"*. Measured across that repo the same day: of 55 issues, **4** carried a
marker and **11** carried an Asana link in a header row only, **6** of those already closed. The
mirror was working exactly as written, and reached 4 of the 15 issues that carry an Asana link at all.

**More than one different task, and no marker, resolves to nothing** -- the workflow names the
candidates in its log and moves on. It never guesses which ticket an issue belongs to, and the way to
settle it is to add a marker.

#### The paste-ready block -- written BEFORE the close, by the session that shipped the work

**The order is the rule** (BWJ/Maikel, September 17, 2026, inbound
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049)). An issue with a linked Asana
task carries a paragraph ready to paste into that task, telling the requester (today: Johnno) where to
see the result -- and that paragraph goes on the issue **while it is still open**, written by the
session that shipped the work, as the closing act of its own chain. **Closing the issue is then the
confirmation that the block reached Asana**, and it is a person's act rather than a script's.

**Read "the block reached Asana" narrowly -- it is not the `ReadyToTest` handover further down this
page.** Two different moments tell two different people something: this one is a paragraph a person
carries into the task by hand, and `Get-SubmitterHandoff`'s is the submitter being told their card has
moved. They sit in the same pipeline, so this page never says "the handover" bare for either.

It is one comment on the **GitHub** issue -- not on Asana. The marker and the framing sentence above
the rules are fixed, because the backstop below has to be able to recognise the comment. The block
between the rules has a fixed **shape** too, and it is written in the **colleague's language**:

```text
<!-- asana-paste-block -->

Paste the block into the Asana task, so the requester knows where to look and when it lands:

---
— automatisch bericht vanuit GitHub #<n>

WAT ER NU ANDERS IS

<what changed, in plain language -- the session's prose>

TE BEKIJKEN OP

Het resultaat is hier te bekijken: <the actual link>

<where exactly to look, and how -- the session's prose>

WANNEER HET LIVE KOMT

Het staat gepland voor de release van <weekday> <date>, als versie <vX.Y.Z>.

Tot die tijd laten deze links zien wat er nu live staat, om mee te vergelijken — en zodra het live is, zie je de wijziging hier:

<market> — <live url, pinned to the live theme id>

WAT ER BEWUST NIET IN ZIT

<what was deliberately left out, and why -- the session's prose>

WAT WE VAN JE VRAGEN

Bekijk het resultaat zelf, via de link hierboven. Het gaat hoe dan ook mee met die release, dus dit is het laatste moment waarop er nog iets aan te passen valt voordat een klant het ziet.

Klopt het: laat het weten en vink deze taak af.

Klopt het niet, dan horen we graag twee dingen: wat er niet goed is, én wat er precies anders moet. Dan pakken we het opnieuw op in een volgende ronde.
---
```

**The shape is BWJ's own, and so is the language** (inbound
[#2507](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2507)). The block is the corrected
one BWJ sent a colleague on September 18, 2026 (the one the five rules below were learned from). It is
Dutch because it is addressed to the colleague, and [step 2](#2-then-asana----a-translation-not-a-copy)
turns the language over at exactly that boundary. Until #2507 the script wrote it in a fixed,
unsectioned English. On `BWJ-Development/smartwatchbanden#769` (September 25, 2026) the owner rejected
that printout, pointing at the reference block, and the block was rewritten by hand. **For a task
written in English the same shape comes out in English** (`-Language en`). The framing sentence above
the rules stays English in both cases, because it is read on GitHub.

**The facts are the script's, and the prose is the session's.** The link, the date, the version, the
live URLs and the ask are derived or fixed. *What changed*, *where exactly to look* and *what was
deliberately left out* are judgements about the work, like the task body step 2 writes, so the
session writes them and hands them over through `-ProseFile`. A section with nothing in it is left
out, heading and all, and is never replaced by a placeholder.

**The marker sits OUTSIDE the block, and the block is what gets pasted.** Everything between the two
`---` rules travels to Asana; the marker and the framing sentence stay on GitHub. A marker inside the
block would arrive in the Asana task as visible junk. The backstop's de-duplication matches the marker
and nothing inside the rules, which is what leaves the block's words free to follow the colleague.

**Who carries it across is the Asana task's ASSIGNEE** (BWJ, September 23, 2026, inbound
[#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352)). The assignee is the one in
conversation with the requester, so they paste the block into the task and then close the GitHub
issue. It is not a fixed relayer: a page naming one person as the relayer for every ticket was
corrected on exactly that point the day it was retired.

#### What the block asks of the requester -- and the two closes it separates

**Five rules, from BWJ's corrections to the first blocks that actually reached Asana** (Maikel,
September 18, 2026), carried here on inbound #2352 once the consumer page holding them was retired.
`build-golive-block.ps1` writes the section that implements the middle three; the other two are about
the block's position and the issue.

1. **The first line says where the message comes from.** The block opens by naming it an automated
   message and naming the issue -- *"— automatisch bericht vanuit GitHub #`<n>`"* -- so a reader knows
   from line one that there is an issue behind it, rather than finding out at the foot after reading
   it as hand-written.
2. **The requester judges the result themselves, and their answer closes the TASK.** Not the gates, not
   the merge and not the session that built it: no gate proves that something *looks* right, which is
   the same reason a visible result stops before its pull request. So the block asks for the look
   instead of assuming it.
3. **A rejection asks for two things, and starts a new round.** *What* is not right yet **and** *what*
   exactly should change -- the first alone hands the next round another guess. The issue is then
   reopened and the cycle starts again with a new result to look at.
4. **The issue and the task close at different moments.** The issue carries the development work, which
   is finished once the block is on the task; the task carries the colleague's question, which stays
   open until they have answered it. Holding the issue open until then ties the tracker to the calendar
   of somebody who does not work in it, and the difference between *"work is left here"* and *"somebody
   is waiting on a colleague"* disappears.
5. **The release is not a reward for an approval, and the block must not read as one.** The work is
   already on the trunk, so it ships with the next release either way. What the look buys is **time**:
   it is the last moment a change can still be made before a customer sees it. Written as a condition
   (*"is it right? then it goes into the release"*) it holds out a key the reader does not have.

**Without a result link the section is not written**, for the reason the missing link sentence is not
written: there is nothing to look at before the release, and an ask to judge a result the block cannot
point at is noise.

**Three things made the old order unworkable, and the third could not be fixed inside it:**

1. **Nobody returns to a closed issue.** A comment posted at the close appears underneath an item that
   has just left every open-issue view, so whether it ever reaches Asana depends on somebody going back.
2. **There was no backstop.** A missed event was a comment that never posted, and nothing detected it
   afterwards.
3. **The link could not be filled in.** `New-AsanaPasteBlockComment` writes `[ADD LINK]` and is right to
   -- "where the result can be viewed" depends on what the ticket was about, and nothing the workflow
   reads says that reliably. **The session that built the thing does know it**: its preview URL, or the
   live page after a push. Moving the composition to that session removes the placeholder instead of
   working around it.

**It is gated on the Asana link, not on the `CRO` label.** A mirrored task is a mirrored task, so the
reach is the same three matchers this step already defines for *which* task an issue belongs to. The
`CRO` gate was narrower than the need -- measured in `BWJ-Development/smartwatchbanden`,
September 17, 2026: of 14 open issues, **13** carried an Asana link and **6** carried `CRO`.

**How this interacts with `dkj-policy`'s resolves gate, which is the half a consumer cannot infer.**
`open-pr.ps1 -Resolves` writes `Closes #<n>` into the pull request body, so GitHub closes the issue at
the **merge** -- before anybody has written a block, and with nobody's confirmation. So an Asana-linked
issue ships with **`-NoResolves`** and cites the issue as context, and the task's assignee closes it by
hand once the block is on it. A third flag that declares the citation deliberately without a closing keyword is named
in #2049 as a larger change and is not assumed here.

**And since inbound
[#2120](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2120) the gate can be TOLD, so the rule
is no longer carried by memory alone.** `open-pr`'s resolves gate reads the optional
`Get-ResolvesExemptMatchers` seam in the repo's own `scripts/repo-config.ps1`, fetches the body of every
issue the merge would close, and REFUSES `-Resolves` on one that matches -- naming `-NoResolves` as the
way through. `adopt-dkj-policy-bwj`'s step 2 proposes the two matchers, keyed on the same marker and
task-link shapes this page already defines above, so a repo that has run that step is enforced rather than
reminded. **A repo that has NOT stated the seam is exactly where this paragraph left it before #2120**: the
rule stands, nothing reads it, and the difference between a correct ship and a wrong one is whether the
session remembered. The measurement behind that sentence is one of each, days apart, in the same repo.

##### The go-live half -- the three facts the requester asks for next

**The block used to answer *where*, and stop there** (Dave, September 18, 2026,
[#2100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2100)). The requester's next
question is always *and when do I actually see it?*, and the ticket is the only place they are looking,
so the block carries three more facts. It is one of the two steps this plugin adds to `dkj-policy`'s
cycle -- the other is the storefront-visibility step in
[`PREVIEW-portable.md`](PREVIEW-portable.md) -- and both are indexed in
[the README](README.md#what-the-cycle-gains-here).

| fact | where it comes from |
|---|---|
| **when it goes live** | the next release day. BWJ cuts on **Mondays**, so it is the next Monday -- strictly the next one, never today, because a Monday's release is cut before the day's work closes |
| **which version** | the newest `vX.Y.Z` tag, bumped by what the pending changelog has earned -- patch where everything pending is tier 0, minor where anything reaches further |
| **where to look once it is live** | the **live** storefront URL per market for the pages the change touched: the same URLs a preview pair is built from, **pinned to the live theme id** wherever the store names it -- the control half of that pair -- so the same link is a comparison before the release and the live page after it ([#2477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2477)). A bare URL renders the preview in any browser that opened the result link first, so where no live id resolves the list stays bare and its label says to open it in a private window before the release |

**It is written by a script, because all three are derivable and none of them is a judgement** --
[`build-golive-block.ps1`](skills/golive-block/SKILL.md), which prints the block and, with `-Post`,
puts it on the issue. That is the difference from the link in the first line, which stays a person's
answer for the reason the backstop below gives.

**Both halves of the release fact are a PLAN, and the block says so in that word.** *"Het staat
gepland voor de release van maandag 22 september, als versie v1.4.0"* is a cadence and a projection,
not a commitment anybody made: a tier-1 entry landing on the Friday turns that patch into a minor, and a
release can slip. Writing it as *will* would hand a colleague a promise this workflow never made, on
the one surface they will quote back.

**Where a fact cannot be derived it is left out, never guessed.** No `v*` tag, or a changelog whose
pending tally cannot be read, means the version line names no number; a repo that has declared no
storefront markets gets no live-URL list. The whole reason the link in the first line is a person's to
fill in is that a plausible wrong answer is worse than a missing one, and that reasoning does not stop
applying one paragraph further down.

**The script does not touch Asana, and that is the rule above rather than a gap.** It writes the
GitHub half; a person carries the block into the task, and closing the issue is their confirmation that
it landed there. An automation posting into the ticket would take back exactly the decision this
chapter keeps with the person who asked for the work.

**It carries the marker, and only the marker.** The framing sentence is no longer the backstop's own
`Get-AsanaPasteBlockLead` -- `Fill in the link below and paste the block into the Asana task` is
false once the links are filled in -- so the de-duplication rides on `<!-- asana-paste-block -->`,
which is the matcher tried first and unconditionally. That lead sentence stays exactly what it always
was -- the backstop's own wording, and the second matcher -- and it is quoted in full one line up for
the reason this page quotes both strings at all: so a block can be written by hand.

##### The backstop: `asana-mirror` still writes one, only where the session did not

Where an Asana-linked issue closes and **no block is on it**, `asana-mirror` posts one -- with
`[ADD LINK]`, because CI genuinely cannot know the link. It is the safety net under the rule above and
not the route to it.

**It writes the same block as the session, cut down to what CI can know** (#2513). Between the rules
it carries the opening line and the `TE BEKIJKEN OP` section with `Het resultaat is hier te bekijken:
[ADD LINK]`, in the same Dutch words, because the block is addressed to the colleague. It writes
nothing else. The other sections hold the session's prose, or facts this standalone template does not
derive, and a section with nothing to say is left out rather than filled with a placeholder. The
template ships without the plugin's libs, so it holds a copy of those words. The plugin's suite keeps
that copy equal to `Get-GoLiveBlockText`.

**It de-duplicates on the block's own marker, and on its lead sentence for one somebody typed by
hand** -- the same two-matcher shape, in the same order, as the task link itself: the machine marker
first and unconditionally, prose second. So a session that did its job never sees a second,
placeholder-only copy appear under its own.

**Either matcher anywhere in any comment counts, so anybody who can comment can switch the backstop
off** -- including by quoting this page, which publishes both strings verbatim so the block can be
written by hand. That is accepted rather than tightened. What is suppressed is an informational
paragraph, in the case where the shipping session had already skipped its own step, so the worst
outcome is the state this workflow was in before #2049; and no exact-match rule survives a person who
can equally well delete the real block.

**An issue whose comments cannot be read gets nothing**, and the run says so. The costs are not
symmetrical: a missed backstop leaves a closed issue without a paragraph nobody was going to read there
anyway, while a blind post puts a placeholder-only copy underneath a block that was already filled in
correctly.

**It runs on the `closed` event only, and the accepted gap is unchanged.** The de-duplication would now
make a sweep safe, and it is still deliberately not swept: a sweep walks every Asana-linked issue closed
in the last 30 days, so its first run would post a placeholder-only block on every one of them that predates
this rule -- a burst of comments on a colleague's tracker, each asking somebody to go back to a closed
issue, which is exactly what #2049 measured as not working. A close that happens while the workflow
cannot run is therefore still a block that never posts, the same accepted gap this page already carries
for a dropped `reopened` event.

### 5. The Asana prio score comes back as a GitHub label

Everything above moves GitHub -> Asana. This one step goes the other way, and it is the only one that
does. The BWJ team scores a task on the board's **`Prio-Score`** number field, 1.00 to 5.00; the
reconcile run reads that score and puts the matching label on the GitHub issue:

| Prio-Score | GitHub label |
|---|---|
| 4.00 - 5.00 | `prio-4` |
| 3.00 - 3.99 | `prio-3` |
| 2.00 - 2.99 | `prio-2` |
| 1.00 - 1.99 | `prio-1` |

Dave's mapping, September 2, 2026. **Four buckets and deliberately no `medium`**, and each boundary is
closed at the bottom and open at the top, so a field with two decimals can never land between two of
them.

**Exactly one prio label sits on an issue at a time.** The sweep removes the other three as it sets
one, so a ticket rescored from 2.5 to 4.2 loses `prio-2` as it gains `prio-4` rather than claiming two
priorities at once. Where the issue already reads correctly nothing is written, so a daily re-run is
quiet.

**ONE VOCABULARY ACROSS THE WHOLE FAMILY, AND THE NAMES SAY NOTHING ABOUT WHICH MOTOR SET THE RUNG**
(Dave, September 11, 2026,
[#1842](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1842)). The source repo's own
tracker ranks its issues on these same four, `prio-1` lowest to `prio-4` highest -- a judgement typed
by whoever files, because there is no Asana behind it to derive one from. The two motors are still two
motors: **here the rung is derived from a score and is never typed**, and a task nobody has scored
carries no label at all.

**What tells them apart now is the label's DESCRIPTION, not its name**, and that is the half worth
knowing before reading a badge. A BWJ repo's `prio-4` reads `Asana Prio-Score 4.00-5.00`; the source
repo's reads `Priority 4 of 4 (highest)`. Keep the score-shaped wording when creating or renaming
these labels -- it survives a rename untouched, and it is the only remaining signal at the one place
somebody looks when the name has stopped distinguishing.

**This reverses half 1 of
[#1686](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1686)**, decided two days
earlier, which held the two sets deliberately disjoint so that a session moving between the families
got a refused label rather than an issue filed at a rung meaning something else. Two of that
decision's three grounds are untouched and still correct -- the BWJ names are code rather than
convention, and the collision could never mis-file anything. The third, *"the names are the only
signal of which motor owns the rung"*, is the one Dave overrode, and the paragraph above is what
replaces it rather than drops it. **Half 2 of #1686 is NOT reopened**: nothing in the portable
workflow reads a priority, `adopt-dkj-policy` still owes no label-creation step, and the rule that
every issue carries a rung remains deliberately NOT part of this workflow.

**Migrating a repo adopted before that day is one command per label**, and the direction matters more
than the order: `gh label edit "very high" --name prio-4 --color b60205` renames in place, so every
issue keeps the label it had and nothing is relabelled by hand. **Carry the `--color` on all four**,
not just this one -- the bottom two rungs change colour as well as name, so a rename without it leaves
the right word on the wrong badge.
[`adopt-dkj-policy-bwj`](skills/adopt-dkj-policy-bwj/SKILL.md) step 4 carries all four lines. Do that
and the `asana-mirror.ps1` refresh in one sitting: the sweep runs only on the daily `reconcile` cron,
so a run caught between the two costs one sweep and the next morning repairs it. And the sweep sheds
the four **old** names as it sets a new one -- never writing them -- so a repo that was brought over
with the additive create step instead, and so holds all eight, is swept clean rather than left
claiming two priorities at once.

**No score means no label, and that is the common case.** A task whose `Prio-Score` is empty, or whose
score falls outside 1.00-5.00, is left without a prio label rather than given a guessed one -- measured
on the board the day this shipped, 28 of its 96 open tasks carried no score at all.

**It walks GitHub, not the Asana project**, and that is what separates it from the sweeps in step 4.
Two consequences worth knowing. It reaches a ticket **imported from Asana**, whose task carries no
GitHub back-link for a project walk to follow -- the same gap the header-row matcher exists for. And it
needs **no `ASANA_PROJECT_GID`**: a repo whose project GID is still wrong or provisional gets its
labels right anyway.

**But `Prio-Score` has to be ON THE PROJECT, and that is the limit to know before relying on this
step.** An Asana custom field is *defined* in a workspace and does not cross into another -- which is why
this sweep looks the field up by *name* and never by GID -- but definition is not the operative test.
A field only becomes readable on a task once it has separately been *added to* that task's project, via
the project's own `custom_field_settings`. Two real BWJ boards sit in the very same workspace and answer
that second question differently: `GitHub - SWB` carries `Prio-Score`, `GitHub - WH` carries no custom
fields at all. Set the per-project test against the two populations the step reaches and they come apart.
A ticket **imported from** the board *is* a task on that board, so it carries whatever fields the board
carries. A ticket the workflow **files itself** lands in whatever `Get-AsanaProjectGid` points at, and
where *that* project does not carry `Prio-Score` -- whether because it sits in a different workspace or
simply because the field was never added to it -- its tasks have no `Prio-Score` for the sweep to find --
not an empty one, none. So the paragraph above reads too generously: a project missing the field costs an
imported ticket nothing, and costs a self-filed one every label it could have had.

**Which gives `Get-AsanaProjectGid` an answer it did not have before.** Whichever project a repo mirrors
into, `Prio-Score` has to be added to it, or step 5 is a feature only imported tickets can use --
`get_project` (`opt_fields=custom_field_settings.custom_field.name`) is the one call that answers whether
it is. Measured across both BWJ stores on September 2, 2026, the day after this shipped: of
the 12 open issues that resolved to a task, every one that came away with a label was an imported one
(4 of the 5 matched by header row; the fifth was unscored), and no self-filed ticket was labelled in
either repo. **The workspace boundary was the first reading of *why*** -- inferred from the field model
above rather than measured, because in that run the same self-filed tasks were unreadable to the
session's own token, which is the separate cause described three bullets into step 7, and from outside
the two cannot be told apart. Issue
[#1213](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1213). **That reading turned out too
narrow, in the safe-looking direction**: measured directly against both boards on September 4, 2026, they
sit in the *same* workspace, and `GitHub - WH` still carries no `Prio-Score` -- a case the workspace rule
cannot express, because nothing about it crosses a workspace boundary. The per-project test above is what
actually gates the field. Issue
[#1386](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1386).

**Why this direction does not contradict "GitHub first".** That rule is about where a ticket is *born*
and where its lifecycle is *tracked*. Priority is neither: it is the business's judgement, made in the
window the rest of BWJ looks through, and the workbench is where it has to be visible. Nothing in this
step writes to Asana.

**What it costs on the GitHub side:** the workflow's `issues:` permission is `write` rather than
`read`. It makes exactly two writes outside Asana, both on this repo's own issues: this step's label
edit, and the one comment
[the step-4 backstop](#the-backstop-asana-mirror-still-writes-one-only-where-the-session-did-not)
posts on a closed issue that has no paste-ready block yet. Nothing else on GitHub is written.

### 6. The board's sections ARE the cycle -- one card, one column per stage

Everything above says what is written *into* a ticket. This step says *where the ticket sits*, and it
is the one view of this workflow a BWJ colleague actually reads: the board's sections, in order, are
the steps of the contributing cycle. A card's column is the answer to *"where is my request?"*, which
until now the board could not give.

**There is exactly ONE board, and its name is the team's** (Dave, September 2, 2026, closing
[#1222](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1222)). At BWJ that is
`Workload Overview`; `Development BWJ` was retired in the same decision, and every card of Dave's was
taken off it that day. So the *"which board, and what happens to the others"* edge that inbound
[#1217](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1217) had to be corrected on by
hand does not arise here any more -- there is no other board to advance by mistake. The containment
that answered it is still in the mechanism, and it is what the next two headings are about.

#### How a section is recognised, and what it MEANS -- two questions, not one

**A section is recognised by the NUMBER its name starts with.** `3. In development` and
`3. Building it` are the same stage; rename the words whenever the team likes. It is the same split
the cross-link of step 3 already uses -- a marker for the machine, prose for the reader.

**And it is the containment.** A section with no leading number is on no pipeline, so a task sitting
only in such sections is never written to. That is why pointing this workflow at a workspace full of
other boards costs nothing, and it is the mechanism that made #1217's correction structural rather
than a written warning. A card on **two** numbered boards has two answers and gets neither: the
candidates are named in the log and nothing moves.

**What each number MEANS is a separate question, and it belongs to the repo.** `Get-AsanaStageMap` in
your own `scripts/repo-config.ps1` -- the file `dkj-policy` already dot-sources -- names
one section per stage of the cycle:

```powershell
function Get-AsanaStageMap {
    return @{
        Requests       = 1   # the submitter's inbox -- never a target, though cards do leave it
        NeedsInfo      = 2   # blocked on the submitter -- driven by the label below
        Filed          = 3   # project status Todo -- tracked on GitHub, nothing linked yet
        InDevelopment  = 4   # project status In Progress -- a pull request is linked
        InReview       = 5   # project status Done -- the issue is closed
        ReadyToTest    = 6   # the submitter has been TOLD -- their turn; never moved OUT of
        Completed      = 7   # the submitter says it is good -- never a target, never moved OUT of
        NeedsInfoLabel = 'needs-info'
    }
}
```

**That seam exists because the meanings were literals in the script for exactly one afternoon.** They
shipped on September 2, 2026 against a six-section board; the board gained a section the same day, and
every stage from `Filed` upward moved by one. **Nothing failed** -- the sweep would simply have put
every card a column early, quietly, on a board whose whole purpose is telling somebody where their
request is. Semantic keys and not GIDs, deliberately: a rebuilt column keeps its number and loses its
GID, so a GID map is born with the failure mode it was meant to prevent.

**A section the map does not name is a HOLD -- not a target, and not a source.** That is the repair
for what just happened: a board that grows a column no longer has its cards yanked into whatever the
old numbering meant. A repo that states no map at all gets the default above, and the run says which
map it used.

#### The three middle stages ARE the GitHub Project's three statuses

**`Filed`, `InDevelopment` and `InReview` are linked to `Todo`, `In Progress` and `Done`, and are
always in sync with them** (Dave, September 2, 2026). The project board's `Status` field is the
**source**; the Asana board follows it. So the sweep reads that field instead of re-deriving the same
answer from the issue and its pull requests:

```powershell
function Get-GithubStatusMap {
    return @{
        FieldName        = 'Status'
        Statuses         = @{
            'Todo'        = 'Filed'
            'In Progress' = 'InDevelopment'
            'Done'        = 'InReview'
        }
        # Where the submitter's name sits in the task notes. '' means stage 6 is never entered.
        SubmitterPattern = ''
    }
}
```

**Why read it rather than derive it: GitHub already writes that field.** The project's own built-in
workflows do it -- `Item added to project` sets `Todo`, `Pull request linked to issue` sets
`In Progress`, `Item closed` sets `Done`. Deriving the same fact a second time in the sweep made
**two writers of one thing**, which is a race and not a sync. Measured on the BWJ board the day this
shipped: all 144 items carried a status, and every one of the 108 closed issues read `Done` -- so the
field is maintained, and it is maintained by GitHub.

**The status names are the keys because they are the board's, not ours.** A team that renames a column
states that once here and nothing else changes. The *values* are stage keys of `Get-AsanaStageMap` and
never section numbers, so renumbering the Asana board is still stated in one place too.

**A status may only name those three stages, and `Test-GithubStatusMap` refuses a map that tries
otherwise.** `Requests` and `Completed` are the submitter's ends, and `ReadyToTest` is reached by the
feedback rule below -- a column change must never hand a card to somebody.

**An issue with no status, or one in a column nobody has mapped, derives no stage at all** and its card
is left where it is. That is the same containment as an unnamed Asana section: the answer to not
knowing is to do nothing, because a missing status must never read as stage 0.

**One thing does still come from the issue rather than the status: `closed as not planned`.**
`Item closed` sets `Done` whatever the reason, so a ticket that will never be built arrives looking
exactly like a finished one. It derives no stage, because nothing was built.

#### A repo with NO project board says so, and then the issue is read instead

**The board is not a requirement of this workflow, and a repo that has none states that by giving
`Get-GithubStatusMap` an empty `FieldName` and no `Statuses`:**

```powershell
function Get-GithubStatusMap {
    return @{
        FieldName        = ''   # this repo has no GitHub Project board
        Statuses         = @{}
        SubmitterPattern = '(?m)^\s*Requested by:\s*(.+?)\s*$'
    }
}
```

The sweep then never sends the `projectItems` query at all -- so **such a repo needs no
`GH_PROJECT_TOKEN`** -- and derives the floor from the issue: **closed** means `InReview`, **open with a
pull request linked** means `InDevelopment`, **open with nothing linked** means `Filed`. An issue GitHub
could not be asked about derives nothing, and `closed as not planned` still derives nothing.

**Saying both is refused.** An empty `FieldName` beside a `Statuses` table that still names columns
reads as "there is no board" and "here are its columns" at once, so the validator complains instead of
guessing which half was meant.

**This does not weaken the rule above, and the reason is mechanical rather than a promise.** The
two-writers race that made the status the source *is* GitHub's project workflow being the other
writer -- so a derivation that fires only where there is no board has no second writer to race with. A
repo naming a `FieldName` takes exactly the path it took before.

**It is the repo's declaration that switches this on, never a missing status**, and those are two
different facts that both used to arrive as nothing: *this repo has no board* and *this issue is not on
the board*. Only the first may derive a stage; deriving one from the second would stage every issue a
board deliberately leaves off its pipeline.

**What its absence cost, because it is four stages and not the three this page describes** (inbound
[#1536](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1536)). With no board every
issue derived nothing, and that also switched off the one promotion no column names: `ReadyToTest` is
reached from a floor already at `InReview`, so **closing an issue stopped handing the card back to the
submitter** -- the transition the whole board model exists for. The close update still went out, so the
person was told the work was ready while their card never moved, and no run failed. Advising a token was
no answer either, there being no board to read.

**And the sweep now says so in one line when a whole run derives nothing at all** -- naming the three
reasons it can be: the project field could not be read, the board's columns are not named in the map, or
the repo has no board and has not said so. Silence is what made that issue expensive: `N card(s) moved`
reads the same on a quiet day as on a run that could not answer for a single ticket. A *partial* figure
is deliberately not reported -- one issue off the pipeline is the design working.

#### `ReadyToTest` is entered on FEEDBACK, and no status can reach it

**A card advances from `InReview` to `ReadyToTest` once the submitter has actually been told** (Dave,
September 2, 2026) -- which is this workflow's own close update, the comment of step 4. Two things
must hold: the issue is closed, and that comment is on the task. So the two columns say genuinely
different things:

- **`InReview`** -- closed on GitHub, and nobody has been told yet.
- **`ReadyToTest`** -- the submitter has the update naming what was fixed, and it is their turn.

**Where a ticket has no submitter, stage 6 is skipped entirely.** Nobody else asked for it, so there
is nobody to hand it to: the card waits in `InReview` until the person who owns it accepts it into
`Completed` themselves. `SubmitterPattern` is how a repo says where the submitter's name is written,
and **`''` -- the default -- means this workflow can never tell, so the promotion never fires at all.**
That is the fail-safe direction: a card held one column short is visible and a person can move it,
where a card pushed into the submitter's column claims a handover that never happened.

**`created_by` is NOT the submitter**, measured on the BWJ board the same day: the intake form creates
every card as its own owner, so it reads identically on a colleague's request and on one filed by a
session. The submitter is the name the form writes into the notes, and is added as a follower when the
form can find them in Asana.

**Being told is MEASURED, not assumed.** The close event posts the comment before it checks, so a card
normally reaches `ReadyToTest` on the event itself; but the check reads the task's own comments, so a
run whose comment failed does not hand the card over on the strength of having tried. The daily sweep
catches those.

#### The stages, and who moves a card into each

| stage | what a card there means | who puts it there | on what signal |
|---|---|---|---|
| `Requests` | new, and nobody has looked at it yet -- a colleague put it on your name | the submitter | **never this workflow** |
| `NeedsInfo` | we cannot proceed until the submitter answers something | the `needs-info` label | that label is on the issue |
| `Filed` | it is tracked on GitHub now, where the work happens | the daily sweep | project status **`Todo`** |
| `InDevelopment` | somebody is building it | the daily sweep | project status **`In Progress`** |
| `InReview` | closed on GitHub, and nobody has been told yet | the daily sweep | project status **`Done`** |
| `ReadyToTest` | the submitter has the update naming what was fixed -- their turn | the close event, and the daily sweep | that update is **on the task**; skipped when there is no submitter |
| `Completed` | the submitter has tested it and says it is good | the submitter | **never this workflow** |

**The two ends of the board belong to the submitter, and the code says so and not only this page.**
`Test-StageIsWritable` permits the five middle stages and nothing else. That is the *section-move twin*
of the rule in step 4: closing an issue says the work is built, and only the person who asked for it
can say it is good. A workflow that could slide a card into `Completed` would take that judgement and
replace it with a guess -- in the board's own currency this time, but the same guess.

#### And TWO stages are terminal, not just one

**A card sitting in `ReadyToTest` or `Completed` is never moved out of it by this workflow** (Dave,
September 2, 2026). Both mean the submitter is holding the card:

> *"it is not the intention that if I drag a ticket to section 6, GitHub syncs it back to 5 later. Once
> it is in six it does not just go back."*

**This outranks even the reopen**, which everywhere else in this model earns a backward move. If the
work turns out not to be done, the person holding the card moves it -- that is what holding it means,
and having it pulled back out from under them by the next morning's sweep is the failure the rule
names. `Test-StageIsTerminal` is the guard, and it is checked **before** the backward-move permission
rather than after.

**It is also the one place `always in sync` deliberately does not hold**, and it is worth saying which
way: the Asana board may sit *ahead* of the GitHub status, never behind it. A closed issue reads `Done`
forever, so a card in 6 or 7 keeps a status that would floor it at 5 -- and that is correct, because
6 and 7 are answers GitHub has no column for at all.

#### Forward only, and the two answers that may go back

`Get-StageFloorForIssue` derives a **floor** from the project status rather than a position, and the
difference is what keeps a person's own move safe: a card somebody advanced by hand is never dragged
back by a sweep reading a column GitHub has no event to update. The concrete case is a branch open
with no pull request yet -- GitHub sets nothing, so the status still reads `Todo`, which floors at
`Filed`, which is **backward** from the `InDevelopment` the session moved the card to. Nothing moves.

**That asymmetry is the deliberate exception to *always in sync***, and the alternative is worse:
syncing it would mean undoing a person's own move on the strength of a column that has no way of
knowing about it.

**Two answers may move a card backward, and both are a person saying something** rather than CI
inferring it:

- **The `needs-info` label**, which *outranks the project status*. A card blocked on the submitter
  stays blocked whatever the board says, because the person who set the label knows something the
  tracker does not. Removing the label hands the card straight back to its status-derived floor --
  which is forward, so it needs no permission. The label fires its own CI run (`labeled` /
  `unlabeled`), so the column changes as the triage happens rather than a day later.
- **An `issue reopened` event**, which is a real state change: the card lands wherever the board now
  says it is, which is out of the review column and back into the one the work is actually in.

**Both are outranked in turn by the terminal rule above.** A reopen moves a card back out of
`InReview`; it does **not** reach into `ReadyToTest` or `Completed`, because those are not this
workflow's to take back.

**A label event moves the card and says nothing.** `closed` and `reopened` are news for the person
waiting on the ticket; a label is a change in *our* state, and commenting on it would put a note on
the submitter's ticket every time somebody triaged the issue.

#### Setting `needs-info` IS writing the question -- one act, and the issue stays open

**The label moves the card to the submitter, so the question has to be on it** (inbound
[#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352), carrying a rule that lived only
in a consumer page until September 23, 2026). The paste-ready block of step 4 is one exit that ends
with the requester; `needs-info` is the second, and it moves the card just as hard. Because the CI run
above deliberately says nothing, the only message this exit ever carries is the one the session
writes. Measured in `BWJ-Development/smartwatchbanden`,
[#702](https://github.com/BWJ-Development/smartwatchbanden/issues/702) and
[#721](https://github.com/BWJ-Development/smartwatchbanden/issues/721): a card sat a day in the
blocked column with no question on it, because the procedure prescribed a message for delivered work
only -- and a card with the submitter and no question is a waiting room nobody knows the subject of.

**So the label and the comment are ONE act**, done by the session that knows what was investigated, at
the moment the card moves -- not later, by somebody reconstructing the dossier. The comment goes on the
issue, carries the same `<!-- asana-paste-block -->` marker below the text so the step-4 backstop never
adds a placeholder copy, and is carried into the task by its assignee exactly like the delivered-work
block. Its shape:

```text
<one to three plain sentences: what was investigated and what came out of it. No file names, no
branch names, no measurement tables -- the technical account is the session's own comment above,
and this is its translation for the person who filed the ticket.>

<say explicitly that nothing was repaired, and why that is not "solved": "could not reproduce it
today" is not "it is gone", and a report nobody could verify stays open.>

What we ask of you:
1. <the first question. Ask for what the requester CAN know -- a time, a screenshot, a reference
   number on an error page -- never for something they would have to look up in code or a log. Say
   per question WHY you need it; without that it reads as a form rather than a question.>
2. <the second, if there is one. Two or three at most.>

<say what happens if they no longer have the answer. There is always a next step -- a standing check
that records it by itself next time, for example -- and it is never "then it stops here".>

<!-- asana-paste-block -->
```

**The form's words follow the reader**, per [step 8's language rule](#the-language----english-form-content-follows-the-reader):
the shape above is stated in English, and the message is written in the language of the Asana task
and of the colleague who reads it.

**This exit does NOT close the issue**, where the delivered-work exit closes it one act after the block.
That is not an inconsistency: there the development work is finished and only the judgement is with
the colleague, while here the work itself is stalled on something only they can supply -- which is still
an open item of ours, and belongs in the list where work is tracked. **Nor does the session remove the
label**: whoever brings the answer does, and the card returns to its status-derived floor.

#### The daily sweep is the mechanism, not a backstop

**A project status changes with no `issues:` event at all** -- somebody drags a card to `In Progress`,
or a built-in project workflow sets `Done` -- and this workflow subscribes to none of that. So unlike
the reconciliation of step 4, sweep (d) is not a safety net for a missed webhook: for the three
statuses it **is** the mechanism, and a column change shows up on the Asana board the next morning.
Only the close, the reopen and the label have events of their own, and they are the ones that matter
most to the submitter, which is why they are also the ones that do not wait a day.

**What that costs at `InDevelopment`, said plainly:** GitHub sets `In Progress` when a pull request is
*linked*, and nothing at all when a branch merely opens. `linkedBranches` answers only for a branch
created through GitHub's own issue UI, and `dkj-policy` branches are not. **So that hop is
still a session's to make first**, and forward-only is what keeps it: a card left in `Filed` while a
branch is open is the one inaccuracy this model tolerates, and it corrects itself the moment the pull
request opens and the board says `In Progress`.

**And the stage sweep needs its own token -- where there is a board.** `GITHUB_TOKEN` cannot read an
organization's Projects v2 at all -- there is no `permissions:` key that grants it -- so with the
workflow's own token the status comes back as an error rather than a value. That failure is **contained
rather than fatal**: the query retries once without the project field, so the close update of step 4
goes out exactly as before and only the staging goes quiet, naming the missing token in the log. Set
`GH_PROJECT_TOKEN` to a PAT that can read the org's projects to turn staging on. **A repo with no board
needs neither the token nor the board** -- it says so with an empty `FieldName` and the issue is read
instead, per the section above.

### 7. What still needs a person

- **Setup, once per repo:** the repo secrets `ASANA_PAT` and `GH_PROJECT_TOKEN`, the variable
  `ASANA_PROJECT_GID`, the four prio labels of step 5 plus the `needs-info` label of step 6, and
  copying the two `templates/` files into `.github/`. The
  [`adopt-dkj-policy-bwj`](skills/adopt-dkj-policy-bwj/SKILL.md) skill walks this.
- **Naming the project board's three statuses, and where the submitter's name sits.** `Get-AsanaStageMap`
  says which Asana section each stage is; `Get-GithubStatusMap` says which GitHub status each of the
  three middle stages is, and carries `SubmitterPattern`. Leave that pattern out and stage 6 is never
  entered automatically -- which is a working configuration, not a broken one, but it does mean every
  card waits in `InReview` for a person. **Or say there is no board at all** -- an empty `FieldName` with
  no `Statuses` -- and the three middle stages come off the issue instead; that is a working
  configuration too, and the one thing this seam could not express until inbound #1536.
- **Numbering the board's sections, once, and stating what each number means.** Step 6 reads a stage
  off the number a section's name starts with, so a board whose sections are named in prose has no
  stages and nothing is ever moved on it. That is the safe default rather than a failure -- but it is
  also silent, so a board that is meant to be a pipeline and is not numbered looks exactly like one
  that works. The meanings go in `Get-AsanaStageMap`; leave it out and the default map is used, which
  is right only if your board happens to be numbered the same way.
- **Re-reading that map whenever the board changes shape.** Adding or removing a column shifts every
  stage above it, and the map is the one place that has to learn it. A section the map does not name is
  left alone rather than guessed at, so the symptom of a forgotten update is cards that stop moving --
  not cards in the wrong place. That is deliberate, and it is still yours to notice.
- **The `InDevelopment` hop, at `new-branch`.** The one stage transition CI cannot see: GitHub has no
  signal for a branch that has no pull request behind it yet. A session opening a branch for a mirrored
  issue moves the card there in the same breath, and **nothing catches it up** -- the sweep never
  derives that stage. Step 6 says why, and it is why the derivation is a floor: nothing undoes the move
  you made by hand.
- **Deciding a ticket is blocked on the submitter.** The `needs-info` label is the whole mechanism for
  that column, and no automation sets or clears it. Putting it on is a judgement about whether the
  request can proceed -- and it is one act with writing the question, in the form step 6 prescribes;
  taking it off says the answer arrived, and the card returns to wherever the work actually is.
- **Scoring the ticket.** The label follows the board and nothing here decides a priority. A task
  nobody has scored carries no prio label, and putting a number on it is the team's call to make in
  Asana -- the same shape as resolving a ticket, further down this list.
- **A token that can reach the tickets.** `ASANA_PAT` is a *user* token: it can only see the
  workspaces that user is a member of. An imported ticket often lives in the requester's own Asana
  organisation rather than in the one the mirror project sits in, and a task the token cannot read is
  logged and skipped rather than failing the run -- so a sweep that reports `0 updated` with a line
  per unreadable task is telling you about the token, not about the tickets.
- **Closing an Asana-linked issue, once the paste-ready block is on it.** Step 4 reverses the old
  order: the session writes the block while the issue is open, and closing it is the confirmation that
  the task's assignee pasted it into Asana. That is why such a branch ships with `-NoResolves` -- a `Closes #<n>`
  would have GitHub close the issue at the merge, with nobody having confirmed anything. Where the repo has
  stated `Get-ResolvesExemptMatchers` (inbound #2120), the resolves gate refuses that `-Resolves` instead
  of leaving it to memory.
- **Resolving the ticket. That is the whole point of step 4**: the colleague who filed
  it ticks it off once they have tested the change, and nothing in this workflow will do it for them.
- **The Asana project answer, and step 6 has now settled it.** This used to be an open BWJ decision --
  one shared project for both stores or one each, as long as both repos made the *same* kind of
  choice. It is not open any more: the board a card is staged on is the board the team reads, there is
  exactly **one** of those (Dave, September 2, 2026), and a task this workflow files anywhere else
  lands on no pipeline and is never staged. Put together with the `Prio-Score` constraint of step 5,
  which independently requires that project to carry the field -- added to it, not merely reachable
  from its workspace -- `Get-AsanaProjectGid`
  has one correct value per repo: **the board itself**. A **provisional** GID is the case where both
  costs land at once -- such a ticket carries no prio label and never moves a column, and neither
  failure says anything in a log. And the board itself is not automatically enough: `GitHub - WH`
  proves a real board can still lack the field, so pointing `Get-AsanaProjectGid` at the right board is
  necessary and not sufficient -- see step 5.

### 8. A ticket that arrives FROM Asana -- whose it is, and the form it takes

Steps 1 to 7 run outward: a finding made here is filed on GitHub and mirrored onto the board. **Work
also arrives the other way** -- a colleague files a request in Asana as a desired outcome, and somebody
has to decide whether it can be built at all before a branch is worth creating. The rules for that
layer are `dkj-policy`'s, under
[Ticket work -- the layer before the branch](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#ticket-work--the-layer-before-the-branch),
and they deliberately leave a list of questions to the repo under
[What your repo answers](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#what-your-repo-answers).
**This step is BWJ's answer to that list, once for both stores**, so neither can drift from the other.
It restates none of the rules; read those first.

**It lived in `smartwatchbanden`'s own tree until September 23, 2026**, as the only copy anywhere --
`xoxowildhearts` had none -- and moved here on inbound
[#2353](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2353), because an answer both stores
owe is this plugin's rather than one repo's. **Its reach is the two stores.** `dkj-claude-plugins` was
admitted to this chapter for *filing* (see the top of this page), and nothing reaches that repo from
the Asana board as a request, so there this step has nothing to apply to.

#### Whose ticket is it -- the Asana assignee decides, and nothing else does

**A task on the board is not by that fact an assignment to the dev team.** Board membership says the
ticket is tracked; it does not say the work is ours. Before a task becomes a GitHub issue -- and again
before anybody claims that issue -- read the **assignee of the Asana task**, and answer three things:

- **Is it assigned to somebody outside the dev team?** Then it is not an assignment. Either leave it
  unmirrored, or mirror it and open it as **blocked on that person** rather than as work -- which is
  what the `needs-info` label of step 6 says, and it parks the card in the blocked column while it is
  true.
- **`Ball with` is read, not assumed.** The header row below is a judgement about *who is up now*, and
  the task's assignee is the evidence for it. `us` is an answer, not a default: if the task is on
  somebody else's name, the answer is that name.
- **Read the comments on the task before picking it up.** A colleague's own comments are where a
  running experiment, a blocking bug or a decision not yet taken is written down, in plain language.
  It is one API call, and it is the call that decides whether the ticket is ready at all.

**`claim-issue` cannot make this check for you, and that is why it is written here.** It reads the
*GitHub* assignee, which on a freshly mirrored issue is empty no matter who owns the Asana task -- so a clean
claim says nothing about whose ticket it is.

Measured in `smartwatchbanden`,
[#722](https://github.com/BWJ-Development/smartwatchbanden/issues/722), filed September 18, 2026: four tasks
were mirrored in as development work from one board section, and three were built and merged before
anybody noticed they were assigned to a colleague and still in that colleague's A/B-test stage, where a CRO ticket
is proven before development touches it. Two of the three changed the very element under test in a running
experiment, so reaching the live theme inside its window would have handed the control group the
variant. **The section could not tell the four apart; the assignee could** -- the fourth was assigned
to the dev team, was built, and that was right. The experiments were described, with window and
traffic split, in comments on the tasks nobody read.

#### One issue per ticket, and everything stays in it

**One GitHub issue per Asana ticket**, in the store's repo, with the Asana link in its header. The issue
is the analysis; Asana keeps the request. `report-issue` files it and puts the card in `Filed` in one
call, and everything after that is `asana-mirror`'s job (step 6) -- **move no card by hand.**

**Everything that comes out of Asana stays in that issue** -- the request, what was worked out, what
was measured, what went back to the requester. There is no second home for it, and the issue's own
comments carry a round of working-out just as well as its body does. **One thing that works in a file
breaks in an issue body: a relative path.** GitHub resolves it against the issue's URL rather than the
repo, so it 404s -- write an absolute blob URL, and a permalink to a commit when you cite a line.

#### The language -- English form, content follows the reader

**The section and field names are English**, because they are the workflow and not the subject: a
colleague who does not read Dutch can open a ticket and recognise its structure without translating
six headings first. **The content follows whoever filed the ticket** -- the reply goes verbatim to the
requester, and the analysis around it takes the same language, because a reply in one language under
an analysis in another does not read. Look up who filed it before you write, rather than assuming.
A **closed value** keeps its source language wherever it appears: `buildable` in a code span is the
value of a field, and is never translated.

#### The header -- seven rows, and `Reviewed` is the provenance boundary

| row | where it comes from |
|---|---|
| **Asana** | the ticket id as a link, with its board column after it |
| **Created** | date and time in Amsterdam time, the raw UTC timestamp, and by whom |
| **Priority** | from Asana |
| **Deadline** | from Asana -- **leave the row out when there is none** |
| **Reviewed** | the date the four rows above were last checked against Asana |
| **State** | our own judgement (vocabulary below) |
| **Ball with** | our own judgement: who is up now -- read off the task's assignee, never assumed to be `us` |

`Reviewed` is the portable layer's provenance boundary in BWJ's form: everything above it is a copy out
of Asana and only true on that date, everything below it is ours and does not rot. **Followers and the
board section are deliberately not rows** -- the first was never cited and changed silently fastest,
and the only informative part of the second is the column, which rides along in the `Asana` row.

**The `State` vocabulary is closed**, so every ticket carries the same word:

```text
draft · question ready · question asked · answer in · buildable · in build · delivered · closed
```

Eight, because four stages follow the reply. **`Ball with` is closed too, and shorter:** `us`, or the
name of whoever is being waited on.

#### The sections -- a route, not a table of contents

| section | what is in it |
|---|---|
| `## About this ticket` | **only when there is something to say about the ticket itself**, and then at the top: it duplicates another ticket, it never got a priority, its deadline has moved twice. Otherwise the ticket opens with the request |
| `## What we know` | collects, and only that. One `###` per source, in this order: **what the ticket asks** (the requester's own words, unedited), **what the replies worked out** (with who and when), **what we measured or looked up** (with the command, or the file and line). Only the first is always there |
| `## Blocked` | the gate between knowing and building, in **every** ticket. Opens with **`### Do we know enough?`** and one of the two fixed sentences below, the reason after it. At *yes* that is the whole section. At *no* it carries the round as **`#### Remaining Question(s)`**, **`#### The reply`**, and once the answer lands **`#### Response (<date>)`** -- after which **`### Do we know enough now?`** judges the round again |
| `## Development` | `### Note` for consequences worth knowing, and `### Steps`: the step list that makes the ticket buildable plus where the change lands. Once built, **`### Changelog`** and **`### Testing`** follow |
| `## Completed` | **only once the Testing checklist is ticked, the preview is approved and the change is live.** Carries `### The final reply`. An empty `## Completed` claims a gate is open that is not |
| `## Activity` | append-only log, newest first, one dated line per event |

**`### Steps` and `### Changelog` are the branch document in ticket form, and the boundary between them
is an agreement** (Dave, August 12, 2026): the branch document's phases and DEPLOY section are the
**working copy for the length of the branch** -- the fold removes it -- and the ticket is the **lasting
record**. At the merge the state is carried over, never maintained in both; two copies kept side by
side are two versions within a week and no way to tell which is right.

#### The two sentences that answer the gate

Verbatim, and in Dutch because that is how they were dictated (Dave, August 12, 2026) -- a person's own
words, quoted as written:

```text
Ja, er is genoeg info om te kunnen bouwen. Ga door naar Development.
Nee, er is nog niet genoeg info. Ga door naar Remaining Question(s).
```

They are closed for the reason `State` is: *can this go ahead?* is answerable at a glance instead of by
weighing a paragraph, and each names the section it points at, so the judgement is also a routing.
**The reason goes straight after the sentence** and differs per ticket; a caveat goes *behind* it with
an em dash, never in front, so the first words are always the answer. The *yes* sentence deliberately
does not say "skip the questions" -- three of the first six tickets reached *yes* **through** a round
of questions.

Each gap under `#### Remaining Question(s)` closes with the question that carries it, or says it has
none and why. An incoming answer lands under the gap it unblocks and names it.

**And the standing agreement around all of it: a ticket with open questions is not built.** The
questions go to the requester with an @-mention, and the work waits until they are answered.

#### What `### Testing` has to carry

Anything visible on the storefront is tested from the ticket, not only from a branch somebody has to
check out (Dave, August 12, 2026):

- **the preview theme id**, with the date it was pushed, so it is clear which state you are looking at;
- **the URLs per market of the pages that actually changed** -- not the homepage. The handles differ per
  market and can be read off a page's `hreflang` alternates, so there is nothing to guess;
- **what there is to see** -- the part most often skipped. Where the change is in the page source or
  the JSON-LD, the answer is explicitly *nothing to see by eye*, plus where to look instead;
- **what still has to be judged, as a checklist**, unticked until it has happened. **That checklist is
  the gate to `## Completed`.**

How the preview itself is handed over is chapter three's, in
[`PREVIEW-portable.md`](PREVIEW-portable.md).

#### Measuring, here, means measuring a shop

The portable layer says to look at the product before writing down a gap, and to measure more than one
instance. In a store the product is a **theme**, so measuring is in practice a `curl` on a live page
with a `grep` behind it, and *more than one instance* means more than one collection and, where it
matters, more than one market.

---

## Why it is shaped this way

- **GitHub first, not Asana first**, because the people who fix the issue live in GitHub and the
  fix's lifecycle (branch, PR, merge, release) is already tracked there by `dkj-policy`.
  Asana is the window the rest of BWJ looks through, not the workbench.
- **A translation, not a copy**, because a mirrored task that is just the issue body helps nobody: a
  non-technical colleague cannot act on a stack trace, and a technical reader already has the issue.
- **CI, not a session**, for the update step, because it must happen every time an issue closes
  whether or not anyone is running Claude, and because a workflow file is version-controlled and
  reviewable where an Asana-side automation rule is not.
- **A reconciliation sweep**, because a single webhook can be missed and a colleague waiting on a
  ticket nobody told them about is exactly the drift this plugin exists to prevent.
- **The prio label goes Asana -> GitHub**, against the grain of everything else here, because
  priority is the one thing the business owns and the developers consume. The board is where it is
  decided and the issue list is where it has to be read; carrying it across beats asking a developer
  to keep a second window open.
- **The block before the close, and not at it**, because the close is the only event a person in this
  chain actually performs, and hanging the composition on it put the paragraph underneath an item that
  had already left every open-issue view. Writing it first turns the close into a **receipt** -- the
  issue is open for exactly as long as the block is outstanding -- and it puts the composing in the
  hands of the one party that knows the link, which is what retires the `[ADD LINK]` placeholder
  instead of working around it.
- **An update and not a tick**, because the two are different claims by different people. The build
  is finished when the person who built it says so; the request is finished when the person who made
  it says so. A tracker that lets one stand in for the other cannot afterwards tell you which of its
  closed tickets anybody actually looked at.
- **The board's sections, and not a status field**, because a section is what a colleague already
  reads. The stages could have been a custom field with six options and nothing about the mechanism
  would change -- but then the answer to *"where is my request?"* would sit one click inside a card
  instead of being the shape of the board, and a card would look identical whether it had been picked
  up or not. That is the failure inbound #1217 measured: an issue existed here while the board still
  said `New`, and the person waiting on it had no way to tell.
- **A number in the section name, and not a GID per section in a config**, because the two halves
  have different owners. The number identifies the column; the words are the team's and change
  whenever one reads badly. Configured GIDs would put both halves in a file only a developer edits,
  and would go stale the first time somebody rebuilt a column -- the way a provisional project GID
  went stale and cost every prio label behind it.
- **But the MEANING of each number in a config after all**, because that half turned out to belong to
  the board rather than to the workflow. It was a literal in the script for one afternoon and the
  board changed shape the same day. The two questions look like one and are not: *which column is
  this?* is answered by the board, and *what does that column mean?* is answered by the team who
  built it.
- **An unnamed column is a hold rather than a stage**, because the alternative is the failure that
  produced the seam. Treating an unknown number as an ordinary stage means a board that grows a column
  has its cards dragged to whatever the old numbering meant, silently. Stopping is the only answer
  that is wrong in a way somebody notices.
- **A label for the blocked column, not an inference**, because "we are waiting on the submitter" is
  not visible in any state GitHub tracks. An open pull request does not mean the question was
  answered, so the card has to stay blocked until a person says otherwise -- which is why the label
  outranks the issue's state instead of competing with it.
- **A floor rather than a position**, because CI knows less than the person at the keyboard. A sweep
  that set the stage outright would spend every night undoing the one hop only a session can see -- a
  branch opening -- and the card would flap between two columns with nothing wrong.
