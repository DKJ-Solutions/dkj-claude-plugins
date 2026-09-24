---
name: report-issue
description: >-
  File a discovered issue the BWJ way -- GitHub first (the source of truth, classified at creation with
  its issue type and the reach label), then -- only where the issue carries the reach label -- a
  colleague-facing Asana task, cross-linked both ways. Use this in a repo that runs the BWJ procedure -- smartwatchbanden or xoxowildhearts
  (whichever org), or the plugin's own source repo dkj-claude-plugins -- whenever a real finding
  needs tracking: a bug, a broken customer-facing behaviour, a stale doc, a decision that is
  not yours to make. The Asana card lands in the board's `Filed` section -- tracked on GitHub now --
  because the board's sections are the cycle's stages. The GitHub issue always gets created
  even if Asana is unreachable, so the source-of-truth guarantee holds. Nothing here resolves a ticket
  and nothing downstream does either: closing the GitHub issue only makes the asana-mirror CI workflow
  post an update saying the work is ready to test and move the card to `ReadyToTest`, and the colleague who
  filed it ticks it off.
---

# report-issue -- the BWJ GitHub-first, Asana-mirrored filing procedure

This skill has **no script of its own** -- it is a procedure over `gh` and the Asana MCP, because the
colleague-facing translation is a judgement call, not a transform. The full rule it implements is in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md); this page is the steps.

## Before you start

- Confirm you are in a repo permitted to run this procedure: `git remote get-url origin` ends in
  `smartwatchbanden`, `xoxowildhearts` or `dkj-claude-plugins`. It applies nowhere else. **Match the
  repo NAME, not the org** -- the two stores are no longer in one organisation (`smartwatchbanden`
  moved to `BWJ-Development` on September 7, 2026, its `BWJ-ecommerce` predecessor is archived, and
  there is no redirect), so a check written against an org path refuses in the live repo it was meant
  to serve. The third name is this plugin's own source repo, admitted by Dave on September 14, 2026;
  the whole of that decision, and what it costs there, is in
  [`adopt-dkj-policy-bwj`](../adopt-dkj-policy-bwj/SKILL.md) step 0.
- Confirm `gh auth status` is clean.
- Read `Get-AsanaWorkspaceGid` and `Get-AsanaProjectGid` from the repo's `scripts/repo-config.ps1`.
  If either is missing, run [`adopt-dkj-policy-bwj`](../adopt-dkj-policy-bwj/SKILL.md) first.
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
  while `asana-mirror`'s CI half drove that same board green over its own `ASANA_PAT` -- so the two
  halves were bound to different workspaces and only the MCP was wrong.

## Step 1 -- the GitHub issue (always)

Apply the `dkj-subagents-alpha` filing bar in full: verify the finding still stands by reading the code, doc
or output behind it; search the tracker for a duplicate; one subject per issue; state what you
measured versus inferred. Then file it **classified** -- the labels on the create itself, and the type
by the call straight after it, in the same step, never left for a later pass:

```bash
gh issue create --repo <owner>/<repo> --title "<precise technical title>" --body "<full detail>" \
  [--label "<reach label>"] [--label documentation]
# gh prints the new issue's URL; its last segment is <n>
gh api --method PATCH repos/<owner>/<repo>/issues/<n> -f type=<Task|Bug|Feature>
```

**The type is a second call, not a `--type` flag, on purpose.** `gh issue create --type` is not on every
`gh` this workflow meets: measured September 24, 2026
([#2416](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2416)), `gh 2.74.0` answers it with
`unknown flag: --type` and creates nothing. The REST `PATCH` sets the type on that `gh` and on any newer
one, so the step names the route that works everywhere rather than a minimum version. **If the `PATCH`
fails, the issue already exists typeless** -- re-run the same call; never file a second issue.

| what to set | how to decide it |
|---|---|
| the type (`-f type=`) | **Bug** for a defect in behaviour that already exists, **Feature** for a capability the store does not have yet, **Task** for everything else -- which is most of it, doc findings included. Always one of the three; both BWJ orgs have exactly these and no others (measured September 7, 2026 -- `gh api orgs/<org>/issue-types` returns Task, Bug, Feature in `BWJ-ecommerce` and in `BWJ-Development` alike) |
| the reach label (`Get-ReachLabel`, default `minor`) | **only** where management or the commissioner would notice it. The test is whether that reader notices the **defect**, not whether the file renders to them: a customer-facing template with a developer-only defect is tier 0, and a build script whose breakage stops a release the business is waiting on is not. **In doubt, leave it off** |
| `--label documentation` | on a doc finding, on top of its type -- the one content distinction the three types cannot express here |
| `--label CRO` (store repos only) | on an issue filed by, or on behalf of, the CRO team (today: Johnno). Never in this plugin's own source repo `dkj-claude-plugins` -- it has no Shopify store for a CRO team to measure. See `WORKFLOW-portable.md`'s classification section |

**Write it in English -- the title as much as the body.** Every consumer of `dkj-policy` runs this same
cycle, so the issue takes the workflow's language no matter which language the session is being spoken
to in; the title carries it furthest, into every list, every filter and every mirrored card. The
carve-out is a person's own words -- a request quoted from an Asana ticket stays as they wrote it. Both
halves are in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#1-github-first----github-is-the-source-of-truth).

**Do not add `bug` or `enhancement`.** Both labels were deleted from both repos on September 1, 2026
because the issue type already carries them. The reasoning behind all three fields is in
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#classify-it-as-you-file-it----three-fields-all-set-at-creation).

Note the issue number and URL. If the finding collapses on verification, stop here and say so -- do
not file a weakened version, and do not create an Asana task for a non-issue.

**On an issue that is already filed** -- yours from an earlier run, or somebody else's -- the same two
fields are set with the same calls:

```bash
gh api --method PATCH repos/<owner>/<repo>/issues/<n> -f type=Bug
gh issue edit <n> --repo <owner>/<repo> --add-label "<reach label>"
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

Compose the task body from the fixed skeleton -- plain language, outcome-framed, no code or repo
jargon:

```text
What is wrong:   <one or two plain sentences -- what a visitor or colleague sees>
Where:           <which store, and which page or flow>
How urgent:      <blocking a sale / visible but not blocking / cosmetic / not customer-facing>
Tracked on GitHub: <issue URL>
```

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

**Where `Get-AsanaTypeFieldGid` returns a GID, set that one on the same call too -- to the type step
1 chose, never to a fresh reading of the finding.** The board's field offers exactly the three types
step 1 picks from, so there is nothing to decide here: the answer is one step old and carrying it
forward is the whole point. It is a **select** field, though, so the value is an option GID rather
than the word. Resolve it from **the project read the preflight already made** -- ask for the options
there, in the same call that proved the board reachable, and carry both forward:

```text
opt_fields: custom_field_settings.custom_field.gid,custom_field_settings.custom_field.name,
            custom_field_settings.custom_field.enum_options.gid,custom_field_settings.custom_field.enum_options.name
```

**Name every subfield -- Asana's `opt_fields` takes no wildcard**, so `custom_field_settings.*`
returns the options *absent* rather than an error, and the write then silently has nothing to send.
Match the option whose `name` is the type you set in step 1, and send its `gid`: a
**multi-select** field takes an **array** of option GIDs, a single-select the bare GID -- the BWJ
board's is multi-select, so `["<option gid>"]`. **If the type matches no option on the board, write
nothing and say which option was missing** -- that is a board somebody has rebuilt or renamed, and
guessing puts a wrong type on a card a colleague reads as authoritative.

Where it is `$null` -- the default -- skip it silently, exactly as for `Github Issue` above.

**Put it straight into the `Filed` section** -- the board's sections are the cycle's stages, and
`Filed` means *tracked on GitHub now*. Read `Get-AsanaStageMap` from `scripts/repo-config.ps1` for the
section **number** that stage is (leave it unset and the default is `3`), then read the project's
sections and take the one whose name starts with that number. The words after the number are the
team's and tell you nothing, so match on the **number** only.
[Step 6](https://github.com/DaveKJohn/claude-code-specialists/blob/main/plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md#6-the-boards-sections-are-the-cycle----one-card-one-column-per-stage)
has the whole stage model. **If the project has no numbered sections, place nothing and say so** --
that board is not a pipeline, and the daily sweep will not move this card either.

**On a ticket that came the other way** -- filed in Asana by a colleague and copied into an issue for
analysis -- the task already exists and is sitting in `Requests`, their untriaged inbox. Filing the
GitHub issue is exactly what `Filed` records, so **move that card there** rather than
creating a second task. Leaving it in `Requests` is the failure inbound
[#1217](https://github.com/DaveKJohn/claude-code-specialists/issues/1217) measured: the issue existed
and the board still read `New`, so to the colleague waiting on it the request looked untouched, and
they chased it in the one place that had no answer.

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
  to add it.

## Step 4 -- report

Give both URLs and stop -- or, for an issue without the reach label, the issue URL and the sentence
that it is GitHub-only because it is tier 0, so the missing card reads as a decision rather than a
failed mirror. **Do not resolve anything, and do not promise that anything else will.**
When the GitHub issue is closed, the `asana-mirror` CI workflow posts an update on the Asana task
saying the work is ready to test and moves the card to `ReadyToTest`; the task stays open until the
colleague who filed it ticks it off. Nothing in this chain -- not you, not the CI -- completes a task,
and nothing puts a card in `Completed` either.

**Say which section the card is in**, alongside the two URLs. It is the half a colleague can see
without a GitHub account, and it is the one part of this run somebody may need to correct.

**And when a branch is opened for this issue, the card moves to `InDevelopment` in the same breath.**
That hop is a session's to make and **nothing catches it up**: GitHub has no signal for a branch with
no pull request behind it, so the sweep never derives that stage at all. Nothing undoes the move
either -- the sweep derives a floor, never a position.

**A ticket blocked on the person who filed it gets the `needs-info` label**, and that is the whole
mechanism for the board's blocked column -- the label fires its own CI run, so the card moves as you
triage. **Setting it and writing the question are one act**: the label moves the card to the submitter,
so the comment asking them what you need goes on in the same movement, in the form
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#setting-needs-info-is-writing-the-question----one-act-and-the-issue-stays-open)
step 6 prescribes, and the issue stays open. Take the label off when the answer arrives and the card
returns to wherever the work actually is. Do not move that card by hand: the label is what the column is derived from, so a hand-move is
undone on the next sweep while the label stays.

**Name the type and the tier you chose, and why.** You infer both rather than asking for them -- the
reach question is answerable from the finding itself, and the whole backfill of 135 issues was
classified from the issue text alone. Naming the call here is what makes it correctable: it puts the
answer in front of the person who knows the store, at no extra turn, beside the one line that changes
it (`gh issue edit <n> --repo <owner>/<repo> --add-label "<reach label>"`, or `--remove-label`). Adding
it afterwards also means running steps 2-3 then, since the card follows the label.
