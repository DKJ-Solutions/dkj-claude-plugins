# The theme lifecycle -- what BWJ's two stores owe the estate

> **Chapter four of `dkj-policy-bwj`.** Policy, never mechanism: the scripts live in
> `dkj-subagents-shopify` and are documented on its
> [`theme-lifecycle`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-shopify/skills/theme-lifecycle/SKILL.md)
> page. What this page states is what the two stores *owe* -- which is Dave's house rule for them
> rather than a fact about Shopify.

Both BWJ store repos -- `smartwatchbanden` and `xoxowildhearts` -- run **one identical theme
lifecycle**, so the estate cannot drift between them. Requested by the store owner on
September 13, 2026; built on inbound
[#1965](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1965).

**This chapter's reach did NOT widen when `dkj-claude-plugins` was admitted to chapter one on
September 14, 2026** (commit `b9b2a65a`) -- a theme estate is a fact about a Shopify store, the source
repo runs none, and there is nothing here for it to owe. See
[`WORKFLOW-portable.md`](WORKFLOW-portable.md) for that widening and why it stops at chapter one.

## The rule, in one paragraph

A Shopify store's theme ceiling is finite and its themes accumulate from both ends: previews pile up
as branches ship, and nobody ever quite gets round to taking a backup. So **two moments in the cycle
own the estate**. The **live push** is followed by a sweep of the spent previews this repo created.
The **release cut** that closes that push takes a fresh backup of live, verifies it is actually
complete, and only then rotates the previous one out. Exactly one backup is retained at a time, and
the cut is what rotates it.

## The order: push, then cut

**The live push comes first, and the release cut is its documented closing act.** That is this
workflow's own answer for a target that can fail or be partial -- a live theme has no locking, third
parties edit it through the theme editor while you work, and a live push is per-file rather than
wholesale. The reasoning is on
[`cut-release`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/skills/cut-release/SKILL.md)'s
page and is not restated here; the invariant it buys is that a failed push cannot leave a **stranded
release** -- a tag, a GitHub Release and an audience document describing a state no customer ever saw,
which nothing detects.

**So the backup is the BASELINE OF WHAT SHIPPED, not a rollback point for the push.** That is the
whole meaning of the artefact, and it is worth being exact about because the other reading is the
natural one:

| | what the backup holds | what it is for |
|---|---|---|
| push, then cut *(this is the order BWJ runs)* | live **after** the push | the fixed point third-party drift is measured from until the next release |
| cut, then push | live **before** the push | a rollback point for the push about to happen |

The baseline reading is the one that matches what these two stores actually need: the entire reason
[`sync-main`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-shopify/skills/sync-main/SKILL.md)
exists is that third parties edit live between releases, and "what did live look like when we last
shipped" is the question that mechanism keeps implicitly asking.

**A backup taken before the push is still a valid copy and the run does not refuse it** -- it warns,
naming which reading applies. Nothing about the copy is wrong; what would be wrong is a later reader
assuming it holds what this page says it holds. Decision by Dave, September 14, 2026.

**#1965 also asked for a preview of the trunk at the cut, and it is deliberately not built.** Under
push-then-cut the trunk is already live at that moment, so the preview would be byte-identical to the
live storefront -- a theme slot spent on a review target with nothing to review. It is worth building
only under the other order, and that is recorded on the issue rather than half-shipped here.

## Deleting a theme: the standing approval, and its bounds

Both store constitutions carry **"never delete a theme without explicit confirmation."** That rule is
unchanged. What this page does is state the exceptions **explicitly and narrowly**, so each store can
point at this page rather than re-deciding locally -- and so the exception stays as narrow on paper as
it is in code.

There are now **three** standing approvals, and nothing else:

1. **The preview theme of a branch that has just shipped live** -- the pre-existing exception, via an
   exact-name-match script that refuses anything live or not `unpublished`.
2. **The sweep of this repo's spent preview themes, after a live push.**
3. **The rotation of the previous backup, at the release cut** -- and *only* after its replacement has
   been created **and verified complete**.

**Every one of those is bounded by the reserved prefix.** A theme this repo did not create is outside
all three, whatever its role, whatever its name looks like. That bound is not a convention anybody has
to remember: it is how the delete set is computed, and a theme without the prefix cannot enter it.

**And the standing approval does not bypass the delete guard.** `dkj-subagents-shopify`'s PreToolUse
hook still refuses every `shopify theme delete` that does not carry `Get-ShopifyThemeDeleteMarker`.
A store that answers that seam runs these removals; a store that has not is a store where these steps
print the command instead of running it, which is the correct behaviour and not a misconfiguration to
route around.

### What is never deleted by any of the three

The live theme -- refused by configured id **and** by the role the store reports, because those are
the same theme today and the day they differ is the day one of them is the only guard left. Any theme
whose role is not `unpublished`. The current branch's own preview. And, above all, **the ~39 themes on
these stores that belong to somebody else**: the agency's working themes, the experimentation tool's
CRO branches, the installed app's generated themes, colleagues' sandboxes, the hand-made duplicate of
live.

That last group is why the delete set is keyed on a prefix this repo **wrote** rather than on anything
a script merely recognises. Keyed on the role instead, a sweep would take all 39 -- and would look
correct in a dry run that only counted themes.

## The previews already standing are a one-time manual cleanup

The reserved prefix only applies to previews created **after** it landed, so the ~21 already on the
store do not carry it and no sweep will touch them. They are reported as *"not created by this
repo"*, which is literally true of their names.

Retire them by hand, taking the archive first:
[`archive-theme`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-shopify/skills/archive-theme/SKILL.md)
pulls a verified copy and leaves a committed receipt, then prints the removal command for somebody to
run as their own visible act.

**Leaving them out of the sweep is the safe direction and not an oversight.** The alternative was to
guess from the shape of a name, on a store where third-party themes are plain hyphenated words -- and
guessing is exactly what this whole design exists not to do.

## What each store still answers for itself

Only the **mechanism** travels. The data stays a seam answer per store, which is what lets one
mechanism serve two brands:

| seam | what each store answers |
|---|---|
| `Get-ShopifyThemeEstateStore` | its own store domain |
| `Get-ShopifyLiveThemeId` | its own live theme id |
| `Get-ShopifyThemeDeleteMarker` | its own delete marker |
| `Get-ShopifyExternalThemePrefixes` | the third-party prefixes on *its* store |
| `Get-ShopifyTrunkIsLive` | optional; answered, the backup can tell which order it is running in |

**`Get-ShopifyThemeEstateStore` is deliberately not `Get-ShopifyStoreDomain`**, even though both hold
a store domain. Answering the latter also makes `sync-main`'s bare route usable, and that route opens
its PR without the repo's lint and test gates -- so a store adopting a *backup* would lift an
unrelated brake as a side effect. A seam whose answer authorises something else is not a shared fact.
