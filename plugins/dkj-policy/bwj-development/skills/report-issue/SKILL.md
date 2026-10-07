---
name: report-issue
description: >-
  File a discovered issue the BWJ way -- GitHub first (the source of truth, classified at creation with
  its labels: bug or feature, and the reach label), then -- only where the issue carries the reach label -- a
  colleague-facing Asana task, cross-linked both ways. Use this in a repo that runs the BWJ procedure -- smartwatchbanden or xoxowildhearts
  (whichever org), the plugin's own source repo dkj-claude-plugins, or phone-factory -- whenever a real finding
  needs tracking: a bug, a broken customer-facing behaviour, a stale doc, a decision that is
  not yours to make. The Asana card lands in the board's `Filed` section -- tracked on GitHub now --
  because the board's sections are the cycle's stages. The GitHub issue always gets created
  even if Asana is unreachable, so the source-of-truth guarantee holds. Nothing here resolves a ticket
  and nothing downstream does either: closing the GitHub issue as completed posts one closed message on
  the task, and reopening it posts one reopened message (the asana-closed-message workflow); the card
  stays where this skill put it unless a person moves it, and the colleague who filed it ticks it off.
---

# report-issue -- the BWJ GitHub-first, Asana-mirrored filing procedure

This skill has **no script of its own** -- it is a procedure over `gh` and the Asana MCP, because the
colleague-facing translation is a judgement call, not a transform. **One of its rules is held by a hook
rather than by this page**: the reach-label gate in step 2 below. The full rule it implements is in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md); this page is the steps.

## Before you start

- Confirm you are in a repo permitted to run this procedure: `git remote get-url origin` ends in
  `smartwatchbanden`, `xoxowildhearts`, `dkj-claude-plugins` or `phone-factory`. It applies nowhere else. **Match the
  repo NAME, not the org** -- the two stores are no longer in one organisation (`smartwatchbanden`
  moved to `BWJ-Development` on September 7, 2026, its `BWJ-ecommerce` predecessor is archived, and
  there is no redirect), so a check written against an org path refuses in the live repo it was meant
  to serve. The third name is this plugin's own source repo, admitted by Dave on September 14, 2026,
  and the fourth is BWJ's Lightspeed store, admitted on October 2, 2026 (#2705); both decisions, and
  what they cost, are in [`adopt-bwj-development`](../adopt-bwj-development/SKILL.md) step 0.
- Confirm `gh auth status` is clean.
- Read `Get-AsanaWorkspaceGid` and `Get-AsanaProjectGid` from the repo's `scripts/repo-config.ps1`.
  If either is missing, run [`adopt-bwj-development`](../adopt-bwj-development/SKILL.md) first.
- Read `Get-AsanaIssueFieldGid` and `Get-AsanaTypeFieldGid` from the same file. Both are optional and
  default to `$null` -- a board carrying neither the `Github Issue` nor the `Github Type` custom
  field leaves them unset, and step 2 skips whichever one is missing.
- Read **`Get-ReachLabel`** from the same file -- **the name GitHub stores for the reach label**, which
  every command below writes rather than a literal. Optional, and `minor` is the default since
  [#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870) -- which is a CHANGE of
  default, not a restatement of one: it was `tier-1` until then, so a store that has renamed nothing
  and answered nothing now types a label it does not have. Where the seam is answered, that answer is
  the name -- and reading it is not optional politeness: `gh issue create` **fails outright** on a
  label the repo does not have, atomically, so you get no issue at all rather than one without a label
  ([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)).
- **Probe the BOARD, not the tool list.** Read the project `Get-AsanaProjectGid` names -- the same
  read step 2 makes for the section and the select-field options, only made earlier, so it costs no
  extra round trip and its answer carries forward. **Availability and authorization come apart:** a
  connector can be registered, authenticated and answering, and still be bound to a *different
  workspace* than the one `Get-AsanaWorkspaceGid` names -- and then the tool list looks perfectly
  healthy while every call against this board returns `unauthorized`. A preflight that asks only
  whether the tools are there reports green for a connection that cannot do the job, and the session
  learns it from a failing `create task` in step 2, half way through the procedure the preflight
  exists to get ahead of.
- **A missing tool and an `unauthorized` board take the same branch: still do step 1, then stop with a
  clear note -- never skip the GitHub issue.** Say in that note that the connector is authorized
  against the **wrong workspace**, because *available but unauthorized* reads to a session as a
  connector it broke, whereas the remedy is a re-authorization against the workspace the seam names
  and is not something a session can do from here. Measured on a `smartwatchbanden` checkout,
  September 15, 2026 ([#2028](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2028)): both
  registered Asana connectors authenticated and both `Not Authorized` for the project the seam names,
  while a script over a personal `ASANA_PAT` read that same board fine -- so the connector was bound to a
  different workspace than the token, and only the MCP was wrong.

## Step 1 -- the GitHub issue (always)

Apply the `dkj-subagents-alpha` filing bar in full: verify the finding still stands by reading the code, doc
or output behind it; search the tracker for a duplicate; one subject per issue; state what you
measured versus inferred. Then file it **classified** -- every label on the create itself, never left
for a later pass:

```bash
gh issue create --repo <owner>/<repo> --title "<precise technical title>" --body "<full detail>" \
  --label <bug | feature> [--label "<reach label>"]
# gh prints the new issue's URL; its last segment is <n>
```

| what to set | how to decide it |
|---|---|
| the kind (`--label bug` or `--label feature`) | **always exactly one of the two** (#2783): **`feature`** for something new being added, **`bug`** for something that exists and has to change. A doc finding is one of them too -- a missing page is a `feature`, a wrong one a `bug`. There is no third kind and no `documentation` label |
| the reach label (`Get-ReachLabel`, default `minor`) | **only** where management or the commissioner would notice it. The test is whether that reader notices the **defect**, not whether the file renders to them: a customer-facing template with a developer-only defect is tier 0, and a build script whose breakage stops a release the business is waiting on is not. **In doubt, leave it off** |

**Never set `CRO`.** That label was retired on October 7, 2026
([#2869](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2869)): an issue raised by the CRO
team gets the kind and the reach label like any other.

**Write it in English -- the title as much as the body.** Every consumer of `dkj-policy` runs this same
cycle, so the issue takes the workflow's language no matter which language the session is being spoken
to in; the title carries it furthest, into every list, every filter and every mirrored card. The
carve-out is a person's own words -- a request quoted from an Asana ticket stays as they wrote it. Both
halves are in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#1-github-first----github-is-the-source-of-truth).

**Do not set a GitHub issue type.** The BWJ repos stopped setting issue types on October 3, 2026, in
favour of labels alone ([#2750](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2750)), so
`bug` and `feature` carry what the type used to. The reasoning behind every field is in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#classify-it-as-you-file-it----labels-only-all-set-at-creation).

Note the issue number and URL. If the finding collapses on verification, stop here and say so -- do
not file a weakened version, and do not create an Asana task for a non-issue.

**On an issue that is already filed** -- yours from an earlier run, or somebody else's -- the same
labels are added afterwards:

```bash
gh issue edit <n> --repo <owner>/<repo> --add-label bug --add-label "<reach label>"
```

## Step 2 -- the Asana task (a translation, not a copy)

**Only for an issue carrying the reach label.** Step 1 has just answered whether a colleague will notice
this, and that answer decides whether they get a card: no reach label means tier 0, a finding only this
repo's developers meet, and it stays **GitHub-only** -- skip steps 2 and 3 and say so in step 4. The
rule and the measurement behind it are in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#2-then-asana----a-translation-not-a-copy). Two
cases are not new tasks and are not gated by it: a ticket that **came from Asana** already has its card
(see below), and an issue that **gains** the reach label later is mirrored then, by running steps 2-3
at that moment.

**The gate is enforced, not only stated** (inbound
[#2482](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2482)). This plugin's
`hooks/guard-asana-mirror.ps1` fires on every Asana create-task call. It reads the labels of each GitHub
issue the task cites on an admitted repo, and it **refuses** the call where the reach label is not among
them. It was needed because the sentence above was missed on the version that carried it:
`smartwatchbanden#770`, filed with only `documentation`, still got a card. A refusal means step 1's
answer was *tier 0*, so skip to step 4. Where a colleague genuinely will notice the issue, the label is
what was missing: add it, then create the task again. Where `gh` cannot answer, the hook lets the call
through with a warning naming the issue it could not check. A wrong card is cheap to remove, while a
board that stalls whenever the tracker is unreachable costs the whole colleague-facing half.

**Removing a wrong card means reading it first, and sometimes only unlinking it** (inbound
[#2508](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2508)). Before you offer or run a
delete, read the task on the Asana side: whether it is completed, whether it has human comments, which
projects it sits in, and who created it. A task that is completed or carries a human comment is never
offered for deletion. Unlink it from the issue instead. Any other offer shows that state beside the
title. The rule and the case behind it are in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#a-task-is-read-before-it-is-offered-for-deletion-and-a-task-a-person-has-worked-is-never-deleted).

Compose the task body from the fixed skeleton -- plain language, outcome-framed, no code or repo
jargon:

```text
Tracked on GitHub: <issue URL>
What is wrong:   <one or two plain sentences -- what a visitor or colleague sees>
Where:           <which store, and which page or flow>
How urgent:      <blocking a sale / visible but not blocking / cosmetic / not customer-facing>
```

**The issue link is the FIRST line of the task's description**, above everything else, so the card
answers *where is this tracked* before a colleague has read a word of it
([#2653](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2653)).

**The four headings stay as written; what goes under them follows the colleague who reads the card.**
This is the one place in the procedure where the language turns over -- the issue you just filed is
English and this card need not be. A ticket that colleague filed themselves is quoted rather than
translated, and its language is never corrected.

Create it in the project `Get-AsanaProjectGid` names, in the workspace `Get-AsanaWorkspaceGid`
names, via the Asana MCP `create task` tool. Note the task GID and URL.

**Where `Get-AsanaIssueFieldGid` returns a GID, set that custom field on the same `create task`
call, to the full issue URL** -- the same URL already going into the `Tracked on GitHub:` line
above, never the bare issue number: Asana only renders a text custom field as a clickable link when
its value is a complete URL. Where it is `$null` -- the default, and the common case -- skip the
field silently; the board carries none and there is nothing to set.

**Where `Get-AsanaTypeFieldGid` returns a GID, set that one on the same call too -- from the kind
label step 1 chose, never from a fresh reading of the finding:** `bug` is `Bug`, `feature` is
`Feature`, and neither is `Task`. The board's field offers exactly those three options, so there is
nothing to decide here: the answer is one step old and carrying it forward is the whole point. It is a **select** field, though, so the value is an option GID rather
than the word. Resolve it from **the project read the preflight already made** -- ask for the options
there, in the same call that proved the board reachable, and carry both forward:

```text
opt_fields: custom_field_settings.custom_field.gid,custom_field_settings.custom_field.name,
            custom_field_settings.custom_field.enum_options.gid,custom_field_settings.custom_field.enum_options.name
```

**Name every subfield -- Asana's `opt_fields` takes no wildcard**, so `custom_field_settings.*`
returns the options *absent* rather than an error, and the write then silently has nothing to send.
Match the option whose `name` is the one step 1's label maps to, and send its `gid`: a
**multi-select** field takes an **array** of option GIDs, a single-select the bare GID -- the BWJ
board's is multi-select, so `["<option gid>"]`. **If that name matches no option on the board, write
nothing and say which option was missing** -- that is a board somebody has rebuilt or renamed, and
guessing puts a wrong type on a card a colleague reads as authoritative.

Where it is `$null` -- the default -- skip it silently, exactly as for `Github Issue` above.

**Put it straight into the `Filed` section** -- the board's sections are the cycle's stages, and
`Filed` means *tracked on GitHub now*. Read `Get-AsanaStageMap` from `scripts/repo-config.ps1` for the
section **number** that stage is (leave it unset and the default is `3`), then read the project's
sections and take the one whose name starts with that number. The words after the number are the
team's and tell you nothing, so match on the **number** only.
`WORKFLOW-portable.md` step 6 says what remains of the stage model: `Filed` is the one section the
tooling writes, and a person moves a card through the others. **If the project has no numbered sections,
place nothing and say so** -- that board is not a pipeline.

**On a ticket that came the other way** -- filed in Asana by a colleague and copied into an issue for
analysis -- the task already exists and is sitting in `Requests`, their untriaged inbox. Filing the
GitHub issue is exactly what `Filed` records, so **move that card there** rather than
creating a second task. Leaving it in `Requests` is the failure inbound
[#1217](https://github.com/DaveKJohn/claude-code-specialists/issues/1217) measured: the issue existed
and the board still read `New`, so to the colleague waiting on it the request looked untouched, and
they chased it in the one place that had no answer.

**But the colleague's task need not be on this board at all** (#2699). A ticket filed in another
project -- `SEO`, a workload overview -- is not a member of the project `Get-AsanaProjectGid` names, so
there is no card here to move, and the two custom-field writes above are refused (`Custom field with ID
<gid> is not on given object`): a field belongs to the board's project, not to the task. **Read the
task's `memberships.project.gid` before the move**, and where this board is not among them:

- **skip the move and both field writes**, and say so in this step's report. Do not create a second
  task on the board to stand in for it: that is the second task the paragraph above rules out, and
  the colleague would be watching the other one.
- **still make the two writes below** -- the link on top of the description and the `created:` comment
  -- because they are written on the task itself, wherever it lives.
- **name the one act that is left to a person**: adding the task to this board in Asana (*Add to
  project*, into the `Filed` section). The session cannot do it: the Asana MCP exposes no
  add-to-project call. Until a person does, the task is on no board of this repo's.

**That existing task then gets two more writes, both in this step** (#2653):

1. **The issue link goes on top of its description.** Prepend `Tracked on GitHub: <issue URL>`, the
   skeleton's own label, and a blank line to the task's notes. Everything the colleague wrote stays below it, unchanged. Write through
   `html_notes` rather than `notes` when the task has formatting, or the rewrite flattens it. If the
   first line already carries this issue's URL, a re-run leaves it alone and never adds a second one.
2. **One comment on the task, in exactly this form**, with only `<owner>/<repo>#<n>` and the issue
   URL filled in:

   ```text
   — GitHub automation 🤖

   GitHub issue <owner>/<repo>#<n> is created: this Asana task is now in development.
   ```

   Post it as `html_text`, with the issue name as the link and **created:** in bold:
   `<body>— GitHub automation 🤖` + two newlines + `GitHub issue <a href="<issue URL>"><owner>/<repo>#<n></a> is <strong>created:</strong> this Asana task is now in development.</body>`.

   It is the one fixed form this skill posts. The CI mirror's CLOSED and REOPENED forms came back as the
   `asana-closed-message` workflow (#2818, #2854), and its CLOSED WHILE WAITING FOR INFORMATION form
   (#2732) stays retired since October 5, 2026
   ([#2656](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2656) fixed the wording, superseding
   #2653's). The form is fixed and English on every board, whatever language the card is
   written in. Its header line is what tells a colleague that the account holder did not type it.
   Post it after the move.

If Asana is unreachable -- or a write is refused that the preflight's read could not cover -- report
the GitHub issue URL, say the mirror did not happen and why, and stop. The issue can be mirrored later
by re-running this skill's steps 2-3.

## Step 3 -- cross-link both ways

- **GitHub issue** -- append to the body (keep everything already there):

  ```text
  Asana: <task URL>
  <!-- asana-task: <numeric task GID> -->
  ```

  The marker holds the bare numeric GID only. `gh issue edit <n> --repo <owner>/<repo> --body "<full new body>"`.

- **Asana task** -- the `Tracked on GitHub:` line already carries the issue URL, so nothing more is
  needed unless you created the task before you had the issue URL; in that case edit the task notes
  to add it **as the first line**. A task that came from Asana got its link and its comment in step 2.

**The only comment this procedure writes is step 2's, on a ticket that came from Asana.** A task this
procedure created itself gets none. Any comment an agent writes **opens with a header line** that
says it is an automated message and not the account holder's own words, and the content comes after
it. Step 2's comment has its header fixed in place. The MCP posts as
the person who connected it and cannot edit or delete a comment afterwards, so a comment without that
line reads as that person's own words for good. The rule and its reason are in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#a-comment-an-agent-writes-on-a-task-says-so-in-its-first-line)
([#2476](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2476)).

## Step 4 -- report

Give both URLs and stop -- or, for an issue without the reach label, the issue URL and the sentence
that it is GitHub-only because it is tier 0, so the missing card reads as a decision rather than a
failed mirror. **Do not resolve anything, and do not promise that anything else will.**
Closing the GitHub issue as completed posts one comment on the task: the `asana-closed-message`
workflow's closed message, carrying the go-live block (the `golive-block` skill) the shipping session
left on the issue (#2818); reopening it posts the reopened message (#2854). That is all it does. The rest
of the retired `asana-mirror` CI (moving the card, the sweeps) did not come back, so the card stays in `Filed` unless a person
moves it, and the task stays open until the colleague who filed it ticks it off. Nothing in this chain
completes a task, and nothing puts a card in `Completed` either.

**Say which section the card is in**, alongside the two URLs. It is the half a colleague can see
without a GitHub account, and it is the one part of this run somebody may need to correct.

**A ticket blocked on the person who filed it gets the `awaiting-more-info` label.** It is a flag on the
GitHub issue only now: it moves no card. **Setting it and writing the question are one act**: the
comment asking the requester what you need goes on in the same movement, in the form
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#setting-awaiting-more-info-is-still-writing-the-question----one-act-and-the-issue-stays-open)
step 6 prescribes, and the issue stays open -- unless the owner wants it off the open list, in which case
it is closed as **not planned with the label kept on**, the one sanctioned alternative. Take the label
off when the answer arrives.

**Name the kind and the tier you chose, and why.** You infer both rather than asking for them -- the
reach question is answerable from the finding itself, and the whole backfill of 135 issues was
classified from the issue text alone. Naming the call here is what makes it correctable: it puts the
answer in front of the person who knows the store, at no extra turn, beside the one line that changes
it (`gh issue edit <n> --repo <owner>/<repo> --add-label "<reach label>"`, or `--remove-label`). Adding
it afterwards also means running steps 2-3 then, since the card follows the label.
