---
name: golive-block
description: >-
  Write the paste-ready block for a GitHub issue, including its go-live half: where the result can be
  seen, when it is planned to go live (the next release day), which version it is on course for, and
  the live storefront URL per market. Use it as the closing act of the chain that shipped the work,
  while the issue is still OPEN -- closing the issue is the confirmation that the block reached the
  Asana task. It prints by default and posts only with -Post; it never touches Asana, and it never
  writes a placeholder link.
---

# golive-block -- the block a colleague reads, with the date and the version in it

`WORKFLOW-portable.md`'s paste-ready block answered *where can I see it* and stopped there. The
requester's next question is always *and when do I actually see it*, and the ticket is the only place
they are looking -- so the block carries three more facts
([#2100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2100), Dave,
September 18, 2026).

## What the skill does

Run the shared script from the **root of the repo the issue is on**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/build-golive-block.ps1" -Issue 412 -Link "https://..." -Path "/collections/straps" -Post
```

1. Resolves the issue (a bare number, `#412`, or its URL) and the repo.
2. **The date** -- the next release day, strictly after today. BWJ cuts on a Monday, which is the
   default; `-ReleaseDay` is there for a repo on another cadence.
3. **The version** -- the newest `vX.Y.Z` tag, stepped by the bump the changelog's pending tally
   already names.
4. **The live URLs** -- `Get-MarketUrls` over the pages `-Path` names: the LIVE URLs, with no preview
   parameters, out of the same market table a preview pair is built from.
5. Prints the block. With `-Post`, comments it on the issue.

## The parameters

| parameter | what it is for |
|---|---|
| `-Issue <n>` | required; a bare number, `#412`, or the issue's URL |
| `-Link <url>` | where the result can be seen. **Omitted, that sentence is not written at all** -- see below |
| `-Path <p[]>` | the storefront pages the change touched; each becomes one live URL per market |
| `-Repo <owner/repo>` | when `GITHUB_REPOSITORY` and `gh repo view` cannot answer |
| `-Version <X.Y.Z>` | override the prediction, or supply one where it cannot be derived |
| `-ReleaseDay <day>` | the weekday releases are cut on. `Monday` |
| `-From <date>` | the day the next release day is counted from. Today |
| `-Post` | actually comment it on the issue. Without it, nothing is written anywhere |
| `-Force` | post although a block already appears to be there, or its comments could not be read |

## What it deliberately does not do

- **It never writes `[ADD LINK]`.** That placeholder belongs to `asana-mirror`'s CI backstop, which
  genuinely cannot know the link. A session running this script does know it, so a link it was not
  given is a **sentence it does not write** -- a missing line, never a placeholder.
- **It never touches Asana.** A person pastes the block into the task, and closing the issue is their
  confirmation that it landed there. That is the one decision this chapter keeps with the colleague
  who asked for the work, and a script cannot reach the Asana MCP anyway.
- **It never promises.** *"Planned to go live with the release of Monday 22 September 2026, as version
  v1.4.0"* is a cadence and a projection: a tier-1 entry landing on the Friday turns that patch into a
  minor, and a release can slip. This block is the one surface a colleague quotes back, so it must not
  read as a commitment nobody made.
- **It guesses nothing.** No `v*` tag, or a pending tally it cannot read, means the sentence names no
  number. A repo that has declared no storefront markets gets no live-URL list.

## The order is the rule, and this script is the second-to-last step

```text
work shipped -> build-golive-block -Post -> paste into Asana -> close the GitHub issue
```

**While the issue is still OPEN.** Nobody returns to a closed one, which is the whole finding behind
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049): a comment posted at the close
appears underneath an item that has just left every open-issue view. The script warns where the issue
is already closed and posts anyway -- a late block beats the backstop's placeholder copy.

**And it refuses a second block by default.** `Test-AsanaPasteBlockPosted` -- the backstop's own
de-duplication -- answers *true* where it cannot read the comments, which is the safe default for CI
and the wrong one here, so an unreadable issue is reported as exactly that and `-Force` is the way
past it.

## Where the rule lives

[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md), chapter one, under *The paste-ready block*. The
other cycle step this plugin adds -- the storefront-visibility step, last under `### CREATE` -- is in
[`PREVIEW-portable.md`](../../PREVIEW-portable.md), and both are indexed in
[the README](../../README.md#what-the-cycle-gains-here).

## Requirements in the consumer

`gh`, authenticated, for resolving the repo and for `-Post`. `git`, for the tag. The live-URL half
needs `Get-StorefrontMarkets` in `scripts/repo-config.ps1`, and is skipped entirely where no `-Path`
is given -- so a repo with no storefront never has to answer it. The changelog is found through
`Get-ChangelogPath`, defaulting to `CHANGELOG.md`.

## Important

This script is maintained in the source repo; do not modify it locally in a consumer. A change lands
first in the source and then travels via a release to the plugin mirror.
