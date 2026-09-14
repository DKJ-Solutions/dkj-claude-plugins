---
name: sync-roster
description: >-
  Stage the roster-sync catch-up after the roster-sessioncheck hook flags that a specialist is
  missing from this repo's roster/lenses. Creates the empty repo-lens scaffolds (additive, never
  overwriting) and prints proposed roster rows ready to paste -- it never writes to CLAUDE.md, never
  commits, and never touches a branch. Use this when the SessionStart roster check reports drift and
  the mechanical part of the recovery should be staged automatically.
disable-model-invocation: true
---

# sync-roster -- the staged recovery for roster drift

When a plugin release adds a new specialist, a consumer that updates the plugin can end up with a
**roster** (the specialists table/list in `CLAUDE.md`) and **repo lenses** that lag behind. Layer 1
(`check-roster-sync.ps1`) detects that; layer 2 (the SessionStart `roster-sessioncheck` hook)
surfaces it at the top of a session. This skill is **layer 3**: it stages the catch-up so you only
have to review and place it.

It does the safe, mechanical part and leaves the remaining judgment calls -- and every write to the
governance doc -- to you.

## Adopting is the default, not a question (Dave, July 28, 2026)

**A specialist that arrives with a plugin update gets adopted. Do not ask permission for it, and do
not ask per specialist which ones are wanted.** Stage the lens scaffold and the roster row for every
one the check reports, and report what you did.

The reasoning: the scaffold is **empty on purpose**. A `VUL-IN` lens may sit there untouched until that
specialist actually has work in this repo — that is what the scaffold is *for*, not an unfinished task.
So adopting costs a file nobody has to fill in yet, while asking costs an interruption for a decision
with no downside either way. That makes it exactly the kind of approval question the governance rule
("approval questions are rare — irreversible, outward-facing, or genuinely risky only") says not to
ask.

What remains a judgment call is *the content*: what the lens says once the specialist does have work
here, and where the roster row belongs in the table. Those are writes to the governance doc, which this
skill deliberately never makes.

**The ignore-list is the exception, and it is a statement, not an answer to a question.** If a
specialist genuinely has no place in this repo, record that in `Get-RosterIgnoredIds`
(`scripts/repo-config.ps1`) with a comment naming who it is and why — a deliberate, documented
omission, put there on your own initiative. It is not a per-update checklist item.

Recorded after a smartwatchbanden catch-up session asked Dave, one by one, which of five new
specialists to adopt. The asking came from a hand-written handover prompt rather than from this skill,
which is precisely why the rule now lives here instead: a prompt is written once and forgotten, a skill
is read every time.

## When to run it

Run it after the `roster-sessioncheck` hook (or a deliberate run of `check-roster-sync.ps1`) reports
`[ERROR]` lines like *"agent '06-24' ... has no roster row"* or *"... has no repo-lens"*. Since
inbound #204 the same applies to **persona-only** specialists (*"persona '01-01' ... has no roster
row"*) — main-loop specialists such as Chris, Derek and Rendall, which ship as a persona rather than
an agent. It is safe to run repeatedly: it is additive and never overwrites.

## What the skill does

**First establish that PowerShell exists on this machine.** This skill is a wrapper around a
`.ps1`, and there are environments where that command is not there at all -- a Linux cloud container,
a colleague's Mac, the Claude app with no repo connected. Ask once:

```powershell
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
```

If that answers `command not found` (exit 127), **say so and stop**: the roster drift stays, and the
manual recovery is the roster rows plus the lens scaffolds by hand. `pwsh` is not a substitute to
reach for -- these scripts target Windows PowerShell 5.1, which is why this repo's own CI runs them on
`shell: powershell`. Measured in an environment with no repo at all, inbound
[#669](https://github.com/DaveKJohn/claude-code-specialists/issues/669) B2.

Run the bundled script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/sync-roster/sync-roster.ps1"
```

The script:

1. **Delegates detection** to `check-roster-sync.ps1` (the single source of truth for what counts as
   drift) -- it runs the check and parses its `[ERROR]` lines, rather than re-implementing the
   enabled-plugins / cache-version / specialist-id logic.
2. **Creates a lens scaffold** for each specialist **missing a lens** -- agent or persona -- where
   `specialists-init` would put it: the seam (`.claude/specialists/lenses/<group>-<id>-extension.md`)
   for a fresh or migrated consumer, and the repo's existing lens tree for one that has not migrated.
   Both writers resolve that through the one shared helper, so they cannot disagree. Uses the same additive,
   BOM-less-LF, never-overwrite format `specialists-init` writes (the lens-only blockquote intro + a
   `## Specific to this repo (VUL-IN)` slot). The scaffold is nameless (issue #145), which is why it
   needs no persona-specific variant.
3. **Proposes a roster row** for each specialist **missing a roster row**: it reads the agent's
   frontmatter (name + description) and prints a proposed markdown row (matching the roster's
   table/list style as best-effort) to stdout. It does **not** edit the roster / `CLAUDE.md`. For a
   **persona** there is no `name`/`description` in the file to read, so the row falls back to the
   `<group>-<id>` id plus an explicit *"(add a short description)"* placeholder -- degraded on purpose
   rather than inventing a name.
4. **Proposes a header reconcile** for each lens whose header still carries a **stale persona name**.
   An older scaffold baked the first name into the lens header (`# Sean · repo-lens`); after the
   agent-def is renamed that name is stale in every consumer. The skill prints the rename-proof,
   nameless replacement header (`# <group>-<id> · repo-lens`) for you to paste. New scaffolds are
   already nameless, so they never drift again (issue #145). It does **not** rewrite the lens file.
5. Prints a summary of what was staged, plus an explicit reminder that **main is sacred**: the skill
   wrote nothing to `CLAUDE.md` or any lens, and committed nothing.

## The human's follow-up (the judgment calls)

After the script:

1. **Fill in each lens.** Every created `*-extension.md` has a `## Specific to this repo (VUL-IN)`
   slot -- replace it with the specialist's repo-specific context (its domain, tasks, and the
   gatekeepers it works under). The portable craft stays in the plugin manual.
2. **Place the roster rows.** Paste the proposed row(s) into the roster and adjust them to the real
   columns/style of your table or list.
3. **Apply each header reconcile.** For each staged reconcile, replace the stale header line (and any
   remaining stale-name mention in the intro just below it) in the named lens with the nameless form.
4. **Branch + PR under your own governance.** Put the changes on a branch and open a PR -- never
   straight on `main`. Opening the PR follows this repo's own rules (in this workshop, on explicit
   request); the `open-pr` skill can do the push once you decide.

## Important

- **It never writes to `CLAUDE.md`, never commits, never touches a branch.** Recovery is *staged*, not
  applied -- the governance doc and the branch stay entirely in your hands.
- **Additive only.** An existing lens is left untouched; the skill is safe to run again.
- This script is maintained in the source repo; do not modify it locally in a consumer. A
  change lands first in the source and travels via a release to the plugin mirror.
