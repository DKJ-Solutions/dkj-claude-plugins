# Changelog

## [Unreleased]

**3 / 3 minor entries** <!-- pending-tally -->

### DEPLOY: fix/3040-house-style-method-call · 20261015-155905Z

`check-house-style` no longer reads a method call or an object spread in a script as a house class
selector ([#3040](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3040)). A chained `.sort(`
or `.map(` before an arrow function, and `...meta,` inside an object literal, had been reported as
restyling `.sort`, `.map` or `.meta`.

**Score:** 2

#### What makes this deploy extra special

In a DKJ-Solutions repo, the house-style gate and its session-start line no longer flag TypeScript or
JavaScript such as `.sort((a, b) => {` or `{ ...meta, }` as a restyled house class. A repo that had to
answer those lines in `Get-HouseStyleAllowlist` can remove those entries.

**Score:** 2

#### Pull Request

check-house-style: a method call or object spread is no house class selector

Plugins: dkj-solutions

[PR #3043](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3043)

---

### DEPLOY: fix/3039-tidy-lane-remove · 20261015-154452Z

`tidy-machine` lane 1 now hands over `git worktree remove <lane>` for a lane whose branch is finished,
instead of `worktree-lane.ps1 -HandBack`
([#3039](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3039)). The hand-back checked the
merged branch out in the primary checkout, so lane 2 still could not reap it, and its script path does
not exist in a consumer. `prune-merged`, which said the same for a merged branch a lane holds, now says
`git worktree remove` too.

**Score:** 2

#### What makes this deploy extra special

When `tidy-machine` finds a worktree holding a merged or abandoned branch, the command it prints now
removes that worktree and leaves your primary checkout where it is, so a rerun deletes the branch. It
used to print a command that put the finished branch back in your primary checkout and told you to ship
it, and in a consumer repo that command's path did not exist.

**Score:** 2

#### Pull Request

tidy-machine lane 1 hands over git worktree remove for a finished lane, not -HandBack

Plugins: dkj-policy

[PR #3042](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3042)

---

### DEPLOY: feat/3035-check-house-style · 20261015-142218Z

A new `check-house-style` gate in the `dkj-solutions` plugin
([#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035)) checks three things. Every
vendored `house-style.css` and `house-theme.js` must be the copy the `house-style` skill pins. The repo's
own layer must not redefine a house token or restyle a house class app-wide. And it must not use a token
name the brand book retired. The gate runs in CI through a reusable workflow and, read-only, at session
start. This repo's connector dashboard passes it.

**Score:** 3

#### What makes this deploy extra special

In a DKJ-Solutions repo with this plugin, a new session-start line now reports a drifted copy of the
house style, a redefined house token or class, or a retired token name such as `--muted` or `--good`, with
file and line. To block a pull request on the same findings, a repo adds the few-line caller from the
`house-style` skill page, which calls `reusable-house-style.yml`. A false positive is answered with a
reason in `Get-HouseStyleAllowlist` in `scripts/repo-config.ps1`.

**Score:** 3

#### Pull Request

house-style: a check-house-style gate

Plugins: dkj-solutions

[PR #3037](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3037)

---

