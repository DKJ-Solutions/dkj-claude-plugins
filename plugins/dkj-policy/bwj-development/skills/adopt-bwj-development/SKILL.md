---
name: adopt-bwj-development
description: >-
  One-time setup of bwj-development in a repo permitted to run it -- BWJ's two Shopify stores
  (smartwatchbanden or xoxowildhearts, whichever org), and for ticket handling alone the plugin's own
  source repo dkj-claude-plugins and BWJ's Lightspeed store phone-factory -- it refuses to run anywhere else -- both chapters:
  propose the Asana config seam for scripts/repo-config.ps1, check that the classification labels
  exist, report the board's numbered sections so the Filed section report-issue writes to can be
  found, write the BWJ extension import into CLAUDE.md, and scaffold chapter two's
  bwj-development/SYNC-LOG.md with its masthead, ready for the first sync branch. In the two store
  repos it also copies the asana-closed-message workflow into .github/ and names the one repo secret it
  needs, ASANA_PAT.
  Strictly additive and dry-run by default; it never overwrites an existing file, only adds the one
  import line to CLAUDE.md, and it renames nothing on the board.
  Run this right after enabling the plugin, or when report-issue reports the Asana config seam
  missing.
---

# adopt-bwj-development -- place both chapters' config seam

An install writes nothing into your repo. This command places what `bwj-development` needs on your
side, across both chapters: the config functions the skill reads, the labels, and chapter two's
`SYNC-LOG.md` scaffold (step 7). **In the two store repos it copies one CI workflow into `.github/`**:
`asana-closed-message`, the closed message on the Asana task (#2818) and, since #2854, the reopened
message beside it. They are the two parts of the retired asana-mirror mechanism that came back (Dave,
October 5 and 6, 2026).

## 0 -- establish that this repo is a permitted adoption target

**Refuse, not warn: nothing is written, copied or proposed until this check passes.** The constraint
-- `smartwatchbanden`, `xoxowildhearts`, `dkj-claude-plugins` or `phone-factory`, and nothing else -- lived only in
this file's own frontmatter until #1522; none of the steps below actually checked which repo
the session is standing in.

```bash
git remote get-url origin
```

**Match the repo NAME -- the last path segment -- and not the org.** This check named
`BWJ-ecommerce/<store>` until September 7, 2026, and on that day it became wrong in the live repo:
`smartwatchbanden` moved to `BWJ-Development` as a fresh repo, the `BWJ-ecommerce` one was archived,
and a fresh repo carries no redirect. An org-path match then refuses the one adoption it exists to
serve, which is the worse of the two failure directions -- and the org may move again while the
names will not. The list is closed at four, so nothing about the strength of this refusal changes.

**Anything else stops the skill here**: report which
repo the session is actually in and go no further -- no config proposed, no label
checked. There is no override flag, and there will not be one: the list itself is the whole
permission, so a fifth target is a change to this page argued on its own merits -- never a flag
somebody passes in the moment, which is a decision nobody can read back afterwards.

**The third name is this skill's own SOURCE repo, and it was admitted deliberately** (Dave,
September 14, 2026). Until that day it was named here as the *most likely wrong* target precisely
because it is the source. That reading is retired for `dkj-claude-plugins` and for nothing else: the
repo is permitted because its maintainer decided it is, not because the guard stopped seeing it.

**The fourth name is `phone-factory`, BWJ's Lightspeed store, admitted for ticket handling alone**
(Dave, October 2, 2026, [#2705](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2705)). It
follows the BWJ procedure, so chapter one applies. Chapters two to four are written against the Shopify
theme and CLI, which it does not run, so they do not reach it -- the same reach as `dkj-claude-plugins`,
for a different reason. It needs its own Asana board in step 2: a GID copied from another store's
config fails silently.

**On the source repo, step 2's board GID is not a formality.** That tracker is the one every consumer
files their inbound reports to, and `report-issue` creates a task on whatever board `Get-AsanaProjectGid`
names, so a provisional or copied value puts this repo's inbound traffic onto somebody else's board. Step 2
already says such a value fails silently.

**Why the guard exists, and what it still catches.** A wrong repo takes the seam proposal, the labels
and the sync-log scaffold somewhere they were never asked to sit, and nothing about running the steps in
order says so. The failure this step exists to catch is a clean first run in the wrong repo, which an
"if the file exists, stop" guard cannot see because it answers a different question.

**Measured, not hypothetical**: this skill was invoked once with the working directory set to the
source repo, `DKJ-Solutions/dkj-claude-plugins`, and nothing before the first step stopped it -- the session
stopped by hand, not the skill
([#1522](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1522)). **Admitting that repo
does not retire the measurement, and reading it as spent is the one mistake this paragraph exists to
prevent.** What #1522 measured was an *unnoticed* run in a repo nobody had chosen, and its repair was
the check rather than the verdict -- so the check still runs here. It now returns a permitted name,
and the difference between the two runs is not the guard but the decision behind it, which is on the
record above.

## 1 -- copy the closed and reopened messages into `.github/` (the two store repos only)

GitHub only runs a workflow from a repo's own `.github/`, so these are copied, not imported:

| from this plugin | to your repo |
|---|---|
| `templates/asana-closed-message.yml` | `.github/workflows/asana-closed-message.yml` |
| `templates/asana-closed-message.ps1` | `.github/scripts/asana-closed-message.ps1` |

Copy them verbatim. If a file already exists at the target, **stop and diff** rather than overwriting:
report the difference and let the maintainer decide. **Only in `smartwatchbanden` and `xoxowildhearts`**
(#2818). The source repo and `phone-factory` adopt this plugin for ticket handling alone, and no closed
message was asked for there.

When an issue closes as completed, the workflow posts one comment on its Asana task: the automation's
header, the closed line, and the go-live block the shipping session left on the issue. It posts nothing on
a close as not planned or as a duplicate. When an issue is reopened, it posts the header and the reopened
line (#2854). It never moves a card and never completes a task. A store that already holds the two files
from before #2854 gets the stop-and-diff above: the difference is the reopen trigger, and taking it is
the maintainer's call. The behaviour is
in [`WORKFLOW-portable.md`, step 4](../../WORKFLOW-portable.md#4-write-the-go-live-block-then-close-the-github-issue----the-closed-message-carries-it-into-asana).

**A repo that adopted before October 5, 2026 still has `asana-mirror.yml` and `asana-mirror.ps1`**, which
the plugin no longer maintains: report them to the maintainer, who can delete
`.github/workflows/asana-mirror.yml` and `.github/scripts/asana-mirror.ps1`. Do not delete them here --
this skill only ever adds -- and say that running both would post the closed message twice.

## 2 -- propose the config seam for `scripts/repo-config.ps1`

Add these functions to the repo-owned `scripts/repo-config.ps1` (the same file `dkj-policy`
dot-sources). **Propose** them -- do not place them -- because the values state what this repo *is*:

```powershell
function Get-AsanaWorkspaceGid { '<your Asana workspace GID>' }
function Get-AsanaProjectGid   { '<the Asana project a mirrored task lands in>' }

# Which numbered section of that board each stage of the cycle IS. Optional -- omit it and the
# built-in map is used, which is right only if your board is numbered the same way. report-issue reads
# it for ONE thing: the Filed section a new card lands in. Nothing moves a card between sections any
# more; the other stages are the board's sections that a person moves cards through.
function Get-AsanaStageMap {
    return @{
        Requests       = 1   # the submitter's inbox
        NeedsInfo      = 2   # blocked on the submitter
        Filed          = 3   # tracked on GitHub -- where report-issue puts a new card
        InDevelopment  = 4   # somebody is building it
        InReview       = 5   # closed on GitHub
        ReadyToTest    = 6   # the submitter's turn
        Completed      = 7   # the submitter says it is good
        NeedsInfoLabel = 'awaiting-more-info'
    }
}

# The GID of the board's 'Github Issue' text custom field (Asana Field settings -> the field's own
# page shows its GID in the URL), so report-issue can set it at task creation with the full issue
# URL. Optional: $null (the default) means the board carries no such field and the step is skipped.
function Get-AsanaIssueFieldGid { $null }

# The GID of the board's 'Github Type' multi-select custom field, so report-issue can set it at task
# creation from the kind label step 1 already chose (bug, feature, or neither for Task -- #2750).
# Optional in the same way: $null (the default)
# means the board carries no such field. The field's OPTION GIDs are not configured -- report-issue
# resolves Bug/Feature/Task by name from the project itself.
function Get-AsanaTypeFieldGid { $null }

# The NAME GitHub stores for the reach label. The axis itself is fixed and portable -- defined in
# RELEASES-portable.md -- and only the string is this repo's to choose. Optional: 'minor' is the
# default, so a store whose label is already called that never writes this function at all. Answer it
# where yours is not: 'tier-1' in a store that has not renamed its label.
function Get-ReachLabel { 'tier-1' }

# WHICH ISSUES A MERGE MUST NOT CLOSE -- read by dkj-policy's resolves gate (inbound #2120). An issue
# with a mirrored Asana task is closed by a PERSON, once the go-live block is on it, so `Closes #<n>`
# is the one thing its pull request must not carry. These two matchers are the same marker and task-link
# shapes the plugin uses to decide which task an issue belongs to -- deliberately not a third
# definition. Without this function the rule still stands and nothing enforces it.
function Get-ResolvesExemptMatchers {
    return @(
        @{ Name    = 'an Asana task marker'
           Pattern = '<!--\s*asana-task:\s*[0-9]+\s*-->'
           Why     = 'the go-live block goes on while the issue is OPEN, and the task''s assignee closes it once the block is right -- ship with -NoResolves and close it by hand.' },
        @{ Name    = 'an Asana task link'
           Pattern = 'https://app\.asana\.com/'
           Why     = 'the same rule: a mirrored ticket is closed by a person, not by a merge.' }
    )
}
```

**`Get-GithubStatusMap` is no longer proposed.** It told the retired stage sweep which GitHub Project
status each stage was, and nothing else read it (Dave, October 5, 2026). A repo that still answers it can
delete the answer.

**`Get-ResolvesExemptMatchers` is the one seam here that a `dkj-policy` gate reads directly**, and it is
proposed rather than placed for the same reason as the rest: it asserts that this repo mirrors its issues
into a second tracker. It carries **two** of the three task matchers and not all three -- the
header-row matcher is an anchored read of a `| **Asana** | ... |` row, and the sole-URL matcher above
already covers that row's link. The cost of the difference is the direction to be wrong in: this gate
refuses a close, so a matcher that reaches slightly wider stops a merge that should have been
`-NoResolves` anyway, while the narrower one that decides which task to read must not guess.

**`Get-ReachLabel` is the one seam here that is NOT about Asana**, which is why it reads as the odd
one out and belongs in the list anyway: every other value states something about a board, and this one
states a string GitHub holds. It exists because a consumer renamed that label while the name was
written as a literal in four places, two of which then pointed at a label the repo no longer had
([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)). **Propose it only where
the repo's label is not `minor`**: that is this workflow's default since
[#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870), and a function restating the
default is a value somebody now has to maintain. Today that means proposing it in a store still carrying
`tier-1` and not in one that has already renamed.

**In the two store repos only, propose the preview question as well** -- chapter three's step, which
[`PREVIEW-portable.md`](../../PREVIEW-portable.md#the-step-that-asks-the-question----always-last-under--create)
makes the last one under `### CREATE`:

```powershell
# The step every branch here closes CREATE with. dkj-policy's new-branch writes each text as an open
# step, last under CREATE, so the step-list gate holds the PR until it is resolved.
function Get-BranchClosingSteps { @('Is the change visible in the frontend / storefront?') }
```

**This seam is what writes the step, and until it is answered nothing does**
([#2655](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2655)). The page used to say the
gate enforces the step by its position, but no scaffold ever wrote it. Measured in `xoxowildhearts`
on September 30, 2026: no branch document there had ever carried it, and a branch with a visible theme
change reached its PR with no handover at all. **Not in `dkj-claude-plugins`**: chapter three's reach
excludes the source repo, which runs no theme, so there the question would be `- [~]` on every branch
forever. It reaches branches created **after** the seam lands. A branch already open gets the line by
hand.

**In the two store repos, propose the task form of the audience release note too**
([#2802](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2802)). Both stores keep an Asana
board, and their colleagues read a note to see which of *their* tasks are solved. Without this answer the
cut drafts the entries form, and somebody rewrites it into tasks by hand at every release:

```powershell
# dkj-policy's cut-release drafts the audience section as one item per solved Asana task, read from the
# same marker report-issue writes. Pass the live-push record to every cut: only it can say which
# storefront changes are live.
function Get-ReleaseNoteTaskLink { @{ Marker = 'asana-task'; Url = 'https://app.asana.com/0/0/{0}'; Label = 'Asana task' } }
```

The rest of the note's form (title, labels, headings) is `dkj-policy`'s, and only `Get-ReleaseNoteWording`
changes it (the `cut-release` skill, step 2). Neither store restates it in a lens.

**Propose the stage map against the board you actually read in step 5, not against the example.** The
keys are the cycle and are fixed; the numbers are that board's and nothing else can supply them. Say
plainly that a wrong map is *silent*: the new card lands in whatever section the map's `Filed` number
names. It is a `.ps1` in the repo, so it goes through that repo's ordinary branch and review route like
any other change.

**Propose the project GID against a real board that is this store's own, never copied from the other
store's.** Measured the day this was written, the workspace holds two GitHub boards, one per store --
`GitHub - SWB` and `GitHub - WH` -- and each store repo answers `Get-AsanaProjectGid` with a board of its
own. **A copied value costs exactly as silently as a provisional one**: the second repo's cards land on
the other store's board, the create call succeeds and nothing fails on the day -- the only symptom is
colleagues on one store finding the other store's tickets sitting on theirs. `smartwatchbanden` added a
test asserting both halves at once: that the value names its own board, and that `xoxowildhearts`' GID is
never adopted in its place
([BWJ-ecommerce/smartwatchbanden#508](https://github.com/BWJ-ecommerce/smartwatchbanden/pull/508), the
PR; [#470](https://github.com/BWJ-ecommerce/smartwatchbanden/issues/470), the issue).

**`Get-AsanaIssueFieldGid` is addressed by GID rather than by name**, because creating a task and setting
one of its custom fields in the same call is the opposite direction from reading a task back: the
`create task` call addresses a custom field by its GID, which Asana Field settings shows on the field's
own page, in the URL. **An Asana custom field only becomes usable once it has been *added to* a project**
via that project's own `custom_field_settings`, and definition in the right workspace is not enough to
guarantee that, so this GID has to come from a field that is actually on `Get-AsanaProjectGid`'s own
project. And it is **plainly optional**: `$null`, the default, means the board carries no `Github Issue`
field, and `report-issue` skips the write silently -- a repo without the field loses nothing by leaving
it unset.

**`Get-AsanaTypeFieldGid` carries every one of those properties and is not restated here** -- same
reason for a GID rather than a name, same silent-skip default, same constraint on where the field has
to live. **What differs is one level of indirection, and it is the whole reason this seam is only
half a seam.** A text field takes the value you send it; a multi-select field takes an array of GIDs
drawn from its own **options**, so writing `Task` means finding out what `Task` is called in GIDs
first.

**Those option GIDs are deliberately not configured.** Three more values per repo, each pinning a
name somebody can rename or rebuild in the Asana UI without anything failing -- and unlike the field
GID they do not have to be pinned, because they are resolvable at run time from the project
`Get-AsanaProjectGid` already names. So this seam answers *which field*, and `report-issue` answers
*which option*, on a call it is already making. The one thing to tell the maintainer is what that
buys: rebuild an option and nothing breaks; **rename** one away from `Bug`, `Feature` or `Task` and
the write is skipped with a note rather than guessing, because an unmatched name on a board that
reads as authoritative is worse than a blank.

## 3 -- the one repo secret: `ASANA_PAT` (the two store repos only)

The closed message from step 1 needs **one** Actions secret, `ASANA_PAT`: a token that may comment on the
board's tasks. Print it for the maintainer to set (`gh secret set ASANA_PAT --repo <owner>/<repo>`);
this skill never sets a secret. Nothing else is needed: no `GH_PROJECT_TOKEN` and no `ASANA_PROJECT_GID`,
which the retired asana-mirror read, because a comment addresses its task by GID alone. What is also
true, and is not a repo setting:

- `ASANA_PAT` in the **session's own environment** is what
  [`build-backlog-page`](../build-backlog-page/SKILL.md) reads the Asana tasks with. It is a personal
  token on the machine that builds the page, and this skill does not set it.
- `Get-AsanaWorkspaceGid` from step 2 stays: `report-issue` reads it session-side, where it CREATES a
  task and the API does want a workspace.

A repo that adopted earlier may still carry `GH_PROJECT_TOKEN` and `ASANA_PROJECT_GID`. Both are dead now
and the maintainer can delete them. **`ASANA_PAT` stays**, because the closed message reads it.

## 4 -- make sure the classification labels exist

[`report-issue`](../report-issue/SKILL.md) files every issue with `bug` or `feature` -- always one of
the two ([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)) -- and with the reach
label where it applies. It sets no GitHub issue type
([#2750](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2750)). **`gh issue create` fails
outright on a label the repo does not have**, so check for all three and create whichever is missing. **Read `Get-ReachLabel` from
`scripts/repo-config.ps1` first** and check for *that* name -- `minor` where the repo has never
answered it, which since [#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870) is
the workflow's own default. **A store still carrying `tier-1` and answering nothing is the one state
that now files against a label it does not have**, and `gh issue create` refuses the whole call over
it -- no issue at all, not even one without the label. Repair it here rather than working around it:
rename the label, or state `tier-1` in the seam.

```bash
gh label list --repo <owner>/<repo> | grep -E '^(bug|feature|<reach label>)\b'
gh label create bug --repo <owner>/<repo> --color FF00FF \
  --description "A defect in behaviour that already exists"
gh label create feature --repo <owner>/<repo> --color a2eeef \
  --description "A capability the store does not have yet"
gh label create "<reach label>" --repo <owner>/<repo> --color fbca04 \
  --description "Reaches the business: management and the commissioner notice it"
```

**`bug` is magenta and `feature` cyan**, the same family colours as this workflow's source tracker. An
existing `bug` label in a different colour still works, and so does an existing `feature` label with
another description: `gh label create` never touches a label that exists.

**Every name in that check has a `create` line beside it, and until September 11, 2026 one did not.**
The grep named a label the step never created, so a repo missing it got a hit in the check and no
instruction -- a check whose result nothing acts on
([#1846](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1846)). That label was
`documentation`, and it is no longer filed at all.

**`documentation` is retired, so this step no longer checks for it** (Dave, October 3, 2026,
[#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)): a doc finding is a `bug` or a
`feature` like everything else. It is one of GitHub's default labels, so a store will still carry it.
Give each **open** issue on it its kind, then take it off:

```bash
gh issue list --repo <owner>/<repo> --label documentation --state open
gh issue edit <n> --repo <owner>/<repo> --add-label <bug|feature> --remove-label documentation
```

Deleting the label itself (`gh label delete documentation`) also strips it from every closed issue, so
that one is the owner's call, not an adoption step.

**A missing reach label is two different situations and this step must not assume the harmless one.**
Every other label in this step is missing because the repo never had it; this one can be missing because the
repo **renamed** it and has not answered the seam. Creating it then leaves two labels for one axis, one
of them empty, with every existing issue on the other -- and nothing reports it, because the run is
doing exactly what it was written to do. That is the state `smartwatchbanden` was one re-adopt away
from on September 11, 2026
([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)); the seam above is the
repair, and this paragraph is what keeps the repair from being skipped by a repo that has not adopted
it yet. So **before creating it, read the whole label list** (`gh label list --repo <owner>/<repo>`)
and look for the axis under another name -- a label carrying issues and describing reach. Where you
find one, the answer is `Get-ReachLabel`, not a second label. Where the list genuinely has no such
label, create it.

**The hazard is not unique to this label; the measurement is.** Rename `bug`, `feature` or a prio label
and this step would re-create that one beside it in exactly the same way -- the difference is that
the reach label is the one a consumer has actually renamed. So the pause is
written here, where it has been paid for, rather than several times on speculation. If a second rename
lands on one of the others, that is the moment for its own seam -- not a reason to widen this one now.

**And the `CRO` label -- Shopify store repos only.** It marks an issue filed by, or on behalf of,
the CRO team (today: Johnno), and it exists in exactly two repos: `smartwatchbanden` and
`xoxowildhearts`. **Skip this label entirely when this skill runs against `dkj-claude-plugins` or
`phone-factory`.** The first has no store at all. The second is a Lightspeed store the CRO team does not
measure ([#2712](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2712)). Both are permitted
adoption targets for the ticket-handling chapter alone, not for this label. See
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#the-cro-label----who-reported-it-not-what-it-is)
for the reasoning.

```bash
gh label create CRO --repo <owner>/<repo> --color 5319e7 \
  --description "Filed by, or on behalf of, the CRO team (currently Johnno) -- store repos only"
```

**And the four prio labels.** They are typed onto an issue by a person now: the daily run that used to
set one from the Asana task's `Prio-Score` was retired on October 5, 2026 (Dave). `gh issue edit` fails on
a label the repo does not have exactly as `gh issue create` does, so they still need to exist.

```bash
gh label create prio-4 --repo <owner>/<repo> --color b60205 \
  --description "Asana Prio-Score 4.00-5.00"
gh label create prio-3 --repo <owner>/<repo> --color e0321a \
  --description "Asana Prio-Score 3.00-3.99"
gh label create prio-2 --repo <owner>/<repo> --color f57c00 \
  --description "Asana Prio-Score 2.00-2.99"
gh label create prio-1 --repo <owner>/<repo> --color ffa726 \
  --description "Asana Prio-Score 1.00-1.99"
```

**The DESCRIPTIONS are score-shaped and that is load-bearing, not decoration.** The names are the same
four the source repo's own tracker uses, where a rung is a judgement somebody typed; here the rung comes
from a score on a board nobody in this repo can see. The description is the one place a badge still says
**which scale it follows**, and it survives a rename untouched -- so keep the `Asana Prio-Score` wording
even if the labels are created by hand. Dave unified the names on September 11, 2026
([#1842](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1842)), reversing half 1 of
[#1686](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1686); the grounds that decision
weighed, and the one it overrode, are recorded there.

**A repo adopted BEFORE that day carries the old names** -- `very high` / `high` / `low` /
`very low` -- and `gh label create` would leave it holding all eight. Rename in place instead, which
keeps every label attached to the issues that carry it, so nothing is relabelled by hand and no
history is lost:

```bash
gh label edit "very high" --repo <owner>/<repo> --name prio-4 --color b60205
gh label edit "high"      --repo <owner>/<repo> --name prio-3 --color e0321a
gh label edit "low"       --repo <owner>/<repo> --name prio-2 --color f57c00
gh label edit "very low"  --repo <owner>/<repo> --name prio-1 --color ffa726
```

**The colours are two yellows and two reds** (Dave, September 28, 2026): `prio-1` yellow, `prio-2` a
yellow leaning to orange, `prio-3` a red leaning to orange, `prio-4` red. That also retired the one
collision this step used to warn about -- `prio-2` shared `fbca04` with `tier-1` until then
([#1844](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1844)). **A repo adopted before
that day keeps its old colours**, because `gh label create` never touches a label that exists;
re-colour in place with `gh label edit prio-<n> --repo <owner>/<repo> --color <hex>`, the hexes above.

**And the `awaiting-more-info` label**, a flag on the issue for a ticket that is blocked on the person who
filed it. It is a GitHub-side flag only now: it used to park the Asana card in the blocked column, and with
the mirror retired it moves nothing in Asana. The label was named `needs-info` until October 2, 2026
([#2723](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2723)): a tracker already carrying
`needs-info` renames it in place, keeping every issue on it, and takes the colour below in the same command
([#2810](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2810)):
`gh label edit needs-info --name awaiting-more-info --color d4c5f9 --repo <owner>/<repo>`.

```bash
gh label create awaiting-more-info --repo <owner>/<repo> --color d4c5f9 \
  --description "Blocked on the person who filed it"
```

**GitHub issue types are not used** ([#2750](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2750)):
the kind is the `bug` or `feature` label created above, always one of the two (#2783). There is
nothing to configure for types, and no `enhancement` label is created.

**The same two labels classify the pull request, so answer the prefix table with them** (Dave, October
3, 2026, [#2769](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2769)). `open-pr` labels a
PR from the row of `scripts/lib/branch-info.ps1` its branch prefix matches. That file is the repo's own
and this skill does not write it, so check it by hand:

```powershell
$script:BranchPrefixTable = @{
    feat  = @{ Label = 'feature'; Type = 'Feat' }
    fix   = @{ Label = 'bug';     Type = 'Fix' }
    docs  = @{ Label = $null;     Type = 'Docs' }
}
```

**`docs` answers `$null`, not `documentation`** (#2783). That label is retired, and a prefix cannot
tell a new page from a corrected one, so a `docs/` PR goes out unlabelled and its issue carries the
kind. A table still naming `documentation` there is stale: replace it.

**A BWJ table adopted before #2750 answers `Label = $null` for `feat` and `fix`.** That was right while
the issue type carried the kind and `bug` and `enhancement` were deleted org-wide, and it is stale now:
the PR goes out unlabelled while its issue carries the kind. Replace both `$null`s with the names above,
and keep any other row the repo has as it is. **Run this step's label check first.** `open-pr`'s label
gate refuses a create whose label the repo does not have, and it refuses before the push, so a table
naming `feature` on a tracker without it stops every `feat/` PR.

## 5 -- read the board's sections, so the Filed section can be found

`report-issue` creates a new card in the board's `Filed` section, and finds it by the **number its
section's name starts with**, taking the *meaning* of each number from `Get-AsanaStageMap`. Nothing moves
a card afterwards (Dave, October 5, 2026), so the map matters for one number. **This step comes before
step 2's proposal can be written** -- read the sections of the project and report them:

```text
<N>. <anything>   ->  which stage of the cycle this column is
```

The words after each number belong to the team; only the number is read. **Report what you find and
change nothing** -- a board is a shared surface, and renaming somebody's column is not an adoption
step. Then map the columns you found onto the cycle stages and put *that* in the step 2 proposal.
Two cases are worth naming explicitly when you report:

- **No numbered sections at all.** `report-issue` cannot find `Filed` and says so; the card is then
  created without a section. Say so plainly.
- **A board numbered differently from the example.** Then the example map is wrong for this repo and
  `Get-AsanaStageMap` is not optional: a map whose `Filed` number is not the board's puts every new
  card in the wrong column, silently. Treat "the default happens to fit" as a claim to verify here, not
  to assume.

The GitHub Project board no longer matters to this plugin: its `Status` field was read only by the
retired stage sweep, so there is no GitHub-side half of this step.

## 6 -- point the repo's governance at the rule

The repo's `CLAUDE.md` imports the BWJ extension of the constitution on the line **directly below**
the `dkj-policy` import that `adopt-dkj-policy` writes
([#2374](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2374)):

```
@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/bwj-development/CLAUDE.md
```

**This step writes that line** ([#2532](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2532)).
It used to ask a person to add it, and #2531 measured what that costs for the constitution line: a
consumer ran for weeks without the rules in context. Run it dry first, then with `-Apply`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-extension-import.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-extension-import.ps1" -Apply
```

It puts the line directly below the constitution import. Without one it goes where the constitution
would, so a later `adopt-dkj-policy` still lands the constitution above it. It takes the marketplace
name the repo's clone sits under, keeps the file's line endings and byte-order mark, and writes
nothing when the line is already imported, under any marketplace name or through a file `CLAUDE.md`
imports. A line quoted inside a code fence counts neither as imported nor as a place to insert.

That file points at all four chapters, so a session reads the BWJ rules the same way it reads the
constitution. **The one thing left to you:** remove any older line that pointed at
`WORKFLOW-portable.md` directly, because the extension replaces it. The script only adds.

Until the line is there, dkj-policy's `consumer-prose-sessioncheck` warns at session start in a repo
whose own settings enable `bwj-development`, and names this step.

## 7 -- scaffold the sync-log folder (chapter two)

**Skip this step in `dkj-claude-plugins` and `phone-factory`.** Both are admitted for chapter one alone,
and chapter two records drift on a live Shopify theme, which neither runs.

Chapter two's record needs somewhere to land before the first `sync/` branch ever runs. If
`Get-ShopifySyncLogPath` is not yet answered, propose it alongside the Asana seams in step 2, in the
same `scripts/repo-config.ps1` -- `'bwj-development/SYNC-LOG.md'` in both store repos. Either way, once it is
answered, create the file it names, with nothing in it but a masthead:

```markdown
# Sync log

One entry per `sync/` branch, newest at the top. Written and committed by `sync-main.ps1` -- never
folded into `CHANGELOG.md`, never read by a release.
```

**If the file already exists, leave it alone** -- this skill only ever adds, never overwrites.
`Add-SyncLogEntry` reads everything above the first `## ` line as the
masthead and prepends new entries beneath it, so this is not a stub waiting to be replaced -- it is the
permanent header the first real entry lands under. See
[`SYNC-LOG-portable.md`](../../SYNC-LOG-portable.md) for the rule this scaffolds.

## What this skill does not do

- It does not enable the plugin -- that is a `.claude/settings.json` change you make first.
- It does not create the Asana project or token.
- It does not copy or maintain any CI workflow, and it sets no repo secret or variable.
- It does not register this repo in the source repo's `connectors/` register -- that happens in the
  source repo after this repo's settings change has merged.
- **It does not set up the shared pages worker.** That seam (`Get-BwjPagesConfig`), the KV namespace
  and the one-time deploy are [`publish-page`](../publish-page/SKILL.md)'s own setup section, and they
  stay there deliberately: this skill's steps are per repo, while that worker is created **once for
  both stores** and the second store answers the same four values the first one already has.
