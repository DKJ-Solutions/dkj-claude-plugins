# Changelog

## [Unreleased]

**6 / 9 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3157-ci-certificate-raw-name-match · 20261019-123734Z

The CI test certificate that lets `open-pr` skip a local suite run now matches the required check by
its exact name, so a look-alike check name (a zero-width or plain space on an edge, or another case)
can no longer stand the test gate down (#3157). The sanitised name is used only for printing. It
prevents a failure that has not happened: a check this repo never named certifying a commit, reachable
today only by somebody with write access adding a workflow job.

**Score:** 1

#### What makes this deploy extra special

N/A: a consumer's gate behaves exactly as before for every real check name.

**Score:** N/A

#### Pull Request

the CI test certificate matches the check name exactly, not after sanitising

Plugins: dkj-policy

[PR #3160](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3160)

---

### DEPLOY: fix/3153-repo-hub-gate-fact · 20261019-122354Z

The Repo hub's "About this repo" card names the brand book's real gate, `npm run gate` in `brandbook/`, instead of a `lint-web.ps1` script that exists only in the old `dkj-brandbook` repo.

**Score:** 1 -- a wrong fact on this repo's own dev-server page, read by its maintainers.

#### What makes this deploy extra special

The Repo hub is this repo's own dev-server page; nothing a plugin user installs changes.

**Score:** N/A

#### Pull Request

The Repo hub names the brand book's real gate, npm run gate

[PR #3159](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3159)

---

### DEPLOY: feat/3155-cut-release-busy-trunk · 20261019-121133Z

A release cut no longer has to start over when a merge lands while its gates run. After the gates, a
`main` that is only behind `origin/main` is caught up rather than refused when the CI run that the push
to the trunk started has proved the new tip green: the cut waits for that run while it is still going,
fast-forwards, and runs itself again on the new tip. That second run re-reads every pending entry and
re-runs every content gate, and it skips only the lint and test gates CI just ran on that exact commit. A
`main` that is ahead, an unnamed or red check, an unreadable run, or a trunk still moving after three
rounds refuse as before (#2899), with the reason no catch-up was made. Measured at the v5.25.0 cut, two
refusals in a row cost about 30 minutes and postponed the release.

**Score:** 3

#### What makes this deploy extra special

A maintainer cutting a release in a repo whose trunk merges often can now finish the cut in one run,
provided the repo names its test check and its slug, instead of retrying the whole gate until the trunk
goes quiet.

**Score:** 3

#### Pull Request

cut-release finishes on a busy trunk by fast-forwarding over merges certified by main-push CI

Plugins: dkj-policy

[PR #3158](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3158)

---

### DEPLOY: fix/3149-repo-hub-reads-this-repo · 20261019-113956Z

The brand book's Repo hub reads its in-flight work (open pull requests, issues, branches) from `DKJ-Solutions/dkj-claude-plugins` instead of `DKJ-Solutions/dkj-brandbook`, and its links, eyebrow and footer name this repo (#3149). Once `dkj-brandbook` is archived, the panel would otherwise have shown a frozen state without saying so.

**Score:** 2

#### What makes this deploy extra special

N/A: the hub is this repo's own dev-server page, which no consumer takes.

**Score:** N/A

#### Pull Request

the Repo hub reads its in-flight work from this repo, not from dkj-brandbook

[PR #3156](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3156)

---

### DEPLOY: fix/3146-sync-revert-on-live · 20261019-112503Z

`sync-main` now takes a theme file that a third party reverted on live to an earlier version, where the trunk's newest commit on that path is the sync that took it. It used to hold that file back as "live holds a version this repo has had before", and the next push overwrote the revert unseen.

**Score:** 1 -- nothing changes for the maintainer of this repo.

#### What makes this deploy extra special

A Shopify store's sync now captures a third party's revert on live instead of silently holding it back for the next release to overwrite -- measured in a store on two header-group files.

**Score:** 3

#### Pull Request

sync-main takes a third-party revert on live when the trunk's copy came from a sync and has not moved since

Plugins: dkj-subagents-shopify

[PR #3154](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3154)

---

### DEPLOY: fix/3148-house-style-gate-reads-tagged-pin · 20261019-111414Z

The reusable house-style gate now reads its pinned checksums from the skill page as it stands at the tag that page names, not from `main` (#3148). Between a merge that changed a house file and the next cut, the page on `main` named the previous tag beside the new checksums, so a consumer vendoring exactly the released file failed the gate. `check-house-style.ps1` takes `-SkillPath` for this. The suite's "repo-config.ps1 that throws" case now really writes that config: it had passed on the previous fixture's exit code.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo calling `reusable-house-style.yml@main` no longer goes red after a house-style change is merged here and before it is released. Its vendored copy is held to the release it can actually fetch, and nothing changes on its side.

**Score:** 3

#### Pull Request

the reusable house-style gate reads its checksums at the tag the skill page pins

Plugins: dkj-solutions

[PR #3152](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3152)

---

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

