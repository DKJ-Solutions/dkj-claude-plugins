---
name: adopt-dkj-policy-bwj
description: >-
  One-time setup of dkj-policy-bwj in a repo permitted to run it -- BWJ's two stores
  (smartwatchbanden or xoxowildhearts, whichever org) and the plugin's own source repo
  dkj-claude-plugins -- it refuses to run anywhere else -- both chapters: copy the asana-mirror CI
  mechanism into .github/, propose the Asana config seam for scripts/repo-config.ps1, print the repo
  secret and variables the CI needs, check that the classification labels exist, report whether the
  board's sections are numbered so the stage model can read them, and scaffold chapter two's
  dkj-policy-bwj/SYNC-LOG.md with its masthead, ready for the first sync branch. Strictly additive
  and dry-run by default; it never overwrites an existing file, and it renames nothing on the board.
  Run this right after enabling the plugin, or when report-issue reports the Asana config seam
  missing.
---

# adopt-dkj-policy-bwj -- place both chapters' mechanism and config seam

An install writes nothing into your repo. This command places what `dkj-policy-bwj` needs on your
side, across both chapters: the CI workflow that resolves Asana tasks, the config functions the skill
and the CI both read, and chapter two's `SYNC-LOG.md` scaffold (step 7).

## 0 -- establish that this repo is a permitted adoption target

**Refuse, not warn: nothing is written, copied or proposed until this check passes.** The constraint
-- `smartwatchbanden`, `xoxowildhearts` or `dkj-claude-plugins`, and nothing else -- lived only in
this file's own frontmatter until #1522; none of the seven steps below actually checked which repo
the session is standing in.

```bash
git remote get-url origin
```

**Match the repo NAME -- the last path segment -- and not the org.** This check named
`BWJ-ecommerce/<store>` until September 7, 2026, and on that day it became wrong in the live repo:
`smartwatchbanden` moved to `BWJ-Development` as a fresh repo, the `BWJ-ecommerce` one was archived,
and a fresh repo carries no redirect. An org-path match then refuses the one adoption it exists to
serve, which is the worse of the two failure directions -- and the org may move again while the
names will not. The list is closed at three, so nothing about the strength of this refusal changes.

**Anything else stops the skill here**: report which
repo the session is actually in and go no further -- no file copied, no config proposed, no label
checked. There is no override flag, and there will not be one: the list itself is the whole
permission, so a fourth target is a change to this page argued on its own merits -- never a flag
somebody passes in the moment, which is a decision nobody can read back afterwards.

**The third name is this skill's own SOURCE repo, and it was admitted deliberately** (Dave,
September 14, 2026). Until that day it was the paragraph below this one, named here as the *most
likely wrong* target precisely because it is the source. That reading is retired for
`dkj-claude-plugins` and for nothing else: the repo is permitted because its maintainer decided it
is, not because the guard stopped seeing it.

**What that admission costs belongs here, where the permission is granted.**
`templates/asana-mirror.yml` and `templates/asana-mirror.ps1` are copied *from* this repo, so step 1
here copies out of `plugins/dkj-policy/dkj-policy-bwj/templates/` into this repo's own `.github/` --
a **public** repo, where the workflow holds `issues: write`, triggers on `issues: [closed, reopened,
labeled, unlabeled]` plus a daily cron, and mirrors to whatever board `Get-AsanaProjectGid` names. On
this repo that tracker is the one every consumer files their inbound reports to, so step 2's board
GID is not a formality here: a provisional or copied value mirrors this repo's inbound traffic onto
somebody else's board, and step 2 already says such a value fails silently.

**And the reason the guard exists is unchanged for every name outside the list.** A wrong stage map
still lands the mirror on the right repo, one column off; a wrong repo lands the whole mechanism --
the CI workflow, the secrets checklist, the labels -- somewhere it was never asked to sit, and
nothing about running the steps in order says so. Nothing fails loudly; the workflow is simply red or
silent, on whatever repo it landed in. Step 1's own guard does not catch it either -- "if a file
already exists at the target, stop and diff" protects a repo that has *already* adopted, and a repo
that has never adopted has no file at either target, so that guard passes cleanly and the copy
proceeds. The failure this step exists to catch is a clean first run in the wrong repo, which the
idempotence guard cannot see because it is answering a different question.

**Measured, not hypothetical**: this skill was invoked once with the working directory set to the
source repo, `DKJ-Solutions/dkj-claude-plugins`, and nothing before step 1 stopped it -- the session
stopped by hand, not the skill
([#1522](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1522)). **Admitting that repo
does not retire the measurement, and reading it as spent is the one mistake this paragraph exists to
prevent.** What #1522 measured was an *unnoticed* run in a repo nobody had chosen, and its repair was
the check rather than the verdict -- so the check still runs here. It now returns a permitted name,
and the difference between the two runs is not the guard but the decision behind it, which is on the
record above.

## 1 -- copy the CI mechanism into `.github/`

GitHub only runs a workflow from a repo's own `.github/`, so these are copied, not imported:

| from this plugin | to your repo |
|---|---|
| `templates/asana-mirror.yml` | `.github/workflows/asana-mirror.yml` |
| `templates/asana-mirror.ps1` | `.github/scripts/asana-mirror.ps1` |

Copy them verbatim. If a file already exists at the target, **stop and diff** rather than
overwriting -- report the difference and let the maintainer decide.

## 2 -- propose the config seam for `scripts/repo-config.ps1`

Add these functions to the repo-owned `scripts/repo-config.ps1` (the same file `dkj-policy`
dot-sources). **Propose** them -- do not place them -- because the values state what this repo *is*:

```powershell
function Get-AsanaWorkspaceGid { '<your Asana workspace GID>' }
function Get-AsanaProjectGid   { '<the Asana project a mirrored task lands in>' }

# Which numbered section of that board each stage of the cycle IS. Optional -- omit it and the
# built-in map is used, which is right only if your board is numbered the same way.
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

# Which GitHub Project status each of the three MIDDLE stages is. Also optional, and the two maps
# answer to two different boards -- this one is keyed on GitHub's own column names.
function Get-GithubStatusMap {
    return @{
        FieldName        = 'Status'
        Statuses         = @{
            'Todo'        = 'Filed'
            'In Progress' = 'InDevelopment'
            'Done'        = 'InReview'
        }
        # A regex over the Asana task's notes whose group 1 is the submitter's name -- the intake
        # form's own line. '' means stage 6 is never entered automatically; see below.
        SubmitterPattern = ''
    }
}

# The GID of the board's 'Github Issue' text custom field (Asana Field settings -> the field's own
# page shows its GID in the URL), so report-issue can set it at task creation with the full issue
# URL. Optional: $null (the default) means the board carries no such field and the step is skipped.
function Get-AsanaIssueFieldGid { $null }

# The GID of the board's 'Github Type' multi-select custom field, so report-issue can set it at task
# creation from the issue type step 1 already chose. Optional in the same way: $null (the default)
# means the board carries no such field. The field's OPTION GIDs are not configured -- report-issue
# resolves Bug/Feature/Task by name from the project itself.
function Get-AsanaTypeFieldGid { $null }

# The NAME GitHub stores for the reach label. The axis itself is fixed and portable -- defined in
# RELEASES-portable.md -- and only the string is this repo's to choose. Optional: 'minor' is the
# default, so a store whose label is already called that never writes this function at all. Answer it
# where yours is not: 'tier-1' in a store that has not renamed its label.
function Get-ReachLabel { 'tier-1' }

# WHICH ISSUES A MERGE MUST NOT CLOSE -- read by dkj-policy's resolves gate (inbound #2120). An issue
# with a mirrored Asana task is closed by a PERSON, once the paste-ready block is on it, so `Closes #<n>`
# is the one thing its pull request must not carry. These two matchers are the same marker and task-link
# shapes the mirror itself uses to decide which task an issue belongs to -- deliberately not a third
# definition. Without this function the rule still stands and nothing enforces it.
function Get-ResolvesExemptMatchers {
    return @(
        @{ Name    = 'an Asana task marker'
           Pattern = '<!--\s*asana-task:\s*[0-9]+\s*-->'
           Why     = 'the paste-ready block goes on while the issue is OPEN, and closing it is the confirmation that the block reached Asana -- ship with -NoResolves and close it by hand.' },
        @{ Name    = 'an Asana task link'
           Pattern = 'https://app\.asana\.com/'
           Why     = 'the same rule: a mirrored ticket is closed by a person, not by a merge.' }
    )
}
```

**`Get-ResolvesExemptMatchers` is the one seam here that a `dkj-policy` gate reads directly**, and it is
proposed rather than placed for the same reason as the rest: it asserts that this repo mirrors its issues
into a second tracker. It carries **two** of the mirror's three matchers and not all three -- the
header-row matcher is an anchored read of a `| **Asana** | ... |` row, and the sole-URL matcher above
already covers that row's link. The cost of the difference is the direction to be wrong in: this gate
refuses a close, so a matcher that reaches slightly wider stops a merge that should have been
`-NoResolves` anyway, while the mirror's narrower one decides which task to write to and must not guess.

**`Get-ReachLabel` is the one seam here that is NOT about Asana**, which is why it reads as the odd
one out and belongs in the list anyway: every other value states something about a board, and this one
states a string GitHub holds. It exists because a consumer renamed that label while the name was
written as a literal in four places, two of which then pointed at a label the repo no longer had
([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841)). **Propose it only where
the repo's label is not `minor`**: that is this workflow's default since
[#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870), and a function restating the
default is a value somebody now has to maintain. Today that means proposing it in a store still carrying
`tier-1` and not in one that has already renamed.

**`SubmitterPattern` is the one value here that decides whether a whole column is used.** Stage 6 is
entered only once the submitter has been told, so a repo that names no pattern never enters it: every
closed ticket waits in `InReview` for a person. That is a working configuration and the safe default,
but it is *silent* -- so if the team expects an acceptance column to fill itself, this is the value
that makes it. Propose it against the wording the repo's intake form actually writes, and do not guess
it from `created_by`: measured on the BWJ board, the form creates every card as its own owner, so
`created_by` reads identically whether a colleague asked for it or a session filed it.

**Propose the stage map against the board you actually read in step 5, not against the example.** The
keys are the cycle and are fixed; the numbers are that board's and nothing else can supply them. Say
plainly that a wrong map is *silent*: every card lands a column early or late, on a board whose whole
job is telling somebody where their request is. It is a `.ps1` in the repo, so it goes through that
repo's ordinary branch and review route like any other change.

**Propose the value against a real board that is this store's own, never copied from the other
store's.** This page used to say the choice was settled on exactly one board across both stores (Dave,
September 2, 2026). Measured today the workspace holds two GitHub boards, one per store -- `GitHub -
SWB` and `GitHub - WH` -- so whatever landed on `main` back then, the present tense above no longer
describes the workspace; whether the decision itself was superseded since or was never carried through
is not something this measurement can distinguish, only that it does not hold now. Two independent
constraints decide what the GID has to name, and both are satisfied by a per-store board exactly as
well as by a shared one:

- **The prio labels.** `Prio-Score` only reaches a task once it has actually been added to that task's
  project, via the project's own `custom_field_settings` -- sitting in the same workspace as the board
  is not enough to guarantee that -- so a task created in a project that does not carry the field can
  never carry a `Prio-Score`, and the sweep of
  [step 5](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md#5-the-asana-prio-score-comes-back-as-a-github-label)
  then reaches only the tickets *imported from* the board
  ([#1213](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1213),
  [#1386](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1386)).
- **The stages.** They live on that board's own sections, so a task filed anywhere else sits on no
  pipeline and never moves a column -- see step 5 below.

**Both bullets argue for a real board rather than a provisional one -- they do not argue for one
board rather than two.** The GID has to name a project that actually carries the `Prio-Score` field
and numbered sections, and each store repo answers that seam with a board of its own: the value is
never copied between them. **A copied value costs exactly as silently as a provisional one**: the
second repo mirrors its issues onto the other store's board, the create call succeeds, the field
writes, the sections still move a card -- nothing fails on the day, and the only symptom is
colleagues on one store finding the other store's tickets sitting on theirs.

`smartwatchbanden` now answers `Get-AsanaProjectGid` with its own store's board, and
added a test asserting both halves at once: that the value names smartwatchbanden's own board, and
that xoxowildhearts' GID is never adopted in its place -- because a copied value is exactly what the
old wording invited
([BWJ-ecommerce/smartwatchbanden#508](https://github.com/BWJ-ecommerce/smartwatchbanden/pull/508), the
PR; [#470](https://github.com/BWJ-ecommerce/smartwatchbanden/issues/470), the issue).

**A provisional GID is where both costs land at once**, and neither says anything in a log: such a
ticket carries no prio label and never advances a stage. So if the real project is not known yet,
record that both are incomplete until it is.

**`Get-AsanaIssueFieldGid` is addressed by GID rather than by name, and that is worth flagging
because it breaks the pattern step 5's `Prio-Score` reading sets.** The reconcile sweep of step 5
looks that field up by *name*, because it is **reading** a task back and the Asana API hands back a
custom field's name alongside its value -- no GID needed. Creating a task and setting one of its
custom fields in the same call is the opposite direction: the `create task` call addresses a custom
field by its GID, which Asana Field settings shows on the field's own page, in the URL. **The same
per-project constraint
[step 5](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md#5-the-asana-prio-score-comes-back-as-a-github-label)
already states for `Prio-Score` applies here too** -- an Asana custom field only becomes usable once it
has been *added to* a project via that project's own `custom_field_settings`, and definition in the
right workspace is not enough to guarantee that, so this GID has to come from a field that is actually
on `Get-AsanaProjectGid`'s own project. And it is **plainly optional**: `$null`, the default, means
the board carries no `Github Issue` field, and `report-issue` skips the write silently -- a repo
without the field loses nothing by leaving it unset.

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

## 3 -- print the CI secret and variables (the maintainer sets these)

The CI workflow needs, on the repo (Settings -> Secrets and variables -> Actions):

- **Secret** `ASANA_PAT` -- an Asana personal access token with write access to the project.
- **Secret** `GH_PROJECT_TOKEN` -- a GitHub PAT that can **read the organization's Projects v2**.
- **Variable** `ASANA_PROJECT_GID` -- same value as `Get-AsanaProjectGid`.

Print these as a checklist. This skill does not set secrets.

**`GH_PROJECT_TOKEN` is not optional if you want the stage sweep off a project board**, and it is worth
saying why rather than listing it. The three middle stages are read off the project board's `Status`
field, and `GITHUB_TOKEN` -- the token the workflow gets for free -- **cannot see an organization's
Projects v2 at all**. There is no `permissions:` key that grants it; it is not a scope this workflow can
ask for.

Without the secret the workflow still runs and the close update still goes out: the query retries once
without the project field, and the log says the status could not be read. **So the symptom is cards that
never move, with the reason in the run log** -- which is the right failure, but only if somebody reads
it. Say that plainly when you report, because "the mirror works" and "the board moves" are two claims
here and the first can be true while the second is not.

**ASK WHETHER THIS REPO HAS A PROJECT BOARD AT ALL, before you print the secret** (inbound
[#1536](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1536)). Where it has none, the
secret is not a gap to close but a line to leave out: there is nothing for the token to read. Such a repo
says so with an empty `FieldName` and no `Statuses` in `Get-GithubStatusMap`, and the three middle stages
then come off the issue itself -- closed means `InReview`, open with a pull request linked means
`InDevelopment`, open with nothing linked means `Filed`. Report it as **a choice between two working
configurations**, never as one configuration with a missing secret.

**And say what the missing declaration used to cost, because it is why this paragraph exists.** With no
board and no way to say so, every issue derived no stage -- which also switched off the promotion that is
not a column at all: a card reaches `ReadyToTest` only from a floor already at `InReview`, so closing an
issue no longer handed it back to the submitter. The close update still went out. The person was told the
work was ready, their card never moved, and no run failed.

**There is deliberately no workspace variable here**, and do not add one back: the CI half addresses
every task and project by GID, so it never needs the workspace. `Get-AsanaWorkspaceGid` from step 2
stays -- `report-issue` reads it session-side, where it CREATES a task and the API does want a
workspace.

## 4 -- make sure the classification labels exist

[`report-issue`](../report-issue/SKILL.md) files every issue with an issue type, and with the reach
label and `documentation` where they apply. **`gh issue create` fails outright on a label the repo
does not have**, so check for both and create whichever is missing. **Read `Get-ReachLabel` from
`scripts/repo-config.ps1` first** and check for *that* name -- `minor` where the repo has never
answered it, which since [#1870](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1870) is
the workflow's own default. **A store still carrying `tier-1` and answering nothing is the one state
that now files against a label it does not have**, and `gh issue create` refuses the whole call over
it -- no issue at all, not even one without the label. Repair it here rather than working around it:
rename the label, or state `tier-1` in the seam.

```bash
gh label list --repo <owner>/<repo> | grep -E '^(<reach label>|documentation)\b'
gh label create "<reach label>" --repo <owner>/<repo> --color fbca04 \
  --description "Reaches the business: management and the commissioner notice it"
gh label create documentation --repo <owner>/<repo> --color 0075ca \
  --description "A doc finding, on top of whatever issue type it has"
```

**Both names in that check now have a `create` line beside them, and until September 11, 2026 only
one did.** The grep named two labels and the step created the reach label alone, so a repo missing
`documentation` got a hit in the check and no instruction -- a check whose result nothing acts on
([#1846](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1846)). It has never bitten,
because `documentation` is one of GitHub's own default labels and both BWJ stores carry it; that is
what kept the gap invisible, not what makes it safe. The label is load-bearing --
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#classify-it-as-you-file-it----three-fields-all-set-at-creation)
records why Dave kept it where `bug` and `enhancement` were deleted, and 42 doc issues across the two
stores sit on it -- so a filing that reaches for it in a repo without it fails at the `gh issue
create`, exactly as a filing that reaches for the reach label does.

**It gets no seam, and that is the same answer the reach label's own paragraph gives below**: a seam
is written where a rename has actually been paid for. Nobody has renamed `documentation`, so what was
missing here is a command, not a seam, and the two are not repaired the same way.

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

**The hazard is not unique to this label; the measurement is.** Rename `documentation` or a prio label
and this step would re-create that one beside it in exactly the same way -- the difference is that
`needs-info` already has a seam (`NeedsInfoLabel`), the prio labels are written by a sweep that would
report a failure, and the reach label is the one a consumer has actually renamed. So the pause is
written here, where it has been paid for, rather than four times on speculation. If a second rename
lands on one of the others, that is the moment for its own seam -- not a reason to widen this one now.

**And the `CRO` label -- store repos only, never here.** It marks an issue filed by, or on behalf of,
the CRO team (today: Johnno), and it exists in exactly two repos: `smartwatchbanden` and
`xoxowildhearts`. **Skip this label entirely when this skill runs against `dkj-claude-plugins`** -- that
repo has no Shopify store for a CRO team to measure, and it is a permitted adoption target for the
ticket-handling chapter alone, not for this label. See
[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md#the-cro-label----who-reported-it-not-what-it-is)
for the reasoning.

```bash
gh label create CRO --repo <owner>/<repo> --color 5319e7 \
  --description "Filed by, or on behalf of, the CRO team (currently Johnno) -- store repos only"
```

**And the four prio labels**, which the reconcile sweep needs: it sets one of them on every open
issue from its Asana task's `Prio-Score`, and `gh issue edit` fails on a label the repo does not have
exactly as `gh issue create` does.

```bash
gh label create prio-4 --repo <owner>/<repo> --color b60205 \
  --description "Asana Prio-Score 4.00-5.00"
gh label create prio-3 --repo <owner>/<repo> --color d93f0b \
  --description "Asana Prio-Score 3.00-3.99"
gh label create prio-2 --repo <owner>/<repo> --color fbca04 \
  --description "Asana Prio-Score 2.00-2.99"
gh label create prio-1 --repo <owner>/<repo> --color 006b75 \
  --description "Asana Prio-Score 1.00-1.99"
```

**The DESCRIPTIONS are score-shaped and that is load-bearing, not decoration.** The names are now the
same four the source repo's own tracker uses, where a rung is a judgement somebody typed; here it is
derived from a board nobody in this repo can see. The description is the one place a badge still says
**which motor set it**, and it survives a rename untouched -- so keep the `Asana Prio-Score` wording
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
gh label edit "high"      --repo <owner>/<repo> --name prio-3 --color d93f0b
gh label edit "low"       --repo <owner>/<repo> --name prio-2 --color fbca04
gh label edit "very low"  --repo <owner>/<repo> --name prio-1 --color 006b75
```

**`prio-2` shares `fbca04` with `tier-1` in this repo, and that is known rather than a slip.** They
are two different axes -- a rung and a reach -- so both can sit on one issue as two identical yellow
badges. It is the hex [#1842](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1842)
prescribes, and whether either label moves is Dave's to decide:
[#1844](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1844). Read the name, not the
badge.

**Do the rename and the `asana-mirror.ps1` refresh of step 1 in one sitting, in either order.** The
copy in `.github/scripts/` is made by hand, so the gap between the two is yours to keep short -- and
the sweep that reads these labels runs only on the daily `reconcile` cron, so a run caught inside the
gap costs one sweep and the next morning repairs it. The sweep also removes the four old names as it
sets a new one, so a repo that ended up with all eight anyway is swept clean rather than left
claiming two priorities at once.

**And the `needs-info` label**, which is the entire mechanism for the board's blocked column: while it
is on an issue the card sits in `NeedsInfo` whatever the branch and the pull request are doing, and
taking it off returns the card to wherever the work actually is. Name it in
`Get-AsanaStageMap`'s `NeedsInfoLabel` if the repo prefers another word; set that to `''` and the
column is switched off, which is a real answer for a board without one.

```bash
gh label create needs-info --repo <owner>/<repo> --color d4c5f9 \
  --description "Blocked on the person who filed it -- parks the Asana card in the blocked column"
```

Four buckets and deliberately no `medium` (Dave, September 2, 2026). **Exactly one of them sits on an
issue at a time** -- the sweep removes the other three as it sets one, so a ticket rescored from 2.5
to 4.2 loses `prio-2` as it gains `prio-4`. A task with **no** score, or a score outside 1.00-5.00,
gets no prio label at all rather than a guessed one; on the BWJ board the day this shipped that was
28 of 96 open tasks, so it is the common case and not an edge one.

The three issue **types** (Task / Bug / Feature) are org-wide, not per repo, so there is nothing to
create for them -- confirm in the org settings that they are enabled and stop there. Do **not** create
`bug` or `enhancement` labels: the type carries both, and they were deliberately deleted from the
existing BWJ repos.

## 5 -- check the board's sections are numbered

The stage model of
[step 6](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md#6-the-boards-sections-are-the-cycle----one-card-one-column-per-stage)
reads a card's stage off the **number its section's name starts with**, and takes the *meaning* of
each number from `Get-AsanaStageMap`. **This step is where both halves are established, and it comes
before step 2's proposal can be written** -- read the sections of the project and report them:

```text
<N>. <anything>   ->  which stage of the cycle this column is
```

The words after each number belong to the team; only the number is read. **Report what you find and
change nothing** -- a board is a shared surface, and renaming somebody's column is not an adoption
step. Then map the columns you found onto the seven cycle stages and put *that* in the step 2
proposal. Four cases are worth naming explicitly when you report:

- **No numbered sections at all.** Nothing is ever moved on that board. That is the safe default, and
  it is *silent* -- so a board meant to be a pipeline and not numbered looks exactly like one that
  works. Say so plainly.
- **A gap in the middle** (say, no `4.`). Cards simply stop at the stage below it and the log says
  which section was missing. Nothing is created.
- **More columns than stages.** A board may have columns this cycle has no stage for. Leave them out
  of the map: an unnamed column is a **hold** -- not a target and not a source -- so cards parked
  there stay put. That is the intended way to keep a column out of the pipeline.
- **A board numbered differently from the example.** Then the example map is wrong for this repo and
  `Get-AsanaStageMap` is not optional. The board this model was first written against gained a column
  the same afternoon it shipped, which moved every stage above it by one -- so treat "the default
  happens to fit" as a claim to verify here, not to assume.

### And read the GitHub side of the same question

The three middle stages come from the **project board's `Status` field**, so that field is the other
half of this step. Read its options and report them beside the Asana columns:

```bash
gh api graphql -f query='
query { organization(login: "<org>") { projectV2(number: <n>) {
  fields(first: 30) { nodes { ... on ProjectV2SingleSelectField { name options { name } } } } } } }'
```

Four cases to name when you report:

- **The three defaults** (`Todo` / `In Progress` / `Done`). The built-in status map fits, and
  `Get-GithubStatusMap` is optional.
- **Renamed or translated columns.** Then the map is **not** optional -- the status names are its keys,
  and an unmapped column derives no stage, so cards simply stop moving.
- **A fourth column** (a `Blocked`, a `Icebox`). Leave it out of the map: an unmapped status is a
  **hold**, which is the intended way to park a card outside the pipeline.
- **No board at all** -- the query above returns nothing, or the repo's org simply keeps none. Then the
  map is **not** optional either, and what it must say is that there is no board: an empty `FieldName`
  with no `Statuses`. The stage then comes off the issue, and `GH_PROJECT_TOKEN` is not needed. **Do not
  report this as the first case**: the built-in map names three columns this repo does not have, so
  "the default fits" is exactly wrong here, and it is the reading that made inbound #1536 silent.

**Also report which of the project's built-in workflows are enabled**, because they are what writes
that field: `Item added to project`, `Pull request linked to issue` and `Item closed` are the three
that matter. A board where those are off has a `Status` nobody maintains, and then this whole half of
the model reads a stale column -- which looks exactly like a board that works.

## 6 -- point the repo's governance at the rule

Add a line to the repo's `CLAUDE.md` (or a repo lens) pointing at
`~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/dkj-policy-bwj/WORKFLOW-portable.md`
so a session reads the BWJ ticket rule the same way it reads the other portable pages.

## 7 -- scaffold the sync-log folder (chapter two)

Chapter two's record needs somewhere to land before the first `sync/` branch ever runs. If
`Get-ShopifySyncLogPath` is not yet answered, propose it alongside the Asana seams in step 2, in the
same `scripts/repo-config.ps1` -- `'dkj-policy-bwj/SYNC-LOG.md'` in both store repos. Either way, once it is
answered, create the file it names, with nothing in it but a masthead:

```markdown
# Sync log

One entry per `sync/` branch, newest at the top. Written and committed by `sync-main.ps1` -- never
folded into `CHANGELOG.md`, never read by a release.
```

**If the file already exists, leave it alone** -- the same rule step 1 uses for the CI mechanism: this
only ever adds, never overwrites. `Add-SyncLogEntry` reads everything above the first `## ` line as the
masthead and prepends new entries beneath it, so this is not a stub waiting to be replaced -- it is the
permanent header the first real entry lands under. See
[`SYNC-LOG-portable.md`](../../SYNC-LOG-portable.md) for the rule this scaffolds.

## What this skill does not do

- It does not enable the plugin -- that is a `.claude/settings.json` change you make first.
- It does not create the Asana project or token.
- It does not register this repo in the source repo's `connectors/` register -- that happens in the
  source repo after this repo's settings change has merged.
- **It does not set up the shared pages worker.** That seam (`Get-BwjPagesConfig`), the KV namespace
  and the one-time deploy are [`publish-page`](../publish-page/SKILL.md)'s own setup section, and they
  stay there deliberately: this skill's steps are per repo, while that worker is created **once for
  both stores** and the second store answers the same four values the first one already has.
