---
name: sync-trunk
description: >-
  Fast-forward this checkout's trunk to origin -- or, with -AllCheckouts, every checkout on this
  machine that holds a plugin install record -- wherever that cannot touch anybody's work: on the
  trunk, no uncommitted change to a tracked file, not diverged, and only `git merge --ff-only`. Use it
  when a trunk is behind origin and you would otherwise pull by hand, for "sync all repos" in whatever
  language it is asked, and after a merge that a CI fold followed. The session's own checkout is
  already synced at every session start by the trunk-sync-sessionprep hook.
---

# sync-trunk -- a clean trunk follows origin, here or everywhere

This is the **plugin mirror** of `sync-trunk.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it (issue
[#3605](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3605)).

## Why it exists

A trunk sat behind origin routinely, and the owner synced it by hand. Nothing moved a trunk that was
just standing there. `new-branch` fast-forwards only when a branch is cut, and `open-pr` refuses rather
than syncs. The CI fold runner also lands its fold commit on origin *after* `ship-pr` has returned the
checkout to the trunk, so a finished chain leaves the checkout behind by construction.

## Two halves, one definition

- **At every session start**, the `trunk-sync-sessionprep` hook syncs the session's own checkout. The
  dispatcher runs it before its parallel checks, because those checks read the trunk it moves. It is
  silent when there is nothing to report. Set `DKJ_TRUNK_AUTOSYNC=0` in your own `env` settings to turn it off.
- **On request**, this command syncs one checkout, or all of them:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/sync-trunk.ps1" -AllCheckouts
```

**In the source repo, run its own copy instead -- `scripts/task/sync-trunk.ps1`.** `${CLAUDE_PLUGIN_ROOT}`
resolves into the plugin cache, which lags the source by however many merges have landed since.

Both halves call `Invoke-TrunkFastForward` (`trunk-sync-lib.ps1`), so the safety conditions are written
once. A checkout that fails one is **skipped, with the reason**. Nothing is ever stashed or rebased, and no
merge commit is ever created:

| Condition | Otherwise |
|---|---|
| the folder is the root of a git checkout, with an `origin/<trunk>` | skipped |
| the checkout is **on its trunk** (`origin/HEAD`, else `main`) | skipped, and not even fetched |
| no tracked file has an uncommitted change (untracked files are fine: `--ff-only` refuses to overwrite one) | skipped |
| the trunk has no local commit origin lacks | skipped as *diverged* |

## The parameters

- **`-AllCheckouts`** -- sync every checkout in `~/.claude/plugins/installed_plugins.json` (each record's
  `projectPath`), the same set `update-plugins -AllCheckouts` sweeps. A record naming a folder that no
  longer exists is counted into one summary line instead, because `tidy-machine` owns those. git runs
  there with that checkout's own hooks and `core.fsmonitor` switched off, because nobody opened those
  repos this time. The session's own checkout keeps its hooks: you opened it.
- **`-DryRun`** -- fetch and measure, move nothing: each checkout says what it *would* do.

Exit code 1 when any checkout **failed** (a fetch, or the fast-forward itself), or when `-AllCheckouts`
cannot read the install administration. A skip is not a failure.

## What it is NOT

- **Not a pull on a branch.** A branch's own remote-ahead question belongs to `new-branch` and `open-pr`.
- **Not a plugin update.** That is `update-plugins`. This command moves the repo's own trunk only.
