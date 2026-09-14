---
name: adopt-shopify-floor
description: Place dkj-subagents-shopify's operational floor in this repo, in one move -- the live-theme guard's seam (which theme is live), a starter theme-check config that is green on arrival in a real theme, and the CI workflow that runs it on every PR. Use this right after enabling or refreshing dkj-subagents-shopify, since a plugin install writes nothing into a repo, and whenever the Shopify floor session check reports that the guard has not been told which theme is live. Strictly additive and dry-run by default; it never overwrites anything.
---

# adopt-shopify-floor -- the floor arrives with the plugin, the answers do not

`dkj-subagents-shopify` ships a `PreToolUse` guard on the live theme, and it starts working the moment the plugin
is enabled -- for **two of its three rules**. A theme publish and a theme delete are refused whatever
this repo says. The third rule, a push aimed at the **live** theme, has two triggers, and only
`--allow-live` is self-declaring: the id half can fire only where this repo has named the live theme's
id. Nothing in an install path owned that answer, so a refreshed consumer met a standing `[ERROR]` at
session start and a guard whose id half was inert (inbound
[#776](https://github.com/DaveKJohn/claude-code-specialists/issues/776)).

This command is what places the answers, plus the two items both existing Shopify consumers had already
written by hand before the floor shipped at all (inbound
[#769](https://github.com/DaveKJohn/claude-code-specialists/issues/769)).

```text
scripts/repo-config.ps1              the Shopify seam block, APPENDED (the file must already exist)
.theme-check.yml                     a starter config: Liquid + JSON syntax, green on arrival
.github/workflows/theme-check.yml    theme-check on every PR into main
```

## Run it

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-shopify-floor.ps1"
```

That is a **dry run**: it prints exactly what it would do and writes nothing. Add `-Apply` when the list
looks right, and add `-LiveThemeId` to arm the guard in the same move:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-shopify-floor.ps1" -LiveThemeId 190793613653 -Apply
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component** -- that is, when your Claude
runs this skill. Typing the command by hand in a terminal means spelling out the absolute path to your
own plugin cache instead, so the easy route is to ask for the skill rather than to copy the line.

## Parameters

| parameter | what it does |
|---|---|
| `-Apply` | write the files. Without it the command is a dry run that prints the plan and touches nothing -- the same default `adopt-config.ps1` and `adopt-workflow-folder.ps1` use. |
| `-LiveThemeId` | the live theme's **numeric** id. Given, the seam function is written *answered* and the session check goes quiet because the guard is genuinely armed. Omitted, the block is written commented out and the check keeps reporting -- see below for why that is the right way round. Find the id with `shopify theme list --store <your-store>.myshopify.com`; it is the one marked `[live]`. |
| `-StoreDomain` | the store the **pre-task sync** pulls from, e.g. `your-store.myshopify.com`. Given, `Get-ShopifyStoreDomain` is written *answered* and the [`sync-main`](../sync-main/SKILL.md) skill works on its first run. Omitted, it is written commented out like the theme id, and `sync-main` refuses rather than guessing which store to read. |

**The seam block carries the pre-task sync's answers too** (inbound
[#787](https://github.com/DaveKJohn/claude-code-specialists/issues/787)). `sync-main` is the higher-risk
half of the problem the guard covers: a live theme has no locking, so work starts by mirroring live into
the trunk, and the obvious wholesale implementation overwrites whatever the trunk has done since. Only
the store is worth answering on day one -- the other five seams
(`Get-ShopifySyncReferencePattern`, `Get-ShopifySyncBranchPrefix`, `Get-ShopifySyncMerges`,
`Get-ShopifySyncPrBody`, `Get-ShopifySyncPrLabels`) are listed in the block with their defaults, which
are right for both existing Shopify consumers. Listing them is what saves the next reader from having to open the script to learn
what is configurable.

## Why the seam is written as a comment when you do not pass the id

This is the one thing in here that looks like an oversight and is not. A stub returning `VUL-IN` would
be **worse than no function at all**: the session check reads a non-empty answer as *answered*, so the
stub would silence the report while the id half of rule 3 stayed exactly as inert as before -- a hole
with a comment on it. `adopt-config.ps1` settled the same question the same way for the values only a repo
can decide, and for the same reason.

So without `-LiveThemeId` the block lands as a paste-ready comment in the right file, with the command
that produces the id, and **the check keeps saying so until a real id is there**. Belt and braces: the
guard and the check both reject a **non-numeric** answer, so leaving the placeholder in place after
uncommenting still counts as unanswered rather than as protection.

## The starter config is measured, not designed

Both existing Shopify consumers wrote a theme-check config independently, before this command existed,
and both arrived at the **same two checks** over `extends: nothing` -- Liquid that does not parse, and
JSON that does not parse. Neither turned the recommended set on, and both wrote down why: on one of
those themes the full set reports **1504 offenses across 171 files** (1078 at error severity), and
roughly **58k** on the other.

> A gate that is red on arrival is not a gate. It gets bypassed on day one and never looks at the change
> that actually broke something.

So the starter is **green on arrival in a real theme** (Dave, August 20, 2026, choosing that over
assuming a clean one), and every other check is *off rather than forgiven*: switch one on in that file
the day its offenses are at zero. The CI workflow runs at `--fail-level error`, which is not a loosening
-- the two checks the config enables are both declared at error severity, so `error` is exactly the set
this repo said it wants to block on. It is what both consumers already run.

## The rules it works under

- **Strictly additive, never overwrites.** A file that already exists is left exactly as it is, whatever
  it contains, and a `repo-config.ps1` that already defines `Get-ShopifyLiveThemeId` gets no block
  appended. A re-run therefore finds nothing to do.
- **Appended, never merged.** The seam block goes at the end of `scripts/repo-config.ps1`. An inserter
  that tried to find "the right place" would be rewriting your file on a guess.
- **Not a bootstrap.** If `scripts/repo-config.ps1` does not exist at all, that is reported and the other
  two files are still placed: `specialists-init` owns that file's existence, this command owns its
  contents.
- **Refused in a repo that publishes plugins.** The source repo of this floor has no theme to lint and
  no live theme to guard, so there is nothing there for this command to do.

## Already have your own guard? Converge before you keep both

If this repo wrote its own live-theme guard before the plugin shipped one, the refresh did not replace
it -- it registered a **second** hook beside it, and both fire on every command (inbound
[#777](https://github.com/DaveKJohn/claude-code-specialists/issues/777)). The floor session check now
reports that, and the route off it is in
[the dkj-subagents-shopify README](../../README.md#converging-off-a-hand-written-guard). Removing a `PreToolUse`
entry from your settings is a deletion, so it stays your keystroke rather than something this command
does for you.
