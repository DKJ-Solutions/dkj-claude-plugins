---
name: prepare-release
description: >-
  Stage a store release days ahead of release day, so the day itself is push, verify, cut. Use it when
  the release is coming up and you want to be ready now -- "the release goes out on Monday, get me
  ready". It reads the trunk, the pending changelog entries and the bump they add up to, derives the
  theme push list by the same rules live-preflight uses, runs an early drift read, collects the
  go-live obligations buried in entry prose, lists open pull requests that could still ride along, and
  prints the release-day runbook. Read-only: it never pushes, cuts, tags, or writes the authorisation
  marker.
---

# prepare-release -- the Friday before the Monday

The chain has tools for the **moment** of release -- `live-preflight`, the push, `cut-release`,
`theme-lifecycle`, `golive-block` -- and until this skill it had nothing for *"release is on Monday,
get me ready now"*. Answering that meant reading five lens sections and running the diff by hand
([#2509](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2509)). This skill is that
sequence as one read-only run.

## What the skill does

Run the shared script from the **root of the store repo**, on the trunk:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prepare-release.ps1"
```

1. **Trunk** -- on the trunk, clean, level with origin, no branch document left unfolded beside the
   changelog, and every check run on the head green.
2. **Scope** -- every pending entry, the bump the fold's pending tally names, the version that makes,
   and whether a minor owes the hand-written audience note.
3. **Scores** -- in a repo whose audience is tier 1, a `fix/` entry that scores its reach is flagged
   for a second look. Advisory: the cut's tier gate decides.
4. **Push list** -- the range's theme files, by the **same rules** `live-preflight` uses
   (`live-push-rules.ps1`, mirrored into this plugin from its one source). Files that came in through a
   sync are held back, and files new on the theme are marked.
5. **Early drift** -- the repo's own drift check over that list, passed as an array, so a third-party
   edit is found days ahead and can get a `sync/` branch. **It runs again, for real, on the day**:
   `live-preflight` does that, and this read does not replace it.
6. **Go-live obligations** -- the *"once this is live"* sentences in the entries' own text, as one
   checklist. Matched by phrase, so it is a candidate list and says so.
7. **Open work** -- open pull requests against the trunk, so what rides along is decided before the
   weekend.
8. **The runbook** -- the day in order: preflight, push, verification pull, obligations, preview sweep,
   cut, backup, release-notes page. Every fact the run derived is filled in; one it could not derive is
   named as missing, never guessed.

The exit code is a summary: `0` when nothing needs attention, `1` when something does. A step that
could not measure is reported as skipped and named, never counted as passing.

## The parameters

| parameter | what it is for |
|---|---|
| `-Store <domain>` | the store domain. Defaults to `Get-ShopifyThemeEstateStore` |
| `-SinceTag <vX.Y.Z>` | derive the push list from this tag instead of the highest release tag |
| `-DriftCheckPath <path>` | the repo's drift check. Defaults to `Get-ShopifyDriftCheckPath`, then `scripts/theme/live-snapshot.ps1` |
| `-SkipDrift` | skip the early drift read -- no Shopify CLI at hand, or a second run the same day |
| `-ReleaseDay <day>` | the weekday releases are cut on. `Monday` |
| `-ObligationPattern <regex[]>` | the phrases that mark a go-live obligation, **replacing** the English defaults -- for entries written in another language |
| `-OutFile <path>` | also write the runbook there (UTF-8). Name a gitignored file or the branch document |
| `-RootOverride <path>` | the repo root, when the run does not start inside the checkout |

## What it deliberately does not do

- **It writes nothing to the store.** No push, publish, duplicate or delete. The live guard reads the
  command string of a tool call and cannot see inside a script, so a store write in here would be one
  nothing guards. The early drift read runs your own drift check, which pulls **from** live.
- **It never writes the authorisation marker, and never reads it.** The runbook's push command is
  composed without one, and says the marker is added by a person. Use the command `live-preflight`
  prints on the day.
- **It writes nothing to git.** No commit, branch or tag. `-OutFile` is the one file it writes.
- **It does not re-derive the bump.** The fold's pending tally already names it, and the tier parser
  that produces it is `dkj-policy`'s. Where the tally cannot be read, the run says so.

## Why two things the issue asked for read differently here

- **The bump comes from the pending tally, not from `Get-ReleaseAudienceTier`.** That seam names which
  audience the repo publishes to. It does not say what the entries add up to.
- **There is no "tier-2 score where tier 2 is off" check.** An entry has one reach section. Whether a
  score there counts as tier 1 or tier 2 is decided by `Get-ReleaseAudienceTier` inside `dkj-policy`'s
  parser, which this plugin may not reach. The `fix/` note is limited to audience tier 1 because it was
  measured as noise at tier 2: 6 of 23 pending entries flagged in this plugin's source repo, every one
  correctly scored.

## Requirements in the consumer

`git`, and `gh` authenticated for the check runs and the open pull requests. Either one missing is a
skipped step, not a crash. The seams it reads from `scripts/repo-config.ps1`, all optional:
`Get-ShopifyThemeEstateStore`, `Get-ShopifyLiveThemeId`, `Get-TrunkBranchName`,
`Get-ShopifySyncBranchPrefix`, `Get-ChangelogPath`, `Get-ShopifyDriftCheckPath`,
`Get-ReleaseAudienceTier` and `Get-RepoName`. It refuses to run in this plugin's own source repo, which
has no theme.

## Important

This script is maintained in the source repo; do not modify it locally in a consumer. A change lands
first in the source and then travels via a release to the plugin mirror.
