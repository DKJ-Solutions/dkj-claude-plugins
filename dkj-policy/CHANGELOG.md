# Changelog

## [Unreleased]

**3 / 3 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3145-reconciliation-owed · 20261019-110552Z

A merged `sync-main -ReconcileBase` branch no longer leaves a path that reads as safe to push while the trunk still lacks live's third-party content. `live-preflight` now refuses a push-list path whose newest commit is still the reconciliation base, `prepare-release` flags it days ahead, and `sync-main`'s closing text says the content commit is required before any live push. A person who decides the trunk's version should win passes `-AcceptOwedReconciliation`.

**Score:** 1 -- the maintainer of this repo sees nothing change here.

#### What makes this deploy extra special

A Shopify store that reconciled a sync conflict with `-ReconcileBase` is now stopped before a live push that would have silently reverted what a third party changed on live -- measured in a store, where it would have undone a raised shipping threshold and a `noindex`.

**Score:** 3

#### Pull Request

A merged reconciliation base reads as safe to push until the content is reconciled

Plugins: bwj-development, dkj-subagents-shopify

[PR #3151](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3151)

---

### DEPLOY: fix/3144-prepare-release-jq-quotes · 20261019-105659Z

`prepare-release` reads the head's check runs on Windows PowerShell 5.1 again (#3144). Its jq filter carried a double quote, which PowerShell 5.1 strips from a native argument, so gh refused the call and step 1 reported "gh missing, logged out, or offline" while reporting the trunk READY. The note now also tells a missing gh apart from a gh that exited non-zero.

**Score:** 2

#### What makes this deploy extra special

A BWJ store repo preparing a release from Windows PowerShell 5.1 now gets the trunk's CI state checked by `prepare-release`, so a red check on the head blocks the READY instead of passing with a soft note.

**Score:** 2

#### Pull Request

prepare-release reads check runs on Windows PowerShell 5.1

Plugins: bwj-development

[PR #3150](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3150)

---

### DEPLOY: feat/3133-house-style-repoint · 20261019-092405Z

The house style's consumer URLs now point at this repo's own release tag, and the release cut writes that tag in, so the skill page always pins the release that ships it (#3133). The three dkj-brandbook changes made after v0.4.0 are ported: a heading above a group of cards (`.grid__head`), a card that takes the whole row (`.grid__full`), and a card in a `.grid-2` without a doubled top margin. The Repo hub drops its own copies of those rules. `cut-release` takes an optional seam, `Get-ReleaseVersionPins`, for any file that pins a URL at the repo's own tag.

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions app fetching the house style now reads it from `DKJ-Solutions/dkj-claude-plugins` at the plugin's release tag instead of from `dkj-brandbook`, with new checksums, and gets three new layout classes for a heading above its cards. A consumer vendoring a copy takes the new one, and `check-house-style` reports the old copy until it does.

**Score:** 3

#### Pull Request

house-style: consumer URLs pin this repo's release tag, written by the cut, and the post-v0.4.0 brandbook rules are ported

Plugins: dkj-policy, dkj-solutions

[PR #3147](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3147)

---

