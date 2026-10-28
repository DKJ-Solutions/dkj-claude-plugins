# Changelog

## [Unreleased]

**2 / 4 minor entries** <!-- pending-tally -->

### DEPLOY: feat/h1-never-framed · 20261028-164121Z

A new house-style rule: the `h1` is never framed. `house-style.css` now clears any border, outline, shadow and background on every `h1`. The README (rule 6) and the `house-style` skill state the layout half too: a page's `h1` stands on the page itself, never inside a card, panel or bordered box. The hub follows it already: its group pages (`/clock` among them) and the SessionStart pages had their `h1` inside the card group's surface, and now set it above the group. Alongside it, `.page-column` stacks its blocks with a `--spacing-3` gap instead of `--spacing-5`, so every page built on it is a little tighter. A repo whose own layer gave its `h1` a frame through a plain `h1` selector loses that frame when it takes this copy. A rule on a class of the repo's own still wins, and the rule says it must not be written.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions app takes this the next time it copies the house style. On the hub, the group pages and the SessionStart pages now show their `h1` above the cards rather than inside the group's surface. The rule exists so that no app starts framing it.

**Score:** 2

#### Pull Request

the h1 is never framed

Plugins: dkj-policy, dkj-solutions

[PR #3627](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3627)

---

### DEPLOY: fix/3626-cut-release-stale-section-lines · 20261028-162619Z

`cut-release` no longer names the two audience-note sections #3584 removed
([#3626](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3626)). The GitHub Release body now
points at the attached notes for "whether you need to act" only. The cut's console says the drafted note
holds the audience section, or only its header where no entry reached the audience tier.

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

cut-release's console and Release body no longer name the two note sections #3584 removed

Plugins: dkj-policy

[PR #3628](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3628)

---

### DEPLOY: fix/3619-merge-on-green-actions-read · 20261028-160541Z

The merge-on-green runner that `adopt-ci-floor` places now also grants its job token `actions: read`
([#3619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3619)). `checks: read` and `statuses: read`
(#3491) were not enough: `gh pr checks --required` also reads the workflow run behind each check run, so a
private repo's picker still could not read its required checks and still merged nothing. A re-run of
`adopt-ci-floor` now names a runner without the scope under `[scope]`. When the required-check read
fails, the picker now prints the first line of the error instead of only "could not be read".

**Score:** 3

#### What makes this deploy extra special

In a private repo, merge-when-green had still never merged anything, and this release is the one that fixes it.
Add `actions: read` under `permissions:` in `.github/workflows/merge-on-green.yml`, or delete that file and run
`adopt-ci-floor -Apply` again. A re-run of `adopt-ci-floor` tells you whether your runner needs it.

**Score:** 3

#### Pull Request

merge-on-green: the job token also reads actions, so a private repo's picker can read its required checks

Plugins: dkj-policy

[PR #3624](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3624)

---

### DEPLOY: fix/3620-suite-servers-owner-watch · 20261028-155416Z

A hub server that a test suite starts through the dev-preview hook is now stopped once that suite's process
has ended ([#3620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3620)). The suite sets
`DKJ_DEV_PREVIEW_OWNER_PID` to its own pid, and `dev-preview-watch` stops the server's tree when that process
is gone. Until now a killed gate never reached the suite's own cleanup, and one kill left 26 servers and
watchers holding about 2.3 GB. A real session never sets the variable, so its hub still outlives the session
for the next one to reuse.

**Score:** 2

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

a hub server a test suite starts is stopped when that suite's process ends, even when the gate was killed

Plugins: dkj-policy

[PR #3625](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3625)

---

