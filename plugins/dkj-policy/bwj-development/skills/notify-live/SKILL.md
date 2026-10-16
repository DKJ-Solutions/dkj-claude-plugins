---
name: notify-live
description: >-
  Tell the Asana task of every issue a store release carried that its work is now live -- run right
  after the live push (or the promotion merge) and the cut, as the release-day runbook's step after the
  cut. It finds the PRs merged in the release's tag range, the issues they closed, and tells only those
  whose closed message said the result "becomes visible with the release": a -LiveSince issue was told
  at the close and a research issue changed nothing. A dry run by default; -Post sends one comment per
  task and marks the issue so nobody is told twice. Use it when a release has just gone live.
---

# notify-live -- the message after the release

An issue that is built but only visible after a release closes at the PR step, and its closed message
says the result *"becomes visible with the release named below"*
([#3069](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3069)). Until this skill nothing
told the task when that release had actually gone out, so the requester had to work out for themselves
whether the release day's release carried their work
([#3070](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3070)).

**It is a step a person runs, on purpose** (Maikel's decision on #3070). The live push is printed for a
person to run and never run by a script, so nothing automated knows the moment a release *is* live. A
step in the cut, or a `release: published` workflow, would say "live" while the store could still show
the old theme. [`prepare-release`](../prepare-release/SKILL.md)'s runbook prints this skill as the step
after the cut, so it is not forgotten.

## What the skill does

Run the shared script from the **root of the store repo**, after the cut:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/notify-live.ps1"
```

1. **The release** -- `-Version` (default: the highest `vX.Y.Z` tag) and the tag below it, compared as
   versions.
2. **The PRs** -- every `#<n>` in the range's first-parent commit subjects, kept only where that PR is
   merged and its merge commit is inside the range, whatever form the store merges in.
3. **The issues** -- the issues those PRs closed, each read with its comments and its last reopen.
4. **The verdict** -- an issue is owed the message only where it is closed as completed, links exactly
   one Asana task (the same matchers the closed message uses, so it is the same task), has not been told
   yet, and its newest go-live block is this round's and carries the after-release marker. Every other
   issue is listed with the reason it is skipped.
5. **The post** -- with `-Post` only: one comment per owed task, then a marker comment on the GitHub
   issue, so a second run tells nobody twice.

**Read the dry run before `-Post`.** It names every issue and why it is owed or skipped, and prints the
message the first one would receive. A change whose files were held back from the push is something this
script cannot see, so hold that issue out with `-SkipIssue`.

## The message

In the automation's form, like the closed message: the header, then
*"GitHub issue `<repo>#<n>` is now **live**, as version `vX.Y.Z`: the review can start now."*, then the
go-live block's own closing ask -- its heading and its yes and no sentences -- in the language the
block was written in. Only the state word is bold.

## The parameters

| parameter | what it is for |
|---|---|
| `-Version <vX.Y.Z>` | the release that went live. Defaults to the highest `vX.Y.Z` tag |
| `-SinceTag <vX.Y.Z>` | the tag the range starts at, instead of the highest one below `-Version` |
| `-Post` | send the messages. Without it nothing is written |
| `-SkipIssue <n>[,<n>]` | hold issues out by hand -- a change whose files were held back from the push |
| `-Repo <owner/repo>` | instead of `Get-RepoName` or the checkout's own |
| `-AsanaPat <token>` | instead of `ASANA_PAT` |
| `-RootOverride <path>` | the repo root, when the run does not start inside the checkout |

The exit code is `0` when every read and post succeeded, and `1` when one failed. An issue that could
not be read is named and not told, never guessed at.

## What it deliberately does not do

- **It writes nothing but the two comments.** No push, cut, tag, card move, task completion or label.
- **It prints nothing another person wrote** beyond an issue number. A failed post reports its HTTP
  status alone, the rule the closed message keeps.
- **It does not read the live-push record.** That record belongs to `dkj-policy` and
  `dkj-subagents-shopify`, outside this plugin's folder, which is why `-SkipIssue` exists.

## Requirements in the consumer

`git` and `gh`, authenticated. **`ASANA_PAT` in the session's environment** (or `-AsanaPat`) -- the
personal token [`build-backlog-page`](../build-backlog-page/SKILL.md) reads too -- asked for only by
`-Post`, and only when a task is owed the message. It reads `Get-RepoName` from `scripts/repo-config.ps1`
where the repo answers it. It refuses to run in this plugin's own source repo, which has no release to
announce.

## Important

This script is maintained in the source repo; do not modify it locally in a consumer. A change lands
first in the source and then travels via a release to the plugin mirror.
