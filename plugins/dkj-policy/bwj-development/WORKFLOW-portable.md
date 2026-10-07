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

**The fourth is `phone-factory`, BWJ's Lightspeed store, admitted for this chapter alone by Dave on
October 2, 2026 ([#2705](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2705)).** It follows
the BWJ procedure for a discovered issue. It is a store, but not a Shopify one, and the other three
chapters are written against the Shopify theme and CLI, so they do not reach it either. One part of this
chapter states its reach by name, and Dave settled it for `phone-factory` on October 2, 2026
([#2712](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2712)): the board-request step
**does** reach it. The other part settled then, the `CRO` label, has since been retired everywhere
(below).

**Keep the two axes apart -- they read as one question and are not.** The org is left off the *store
pair's* name because an org can move out from under a repo while the repo itself does not; the *repo
count* differs by chapter because only this chapter's gate actually widened. `report-issue` and
`adopt-bwj-development` both check the repo name against all three; this page is the reasoning their
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

#### Classify it as you file it -- labels only, all set at creation

An issue that arrives unlabelled has to be classified by hand afterwards, and afterwards never comes.
So every label goes on the `gh issue create` itself.

| label | what it carries | how |
|---|---|---|
| **`bug` or `feature`** | the kind | **always exactly one of the two.** `--label feature` for something new being added, `--label bug` for something that exists and has to change. A doc finding is one of them too: a missing page is a `feature`, a wrong one a `bug` |
| **the reach label** | how far the issue reaches | one `--label`, and only where it reaches the audience tier. Absence is the answer for tier 0 and is not a missing field. Its **name** is `Get-ReachLabel`'s, default `minor` -- see below |

**There is no third kind, and no `documentation` label** (Dave, October 3, 2026,
[#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)). Until then an issue with
neither kind label was a task, and a doc finding carried `documentation` on top of it; both are gone.
**An issue filed before this change may carry `documentation`, or no kind at all.** Give it its kind
when you touch it, and take `documentation` off.

**GitHub issue types are not used** (Dave, October 3, 2026,
[#2750](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2750)). Labels leave more room to
customize, and issue types are **org-wide**, so the same three were imposed on every repo of both BWJ
orgs. The history runs the other way: on September 1, 2026, `bug` and `enhancement` were deleted from
both stores because the type then carried them, and the type was backfilled by hand onto 135 issues.
**An issue filed before this change may still carry a type and no kind label.** Add the label when you
touch it, and leave the type alone, because nothing reads it any more. Deleting the org-wide types is
an org setting, so it is the owner's to do.

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

#### The CRO label -- retired

**There is no `CRO` label any more, in any repo** (Dave, October 7, 2026,
[#2869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2869)). It marked an issue filed by,
or on behalf of, the CRO team, as a third axis beside the kind and the reach. Now a filing session picks
the kind -- `bug` or `feature` -- and the reach label, and nothing records who raised an issue. An Asana
ticket from the CRO team is filed exactly like any other.

**Where the label already exists, it stays as history** on the issues that carry it, and nothing sets it
again. Deleting it from `smartwatchbanden` or `xoxowildhearts` is a repo setting, so that is the owner's
call, and nothing in this plugin does it. [`adopt-bwj-development`](skills/adopt-bwj-development/SKILL.md)
no longer creates it.

**It triggers nothing on its own, and it used to.** Until inbound
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049) this label was what
turned on the paste-ready block at the close. That block is now gated on the **Asana link** instead --
a mirrored task is a mirrored task -- and it is written before the close rather than at it. See
[step 4 below](#the-go-live-block----written-before-the-close-by-the-session-that-shipped-the-work).
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
`Get-AsanaProjectGid` names, where the card lands in the board's `Filed` section. **After that, two
things update the task: the closed message and the reopened message** (Dave, October 5 and 6, 2026,
#2818 and #2854). When the issue closes as completed or is reopened, the `asana-closed-message`
workflow posts the matching one on the task (step 4). The rest of the CI
automation that used to follow the issue is retired (steps 5 and 6). The Asana task is **not** a paste of the issue body. It is written for
a BWJ colleague who does not read code and does not know the repo:

- **Plain language, outcome-framed.** What a customer or colleague actually experiences, not what the
  code does.
- **No jargon** -- no file paths, no function names, no branch names, no GitHub label vocabulary.
- **A fixed skeleton**, so every mirrored task reads the same way:

  ```text
  Tracked on GitHub: <issue URL>
  What is wrong:   <one or two plain sentences -- what a visitor or colleague sees>
  Where:           <which store, and which page or flow>
  How urgent:      <blocking a sale / visible but not blocking / cosmetic / not customer-facing>
  ```

  The issue link is the **first** line, so the card says where it is tracked before anything else
  ([#2653](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2653)).

- The task's assignee, section and due date are for the BWJ team to set in Asana. This page does not
  prescribe them.

The colleague-facing wording is Claude's to draft; a colleague may refine it in Asana afterwards
**without touching GitHub**. GitHub stays leading -- if the two ever disagree on substance, the
GitHub issue is right and the Asana task is corrected to match.

**This is where the language turns over, and it is the ONLY place in this procedure that it does.**
The skeleton's four headings stay as written above -- they are the form -- while what you write under them is addressed to a colleague and
follows **that colleague**, not the repo. So one finding legitimately reads English on GitHub and the
colleague's own language on the board: that is the translation this step is named for, and not drift
between the two.

**And a ticket a person filed in Asana themselves is theirs entirely** (Dave, September 11, 2026,
[#1875](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1875)) -- the one carve-out the
English rule in step 1 makes. Quote it into the issue as it was written rather than translating it,
because the wording is the evidence of what was actually reported, and write your own analysis around
it in English. Nobody corrects the language of a card a colleague wrote, in either direction.

**Such a card still learns where it is tracked, in two writes and nothing more** (#2653). The issue
link is prepended as the first line of its description, as `Tracked on GitHub: <issue URL>`, with the
colleague's own text left untouched below it. And one comment goes on the task, in exactly this form:

```text
— GitHub automation 🤖

GitHub issue <owner>/<repo>#<n> is created: this Asana task is now in development.
```

Only the issue name varies. It is posted as the link to the issue, with **created:** in bold. The CI
mirror's CLOSED form came back as the `asana-closed-message` workflow (#2818,
[step 4](#4-write-the-go-live-block-then-close-the-github-issue----the-closed-message-carries-it-into-asana));
its REOPENED form came back beside it (#2854, October 6, 2026), and its CLOSED WHILE WAITING FOR
INFORMATION form stays retired (October 5, 2026).
It is English on every board, the one exception to the rule that what a
session writes to a colleague follows their language: the requester fixed it word for word
([#2656](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2656), replacing #2653's
wording). The steps are in `report-issue`.

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
as-configured name -- **whose options are `Bug`, `Feature` and `Task`**, filled from the kind label
[step 1](#classify-it-as-you-file-it----labels-only-all-set-at-creation) chose (`bug`, `feature`, or
neither for `Task`). Step 1 now always chooses one of the two (#2783), so `Task` is only ever reached
by an issue filed before that, still carrying no kind. The field
outlived the issue types it was built for on purpose (#2750). Where it exists it is set on the same
creation call, **from the label step 1 already chose**, never re-derived from the card. That is what makes it worth writing rather than
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
written by the account that posted it, and a session posts under no account of its own: it writes
through the Asana MCP as the person who connected it. So a comment without that line reads to a
colleague as that person's own words, and they did not write it. Measured in `BWJ-Development/smartwatchbanden` the
day the rule was written: a session running `report-issue` on an existing ticket posted a
colleague-facing comment, and the story's author read as the owner's own name with nothing in the
text to say otherwise.

A session writes the line in the colleague's language, [as everything addressed to them
is](#2-then-asana----a-translation-not-a-copy), and it names both facts: automated, and not written
by the account holder personally. The comment `report-issue` posts on an Asana-origin ticket is the
exception: its header is fixed as *"— GitHub automation 🤖"* (#2656). The content
comes after the header and never before. The second writer is the `asana-closed-message` workflow, whose
closed message opens with the same header (#2818).

**Write the line BEFORE you post, because you cannot add it afterwards.** The Asana MCP exposes adding
a comment but no tool to edit or delete one, although the API itself supports both. So a comment a
session posts without the line stays that way. **A block a person pastes by hand** (step 4's
paste-ready block, the `awaiting-more-info` question) is that person's own message once they post it, and it
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
  rather than the account the session writes through, and for one that also sits in a
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

The link is stored on both sides, and one half is machine-readable because scripts match on it (the
backlog page, the release-note task link, the resolves gate):

- **On the GitHub issue** -- appended to the issue body:

  ```text
  Asana: <task URL>
  <!-- asana-task: <numeric task GID> -->
  ```

  The HTML-comment marker holds the bare numeric GID and nothing else, and it is what the matchers
  below try **first and unconditionally**. Write it whenever you create the task yourself: it is the
  only form that cannot be misread, and an issue carrying one is never matched any other way.

- **On the Asana task** -- the `Tracked on GitHub:` line of the skeleton already carries the issue
  URL. Nothing else is required there. A task that came from Asana got its link and its comment in
  step 2.

### 4. Write the go-live block, THEN close the GitHub issue -- the closed message carries it into Asana

**Closing the GitHub issue is the signal that the work is BUILT, not that the ticket is DONE.** Until
October 5, 2026 a GitHub Actions workflow (`asana-mirror`, copied into each store's `.github/`) followed
the issue: it commented on the linked task when the issue closed or reopened, moved the card through the
board's numbered sections, ran a daily reconciliation sweep, synced the task's `Prio-Score` into `prio-N`
labels and posted a placeholder backstop block on the issue. Dave retired all of it that morning, and the
same day brought back **the closed message** (#2818), and the next day **the reopened message** beside it
(#2854). Both are the `asana-closed-message` workflow, copied into each store by
`adopt-bwj-development`, and it needs `ASANA_PAT` only. In practice:

- **Closing an issue as completed** posts one comment on the linked task: the automation's header, the
  closed line, and the go-live block's sections under it. Where the issue carries no block, it posts the
  header and the closed line alone, so the requester still hears.
- **Closing as not planned or as a duplicate posts nothing** (#2765): nothing was built, so there is
  nothing to test.
- **Reopening an issue** posts one comment on the linked task, whatever it was closed as: the header
  and the reopened line, *"GitHub issue <owner>/<repo>#<n> **is reopened:** this Asana task is now back in
  development."* (#2854, in #2656's fixed form). It moves no card and un-completes nothing, so a
  requester who already ticked the task off sees the comment and decides. **So a reopen is a claim
  that development has restarted, and it is made only once that is true** (Dave, October 6, 2026,
  #2856): a follow-up question or a rejection on the task is researched with the issue still closed,
  and the issue is reopened only when that research shows something has to be built. Where it ends in
  an explanation alone, nothing is reopened and nothing is posted: the session gives the answer in
  the terminal, to the person in the session, and that is the whole route (Dave, October 6, 2026,
  #2860). No comment goes on the closed issue, no relay carries it and no connector posts it on the
  task. The issue stays closed, so nothing is done with it there. Measured on smartwatchbanden#393: reopened at the question, the answer was "this is already
  how it works", and the task kept a reopened/closed pair for work that never restarted.
- A card stays where `report-issue` put it (`Filed`) unless a person moves it.
- A priority is set in Asana and, where wanted, typed onto the issue by a person.

**The task is never completed by this plugin, and no code path can do it** (Dave, September 1, 2026).
Closing a GitHub issue is a statement by whoever built the thing; resolving the ticket is a statement by
whoever asked for it, and only that person can make it -- after they have tested it. An automation that
ticks the box takes the one decision the ticket exists to record and replaces it with a guess, and it
does so silently, so nobody can tell an accepted change from an unverified one afterwards.

**Which task an issue belongs to is answered by three matchers, tried in order** -- 'tier' is the reach
label above and means nothing here. They are read by the backlog page, the go-live block's duplicate
check and the release-note task link, because a repo has two kinds of issue and only one of them was
ever written by this workflow:

1. **the marker** -- `<!-- asana-task: <gid> -->`, written in step 3 above. Authoritative.
2. **the header row** -- a `| **Asana** | ... |` row carrying a task URL. This is the shape of a
   ticket **imported from Asana**: a colleague filed it there, somebody copied it into an issue for
   analysis, and the link in its header was written for a reader rather than for a machine.
3. **a sole task URL** anywhere else in the body.

**The header-row matcher exists because of what the marker alone could not reach.** Measured in
`BWJ-ecommerce/smartwatchbanden` on 2026-09-01: of 55 issues, **4** carried a marker and **11** carried an
Asana link in a header row only, so a marker-only reader reached 4 of the 15 issues that carry an Asana
link at all.

**More than one different task, and no marker, resolves to nothing** -- the reader names the
candidates and moves on. It never guesses which ticket an issue belongs to, and the way to
settle it is to add a marker.

**The same three matchers answer every OTHER document that names an issue's Asana task** -- an item in
an audience release document above all, since no script writes that link and a session picks it by
hand. **Never take the first Asana URL in the body.** A body can link a task that is only context -- a
`**Referentie:**` line naming the CRO test a build came out of -- and that one usually comes first.
Measured in `BWJ-Development/smartwatchbanden`, v2.45.0 (inbound
[#2567](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2567)): an issue carried the CRO test's
task on its reference line and the development task in its marker, and the audience item linked the
test. A reader checking whether their own ticket had shipped could not find it. Where the matchers
resolve to nothing, the item gets no Asana link. It never gets a guessed one.

**A store may hand that picking to the cut itself, and then it is the marker alone, not the three
matchers** (`dkj-policy`'s `Get-ReleaseNoteTaskLink`,
[#2586](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2586)). Answer it in
`scripts/repo-config.ps1` with this same marker -- `@{ Marker = 'asana-task'; Url =
'https://app.asana.com/0/0/{0}'; Label = 'Asana task' }` -- and `cut-release.ps1` drafts the audience
section as one item per issue an audience entry closed that carries `<!-- asana-task: <gid> -->`, titled
from the issue and linked to the task: no entry prose, no PR link, because the reader is a colleague
asking which of their tasks are solved, exactly the shape the owner hand-corrected the v1.3.0 note into.
It reads the marker directly and never falls back to the header-row or bare-URL matchers above, because
the note is generated at cut time from entries a person has not looked at yet -- a match that needs
judgement has no reader here to make it. Answer it only where a solved task earns its place by the
owner's three rules: it carries an Asana card (the marker), it is a storefront change, and it is live --
the last two only checkable with the live-push record `live-preflight` writes (see that plugin's
[`live-preflight` skill](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-shopify/skills/live-preflight/SKILL.md#the-live-push-record-it-writes-for-the-cut-2570-2586)),
which is why a store answering this seam passes that record to every cut.

#### The go-live block -- written BEFORE the close, by the session that shipped the work

**The order is the rule** (BWJ/Maikel, September 17, 2026, inbound
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049)). An issue with a linked Asana
task carries a block for that task, telling the requester (today: Johnno) where to see the result --
and that block goes on the issue **while it is still open**, written by the session that shipped the
work, as the closing act of its own chain. The close then follows, and **the close carries the block**:
closing the issue as completed makes `asana-closed-message` post it on the task as its closed message
(#2818, the shape #2700 gave `asana-mirror`). Nobody pastes it. The closed message reads the newest
comment carrying the marker, so a block rewritten after a reopen is the one that goes. The name
*paste-ready* is kept for the marker and the functions, which match on it.

It is one comment on the **GitHub** issue -- not on Asana. The marker and the framing sentence above
the rules are fixed, because the duplicate check has to be able to recognise the comment. The block
between the rules has a fixed **shape** too, and it is written in the **colleague's language**:

```text
<!-- asana-paste-block -->

The closed message carries the block below into the Asana task when this issue closes as completed -- no paste needed:

---
— GitHub automation 🤖

GitHub issue [<owner>/<repo>#<n>](<issue url>) is now **closed**. It can be reopened anytime when something is still not working as expected.

TE BEKIJKEN OP

Het resultaat is hier te bekijken: <the actual link>

<where exactly to look, and how -- the session's prose>

WAT ER NU ANDERS IS

<what changed, in plain language -- the session's prose>

WANNEER HET LIVE KOMT

Het staat gepland voor de release van <weekday> <date>.

Zodra het live is, zie je het hier. Open ze tot die tijd in een privévenster: een browser die de link hierboven al heeft geopend, blijft op deze pagina's het resultaat tonen en niet wat er live staat.

<market> — <the bare live url>

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
the rules stays English in both cases, because it is read on GitHub, and so do the header and the
closed line, which are fixed on every board. **`TE BEKIJKEN OP` leads** (Dave,
#2700): where to look is what the requester acts on; the other sections keep their order.

**The facts are the script's, and the prose is the session's.** The link, the date, the version, the
live URLs and the ask are derived or fixed. *What changed*, *where exactly to look* and *what was
deliberately left out* are judgements about the work, like the task body step 2 writes, so the
session writes them and hands them over through `-ProseFile`. A section with nothing in it is left
out, heading and all, and is never replaced by a placeholder. **A block that hands the requester a new
task** rather than a result to look at has its prose written in a fixed order, and when the model
changes the whole instruction is rewritten rather than only the delta. The order is in
[`golive-block`](skills/golive-block/SKILL.md#when-the-change-hands-the-requester-a-task) (#2878).

**The marker sits OUTSIDE the block, and the block is what travels.** Everything between the two
`---` rules is what a person pastes into Asana; the marker and the framing sentence stay on GitHub. A
marker inside the block would arrive in the Asana task as visible junk. The duplicate check matches the
marker and nothing inside the rules, which is what leaves the block's words free to follow the colleague.

**Who closes the issue is the Asana task's ASSIGNEE** (BWJ, September 23, 2026, inbound
[#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352)). The assignee is the one in
conversation with the requester, so they read the block on the issue, paste it into the task where it is
needed, and close the issue once it is right. It is not a fixed relayer: a page naming one person as the
relayer for every ticket was corrected on exactly that point the day it was retired.

#### Store-admin prerequisites -- a checklist on the issue, and the block waits for it

**Some changes need work on the store, not in the theme**: a metafield definition, a menu, a page, an
app embed, a store setting. The theme can read a metafield, but only its definition makes the field
appear in admin. Measured in `BWJ-Development/xoxowildhearts` (#383, #391, #399): the PR named such a
definition in its prose, nobody created it, the issue closed, and the go-live block told the reviewer
to tick a checkbox that did not exist
([#2885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2885)).

**The session that finds such a step writes it on the issue as a checklist, in a comment of its own:**

```text
<!-- store-admin-prerequisites -->
**Store-admin prerequisites** -- work this change needs on the store itself, outside the theme. Tick each one once it is done on the live store.

- [ ] <what, and where in admin: "Metafield definition `custom.show_menu_image` (collections, true/false) -- Settings > Custom data > Collections">
```

**The issue, because it is the one record both moments can read** (Dave, October 7, 2026). The branch
document is gone by the close, and the go-live block looks up no pull request. Only the task-list lines
after the marker count, up to the next heading or HTML comment, and a box is ticked when GitHub writes
`[x]`. The read errs towards holding back: a box with no text, or a marker with no box under it, counts
as open. Whoever does the step on the
store ticks it.

- **`build-golive-block -Post` refuses while a box is open**, and while it cannot read the issue.
  `-Force` gets past it, as it does for the duplicate check. The block tells a colleague to go and
  look, and what they would look at is not there yet.
- **The preview handover warns** and does not refuse, because a reviewer may well look before the
  store is set up. `-OutFile`, the run the page embeds, prints the open items, and the page names them
  ([`PREVIEW-portable.md`](PREVIEW-portable.md#the-shape-of-the-handover)).
- **No checklist means no prerequisites.** The check cannot see a step nobody wrote down, so the
  question *does this change need anything on the store?* is asked while the work is built.

#### What the block asks of the requester -- and the two closes it separates

**Five rules, from BWJ's corrections to the first blocks that actually reached Asana** (Maikel,
September 18, 2026), carried here on inbound #2352 once the consumer page holding them was retired.
`build-golive-block.ps1` writes the section that implements the middle three; the other two are about
the block's position and the issue.

1. **The first line says where the message comes from.** The block opens with the automation's header
   -- *"— GitHub automation 🤖"* -- and its closed line names the issue as a link, so a reader knows
   from line one that there is an issue behind it, rather than finding out at the foot after reading
   it as hand-written.
2. **The requester judges the result themselves, and their answer closes the TASK.** Not the gates, not
   the merge and not the session that built it: no gate proves that something *looks* right, which is
   the same reason a visible result stops before its pull request. So the block asks for the look
   instead of assuming it.
3. **A rejection asks for two things, and starts a new round.** *What* is not right yet **and** *what*
   exactly should change -- the first alone hands the next round another guess. The rejection is
   researched with the issue still closed, and the issue is reopened only once that shows something has
   to be built (#2856, under *Reopening an issue* above); then the cycle starts again with a new result
   to look at.
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

**Two things made the old order (block at the close) unworkable:**

1. **Nobody returns to a closed issue.** A comment posted at the close appears underneath an item that
   has just left every open-issue view, so whether anybody ever sees it depends on somebody going back.
2. **The link could not be filled in by anything but the session.** "Where the result can be viewed"
   depends on what the ticket was about, and nothing a workflow reads says that reliably. **The session
   that built the thing does know it**: its preview URL, or the live page after a push. Composing the
   block in that session removes the placeholder link instead of working around it.

**It is gated on the Asana link, not on the `CRO` label** (since retired, #2869). A mirrored task is a mirrored task, so the
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
way through. `adopt-bwj-development`'s step 2 proposes the two matchers, keyed on the same marker and
task-link shapes this page already defines above, so a repo that has run that step is enforced rather than
reminded. **A repo that has NOT stated the seam is exactly where this paragraph left it before #2120**: the
rule stands, nothing reads it, and the difference between a correct ship and a wrong one is whether the
session remembered. The measurement behind that sentence is one of each, days apart, in the same repo.

##### The go-live half -- the facts the requester asks for next

**The block used to answer *where*, and stop there** (Dave, September 18, 2026,
[#2100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2100)). The requester's next
question is always *and when do I actually see it?*, and the ticket is the only place they are looking,
so the block carries more facts: the release day, the live URLs, and a version only where one is given. It is one of the two steps this plugin adds to `dkj-policy`'s
cycle -- the other is the storefront-visibility step in
[`PREVIEW-portable.md`](PREVIEW-portable.md) -- and both are indexed in
[the README](README.md#what-the-cycle-gains-here).

| fact | where it comes from |
|---|---|
| **when it goes live** | the next release day. BWJ cuts on **Mondays**, so it is the next Monday -- strictly the next one, never today, because a Monday's release is cut before the day's work closes |
| **which version** | **left out of the block unless `-Version` names it** ([#2620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2620)). The newest `vX.Y.Z` tag bumped by what the pending changelog has earned *so far* is printed on the console for the session, but every entry still to land before release day can raise it, so it is a guess -- and the requester quotes the block back as a fact |
| **where to look once it is live** | the **live** storefront URL per market for the pages the change touched: the same URLs a preview pair is built from, **bare**. A bare URL renders the preview in any browser that opened the result link first ([#2477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2477)), so beside a result link the list's label says to open it in a private window before the release. It is not pinned to the live theme id the way a handover's control half is: to a colleague `?preview_theme_id=<live id>` reads as a preview link under a label saying *live* ([#2619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2619)) |

**It is written by a script, because all three are derivable and none of them is a judgement** --
[`build-golive-block.ps1`](skills/golive-block/SKILL.md), which prints the block and, with `-Post`,
puts it on the issue. That is the difference from the link in the first line, which stays a person's
answer: a plausible wrong link is worse than a missing one.

**The release day is a PLAN, and the block says so in that word.** *"Het staat gepland voor de
release van maandag 22 september"* is a cadence, not a commitment anybody made: a release can slip.
Writing it as *will* would hand a colleague a promise this workflow never made, on the one surface they
will quote back. The version was the other half of that sentence until #2620, and no wording saved it:
a tier-1 entry landing on the Friday turns a predicted patch into a minor, and *"als versie v2.45.1"*,
six days out, was rejected by the owner as a number nobody could know.

**Where a fact cannot be derived it is left out, never guessed.** A version is named only when `-Version` says it; a repo that has declared no storefront markets gets no live-URL list. The whole reason the link in the first line is a person's to
fill in is that a plausible wrong answer is worse than a missing one, and that reasoning does not stop
applying one paragraph further down.

**The script does not touch Asana.** It writes the GitHub half only, and the close carries it across:
the `asana-closed-message` workflow posts the block on the task when the issue closes as completed.

**It carries the marker, and only the marker.** The duplicate check (`Test-AsanaPasteBlockPosted`, which
makes the script refuse a second block unless told otherwise) rides on `<!-- asana-paste-block -->`,
the machine marker tried first and unconditionally. The second matcher is a lead sentence somebody typed
by hand -- `Fill in the link below and paste the block into the Asana task` -- quoted here so a block can
be written by hand. The backstop that used to post a placeholder-only block on a close with no block on it is
retired with the mirror (Dave, October 5, 2026) and did not come back: an issue closed without a block
has none, and its closed message goes out with the header and the closed line only. So does one whose
comments the workflow could not read (it reads them through REST, `gh api .../issues/<n>/comments`), and
its run log then says the read failed, with gh's exit code and error, rather than that no block was on
the issue (#2875).

### 5. (Retired October 5, 2026) The Asana prio score no longer comes back as a label

The daily run that read the board's **`Prio-Score`** field and set one of `prio-4` / `prio-3` / `prio-2` /
`prio-1` on the GitHub issue is retired with the rest of the mirror (Dave, October 5, 2026), and nothing
replaces it. **The four labels themselves stay**: the source repo's own tracker ranks its issues on them,
typed by whoever files, and a BWJ repo's priority label is now typed by a person too, from the score
they read in Asana. The step keeps its number so the references to step 8 stay valid.

### 6. (Retired October 5, 2026) The board's sections are no longer moved automatically

The board's numbered sections are still the stages a colleague reads, from *a colleague put this on your
name* to *tested and good*, and `Get-AsanaStageMap` still names what each number means. **But no workflow
moves a card between them any more** (Dave, October 5, 2026): the stage sweep, the three GitHub Project
statuses that drove it, the `ReadyToTest` promotion on feedback and the terminal-stage guard are retired
with the mirror, and `Get-GithubStatusMap` is no longer read. **`Filed` is the one section the tooling
writes**: `report-issue` creates the card there and reads the stage map to find it. Every other move is a
person dragging the card, so a card stays in `Filed` after the issue is built, closed or reopened until
somebody moves it.

The two ends were always the submitter's -- their untriaged inbox at one end and `Completed` at the other
-- and that is unchanged: **this plugin never ticks a task off** (step 4).

#### Setting `awaiting-more-info` is still writing the question -- one act, and the issue stays open

**The label is a GitHub-side flag now, not a card mover** (inbound
[#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352), carrying a rule that lived only
in a consumer page until September 23, 2026). It used to park the card in the blocked column; with the
mirror retired it moves nothing in Asana, so the question has to reach the requester some other way. The
go-live block of step 4 is one exit that ends with the requester; `awaiting-more-info` is the second.
Measured in `BWJ-Development/smartwatchbanden`,
[#702](https://github.com/BWJ-Development/smartwatchbanden/issues/702) and
[#721](https://github.com/BWJ-Development/smartwatchbanden/issues/721): a card sat a day in the
blocked column with no question on it, because the procedure prescribed a message for delivered work
only -- and a card with the submitter and no question is a waiting room nobody knows the subject of.

**So the label and the comment are ONE act**, done by the session that knows what was investigated, at
the moment the issue is parked -- not later, by somebody reconstructing the dossier. The comment goes on
the issue, carries the same `<!-- asana-paste-block -->` marker below the text so the duplicate check
recognises it, and is pasted into the task by its assignee. Unlike the delivered-work block nothing carries
it: the issue stays open, so no closed message fires, and the question carries no `---` rules, so a later
closed message never mistakes it for a block. Its shape:

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

**This exit does NOT close the issue by default**, where the delivered-work exit closes it one act after
the block. That is not an inconsistency: there the development work is finished and only the judgement
is with the colleague, while here the work itself is stalled on something only they can supply -- which
is still an open item of ours, and belongs in the list where work is tracked. **Nor does the session
remove the label**: whoever brings the answer does.

**Closing while waiting is the one sanctioned alternative** (Dave, October 3, 2026,
[#2732](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2732)), for an owner who wants the
waiting ticket off the open list. Close it as **not planned** and **keep the `awaiting-more-info` label
on through the close**, so the pair still reads as *waiting for information* and not as a rejection. The
question is written first, exactly as above. (The CI comment that used to say so on the task is retired.)

### 7. What still needs a person

- **Setup, once per repo:** the classification labels (`bug`, `feature`, the reach label, the four prio
  labels and `awaiting-more-info`) and the Asana config seam. The
  [`adopt-bwj-development`](skills/adopt-bwj-development/SKILL.md) skill walks this. **No CI secret and no
  `.github/` file is needed for the mirror any more.**
- **Everything that happens to a card after it is filed.** `report-issue` puts it in `Filed`; moving it
  through the board's sections, pasting the go-live block into it and ticking it off are people's acts.
- **Deciding a ticket is blocked on the submitter.** The `awaiting-more-info` label is a flag on the
  GitHub issue, and no automation sets, clears or reads it into Asana. Putting it on is a judgement about
  whether the request can proceed -- and it is one act with writing the question, in the form step 6
  prescribes; taking it off says the answer arrived.
- **Scoring the ticket.** A priority is the team's call, made in Asana; typing the matching `prio-N` label
  onto the issue is a person's act now (step 5).
- **A token that can reach the tickets, locally.** `ASANA_PAT` is a *user* token: it can only see the
  workspaces that user is a member of. It is still what [`build-backlog-page`](skills/build-backlog-page/SKILL.md)
  reads the tasks with, from the session's environment, and an imported ticket often lives in the
  requester's own Asana organisation rather than the board's.
- **Closing an Asana-linked issue, once the go-live block is on it.** Step 4's order: the session writes
  the block while the issue is open, and the task's assignee closes it. That is why such a branch ships
  with `-NoResolves` -- a `Closes #<n>` would have GitHub close the issue at the merge, with nobody having
  confirmed anything. Where the repo has stated `Get-ResolvesExemptMatchers` (inbound #2120), the
  resolves gate refuses that `-Resolves` instead of leaving it to memory.
- **Resolving the ticket.** The colleague who filed it ticks it off once they have tested the change, and
  nothing in this workflow will do it for them.
- **The Asana project answer.** `Get-AsanaProjectGid` has one correct value per repo: **the board the
  team reads**, and there is exactly one of those (Dave, September 2, 2026). A task filed anywhere else is
  on no board a colleague looks at.

### 8. A ticket that arrives FROM Asana -- whose it is, and the form it takes

Steps 1 to 7 run outward: a finding made here is filed on GitHub and mirrored onto the board. **Work
also arrives the other way** -- a colleague files a request in Asana as a desired outcome, and somebody
has to decide whether it can be built at all before a branch is worth creating. The rules for that
layer are `dkj-policy`'s, under
[Ticket work -- the layer before the branch](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#ticket-work--the-layer-before-the-branch),
and they deliberately leave a list of questions to the repo under
[What your repo answers](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/CONTRIBUTING-portable.md#what-your-repo-answers).
**This step is BWJ's answer to that list, once for all three stores**, so none can drift from the others.
It restates none of the rules; read those first.

**It lived in `smartwatchbanden`'s own tree until September 23, 2026**, as the only copy anywhere --
`xoxowildhearts` had none -- and moved here on inbound
[#2353](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2353), because an answer both stores
owe is this plugin's rather than one repo's. **Its reach is the three stores**: `smartwatchbanden`,
`xoxowildhearts` and `phone-factory`. The last was added by Dave on October 2, 2026
([#2712](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2712)), because the Lightspeed store
gets an Asana board of its own, so colleagues' requests reach it the same way. `dkj-claude-plugins` was
admitted to this chapter for *filing* (see the top of this page), and nothing reaches that repo from
the Asana board as a request, so there this step has nothing to apply to.

#### Whose ticket is it -- the Asana assignee decides, and nothing else does

**A task on the board is not by that fact an assignment to the dev team.** Board membership says the
ticket is tracked; it does not say the work is ours. Before a task becomes a GitHub issue -- and again
before anybody claims that issue -- read the **assignee of the Asana task**, and answer three things:

- **Is it assigned to somebody outside the dev team?** Then it is not an assignment. Either leave it
  unmirrored, or mirror it and open it as **blocked on that person** rather than as work -- which is
  what the `awaiting-more-info` label of step 6 says.
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
call. Nothing moves the card after that (step 6 is retired), so a person moves it through the board's
sections as the ticket progresses.

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
- **No CI mirror, and one closed message** (Dave, October 5, 2026). The card moves, the sweep, the prio
  sync, the label comments and the backstop block were retired together, and keeping the board in step
  with the tracker is a person's act. The closed message came back (#2818): it is the one moment the
  requester has something to do, and the block it carries is already written by then. The reopened
  message came back beside it (#2854), because without it a requester goes on testing a result that is
  being reworked.
- **The block before the close, and not at it**, because the close is the only event a person in this
  chain actually performs, and hanging the composition on it put the paragraph underneath an item that
  had already left every open-issue view. Writing it first turns the close into a **receipt** -- the
  issue is open for exactly as long as the block is outstanding -- and it puts the composing in the
  hands of the one party that knows the link.
- **An update and not a tick**, because the two are different claims by different people. The build
  is finished when the person who built it says so; the request is finished when the person who made
  it says so. A tracker that lets one stand in for the other cannot afterwards tell you which of its
  closed tickets anybody actually looked at.
- **A number in the section name, and not a GID per section in a config**, because the two halves
  have different owners. The number identifies the column; the words are the team's and change
  whenever one reads badly. The *meaning* of each number is in the `Get-AsanaStageMap` seam, because that
  half belongs to the board: it was a literal in a script for one afternoon and the board changed shape
  the same day. Today `report-issue` is its one reader, to find `Filed`.
