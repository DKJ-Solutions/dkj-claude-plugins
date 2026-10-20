# Changelog

## [Unreleased]

**1 / 3 minor entries** <!-- pending-tally -->

### DEPLOY: feat/ink-and-paper · 20261020-205113Z

The house colour splits into two groups. **Paper** (`--paper-1` to `--paper-4`) is what sits behind the text, in
very small steps: the page, the cards, every line and the tinted surfaces, and a stronger border. **Ink**
(`--ink-1` to `--ink-7`) is what sits on it, in large steps: `ink-1` (the highlight and `h1`), `ink-2` (`h2`), then the three greys
(the eyebrow and fills, sub lines and notes, the breadcrumb), then `h3`-`h5` and all text: seven steps evenly spaced in lightness, `ink-7` the darkest on light. `--primary-*` is gone.
The paper roles keep their colours except the stronger border, now a tint a step past the line; the ink steps take
new values, evenly spaced, so `h2` and `h3`-`h5` shift slightly and the muted greys read darker on light and
lighter on dark.
The house-style gate reports every `--primary-*` left behind as a retired token.

**Score:** 4

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release has to rename its own layer: `--primary-1`..`-3` become
`--paper-1`..`-3`, `-5` becomes `--paper-4`, `-9`/`-10` become `--ink-1`/`-2`, `-6`/`-7`/`-8` become
`--ink-3`/`-4`/`-5`, and `-11`/`-12` become `--ink-6`/`-7`. The house-style README carries the table, and the gate names each leftover.

**Score:** 5

#### Pull Request

Split the primary scale into ink and paper

Plugins: dkj-policy, dkj-solutions

[PR #3234](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3234)

---

### DEPLOY: feat/3231-hub-repo-sessions · 20261020-193428Z

The Repo hub has a **DKJ repos** page in its DKJ-Solutions card: every DKJ-Solutions repo on GitHub with its
open issues and pull requests, its checkout on this machine, and the command that opens Claude Code there
([#3231](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3231)). The new repo-local
`repo-session` skill does the same from a session: it shows a repo's checkout, branch and open issues, and
opens a session in that checkout in a window of its own, optionally with a first prompt. The work then runs under that repo's own rules, and an issue for it is filed
there.

**Score:** 1

#### What makes this deploy extra special

N/A: the hub and the skill are this repo's own, and no consumer takes them.

**Score:** N/A

#### Pull Request

Hub: look into every registered repo and open a Claude session in its checkout

Plugins: dkj-policy, dkj-solutions

[PR #3233](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3233)

---

### DEPLOY: fix/3230-lifehub-checkout-path · 20261020-185630Z

The connector register finds the lifehub checkout under its renamed folder, `../dkj-lifehub`
([#3230](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3230)). Until now the connector check could
not find it and skipped its whole block.

**Score:** 1

#### What makes this deploy extra special

N/A: the register is bookkeeping inside this repo, and no consumer takes it.

**Score:** N/A

#### Pull Request

life-hub connector names the renamed checkout folder

[PR #3232](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3232)

---

