---
name: stopwatch-prepare
description: Put a Stopwatch card for a label on the hub's /stopwatch overview with NO clock running, so the owner can start the run themselves afterwards, or withdraw such a card. Use before a run the owner wants to time and start by hand -- above all before a release cut ("prepare the release cut card first, then we start it ourselves") -- and when a prepared card is no longer wanted.
---

# stopwatch-prepare -- a Stopwatch card that is ready and not started

**It exists so a run can be prepared first and started by the owner.** A Stopwatch run starts only from a
prompt whose first line is `stopwatch: <label>` (the hook in `hooks/stopwatch-hook.ps1`), so Claude cannot
start one by itself and should not: the run still starts only from such a prompt. What it can do is put the card on the page beforehand.

**It writes a `prepared` entry in this machine's store, never a run.** The overview `/stopwatch` then shows a
card for the label that says it is ready and not started, and how to start it. The label page opens too, with
the same message in place of runs. When the owner sends `stopwatch: <label>`, the run starts exactly as
always, lands on that card, and the hook removes the prepared entry. A label that already has runs keeps its
normal card. A prepared label is this machine's own and is never shared with other machines.

The label is normalised as a prompt's label is (control characters as spaces, trimmed, cut at 80
characters), so the card and the prompt agree. Case does not matter: labels compare case-insensitively.

**In the source repo, run its own copy instead** -- `plugins/dkj-policy/hub/pages/stopwatch-prepare.ps1` --
since `${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last released copy.

## Run it

```powershell
# prepare the card
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-prepare.ps1" -Label "release cut"

# withdraw it
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hub/pages/stopwatch-prepare.ps1" -Label "release cut" -Remove
```

It prints a short receipt. Tell the owner the card is on `/stopwatch` and that the run starts with a prompt
whose first line is `stopwatch: <label>`.

## What to know

- **No clock runs.** Preparing a card starts nothing; do not describe the run as started.
- **A store that does not read stops it.** The script refuses, as the hook does, and writes nothing.
- **A different prompt label leaves the prepared card alone**; it stays until its own label starts a run or
  it is withdrawn with `-Remove`.
