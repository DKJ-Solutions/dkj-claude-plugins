# dkj-solutions — DKJ-Solutions' codex

The binding rules every DKJ-Solutions app shares, written once instead of rebuilt in each repo. It is
the counterpart of `bwj-development` (BWJ-Development's codex) for the other organisation: an
**additive** add-on to `dkj-policy` that contradicts nothing that workflow decides, and that carries
no specialists.

## Chapters

| Chapter | Where | What it holds |
|---|---|---|
| The house style | [`skills/house-style/`](skills/house-style/SKILL.md) | The canonical house style in [`assets/house-style/`](assets/house-style/) (the design tokens, the twelve themes, the base stylesheet and the rules), the skill with what a session needs before it fetches them, and the `check-house-style` gate that holds a repo to them |
| The tracker labels | [below](#the-tracker-labels--feature-and-bug-in-every-repo) | `feat/` is labelled `feature` and `fix/` `bug`, in every DKJ-Solutions repo, and how a repo still on `enhancement` moves over |

## The tracker labels — `feature` and `bug`, in every repo

**Every DKJ-Solutions repo labels a `feat/` pull request `feature` and a `fix/` one `bug`, and files its
issues under the same two names**, as the source tracker does (decided October 13, 2026,
[#2961](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2961)). An issue is always a
feature or a bug ([#2783](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2783)), and
`feature` is GitHub's default `enhancement` renamed
([#2764](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2764)). A `docs/` branch carries no
label. The name used to be left to each repo's own branch table, and the `specialists-init` scaffold
suggested `enhancement`, so the repos that copied it diverged from the source.

**A repo whose `scripts/lib/branch-info.ps1` still maps `feat` to `enhancement` moves over in two steps,
in this order.** `open-pr` refuses a label the tracker does not carry, so the tracker goes first:

1. Rename the label on the tracker. A rename keeps it on every issue and PR that already carries it:
   `gh label edit enhancement --name feature --color a2eeef --repo DKJ-Solutions/<repo>`
2. Then point the table at it, `feat = @{ Label = 'feature'; Type = 'Feat' }`, in the repo's own
   `scripts/lib/branch-info.ps1`, on an ordinary branch.

Measured on October 13, 2026, five repos needed it: `dkj-brandbook`, `dkj-etf-tracker`,
`djcylow-react`, `dkj-music-library` and `dkj-recipes`.

Beside its chapters, the plugin ships one SessionStart hook (below). A hook is tooling the harness runs,
not a rule a session has to follow, so it is no chapter and `CLAUDE.md` does not name it.

## The house-style session check

[`hooks/house-style-sessioncheck.ps1`](hooks/house-style-sessioncheck.ps1) runs the `check-house-style`
gate at session start (`startup`, `resume`, `clear`) and reports what it finds: a vendored copy that is not
the pinned one, a redefined house token or class, a retired token name. It is read-only and never fails
the session. In a repo with no house style at all it prints one line saying there is nothing to check.
The gate itself, its allowlist and the CI caller are on the
[`house-style` skill page](skills/house-style/SKILL.md#the-gate-check-house-style)
([#3035](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3035)).

## The Repository's DKJ-Solutions card and the Brandbook

**The dev-preview hook, the Repository and the general pages server are `dkj-policy`'s**, since
[#3198](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3198) (the owner's decision, October
20, 2026): "General" means what every repo has, whichever organisation it belongs to, and BWJ-Development
never enables this plugin. They are documented in
[`dkj-policy`'s `hub/README.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/hub/README.md), the `Get-DevPreview` seam included.

**What stays here is the DKJ-Solutions card and the page it links, the Brandbook**:
[`scripts/lib/dkj-solutions-pages-lib.ps1`](scripts/lib/dkj-solutions-pages-lib.ps1). The house style
belongs to every DKJ-Solutions repo and to no other, so a hub shows that card, as its home page's Brand book
section (#3270), only in a repo that enables this plugin, and the general pages server answers `/brandbook` only there. **The
Brandbook is the source repo's `brandbook/` React app**, built by every release into this plugin's
`assets/brandbook/` and served from there under `/brandbook/` (the owner's decision on
[#3210](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3210), October 20, 2026, which retired
the PowerShell page that rendered the house style a second time). A copy of the plugin from before that
release ships no build, and the page then says so. Every page the
hub machinery renders uses the house style, in every repo, from the copy of this folder inside
`dkj-policy`'s own payload.

## The dev-preview hook

Moved to `dkj-policy` in #3198: see [`dkj-policy`'s `hub/README.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/hub/README.md#the-dev-preview-hook).

## Who enables it

**DKJ-Solutions repos only.** BWJ-Development has its own styling, so this plugin is never enabled in
BWJ's repos. It requires `dkj-subagents-alpha` and `dkj-policy`.

## Installing it in a DKJ-Solutions repo

1. Refresh the marketplace clone first (`claude plugin marketplace update dkj-claude-plugins`). A stale
   clone reports success with the previous version. Then enable the plugin in the repo's
   `.claude/settings.json` (`"dkj-solutions@dkj-claude-plugins": true`) and install it with
   `claude plugin install dkj-solutions@dkj-claude-plugins --scope project`.
2. Run the `adopt-dkj-policy` skill's Part 1 (`adopt-workflow-folder.ps1 -Apply`). It writes the
   extension import into the repo's `CLAUDE.md`, on the line directly below the `dkj-policy` import:
   `@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/dkj-solutions/CLAUDE.md`

That run writes the line for every `dkj-policy` extension the repo enables, so this plugin needs no
adopt step of its own. While the line is missing, the `consumer-prose-sessioncheck` hook warns at
session start ([#2697](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2697)).

## In this source repo

The plugin is enabled here since October 13, 2026
([#2976](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2976)), first for the dev-preview hook
and, since that moved to `dkj-policy` (#3198), for the house-style session check and the hub's
DKJ-Solutions card. This repo's Repository is described in [`dkj-policy`'s `hub/README.md`](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-policy/hub/README.md#in-the-source-repo).
Its server answers `/brandbook` itself, with this tree's own build of the `brandbook/` app, so a change
shows here before the release that ships it.

The house style itself is maintained here, in `assets/house-style/`, since
[#3130](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3130) (October 18, 2026) moved it in
from `dkj-brandbook`. A consuming repo asks for a change through an inbound issue on this repo.
