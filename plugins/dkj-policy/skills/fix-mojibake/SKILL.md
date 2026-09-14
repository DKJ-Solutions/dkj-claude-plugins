---
name: fix-mojibake
description: >-
  Repair double-encoded characters (mojibake) in text files via the shared, centralized fix-mojibake
  script from the plugin (single source of truth, issue #413) -- so a consumer does not keep its own
  copy. Damage of this kind is silent: the file stays valid UTF-8, nothing errors, it just says
  something else, and a mangled separator can stop a release script from reading its own input.
  Repairs by running the corruption backwards rather than by matching a table of known sequences, so
  it reaches characters nobody thought to list. Use -Check for a gate or a dry run. Use this when
  non-ASCII text has been mangled, or to verify that it has not been.
disable-model-invocation: true
---

# fix-mojibake — the shared encoding repair for consumers

This is the **plugin mirror** of `fix-mojibake.ps1`: the same tested source as in the source repo,
shared here so consumers do not each keep a copy. Background in
[issue #413](https://github.com/DaveKJohn/claude-code-specialists/issues/413).

**Three repos had written their own version of this before it was shared**, which is the argument for one
source rather than for a fourth. Three copies of a repair tool drift, and the one that drifts is the one
nobody reads until the day it matters.

## What mojibake is, and how it gets into a repo

**UTF-8 that was once read as Windows-1252 and then saved as UTF-8 again.** A middot (`U+00B7`, bytes
`C2 B7`) is read back as two characters, and writing that out stores the mangled pair.

**One read-and-write round trip is enough, and nothing errors.** Windows PowerShell 5.1's `Get-Content`
reads a BOM-less UTF-8 file as ANSI unless told otherwise. The file stays valid UTF-8 afterwards — it
simply says something else. That is what makes this class worth a tool: there is no failure to notice.

**It is not cosmetic when the mangled character is doing work.** Measured in the source repo on
August 1, 2026: demoting four headings in `CHANGELOG.md` with `Get-Content` plus a write mangled **35**
separators — and since the separator *is* the field delimiter in an entry heading, the release script
could no longer read the entry **type**. Eleven entries fell into a catch-all category instead of
Features/Fixes/Documentation. It was caught by inspecting the generated notes before pushing, which is
what `cut-release`'s `-NoPush` is for.

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/fix-mojibake.ps1"
```

**In the source repo, run its own copy instead — `scripts/maintenance/fix-mojibake.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

| Parameter | What it does |
|---|---|
| `-Path` | The files to repair. Omit it and the set is **repo-owned** — see [Which files](#which-files-it-examines) below. |
| `-Check` | **Report only, change nothing, exit 1 if any file would change.** For a gate or a dry run. |

```powershell
# a gate or a dry run -- exits 1 on damage, touches nothing
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/fix-mojibake.ps1" -Check

# a specific file
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/fix-mojibake.ps1" -Path CHANGELOG.md
```

## Why it runs the corruption backwards instead of matching a table

Each run of non-ASCII text is re-encoded to Windows-1252 and decoded as UTF-8 — the mangling, in
reverse — repeatedly, for as long as the result gets **shorter**. Correctly encoded characters fail that
round trip and are left untouched, which is what makes it safe to run over a whole repo.

**It used to work off a table of known sequences, and that is why the method is stated first.** A table
repairs the characters somebody thought to write down. On August 2, 2026 the source repo held **517**
doubly-encoded runs — em dashes, arrows, ellipses, en dashes — that matched no rule in that table, in
files the gate beside the tool reported as **clean**. A gate that examines almost nothing while reporting
"clean" is worse than no gate. The table survives as a net for cases the round trip cannot reach, but it
is no longer the method.

**Both the round trip and the table repeat to a fixpoint, because text can have been mangled twice.** A
middot from a changelog heading then comes back as four characters rather than two, and a single pass
peels one layer and leaves a remainder — which is what cost one consumer a manual fix at its `v2.1.0`,
and what hid those 517 sequences. Termination is guaranteed the same way in both loops: every accepted
step makes the text strictly shorter.

**A UTF-8 BOM on the file is preserved; a file without one does not gain one.**

## Which files it examines

Without `-Path`, the set is **repo-owned**: `Get-MojibakePaths` in the consumer's
`scripts/repo-config.ps1` names it. The function is **optional** — a repair tool that refuses to run
because a config file is missing helps nobody — and without it the script falls back to **every `*.md` in
the repo root**: the changelog, the root docs, and any unfolded changelog entry. That is a defensible set
in any repo.

**The fallback replaces the repo-owned list, it does not extend it.** If you declare
`Get-MojibakePaths`, you own the set completely.

**That seam exists because the built-in list used to be workshop-shaped.** It walked directories that
exist in the source repo and in no consumer, so the path filter silently reduced the default to whatever
root docs happened to be present — the same "reports clean while examining almost nothing" failure the
round trip replaced the table for. If `repo-config.ps1` cannot be loaded at all, the script **warns and
uses the fallback** rather than stopping.

## Prevention, in order of preference

Running this tool is the third-best outcome. In order:

1. **Never read a possibly-non-ASCII file with bare `Get-Content`.** Use your editing tooling, or
   `[System.IO.File]::ReadAllText(<path>, [Text.Encoding]::UTF8)`.
2. **Let a lint gate catch it.** The source repo runs this tool's `-Check` as one of its integrity
   checks, so damage surfaces on the PR rather than in a release artifact.
3. **Run this script.**

## Important

- **The script's own source is pure ASCII**, with every non-ASCII character built from a `[char]0x..`
  codepoint. That is not decoration: a mojibake table written as literal characters corrupts on the first
  careless edit and then silently repairs nothing — the repair tool cannot be allowed to fall to the round
  trip it repairs.
- **It repairs, and never invents.** Correctly encoded text is left untouched; if a sequence cannot be
  peeled, it stays as it is rather than being guessed at.
- This script is maintained in the source repo; do not modify it locally in the consumer. A
  change lands first in the source (`scripts/maintenance/fix-mojibake.ps1`) and then travels via a release
  to the plugin mirror — guarded by the shared-scripts drift lint.
