---
name: theme-lifecycle
description: Keep the Shopify theme estate from filling up, in the two places it grows -- back the live theme up as a verified baseline and rotate the previous backup out, and sweep away the spent preview themes this repo created. Use the backup as the closing step of a release cut, and the sweep after a live push. Both are destructive against a real store, so both are keyed on a reserved name prefix this repo WROTE rather than on anything they merely recognise: a theme somebody else created is never in the delete set, whatever its role. The backup polls until the copy is provably complete, because the CLI returns long before it is -- a backup nobody verified is worse than no backup. The sweep is dry-run by default and the live theme is refused by id and by role.
---

# theme-lifecycle -- the backup that is verified, and the sweep that only takes its own

Two scripts, one estate, and one rule holding both together: **this repo may only remove what this
repo created.** Inbound
[#1965](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1965).

## Why the delete set is a prefix and not a pattern

The store this was specified from carries **61 themes** -- 1 live and 60 unpublished -- and only about
**21** were created by the repo. The other ~39 belong to other people: a third-party agency's working
themes, an experimentation tool's CRO test branches, an installed app's generated themes, colleagues'
sandboxes, a hand-made duplicate of live.

**A sweep keyed on `role == 'unpublished'` would destroy every one of them, and it would look correct
in a dry run that only counted themes.** That is the failure this design exists to make impossible.

The obvious alternative key -- *"the name looks like a flattened branch name"* -- cannot serve either,
and that is measured rather than cautious: several of those third-party themes are **plain hyphenated
words**, indistinguishable in shape from a branch-derived name, and others are branch-shaped but keep
the slash, so they look like ours and are not. Identifying a delete set by resemblance is guesswork on
an irreversible operation.

So every theme `push-preview` creates now carries a **reserved prefix this repo owns**, and the sweep
matches on that and on nothing else.

**Cross-checking against the repo's branch list is a useful second gate and cannot be the first**: a
branch deleted after its merge no longer exists locally, which is exactly when its preview becomes due
for sweeping. A key that goes stale in the direction of *"sweep it"* is the wrong way round.

## The migration is explicit, and that is the safe direction

A preview created **before** the prefix landed does not carry it, so the sweep reports it as *"not
created by this repo"* -- which is literally true of its name -- and leaves it standing. Those are a
one-time manual cleanup ([`archive-theme`](../archive-theme/SKILL.md) takes the copy first). The
alternative was guessing, which is the thing above.

`push-preview` still **finds** such a theme by its old name, so a branch mid-flight keeps pushing to
the preview it already has rather than silently growing a second one. It keeps that old name.

## Back up the live theme (the closing step of a release cut)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/backup-live-theme.ps1" -DryRun
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/backup-live-theme.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves **only inside a plugin-owned component**. From an ordinary shell,
spell the plugin cache path out.

| Parameter | What it is for |
|---|---|
| `-Store` | overrides `Get-ShopifyThemeEstateStore` for this run. |
| `-DryRun` | report every verdict and change nothing. Worth doing once in a new store. |
| `-PollSeconds` | seconds between file-count samples while the copy fills. Default 20. |
| `-TimeoutMinutes` | give up waiting and fail loudly. Default 20. |

**Three steps, and the order is the whole design: create -> verify -> rotate.**

1. **Create.** `shopify theme duplicate` from live into `<prefix>backup-<timestamp>`.
2. **Verify.** Poll the copy's file count until it settles **and** matches the source's.
3. **Rotate.** *Only now* is the previous backup deleted, so there is never a window in which the
   store holds no backup at all. That costs one theme slot transiently, which is the price of the
   guarantee.

### The verify step is the point, and it is the one nobody thinks to ask for

`shopify theme duplicate` **returns long before the copy is complete.** Measured in the consumer on
September 13, 2026: a duplicate of the live theme grew **38 -> 538 -> 738 -> 833 files over roughly
eight minutes**.

A step that created the duplicate and reported success would be reporting on a theme that may hold a
fraction of what it is meant to protect -- and the failure is **silent**, because the theme exists, is
correctly named, and has the right role. Nothing about it looks wrong until somebody needs it.
**A backup nobody verified is worse than no backup, because it is relied on.**

So a copy that settles **below** the source is a refusal, not a warning. On any verdict other than
*complete* the run exits non-zero, the new theme is left standing so it can be inspected, and
**nothing is rotated** -- the previous backup is still there, which is the state a reader would have
asked for.

## Sweep the spent previews (after a live push)

```powershell
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/sweep-preview-themes.ps1"
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/sweep-preview-themes.ps1" -Execute
```

| Parameter | What it is for |
|---|---|
| `-Store` | overrides `Get-ShopifyThemeEstateStore` for this run. |
| `-Execute` | actually remove them. Without it the run reports and changes nothing. |
| `-Keep` | extra theme names to spare, beyond the current branch's own preview. Exact names, never patterns. |

**Dry run is the default**, deliberately: a destructive step whose safe mode has to be remembered is
one that gets run without it.

**Every theme gets a row, including the ones that stay.** That is the design rather than verbosity --
a summary that listed only the delete set would be unfalsifiable, because the ~39 themes it must never
touch are exactly the rows it would not print.

Never swept, each as its own refusal rather than one rule stretched over several cases:

| what | why |
|---|---|
| anything without the reserved prefix | this repo did not create it |
| the backup | only the release cut rotates that, and only after its replacement is verified |
| the live theme, **by configured id** | `Get-ShopifyLiveThemeId` |
| the live theme, **by the role the store reports** | the two are the same theme today, and the day they differ one of them is the only guard left |
| any role that is not `unpublished` | a `development` theme belongs to whoever is running `shopify theme dev` right now |
| the current branch's own preview | legal by every other rule here, and almost never what was meant |
| a name that also matches a third-party prefix | refusing beats resolving a namespace collision in favour of deleting |

And when `Get-ShopifyLiveThemeId` is unanswered, **nothing is swept at all** -- not "everything except
whatever has role `main`". Knowing which theme is live is the one thing standing between a sweep and
the live theme.

## The delete marker, and why neither script works around it

This plugin's live-theme guard is a **PreToolUse hook** that reads the *command string* of a tool call,
and it refuses every `shopify theme delete` unless the repo has answered
`Get-ShopifyThemeDeleteMarker` **and** the command carries it. That default is an absolute refusal.

Neither script here works around it. With the seam unanswered, both **print** the removal command for
a person to run as their own visible act -- the same answer [`archive-theme`](../archive-theme/SKILL.md)
gives, for the same reason. A repo that has not answered that seam is a repo that has not authorised an
automatic theme delete, which is a decision rather than a gap.

**What the standing approval covers, and its bounds**, is not decided here. BWJ states it in
`dkj-policy-bwj`'s `THEME-LIFECYCLE-portable.md`; another consumer states it wherever their own safety
rules live.

## The seams

| seam | required? | what it answers |
|---|---|---|
| `Get-ShopifyThemeEstateStore` | **required** | the store these two scripts act on. `-Store` gets you through one run. |
| `Get-ShopifyLiveThemeId` | **required** | which theme is live. Both scripts refuse without it rather than guessing. |
| `Get-ShopifyThemeDeleteMarker` | optional | unanswered, the removals are printed instead of performed. |
| `Get-ShopifyExternalThemePrefixes` | optional | third-party name prefixes, for the collision refusal. |
| `Get-ShopifyTrunkIsLive` | optional | whether the trunk has reached live. Answered `$false`, the backup prints the order warning below. |

### Why the store is its own seam and not `Get-ShopifyStoreDomain`

Because answering that one **also** unlocks something else. At least one consumer deliberately leaves
it unanswered as a brake: answering it makes [`sync-main`](../sync-main/SKILL.md)'s bare route usable,
and that route opens its PR with plain `gh` rather than through the repo's lint and test gates --
which `sync-main`'s own header names as the accepted cost of not coupling to a workflow plugin.

If these scripts read that seam, the first consumer to adopt a backup would lift an unrelated brake as
a side effect, and the gate-bypassing route would open silently while looking like configuration
tidy-up. **A seam whose answer authorises something else is not a shared fact.**

## The cut/push order, because it decides what the backup *means*

This workflow runs **push, then cut** -- and [`cut-release`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/skills/cut-release/SKILL.md)
argues for it on this exact target type: a Shopify live theme has no locking, third parties edit it
through the theme editor while you work, and a live push is per-file rather than wholesale. Cutting
first risks a **stranded release** -- a tag and a Release describing a state no customer ever saw, which
nothing detects.

Under that order the backup taken at the cut is the clean **baseline of what actually shipped**: the
fixed point third-party drift is measured from until the next release, which is the thing
`sync-main`'s whole existence implies a store needs.

So the signature of the other order is an **unpushed trunk**, and `Get-ShopifyTrunkIsLive` is how the
run can tell. It **warns and does not refuse**: the copy itself is correct and useful either way, so
what is at risk is only the *reading* of the artefact, and a line of output is the proportionate answer
to that. The destructive halves -- rotation and the sweep -- refuse rather than warn, and they are the
ones that can take something away.

## What is tested, and what cannot be

`scripts/tests/theme-lifecycle-rules.tests.ps1` pins the rules both scripts invoke: the reserved
namespace against a miniature of the real store, the backup name, the fill verdict in all four of its
states, both states in which rotation refuses outright, and the two blind states in which the sweep
takes nothing.

**The scripts themselves are not driven**, for the reason [`push-preview`](../push-preview/SKILL.md)
gives: every path in them reaches a real store or a consumer's `repo-config.ps1`, and a suite must not
be able to reach a store. What therefore cannot be asserted here is the CLI's own behaviour -- that
`theme duplicate` fills asynchronously, what `theme list --json` returns. Those are the consumer's
measurements, cited as theirs.
