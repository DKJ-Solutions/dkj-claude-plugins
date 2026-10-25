---
name: stopwatch-hide
description: Delete a Stopwatch run, or every run of a label, from every machine's /stopwatch pages -- whichever machine recorded it -- or show it again before it is erased. Use when the owner asks to delete, remove or hide a Stopwatch card, run or label ("delete that stopwatch run", "remove the reconstructed card"), when a run was recorded by mistake, and to undo such a hide in time. Writes one entry beside this machine's store and syncs it; the recording machine erases the run at its next sync.
---

# stopwatch-hide -- delete a Stopwatch run from any machine

**It exists because a run could only be removed on the machine that recorded it**
([#3446](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3446)). Every machine publishes its
whole store to its own ref, `refs/stopwatch/<machine id>`, at every sync, so a run deleted anywhere
else came back, and editing another machine's ref breaks the one-writer-per-ref rule.

**So it writes a hide entry, and the recording machine does the erasing.** The entry goes into
`stopwatch-hidden.json` beside **this** machine's store, travels in this machine's own payload, and
every machine's pages leave out what any machine hid, at once. Then, at its next sync, the machine
that **recorded** the run erases it from its own `stopwatch.json` and publishes without it
([#3453](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3453): the owner wanted the run
gone, not hidden). Per run id or label the **newest entry wins**, so `-Show` undoes a hide from any
machine **until that sync**; after it the run no longer exists to show. The pages stay read-only
(#3323). The rules are in this plugin's `hub/lib/stopwatch-sync-lib.ps1`.

**It ships with `dkj-policy`** since the Stopwatch is every repo's hub page
([#3470](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3470)). The runs it hides are the repo
the session runs in: its own store on this machine. Where the repo does not share its runs with its
other machines (`DKJ_STOPWATCH_SHARE=1` in the env block of its `.claude/settings.json` opts in), the
entry hides the run on this machine's pages only, and the sync says `not shared`.

**In the source repo, run its own copy instead** -- `plugins/dkj-policy/hub/pages/stopwatch-hide.ps1`
-- since `${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last released copy.

## Run it

```powershell
# delete one run, by its id (the run page's crumbs and the store name it)
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-hide.ps1" -RunId 20261023-112047-da87

# delete every finished run of a label: the exact label, in full
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-hide.ps1" -Label "CSS comment change (reconstructed)"

# undo either one, while the recording machine has not synced yet
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-hide.ps1" -Label "CSS comment change (reconstructed)" -Show

# what is hidden now, and what this machine wrote
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-hide.ps1" -List
```

It writes the entry and then runs `stopwatch-sync.ps1` in the foreground, printing its outcome. When
this machine recorded the run, that sync is the one that erases it. `-NoSync` skips the sync; the next
one, at most five minutes later, publishes the entry. This machine's own pages honour the entry at
once either way.

## What to know before using it

- **The erase cannot be undone.** Once the recording machine has synced, the run is gone from its
  store and its ref, and `-Show` has nothing to bring back.
- **A label is matched exactly and in full.** A card shows a label's short title, so take the label
  from the run page or `-List`. A name that matches no run this machine can see is still written,
  because the run may sit on a machine not fetched yet, and the script says so.
- **A label hide covers later runs too.** It stays in force, so a run of that label finished after
  the hide is erased at the first sync after it ends. To record under that label again, `-Show` it
  first. A run still going is never hidden or erased.
- **A hide file that does not read stops everything.** The script refuses to write, and the sync
  refuses to publish, because publishing no entries would show everything again. A store holding a
  run that does not parse is not erased from either, since rewriting it would drop that run too.
