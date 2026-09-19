---
id: 24
group: 06
---

# Ravi ♻️ · claude-code-specialists addendum

> Repo-lens (claude-code-specialists) accompanying the portable playbook in the `dkj-subagents-alpha` plugin (`plugins/dkj-subagents/dkj-subagents-alpha/manuals/06-24-manual.md`). This file does not describe the craft, but what Ravi guards in this repo and with which mechanism.

A refactoring specialist does the same thing everywhere — track down duplication of behavioral rules
and promote it to a single source. **What is repo-specific in claude-code-specialists is not that Ravi
deduplicates, but which artifacts fall under him here and with which mechanism he globalizes.**

### What Ravi guards here

- **The agent defs** in all plugins (`plugins/*/subagents/*-agent.md`)
  and the **persona templates** (`.../specialists/personas/*-persona.md`) — for verbatim-shared bullets
  under **Boundaries** and **Working method**, and for standalone behavior
  directives outside those sections (e.g. the closing language-choice line). This repo is the **source** of
  the specialists system, so a duplication eliminated here propagates through a release to all
  consuming repos.
- This repo is itself a consumer too, so the same rule applies to the **repo lenses** in
  `.claude/specialists/lenses/` wherever those behavioral rules would duplicate.

### The mechanism in place here

The verbatim-shared blocks run on **build-and-lint** (built July 2026):

- **Source:** `plugins/dkj-subagents/subagent-shared/<name>.md` — one canonical text
  per block, placed next to the four team directories (every carrier is a team's) and outside every
  plugin root, so it does not travel with the plugin cache.
- **Sentinels:** in an agent def the block sits between `<!-- BEGIN/END shared:<name> -->`; the
  content is there verbatim (always loaded), but is filled from the source.
- **Generator:** `scripts/agents/build-agent-defs.ps1` fills the blocks; `-Check` reports drift.
- **Gate:** `check-plugin-integrity.ps1` (check 7) fails as soon as a marked region deviates from its
  source. Details in the [Sylvester #15 lens](specialist-05-15-lens.md).

Current shared blocks, sourced one file each under `subagent-shared/`, fall into four tiers by how far
each one reaches: **universal** — `inbound-behaviour` and `laziness-automation` (every agent def
carries both), plus `repo-way-of-working` and `findings-become-issues`, which are the only two that
reach the four personas as well, so 30 carriers rather than 26; **near-universal** —
`language-behavior` (every agent def except 03-07/Rebecca, who
keeps a local variant with a source-quoting nuance, deliberately not shared); a **middle tier** —
`no-conversation-history` and `no-commit-push-pr`, each reaching a meaningful share of agent defs,
comfortably wider than the narrow tier below but well short of near-universal; and a **narrowly
applied** tier — `browser-compatibility`, `webcontent-boundary`, `changelog-entry-boundary`,
`design-owner-boundary`, `storefront-preview-boundary`, and `artifact-publishing-boundary` — each
reaching only the circle of agent defs whose craft the rule actually touches (e.g.
`changelog-entry-boundary` only where the specialist owns an entry file,
`design-owner-boundary`/`storefront-preview-boundary` only for the relevant Shopify roles).
Deliberately no per-block agent-def counts here: they drift with every new agent def, which is
exactly the kind of staleness this lens exists to catch, not repeat. To check the current count or
circle for a given block, search the sentinel across the plugins — e.g.
`Get-ChildItem -Recurse -Filter '*-agent.md' plugins | Select-String
-Pattern 'BEGIN shared:<name>'` lists every agent def currently carrying it;
`scripts/agents/build-agent-defs.ps1 -Check` complements that by flagging any of those that has
drifted from its source in `subagent-shared/`.

**A UNIVERSAL BLOCK'S COST IS NOT UNIFORM, AND THAT IS THE FACT THE TIER MODEL ABOVE DOES NOT CARRY**
([#1705](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1705), September 9, 2026).
Of `findings-become-issues`'s 30 carriers, exactly **one** sits on the always-on path: Chris's persona
body, which `CLAUDE.md` imports through `SPECIALISTS.md` on every turn. The other 29 are paid per
invocation — the agent defs carry these blocks in the **body**, not in the frontmatter `description`
that Claude Code loads for every enabled plugin. So a bullet appended to a universal block is paid
**once per session in every consuming repo**, plus once per invocation twenty-nine times over, and the
word *universal* makes that sound cheaper than it is.

**The test before appending to one, therefore: would you put this bullet in Chris's body on its own?**
If the answer is no, it belongs in a narrower block rather than in a universal one — the generator
already supports several independently-named regions per file, so the cost of a new circle is a name
and a source file. And there is no cheap middle: `Get-SharedBlockText` reads the source file **whole**,
so a source cannot carry a header that stays behind. Anything written into it travels to all 30.

**#1705 asked the sharper version of that question — is every bullet of `findings-become-issues` one
every carrier needs? — and the answer was measured per bullet and the split DECLINED.** Seven of the
eight are universal on their face: what a finding is, that an inconsistency is one, that a tracker has
to exist before you promise it, the filing bar, file-before-you-cite, that filing needs no permission,
and that the question is *"does it still stand"* rather than *"may I"*. The eighth reads narrow — it is
about reading the issue that produced a **guardrail** before proposing to change it, which sounds like
Sylvester's and Sebastian's business — and it generalises on reading to *"read why a thing exists
before proposing to change it"*, which no carrier is exempt from. A block whose every bullet answers
one question (*how do I file what I found*) is coherent, and splitting it to save one bullet's bytes
would trade a real cost for a real seam. What the measurement is worth is the paragraph above it: the
bar, so the next bullet is weighed rather than appended.

### Working method in this repo

- Ravi **proactively** takes part in the quality check before a PR (just like [Victor #19](specialist-06-19-lens.md)
  and [Sebastian #23](specialist-06-23-lens.md)): he scans the diff for newly introduced duplication of
  behavioral rules, and periodically sweeps the entire system.
- He performs the deduplication itself with the existing mechanism. If it calls for **new
  machinery** (e.g. a detection lint that reports a verbatim bullet in ≥2 places without a shared
  source), that is [Sylvester #15](specialist-05-15-lens.md);
  if it calls for **harmonizing near-duplicates into a single text**, he works with [Tessa #16](specialist-06-16-lens.md).
- Known open jobs on his plate: (1) the **Tier 2 sweep** (the stem-with-slot bullets: final message,
  conversation history, branch); (2) the **detection lint** as alarm-bell automation.

  **Extending the mechanism to the persona templates was the third, and it shipped on August 8, 2026**
  — the generator started walking `personas/` alongside `agents/`, as that directory was named then (`scripts/agents/build-agent-defs.ps1`), which
  is what let a shared block reach the two specialists whose craft *is* a way of working. It is written
  here as a closed job rather than deleted, because the comment in that generator still cites this list
  as the place the widening was foreseen; a reader who follows that citation has to land on the answer,
  not on the plan.

In short: the **how** (tracking down duplication and promoting it to a single source) is portable;
the **what** (the agent defs/personas of this marketplace and the `subagent-shared/` build-and-lint
mechanism) belongs to this repo.
