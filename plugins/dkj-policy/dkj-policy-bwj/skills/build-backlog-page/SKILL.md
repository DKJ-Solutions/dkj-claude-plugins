---
name: build-backlog-page
description: >-
  Build minor-backlog.html: the open issues carrying the reach label, shown with the colleague-facing
  text their mirrored Asana tasks already carry -- never the GitHub issue's own developer-facing title
  and body. Use it whenever the backlog page needs refreshing before a publish, or to see what a
  colleague would currently read. It only writes the local file; publish-page.ps1 -Kind backlog is the
  separate, later step that sends it out.
---

# build-backlog-page -- the minor backlog, for a reader with no repository

Issue #1979, the builder split out of #1977. That issue's worker and `publish-page.ps1` already route
and publish the `backlog` kind; this is what puts a real page in front of them to publish.

## What the skill does

Run the shared script from the **root of the store repo**:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/build-backlog-page.ps1"
```

It reads this repo's **open** issues carrying the reach label (`Get-ReachLabel`, default `minor`),
resolves each one's mirrored Asana task from the marker `report-issue` already writes
(`<!-- asana-task: <gid> -->`), and renders that task's `Name` and `Notes` -- not the issue's own
title and body -- into `minor-backlog.html` in the page directory `publish-page.ps1` already derives
from `Get-ReleaseNoteRoot` (`<note root>/../page`).

## Whose text renders, and why this is not a re-parse of report-issue's skeleton

Decided on the issue before this was written (Dave, September 14, 2026): the page shows the **Asana
variant**, because that is the text written for the reader it serves -- plain language, outcome-framed,
no repo jargon -- while the GitHub issue is written for a developer. An issue with no mirrored task yet
contributes **nothing** to the page rather than falling back to its own (wrong-register) text.

The Asana task's `Notes` field is shown **verbatim**, whatever shape it carries, rather than re-parsed
back into report-issue's "What is wrong / Where / How urgent" fields. A ticket filed the GitHub-first
way carries that fixed skeleton; one imported the other way round carries a colleague's own words. Both
are already colleague-facing by construction -- that is what makes them fit to publish -- so re-parsing
would only add a shape the notes have to match, and refuse the ones that do not.

## What is dropped, and why silently

- **An issue with no marker, or an ambiguous one.** Reported in the run's own output as a skip, never
  as a page defect -- the ticket has simply not been mirrored yet.
- **A task this token cannot read.** The token may lack access to that task's workspace; reported and
  skipped rather than guessed at.
- **A task Asana already shows as completed**, even while its GitHub issue is still open. That is a
  sync gap between the two trackers, not a reason to tell a colleague the work is outstanding.

None of the three ever produces broken markup or a dead link on the page -- the entry is simply absent,
and the run's own output says why for each one it dropped.

## No link back to the issue, anywhere

The page never links to the GitHub issue. The reader has no login for a private BWJ store repo, so a
link they cannot follow is worse than no link -- the same reasoning that keeps issue numbers off the
rendered page entirely (`Number` exists in the resolved entry only to sort by; it is never shown).

## Parameters

| parameter | what it does |
|---|---|
| `-Repo <owner/repo>` | which store repo. Defaults to `GITHUB_REPOSITORY`, then to what `gh repo view` resolves from the checkout |
| `-AsanaPat <token>` | defaults to `ASANA_PAT`. Asked for only once at least one issue has a mirrored task to read -- an empty backlog never needs it |
| `-Html <path>` | write somewhere other than the page directory's own `minor-backlog.html` |
| `-DryRun` | resolve everything and print the entry count and every skip -- write nothing. Still reads `gh` and Asana: previewing what would be built means actually building it |
| `-RootOverride <path>` | the repo root, when the run does not start inside the checkout |

## Requirements in the store repo

- `scripts/repo-config.ps1` answering `Get-ReachLabel` (optional, defaults to `minor`) and
  `Get-ReleaseNoteRoot` (optional, defaults to `releases/notes`) -- the same two seams
  `report-issue` and `publish-page.ps1` already read.
- `gh`, authenticated, for the two reads this makes: `gh repo view` (only when `-Repo` and
  `GITHUB_REPOSITORY` are both empty) and `gh issue list`. Neither writes to GitHub.
- `ASANA_PAT` in the environment (or `-AsanaPat`), needed only when at least one issue actually has a
  mirrored task to read.

## A failed issue listing throws -- it does not fall back to an empty page

`asana-mirror.ps1`'s own `Get-OpenIssues` returns nothing on a `gh` failure, correctly: it drives a
best-effort CI sweep where a skipped run costs nothing. This script produces the one artifact a
colleague reads, and a silently empty page from a broken `gh issue list` would read as **"nothing
outstanding"** -- the one wrong answer this script must never give by accident. So a failed listing
stops the run instead.

## Important

- **It never writes to GitHub or to Asana.** Every network call here is a read. The one write in the
  whole run is the local HTML file, which is why -- unlike `publish-page.ps1`, which sends that file
  out from behind a private repo's walls -- this skill is left model-invocable.
- **It does not publish.** `publish-page.ps1 -Kind backlog` is the separate, later, explicitly-typed
  step (`disable-model-invocation: true`, deliberately) that sends the file this script wrote to the
  shared worker.
- **This script is maintained in the source repo**; do not modify it locally in a store. A change lands
  there first and then travels to both stores via a release.
