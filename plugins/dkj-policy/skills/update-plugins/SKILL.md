---
name: update-plugins
description: >-
  Update every plugin this checkout enables, in one command instead of 1 + N -- refreshes the
  marketplace clone once, then runs `claude plugin update <id>` for each enabled plugin at the scope
  that plugin is installed at, then prints plugin-versions' receipt so the run's own result is
  verifiable. Use it whenever
  plugin-versions (or connector-sessioncheck's -Brief line) reports something behind and you want to
  close the gap without typing one command per plugin. Scoped to this checkout plus the machine-wide
  marketplace clone -- never a walk into another repo.
---

# update-plugins -- one command instead of 1 + N

This is the **plugin mirror** of `update-plugins.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it -- the same argument as
[issue #81](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/81).

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/update-plugins.ps1"
```

**In the source repo, run its own copy instead -- `scripts/task/update-plugins.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own,
so for them the line above is the correct one.

**See what it would run first, with no side effect at all:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/update-plugins.ps1" -DryRun
```

## Why this exists

[plugin-versions](../plugin-versions/SKILL.md) answers *whether* a checkout is behind; closing the
gap it reports was still, measured against `claude plugin update --help` / `install --help`, **1 + N
commands with no `--all` and no repeatable `<plugin>` argument** -- one `claude plugin marketplace
update <marketplace>`, then one `claude plugin update <id> --scope <scope>` per enabled plugin. This
skill is that wrapper, and nothing more: it runs exactly the commands a person would otherwise type by
hand, in the order plugin-versions' own verdict table already prescribes.

## The three steps

1. **Refresh.** `claude plugin marketplace update <marketplace>`, once per **distinct** marketplace
   this checkout's enabled plugins name (ordinarily one).
2. **Update.** `claude plugin update <id> --scope <scope>` for every plugin id this checkout actually
   enables -- the full effective set after the settings-chain precedence (local > project > user),
   the same set plugin-versions.ps1 reports on. **The scope is read off the install record, never
   assumed** ([#1986](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1986)) -- see
   [the scope section](#the-scope-is-read-not-assumed) below.
3. **Receipt.** plugin-versions.ps1 runs and prints its usual summary, so the result of steps 1-2 is
   read off the same tool that would have reported the checkout as behind in the first place, rather
   than trusted on the strength of the update commands' own "success" lines.

**Continues past a failure.** One marketplace or one plugin failing to update is not a reason to skip
the rest. Every `FAILED` line names the exit code; the run's own exit code is non-zero only if
something failed, and `-DryRun` never runs anything and always exits 0.

## The boundary -- this checkout plus the machine-wide lanes, never a walk into another checkout

Named in [#1890](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1890) and kept here on
purpose. Every `claude plugin update` call names the checkout you ran this
from; nothing here reads or writes any other repo's tree. That matters because `claude plugin
install`/`update` **rewrites the visited repo's `.claude/settings.json`** -- a sweeping updater that
walked several checkouts would leave uncommitted diffs in repos nobody opened, possibly on a mid-work
branch. The marketplace clone itself is the one machine-wide piece (it lives under
`~/.claude/plugins/marketplaces/`, shared by every checkout on the machine that uses it), and step 1
refreshes it exactly once per marketplace regardless of how many enabled plugins name it.

**What this does not reach**, by the same construction as `plugin-versions`: a machine on which
nobody opens a checkout is invisible to every mechanism here. That is the "part no tool reaches" the
parent issue named, and it stays outside this skill's scope -- see the issue for the open question
behind it.

## The scope is read, not assumed

Until [#1986](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1986) every step-2 call was
hardcoded `--scope project`, and the CLI **refuses a scope a plugin is not installed at**:

```
claude plugin update ... --scope project
  x Failed to update plugin "shopify-ai-toolkit@claude-plugins-official": Plugin
    "shopify-ai-toolkit" is not installed at scope project (C:\...\dkj-claude-plugins)
```

(The target is elided as `...` per this repo's convention: the line above is the SUBJECT of the
paragraph, not an instruction anybody should run.)

Two costs, and the second is the worse one. The plugin is **never updated** -- the one command that
could have moved it is the one being refused, no matter how often the skill runs. And the run **exits
non-zero on a healthy machine**: a machine-wide install is a supported state that this workflow's own
session check already reports as needing no action, so the updater's exit code disagreed with the
session check about the same record.

**The scope now comes from `Get-PluginUpdateScope`, reading the install administration this run
already reads** -- a record naming this checkout first, then a record tied to no path at all. It is
not only the machine-wide case: a **session start** rewrites install records with no command run,
flipping a `project` record to `local` and sometimes dropping the path off one entirely, and `project`
is wrong in both of those too.

**It returns one of the CLI's own four scope names, never the file's string.** `installed_plugins.json`
is machine-written, but it still feeds a `claude plugin ...` line this skill both executes and prints,
so the value is matched case-insensitively against `user`/`project`/`local`/`managed` and the canonical
spelling is what goes in the command. Where the administration cannot answer -- unreadable, silent on
the scope, or holding records that **disagree** with each other (a scope mismatch accumulates records
rather than replacing one) -- the run falls back to `project` exactly as before and prints one line per
plugin saying why, above step 1.

**One scope per plugin was not enough, and a path-less user-scope record is now a second target**
([#2459](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2459)). Where a plugin has both a
record for this checkout and a path-less `user` record, the checkout's record wins that lookup, so the
path-less one was never updated -- and `plugin-versions` then reported it behind in the run's own
receipt (#2442: a session can load the older one), under a summary saying `0 failed`. Measured
September 24, 2026, v5.7.0 -> v5.8.0: 5 of 7 plugins behind straight after the run. Step 2 now updates
that record too, at `--scope user`. The update is **not gated on the version**, because in the measured
run both records matched before step 2, so the gap only opened once the checkout's record had moved. A
path-less `managed` record is left alone, since it belongs to an administrator.

**This does not widen the boundary above.** That boundary is about which *tree* gets written: a
user-scope update rewrites no repo's tree at all, and a `local`/`project` one rewrites exactly the
checkout you are standing in.

## Why it EXECUTES rather than only prints

Unlike plugin-versions.ps1's own paste-ready commands, every `claude ...` call here reaches the CLI
through an argument **array** (`Invoke-NativeCapture`), never through a string a shell re-parses --
so the paste-into-a-terminal injection surface `Format-SafeProseToken` and the withhold doctrine exist
for does not apply to the exec path itself. What an untrusted `enabledPlugins` **key** can still do is
confuse the CLI's **own** argument parser (an id starting with `-` reads as a flag to `claude`, not to
a shell), so a target is only ever built from an id that passes the same `Test-PluginNameSlug` /
`Test-PluginMarketplaceSlug` check plugin-versions.ps1 already applies to its printed commands.
Anything else is reported under a `Skipped` line and never handed to the CLI.

## Parameters

The default run takes no arguments. `-DryRun` is the one a caller might genuinely pass; the other two
are **test seams** a consumer never types.

| parameter | what it does |
|---|---|
| `-DryRun` | print every command this run would execute and run none of them -- no receipt either, since nothing changed for it to report on. |
| `-RootOverride` | the repo root to resolve the enable state against. |
| `-UserHomeOverride` | the home directory `~/.claude` hangs off. |
| `-ReceiptScriptOverride` | the plugin-versions.ps1 path step 3 runs as a child process -- a test double, never a consumer's own path. |

## Requirements in the consumer

`claude` on PATH (the CLI this skill drives) and everything `plugin-versions` already needs for its
own receipt (`git`, to read the marketplace clone's HEAD). Nothing is repo-owned -- there is no seam
to scaffold. It resolves its repo root dual-context via `${CLAUDE_PROJECT_DIR}`.

## Important

- **Not read-only, unlike `plugin-versions`.** This runs real `claude plugin` commands, which rewrite
  this checkout's `.claude/settings.json` and this machine's plugin administration. `-DryRun` is the
  read-only mode; the default run is not.
- **A session already running against the plugin being updated does not reload it mid-session.**
  Per this repo's own `CLAUDE.md`, a session loads an *extracted* payload at start, and only a later
  session start (after this run and, where the update crosses a release, after the next one) picks up
  the change. Nothing here restarts anything for you.
- This script is maintained in the source repo; do not modify it locally in the consumer. A change
  lands first in the source (`scripts/task/update-plugins.ps1`) and then travels via a release to the
  plugin mirror -- guarded by the shared-scripts drift lint.
