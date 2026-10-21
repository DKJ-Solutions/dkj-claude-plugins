# Changelog

## [Unreleased]

**8 / 11 minor entries** <!-- pending-tally -->

### DEPLOY: docs/3253-created-comment-on-own-tasks · 20261021-121925Z

`report-issue` now posts the fixed `created:` comment on a task it creates itself too, right after
placing it, not only on a task that came from Asana (#3253). Colleagues read that comment as the sign
that the GitHub issue exists, on every card, and a session-created card without it read as a skipped
automation. Step 3 and `WORKFLOW-portable.md` say the same.

**Score:** 2

#### What makes this deploy extra special

A session running `report-issue` in a store repo now writes one more comment on every task it creates.

**Score:** 2

#### Pull Request

report-issue: the created: comment on a task the procedure creates itself too

Plugins: bwj-development

[PR #3254](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3254)

---

### DEPLOY: fix/3244-dev-preview-name-port-holder · 20261021-120747Z

When every port the repo's dev server may use is taken, the session-start line now names who holds
each one (#3244): `Repo hub: not started -- port 3000 taken by other processes: 3000 by dkj-lifehub
(pid 19544).` The holder is the checkout its command line names, or else its executable, read from the
process table the hook already holds, so finding the server to stop no longer takes a netstat and a
process lookup by hand.

**Score:** 2

#### What makes this deploy extra special

An owner whose pinned port is held by another repo's server sees which one to stop in the line itself.

**Score:** 2

#### Pull Request

dev-preview: name who holds the port when the repo's server cannot start

Plugins: dkj-policy

[PR #3252](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3252)

---

### DEPLOY: feat/3242-golive-already-fixed · 20261021-115859Z

A ticket that an earlier release had already fixed now has its own close:
`build-golive-block.ps1 -AlreadyFixed -FixedIn <X.Y.Z> -FixedOn <date>` (#3242). Under the intro it says
*"Nothing was changed for this ticket: it was already fixed by an earlier release. Check below that it
holds for you."*, then when it was fixed (the release by day and version, and your `[fixed]` prose) and
where to look (`-Link` and `[where]`). The closed message ends with its own ask: does it hold, then
complete the task, and if not, comment. It refuses every input that would present the earlier fix as
this round's work, such as `[changed]`, `-LiveSince` or `-Path`. The close table now asks *"did something
change, in this round?"*. The skill page and `WORKFLOW-portable.md` describe the form.

**Score:** 3

#### What makes this deploy extra special

Nothing changes for an existing call: the form is new, and only a session that passes `-AlreadyFixed`
meets it.

**Score:** N/A

#### Pull Request

golive-block: an -AlreadyFixed close for a ticket fixed by earlier work

Plugins: bwj-development

[PR #3251](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3251)

---

### DEPLOY: fix/3243-release-notes-history-default · 20261021-115028Z

The release-notes page builder now finds the release history where the cut writes it (#3243). In a repo
that leaves `Get-ReleaseHistoryPath` unanswered, `build-release-notes-page.ps1` looked for
`releases/README.md`, the pre-#885 default, while `cut-release.ps1` wrote the history to
`dkj-policy/releases/history.md`, so the build refused and the general pages server's `/release-notes`
returned 404. It now resolves the same computed default the cut uses.

**Score:** 3

#### What makes this deploy extra special

A consumer that follows the default gets its release-notes page after this release; the workaround of
answering `Get-ReleaseHistoryPath` in `scripts/repo-config.ps1` can stay or go.

**Score:** 3

#### Pull Request

build-release-notes-page: fall back to the computed release-history default

Plugins: dkj-policy

[PR #3249](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3249)

---

### DEPLOY: fix/3241-golive-live-since-heading · 20261021-113444Z

A go-live block closed with `-LiveSince` no longer carries the future-tense heading `WANNEER HET LIVE
KOMT` (`WHEN IT GOES LIVE`) above *"Het staat live sinds ..."* (#3241). Under `-LiveSince` the section
now reads `SINDS WANNEER HET LIVE STAAT` (`LIVE SINCE`), so heading and sentence never disagree; a
planned block keeps the old heading.

**Score:** 2

#### What makes this deploy extra special

A requester reading an Asana closed message for work that is already live is no longer told it is
still coming; nothing to do but take the release.

**Score:** 2

#### Pull Request

golive-block: a past-tense heading under -LiveSince

Plugins: bwj-development

[PR #3246](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3246)

---

### DEPLOY: fix/3237-shop-connector-myshopify-domain · 20261021-101927Z

`check-shop-connector` no longer stops on every store with a custom primary domain (#3237). It took the
`*.myshopify.com` domain from `get-shop-info`, whose `domain` is the custom domain and which has no
`myshopify.com` field, so the comparison read as a mismatch on any store with a custom domain, even
when the connector was bound to the right store. Step 2 now reads it with the read-only Admin GraphQL query
`{ shop { myshopifyDomain } }`.

**Score:** 3

#### What makes this deploy extra special

A store repo whose session stopped at this check on the right store now passes it; nothing to do but
take the release.

**Score:** 3

#### Pull Request

check-shop-connector: read the myshopify.com domain through Admin GraphQL, not get-shop-info

Plugins: dkj-subagents-shopify

[PR #3240](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3240)

---

### DEPLOY: fix/3236-golive-no-storefront-result · 20261021-100334Z

A change that shows nothing on the storefront -- infrastructure, a deploy route, an admin-only setting --
now has its own go-live block: `build-golive-block.ps1 -NoStorefrontResult` (#3236). Its *where to look*
says that nothing changes for customers, with your `[where]` prose (where it does show) under it, and its
ask points at that prose instead of a link. It carries no after-release line, since nothing becomes
visible with the release. **A `github.com` `-Link` is now refused in every form**: a pull request, a
release or a commit had reached requesters as *"the result"*, above *"wat je ziet is wat een klant
ziet"*. The host is parsed, so github.com's subdomains and githubusercontent.com are refused too. The skill page and `WORKFLOW-portable.md` describe the form.

**Score:** 3

#### What makes this deploy extra special

A session in a store repo that passes a pull request, release or commit URL as `-Link` is now refused,
with the remedy named; nothing else changes for an existing call.

**Score:** 2

#### Pull Request

golive-block: a form for a change with no storefront result, and no github.com link as the result

Plugins: bwj-development

[PR #3239](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3239)

---

### DEPLOY: feat/3235-color-token-model · 20261021-094328Z

Every theme's colours are rebuilt on one model (#3235), and computed by a script rather than tuned by hand. Each
theme has **one primary**, the most saturated colour of its hue that reads at 4.5:1 on all four paper steps (so the
paper reads on it too); **two greys**, `--muted` at 7:1 on the page and `--muted-inverse` at 7:1 on the far end;
**four paper steps** from white towards a little darker; and **four text steps** (`--fg-1` to `--fg-4`), near black
on light and near white on dark, in very small steps. `h2` and `h3`-`h5` move from the colour to the text steps, and
two new classes, `.fill-primary` and `.fill-inverse`, switch the text to the paper on a coloured ground, so an `h2`
reads there as well. The breadcrumb bar now stands on the primary, with its crumbs in the paper steps, and the theme settings button takes it as its border. On dark the primary is a light tint, reaching 9:1 on every paper step and no more saturated than OKLCH chroma 0.13, so a fill reads as a calm band under dark text. On light the primary is a little darker and the paper a little lighter than before; nothing in
the model is below 4.5:1 any more. `scripts/build/build-house-palette.ps1` computes and writes the values, and a
new suite holds the stylesheet to them.

**Score:** 4

#### What makes this deploy extra special

Every DKJ-Solutions app that takes this release renames its own layer. From v5.26.0's twelve steps:
`--primary-1`..`-3` become `--paper-1`..`-3`, `-4` is removed, `-5` becomes `--paper-4`, `-6` and `-7` become `--muted`, `-8`
becomes `--fg-4`, `-9` becomes `--primary`, `-10` `--fg-2`, `-11` `--fg-3` and `-12` `--fg-1`; a grey on an
inverted surface takes `--muted-inverse`. The house-style README carries both tables, and the gate names each
leftover.

**Score:** 5

#### Pull Request

A new colour token model: primary, muted, paper and text

Plugins: dkj-policy, dkj-solutions

[PR #3238](https://github.com/DKJ-Solutions/dkj-claude-plugins/pull/3238)

---

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

