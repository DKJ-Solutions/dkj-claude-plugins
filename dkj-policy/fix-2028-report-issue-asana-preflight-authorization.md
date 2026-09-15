## fix/2028-report-issue-asana-preflight-authorization

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#### What #2028 reported, and what verifying it changed

The report names one line in `plugins/dkj-policy/dkj-policy-bwj/skills/report-issue/SKILL.md` -- the
last bullet of the `## Before you start` preflight, *"Confirm the Asana MCP tools are **available** in
this session"* -- and it stands unchanged on `main`. Availability and authorization come apart, and
the measurement behind the report is the state where they do: on a `smartwatchbanden` checkout,
September 15, 2026, both registered Asana connectors were authenticated and both answered
`unauthorized` for the project `Get-AsanaProjectGid` names, because the MCP was bound to workspace
`1206473494432180` while `Get-AsanaWorkspaceGid` names `1199613597897177`. The CI half drove that same
board green over `ASANA_PAT` throughout, so only the MCP was wrong.

**In that state the preflight reports green and the procedure half-runs:** step 1 files the GitHub
issue, and step 2's `create task` is where the session learns -- inside the one branch the preflight
was written to get ahead of. The source-of-truth guarantee is not at risk (the issue is filed first
and unconditionally), so the cost is the green itself.

**One thing verification added, and it is what makes the repair cheap.** The report calls the board
probe "not an extra round trip", and that is exact: step 2 already reads that project twice over --
once for the numbered section, once for the `Github Type` select field's option GIDs -- so the repair
MOVES a read rather than adding one, and the answer carries forward into step 2 unchanged.

**Checked and NOT a finding**, so nobody widens this later:

- `WORKFLOW-portable.md`, which this page names as the full rule it implements, says nothing about the
  MCP at all -- the preflight is a step, and steps live on the skill page. One site, not two;
- `adopt-dkj-policy-bwj`'s own preflight carries no availability check to mirror the defect;
- the consumer-side remedy -- re-authorizing the connector against `BWJ E-Commerce`, and the duplicate
  `claude.ai Asana` / `claude.ai Asana (2)` registration -- is machine and account state, not repo
  state. The report scopes it out and so does this branch.

### CREATE

- [x] the availability bullet in `## Before you start` replaced by a **board probe**: read the project
      `Get-AsanaProjectGid` names, which is step 2's own read made earlier, and carry its answer forward
- [x] a second bullet routing a missing tool and an `unauthorized` board into the same branch -- still
      do step 1, then stop -- and requiring the note to name the **wrong workspace** as the cause,
      because *available but unauthorized* otherwise reads to a session as a connector it broke, while
      the remedy is a re-authorization no session can perform from here
- [x] step 2's select-field paragraph pointed at the read the preflight already made, so the two halves
      cannot drift into describing two different calls
- [x] step 2's `unreachable` fallback widened to a write the preflight's read could not cover, since
      the preflight now catches the board-refusal case ahead of it

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: four asserts over the preflight -- the retired availability wording is
      gone, and the block names an `unauthorized` outcome, the project the seam names, and the wrong
      workspace as the cause
- [x] the asserts are **scoped to the `## Before you start` block**, not the page: step 2 names
      `Get-AsanaProjectGid` too, so a page-wide sweep would stay green with the preflight bullet deleted
      -- the one edit this guards
- [x] a fifth assert pins that the preflight block is still findable at all, so a renamed heading fails
      loudly instead of emptying the string every other assert reads
- [x] **measured against the pre-branch tree rather than asserted:** with `main`'s copy of the skill page
      restored, the block is 4 failed / 297 passed; on the branch, 301 passed. A sweep green on the tree
      it was written for proves nothing about the one it was written against
- [x] `check-plugin-integrity.ps1` + every suite green

### DEPLOY: fix/2028-report-issue-asana-preflight-authorization

`report-issue`'s Asana preflight asked whether the MCP tools were **available**, and availability is not
authorization. A connector can be registered, authenticated and answering while bound to a different
workspace than `Get-AsanaWorkspaceGid` names -- and then the tool list looks healthy and every call
against the board answers `unauthorized`. Measured on a `smartwatchbanden` checkout, September 15, 2026:
both registered Asana connectors authenticated, both `Not Authorized` for the project the seam names,
while the `asana-mirror` CI half drove that same board green over its own `ASANA_PAT`. The preflight
passed, step 1 filed the issue, and the session found out from a failing `create task` in step 2 --
inside the branch the preflight exists to get ahead of.

The preflight now **probes the board instead of the tool list**: it reads the project
`Get-AsanaProjectGid` names, which is the read step 2 already makes for the numbered section and for the
`Github Type` select field's option GIDs, only made earlier -- so the repair moves a read rather than
adding one, and its answer carries forward. A missing tool and an `unauthorized` board take one branch:
file the GitHub issue, then stop. The note that stops has to name the **wrong workspace** as the cause,
because *available but unauthorized* reads to a session as a connector it broke, whereas the remedy is a
re-authorization against the workspace the seam names and no session can perform it.

The suite pins the preflight rather than the page, because step 2 names the same seam function and a
page-wide sweep would stay green with the preflight bullet deleted.

**Score:** 3

#### What makes this deploy extra special

N/A. `dkj-policy-bwj` is tooling for the repos that run the BWJ ticket procedure, and nothing a
subscriber of a service takes delivery of changes here. The reader this page is written for is a
colleague inside the business -- the tier-0 audience one hop before the tier-2 one.

**Score:** N/A

#### Pull Request

report-issue's Asana preflight probes the board, not the tool list

