# dkj-policy-dkjs — DKJ-Solutions' codex

The binding rules every DKJ-Solutions app shares, written once instead of rebuilt in each repo. It is
the counterpart of `dkj-policy-bwj` (BWJ-Development's codex) for the other organisation: an
**additive** add-on to `dkj-policy` that contradicts nothing that workflow decides, and that carries
no specialists.

## Chapters

| Chapter | Where | What it holds |
|---|---|---|
| The house style | [`skills/house-style/`](skills/house-style/SKILL.md) | The design tokens (light and dark), the light/dark mechanism and the base stylesheet, as one self-contained CSS file |

## Who enables it

**DKJ-Solutions repos only.** BWJ-Development has its own styling, so this plugin is never enabled in
BWJ's repos. It requires `dkj-subagents-alpha` and `dkj-policy`.

## Installing it in a DKJ-Solutions repo

1. Refresh the marketplace clone first (`claude plugin marketplace update dkj-claude-plugins`). A stale
   clone reports success with the previous version. Then enable the plugin in the repo's
   `.claude/settings.json` (`"dkj-policy-dkjs@dkj-claude-plugins": true`) and install it with
   `claude plugin install dkj-policy-dkjs@dkj-claude-plugins --scope project`.
2. Add the extension import to the repo's `CLAUDE.md`, on the line directly below the `dkj-policy`
   import:
   `@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/dkj-policy-dkjs/CLAUDE.md`

No tooling writes that line yet. `dkj-policy-bwj` has an adopt step for its own import, and this
plugin has none, so for now the line is added by hand.

## In this source repo

The plugin is listed as `false` in this repo's `.claude/settings.json`: there is no app here that
renders anything. The house style is maintained here, and only tried out in a consumer.
