---
name: stopwatch-hide
description: Hide a Stopwatch run, or every run of a label, on every machine's /stopwatch pages -- or show it again -- whichever machine recorded it. Use when the owner asks to delete, remove or hide a Stopwatch card, run or label ("delete that stopwatch run", "remove the reconstructed card"), when a run was recorded by mistake, and to undo such a hide. Writes one entry beside this machine's store and syncs it; nothing is erased from any store.
---

# stopwatch-hide -- delete a Stopwatch run from any machine, undoably

**It exists because a run could only be removed on the machine that recorded it**
([#3446](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3446)). Every machine publishes its
whole store to its own ref, `refs/stopwatch/<machine id>`, at every sync, so a run deleted anywhere
else came back, and editing another machine's ref breaks the one-writer-per-ref rule.

**So it hides rather than deletes.** The entry goes into `stopwatch-hidden.json` beside **this**
machine's store, travels in this machine's own payload, and every machine's pages leave out what any
machine hid. Per run id or label the **newest entry wins**, so `-Show` undoes a hide from whichever
machine wrote it. The pages stay read-only (#3323). The rules are in
`scripts/lib/stopwatch-sync-lib.ps1`.

**It is repo-local**, beside `harvest-artifacts`: the Stopwatch is this repo's own dev server.

## Run it

```powershell
# hide one run, by its id (the run page's crumbs and the store name it)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dashboard/stopwatch-hide.ps1 -RunId 20261023-112047-da87

# hide every finished run of a label: the exact label, in full
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dashboard/stopwatch-hide.ps1 -Label "CSS comment change (reconstructed)"

# undo either one
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dashboard/stopwatch-hide.ps1 -Label "CSS comment change (reconstructed)" -Show

# what is hidden now, and what this machine wrote
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dashboard/stopwatch-hide.ps1 -List
```

It writes the entry and then runs `stopwatch-sync.ps1` in the foreground, printing its outcome.
`-NoSync` skips the sync; the next one, at most five minutes later, publishes the entry. This
machine's own pages honour the entry at once either way.

## What to know before using it

- **A label is matched exactly and in full.** A card shows a label's short title, so take the label
  from the run page or `-List`. A name that matches no run this machine can see is still written,
  because the run may sit on a machine not fetched yet, and the script says so.
- **A label hide covers later runs too.** Every finished run of that label stays hidden, including
  one finished after the hide, until it is shown again. A run still going is never hidden.
- **A hide file that does not read stops everything.** The script refuses to write, and the sync
  refuses to publish, because publishing no entries would show everything again.
