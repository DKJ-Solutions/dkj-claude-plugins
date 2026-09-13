---
name: archive-theme
description: Archive one or more Shopify themes to a local, verified backup and leave a committed receipt for each -- the step that makes removing a spent preview theme recoverable. Use it before any theme leaves the store, and re-run it over an estate already backed up to give older archives the receipt they never had. It NEVER removes a theme: it prints the removal command for somebody to run as its own visible act, because a command buried inside a script is invisible to the live-theme guard. The live theme is refused outright.
---

# archive-theme -- the backup, the receipt, and the command it will not run for you

A Shopify store has a hard ceiling of 20 themes, so spent branch previews have to leave it. Removing one
is irreversible and the store offers no undo, so the removal is only safe once a verified copy exists.
This takes that copy -- and leaves behind something the copy itself cannot be: a **committed receipt**.

## Run it

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/archive-theme.ps1" -ThemeId 184381800789
```

Several at once, which is the common case:

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/archive-theme.ps1" -ThemeId 183398957397,184381800789,184636047701
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component**. From an ordinary shell, spell
the plugin cache path out.

| Parameter | What it is for |
|---|---|
| `-ThemeId` | one or more ids, comma-separated. Required. |
| `-Store` | overrides `Get-ShopifyStoreDomain`. |
| `-ArchiveRoot` | where the bytes land. Default `<repo>/theme-archive`, which belongs in `.gitignore`. |
| `-ManifestRoot` | where the receipts land. Default `<repo>/theme-archive-manifests`, which is **committed**. |
| `-Refresh` | re-pull a theme that already has a verified archive. Without it, an existing archive is reused. |
| `-NoManifest` | leave no receipt. For a throwaway archive taken to *look* at a theme. |

## It never removes a theme, and that is a guard property rather than caution

This plugin's live-theme guard is a **PreToolUse hook**: it reads the *command string* of a tool call. A
destructive theme command buried inside a `.ps1` is invisible to it -- the tool call reads
`powershell -File ... -Execute`, which holds nothing for the guard to match. So a script that removed a
theme itself would not be a rule broken in the open; it would be a silent hole in the one mechanism that
closes the wrapper vector. One of the two stores this script converges had exactly that shape.

Instead the run **ends by printing the command**, with the theme's name and role beside it. Whether a
session may run it is the guard's decision, answered by `Get-ShopifyThemeDeleteMarker` in
`scripts/repo-config.ps1`: answered, the guard allows a command carrying that exact marker; unanswered,
it refuses outright and a person runs it. The output says which of the two this repo is in -- a script
whose prose said one thing while its printed command did the other is the defect that put the command
behind a tested function in the first place.

**The live theme is refused, by id and by role.** Not because of the removal -- this script performs
none -- but because a pull of live is a read of live, and that belongs to `sync-main`. The check is
doubled on purpose: the id catches what `repo-config` says is live, the role catches what the **store**
says is live, and the day those disagree is the day one of them is the only thing standing between a
wholesale pull and the live theme.

## The receipt is the half that survives

`theme-archive/` is gitignored, so a verified archive proves a removal recoverable **on the day it is
taken** and nothing keeps that true afterwards. Measured in a store: eight themes archived, all eight
gone from the store a week later, the archive folder absent from the checkout, and the only evidence the
2,934 files had ever existed was one sentence in a changelog entry. Nobody could say which eight, what
was in them, or which of two machines held the copy.

Making the *bytes* durable was rejected: for a spent branch preview the durable copy is git -- the branch
that produced it, merged. What is durable instead is a small committed text file per theme, naming the
theme, every file with its size and SHA-256, and **one event per machine that has held a copy**.

> It does **not** restore a theme. It answers the three questions a bare archive could not -- was this
> archived, what was in it, and where would a surviving copy be -- and it makes a recovered copy
> *verifiable*, which a folder of bytes with no reference never is.

**Re-running is cheap and is the repair path.** An existing verified archive is reused rather than
re-pulled, so a run over an estate already backed up writes only the receipts that were missing, without
fetching a single file. A run landing identical bytes leaves its event alone, so the recorded day stays
the day those bytes landed.

## A third-party theme is archived, never gated -- and the command carries a warning

Where a store's estate holds themes belonging to an outside integration, removing one breaks that party's
integration. Archiving one harms nothing, so the archive is never refused; the warning attaches to the
**printed command**, which is where the risk actually is.

Declare the prefixes with `Get-ShopifyExternalThemePrefixes` in `scripts/repo-config.ps1`, returning an
array of theme-name prefixes. Unanswered -- the ordinary case -- nothing matches and nothing is printed.

This is the one place where neither converged copy was right: one refused the archive (strictness with no
subject, since it never removed anything either), and the other handed the caller the exact command that
breaks a live integration without a word.

## What this skill is NOT

- **Not a cleanup step.** Whether a theme is spent is a judgement: its work merged, and if it was ever
  pushed, already live. The script takes a backup and states the facts; it decides nothing.
- **Not a restore.** See the receipt section -- a manifest is not a backup.
- **Not the verifier.** Reading a receipt back and measuring a recovered folder against it is a consumer
  script today. Its three rules ship in `scripts/lib/theme-archive-rules.ps1` and a consumer that has
  one dot-sources them rather than keeping a copy.

## Where the decisions live

`scripts/lib/theme-archive-rules.ps1`, and the split is `sync-rules.ps1`'s: everything in the script
either invokes the Shopify CLI against a real store or reads a consumer's own `repo-config`, and a suite
must reach neither. What *can* be wrong without a network -- what the caller asked for, whether a theme
may be archived, what it is called on disk, whether the pull landed, and every byte of the receipt -- is
pure, and the source repo's `scripts/tests/theme-archive-rules.tests.ps1` measures it.
