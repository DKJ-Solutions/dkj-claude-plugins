# `releases/` — the release list

This directory holds **one thing: the list of every release this repo has ever cut**, at the foot of
this page. It is not written by a plugin and does not depend on one being installed — a repo that has
cut releases has a history whichever tooling cut it, so the list stays here, where nothing can take it
away.

**The generated documents moved out on August 26, 2026** (issue
[#914](https://github.com/DaveKJohn/claude-code-specialists/issues/914)). They are what the workflow
*produces*, so they now sit in the workflow's own folder beside the hand-written note that was already
there — one directory per document, and none of them at the repo root any more:

| directory | one file per version | written for |
|---|---|---|
| [`changelog/`](changelog) | `<X>.x/<X.Y.Z>.md` — the complete, raw note: every change the release carried | this repo's own developers |
| [`github/`](github) | `<X>.x/<X.Y.Z>.md` — the body of that version's GitHub Release | whoever opens the release on GitHub |
| [`audience/`](audience) | `<X>.x/<X.Y.Z>.md` — the one hand-written document, a named section per reader | whoever this repo publishes to |

`changelog/` was called `development/` until that same day. The name says what the document *is* — the
changelog for that version, the entries as the fold left them — rather than which stage of the work
happened to produce it.

**Each file is a published record.** It was true at the moment it was cut, and going stale afterwards
is the record working rather than a defect — so links may be repointed when a target moves, and prose
is not rewritten. The one line that may be corrected is one that was *false when it was written*; the
rule and how to mark such a correction are in
[`RELEASES-portable.md`](../../plugins/dkj-policy/RELEASES-portable.md#once-it-has-landed-it-is-a-published-record--and-that-protects-only-what-was-true).
That rule is exactly what the move obeyed: all 134 relative links in the notes were repointed one level
deeper, and no note's prose was touched — so several of them still describe their own path as
`releases/development/`, which is where they were written.

**Older notes are in the language they were written in.** The repo switched to English on July 20,
2026 and history is not rewritten, so the earliest notes are Dutch — one of the deliberate
exceptions in [`language-layers.md`](../../.claude/rules/language-layers.md).

> **Named `davekjohns-workshop` until August 3, 2026.** The marketplace was renamed with the
> [one-product decision](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/123878dd51f7e06861777805402ce46a55375e41/README.md#one-product-one-repository); the older notes under
> `changelog/` still carry the old name and are deliberately not rewritten — they are history.

## What is not on this page

**The release list below is this repo's own**, and since #914 it is the only thing on this page that
is. Everything a release *produces* belongs to the workflow and is one layer up, in
[`contributing-davekjohn/releases/`]():

- **The three note trees** in the table above — the raw record, the GitHub Release body, and the one
  hand-written document with a named section per reader. The first two are generated at every cut; the
  third exists *because* the tier model exists, so a repo without that workflow writes no such note.
- **How a release is cut**, and this repo's answers to it — the seam values, the local decisions —
  are in
  [Rendall's repo lens](../../.claude/specialists/lenses/specialist-05-06-lens.md#versioning--releases)
  over
  [`RELEASES-portable.md`](../../plugins/dkj-policy/RELEASES-portable.md), which states
  what it covers rather than being summarised here twice. This line named
  `contributing-davekjohn/releases/README.md` until #2196 retired that page; the link is repointed and
  the answers it reached are unchanged.

That is the layering this repo uses throughout: the root holds what is true regardless, and the
`contributing-davekjohn` layer adds what the workflow brings. Where the two disagree, the workflow page
wins — the same rule [`CONTRIBUTING-portable.md`](../../plugins/dkj-policy/CONTRIBUTING-portable.md) and
[`.claude/rules/this-repo.md`](../../.claude/rules/this-repo.md) state.

## The release list

**Every release ever cut, newest first, grouped by major version.** This is the full record:
`CHANGELOG.md`'s release block names only the current version and points here for the rest, so nothing else
in the repo carries this list.

New releases are added to the current major's table, the top one. That is why **opening a new major's
section is a deliberate act, taken before the release is cut**: `cut-release.ps1` inserts the row after the
first release table it finds, so without a section for the new major a `v4.0.0` row would be filed under
`3.x` with nothing erroring. A guardrail refuses that rather than doing it quietly.

Three things about the structure below are load-bearing rather than stylistic, and all three are why this
list sits at the **end** of the page:

- **The inserter takes the first release table in the whole document**, so any table introduced above these
  would silently start receiving the rows. That is the one thing to check when adding a section anywhere on
  this page.
- **The guardrail reads the last `<n>.x` heading above that table**, so those headings must stay
  recognisable. The heading **level** may change — `###` and `####` are both accepted, because how deeply
  the list is nested is a layout choice the repo owns — but the `<n>.x` text is not decoration.
- **The table header is described in prose and quoted nowhere on this page**, because the inserter matches
  that exact line and a document explaining a pattern should not be one edit away from triggering it.

### 5.x

| Version | Date | Type | Title |
|---|---|---|---|
| [5.7.0](audience/5.x/5.7.0.md) | 2026-09-23 | Minor | Minor release |
| [5.6.0](audience/5.x/5.6.0.md) | 2026-09-21 | Minor | Every specialist file takes its specialist- name, and consumers migrate the orchestrator import once |
| [5.5.0](audience/5.x/5.5.0.md) | 2026-09-18 | Minor | The close-out gets a gate, and the cycle's scripts stop failing silently |
| [5.4.0](audience/5.x/5.4.0.md) | 2026-09-17 | Minor | Release version 5.4.0 |
| [5.3.0](audience/5.x/5.3.0.md) | 2026-09-14 | Minor | One shared Cloudflare Worker for both BWJ stores |
| [5.2.0](audience/5.x/5.2.0.md) | 2026-09-14 | Minor | Native-capture argv quoting closed as a class, the fixture-load guard reaches every copying suite, and the BWJ theme lifecycle ships |
| [5.1.0](audience/5.x/5.1.0.md) | 2026-09-12 | Minor | Adoption gaps close - shared BWJ mechanism, one-command plugin updates, and a portable reach label |
| [5.0.0](audience/5.x/5.0.0.md) | 2026-09-11 | Major | The marketplace is dkj-claude-plugins -- every existing install must be re-installed under the new name |

### 4.x

| Version | Date | Type | Title |
|---|---|---|---|
| [4.33.0](audience/4.x/4.33.0.md) | 2026-09-10 | Minor | Release version 4.33.0 |
| [4.32.0](audience/4.x/4.32.0.md) | 2026-09-07 | Minor | Retire the merge queue as policy for detect-and-rebase, repair ship-pr's required-check handling, and fix the Asana mirror and BWJ connector registers after the org move |
| [4.31.0](audience/4.x/4.31.0.md) | 2026-09-06 | Minor | Every plugin carries its owner in its name, and the fold survives a queue merge |
| [4.30.0](audience/4.x/4.30.0.md) | 2026-09-05 | Minor | The workflow plugin is now dkj-policy, and consumers re-install under the new ids |
| [4.29.0](audience/4.x/4.29.0.md) | 2026-09-04 | Minor | Per-branch development documents, a live work-tracker mirror, and a test gate packed by measured duration |
| [4.28.0](audience/4.x/4.28.0.md) | 2026-08-31 | Minor | Add the workflow-bwj plugin, and harden the release gates and measurement tools for other locales and checkouts |
| [4.27.0](audience/4.x/4.27.0.md) | 2026-08-30 | Minor | prune-merged leaves the checkout alone, and the consumer-facing messages name the seam |
| [4.26.0](audience/4.x/4.26.0.md) | 2026-08-30 | Minor | The gates and their messages name what actually happened instead of an assumed cause |
| [4.25.0](audience/4.x/4.25.0.md) | 2026-08-30 | Minor | Testrun 3's findings land: four pages that contradicted their own tree, a pasteable settings proposal, and two backslash-aware un-escapes |
| [4.24.0](audience/4.x/4.24.0.md) | 2026-08-29 | Minor | A fresh repo can walk the adoption path from install to its first release |
| [4.23.0](audience/4.x/4.23.0.md) | 2026-08-29 | Minor | the first full adoption test run's findings, repaired -- the fresh-repo path and the shipping cycle |
| [4.22.0](audience/4.x/4.22.0.md) | 2026-08-28 | Minor | Gates that read what merges, notifications that name their sender, and two seams for the Shopify sync |
| [4.21.0](audience/4.x/4.21.0.md) | 2026-08-27 | Minor | The workflow folder holds this repo's own documents, the branch document becomes development.md, and /lock and /handover are retired |
| [4.20.0](audience/4.x/4.20.0.md) | 2026-08-26 | Minor | The workflow plugin becomes contributing-davekjohn and stops writing into your repo root, and a branch reaches origin without anybody remembering to push |
| [4.19.0](audience/4.x/4.19.0.md) | 2026-08-24 | Minor | A branch carries one document through four phases, the close-out gains three shapes, and findings become issues instead of questions |
| [4.18.0](audience/4.x/4.18.0.md) | 2026-08-21 | Minor | Consumer-reported repairs across the sync, the cut and the branch files, plus a shared Shopify preview push |
| [4.17.0](audience/4.x/4.17.0.md) | 2026-08-20 | Minor | The Shopify floor gains its pre-task sync, and the branch-entry convention gains a shipped gate |
| [4.16.0](audience/4.x/4.16.0.md) | 2026-08-20 | Minor | The Shopify floor gains the install path it shipped without |
| [4.15.0](audience/4.x/4.15.0.md) | 2026-08-20 | Minor | A two-section branch entry, a live-theme guard for team-shopify, and a release-notes page you can scan |
| [4.14.0](audience/4.x/4.14.0.md) | 2026-08-19 | Minor | The root docs hold without a plugin installed, and the workflow layer sits on top |
| [4.13.0](audience/4.x/4.13.0.md) | 2026-08-16 | Minor | The changelog entry halves, the changelog reads newest first, and /continue becomes /handover |
| [4.12.0](audience/4.x/4.12.0.md) | 2026-08-16 | Minor | A finding is measured before it is repaired, and a gate records what it proved |
| [4.11.0](audience/4.x/4.11.0.md) | 2026-08-15 | Minor | A prompt inbox for assignments, and a third of the always-on layer moved off the load path |
| [4.10.0](audience/4.x/4.10.0.md) | 2026-08-15 | Minor | The Claude App marketplace publishes a chosen subset, and an inbound report's subject is verified before it is routed |
| [4.9.0](audience/4.x/4.9.0.md) | 2026-08-15 | Minor | the workflow gathers into its own root folder at the consumer, and what the plugin ships is held to what a consumer can actually use |
| [4.8.0](audience/4.x/4.8.0.md) | 2026-08-13 | Minor | The branch and release conventions and the consumer test gate now travel with the plugin |
| [4.7.0](audience/4.x/4.7.0.md) | 2026-08-13 | Minor | The documents describe what the tooling actually writes: the entry's tier shape, the post-merge step, and a seam that escaped in a third spelling |
| [4.6.0](audience/4.x/4.6.0.md) | 2026-08-12 | Minor | One audience tier per repo, and releases/ reduced to three reader-named roots |
| [4.5.0](audience/4.x/4.5.0.md) | 2026-08-11 | Minor | Repairs across the entry, PR-body and release-document machinery: gates and documents that pointed at retired shapes now name the ones actually written. |
| [4.4.0](audience/4.x/4.4.0.md) | 2026-08-11 | Minor | The merged note model gets its first written instance, and a release now times itself end to end |
| [4.3.0](audience/4.x/4.3.0.md) | 2026-08-11 | Minor | One hand-written release note per release, a generated Release page, and the performance engineer owns wall-clock |
| [4.2.0](audience/4.x/4.2.0.md) | 2026-08-10 | Minor | The consumer release document is named and written for its reader, and three silent failures gain a check |
| [4.1.0](audience/4.x/4.1.0.md) | 2026-08-10 | Minor | The workflow's portable half: a consumer can copy the PR template and the contribution cycle, and three seams stop failing quietly |
| [4.0.0](audience/4.x/4.0.0.md) | 2026-08-09 | Major | Chapter 3 consolidated (v3.0.0 -> v3.10.0) |

### 3.x

| Version | Date | Type | Title |
|---|---|---|---|
| [3.10.0](audience/3.x/3.10.0.md) | 2026-08-09 | Minor | Teams and workflows |
| [3.9.0](audience/3.x/3.9.0.md) | 2026-08-09 | Minor | A consumer can adopt the source's release config with one command |
| [3.8.0](audience/3.x/3.8.0.md) | 2026-08-08 | Minor | The workflow becomes opt-in, and the product has one changelog |
| [3.7.0](audience/3.x/3.7.0.md) | 2026-08-07 | Minor | The branch files take their designed form |
| [3.6.0](audience/3.x/3.6.0.md) | 2026-08-06 | Minor | The changelog ranks itself by reach and weight, a branch keeps its plan in branch/, and a filled lens survives the teardown |
| [3.5.0](audience/3.x/3.5.0.md) | 2026-08-05 | Minor | The changelog gets three tiers and a release has to earn its bump, and the shared workflow stops assuming it runs in the repo it was written in |
| [3.4.0](audience/3.x/3.4.0.md) | 2026-08-04 | Minor | Every shared script has a page, and the changelog leads with the release instead of archiving them |
| [3.3.0](audience/3.x/3.3.0.md) | 2026-08-04 | Minor | A release now writes for three readers, and a third gate keeps scaffolding out of it |
| [3.2.0](audience/3.x/3.2.0.md) | 2026-08-03 | Minor | One product, one marketplace: renamed and flattened, with the release cut shared and three tiers deep |
| [3.1.2](changelog/3.x/3.1.2.md) | 2026-08-02 | Patch | Round v12 processed: the teardown papers corrected, and the staleness gate reaches into prose |
| [3.1.1](changelog/3.x/3.1.1.md) | 2026-08-02 | Patch | The v11 follow-up: the gates see what they claim to see |
| [3.1.0](changelog/3.x/3.1.0.md) | 2026-08-01 | Minor | Every finding of test rounds v9 and v10, processed — and a gate so a PR closes what it fixes |
| [3.0.9](changelog/3.x/3.0.9.md) | 2026-08-01 | Patch | Round v8: the install record now says what you are actually running — plus the gate for the class behind all three findings |
| [3.0.8](changelog/3.x/3.0.8.md) | 2026-07-31 | Patch | a crafted plugin id can no longer forge a line, and a repo-wide guard keeps every native call site honest |
| [3.0.7](changelog/3.x/3.0.7.md) | 2026-07-31 | Patch | the checks read the install record, and three adoption claims match the measurement |
| [3.0.6](changelog/3.x/3.0.6.md) | 2026-07-31 | Patch | the enable state is read from the whole settings chain, and three claims are corrected to what was measured |
| [3.0.5](changelog/3.x/3.0.5.md) | 2026-07-31 | Patch | what the refresh was measured to do, per command |
| [3.0.4](changelog/3.x/3.0.4.md) | 2026-07-31 | Patch | the checks that reported the wrong answer — and a gate for the class |
| [3.0.3](changelog/3.x/3.0.3.md) | 2026-07-30 | Patch | the second update gate: refresh the marketplace before you update |
| [3.0.2](changelog/3.x/3.0.2.md) | 2026-07-30 | Patch | the adoption and teardown paths, measured against the actual CLI |
| [3.0.1](changelog/3.x/3.0.1.md) | 2026-07-30 | Patch | Patch release |
| [3.0.0](changelog/3.x/3.0.0.md) | 2026-07-30 | Major | Chapter 2 consolidated (v2.2.0 -> v2.16.0) |

### 2.x

| Version | Date | Type | Title |
|---|---|---|---|
| [2.16.0](changelog/2.x/2.16.0.md) | 2026-07-30 | Minor | Adoption is reversible by design, and a gate now says what it checked |
| [2.15.1](changelog/2.x/2.15.1.md) | 2026-07-29 | Patch | Three silent failures made visible |
| [2.15.0](changelog/2.x/2.15.0.md) | 2026-07-29 | Minor | The seam: a consumer's whole specialist surface becomes one directory and one line, and the orchestrator can be delivered by the plugin |
| [2.14.1](changelog/2.x/2.14.1.md) | 2026-07-29 | Patch | Three checks now see what they claimed to cover: the entry scan, the machine records, and the settings proposal |
| [2.14.0](changelog/2.x/2.14.0.md) | 2026-07-29 | Minor | Teardown becomes a real exit: it warns about the runtime dependency and can hand the shared scripts back |
| [2.13.3](changelog/2.x/2.13.3.md) | 2026-07-29 | Patch | Entry heading levels corrected, the round-trip protocol moved into the skill, and the notes parser no longer reads quoted markdown as structure |
| [2.13.2](changelog/2.x/2.13.2.md) | 2026-07-29 | Patch | The teardown-init round trip is honest and idempotent: no false authorship claim, no accumulation, no line-ending drift |
| [2.13.1](changelog/2.x/2.13.1.md) | 2026-07-29 | Patch | The teardown no longer deletes a filled-in scaffold that merely mentions VUL-IN |
| [2.13.0](changelog/2.x/2.13.0.md) | 2026-07-29 | Minor | Adoption becomes reversible: a teardown skill, a fresh consumer told what to do instead of shown 44 errors, and a lighter always-on path |
| [2.12.0](changelog/2.x/2.12.0.md) | 2026-07-29 | Minor | Inventory drift in a repo's own connector entry becomes visible at session start, and the register catches up with reality |
| [2.11.0](changelog/2.x/2.11.0.md) | 2026-07-28 | Minor | Session hooks survive compaction, the consumer is served instead of put to work, and the ignore-list is empty |
| [2.10.0](changelog/2.x/2.10.0.md) | 2026-07-28 | Minor | An unregistered consumer no longer reads as 'no errors', plus the register handover in specialists-init |
| [2.9.0](changelog/2.x/2.9.0.md) | 2026-07-28 | Minor | Two inbound fixes: session checks name the repo a finding is about, and the roster check covers persona-only specialists |
| [2.8.0](changelog/2.x/2.8.0.md) | 2026-07-27 | Minor | Relaxed PR flow and Sylvester permission rules |
| [2.7.3](changelog/2.x/2.7.3.md) | 2026-07-26 | Patch | Follow the ruleset rename in the docs and retire the dated research dossiers |
| [2.7.2](changelog/2.x/2.7.2.md) | 2026-07-26 | Patch | Documentation audit: correct the GitHub Release doctrine, stale enumerations, and the last language gap |
| [2.7.1](changelog/2.x/2.7.1.md) | 2026-07-26 | Patch | Cross-link the new-skill restart rule from the connectors README |
| [2.7.0](changelog/2.x/2.7.0.md) | 2026-07-26 | Minor | Skill-enumeration lint check, plus the corrected cut-release skill claim in the family README |
| [2.6.1](changelog/2.x/2.6.1.md) | 2026-07-26 | Patch | Document that a new skill from an updated plugin needs a session restart |
| [2.6.0](changelog/2.x/2.6.0.md) | 2026-07-26 | Minor | Four inbound fixes from consuming repos: lens paths, changelog heading, roster token boundary, and the shared cut-release checklist |
| [2.5.0](changelog/2.x/2.5.0.md) | 2026-07-24 | Minor | Shared park-branch script + park skill for the branch-workflow layer |
| [2.4.1](changelog/2.x/2.4.1.md) | 2026-07-24 | Patch | Allow cut-release.ps1 in settings.json to bypass the auto-mode classifier |
| [2.4.0](changelog/2.x/2.4.0.md) | 2026-07-24 | Minor | THESIS.md convention for Auden (#30) and the isolated-worktree parallel-PR pattern for Derek (#05) |
| [2.3.0](changelog/2.x/2.3.0.md) | 2026-07-24 | Minor | Auden #30, the academic/long-form content author (resolves inbound #169) |
| [2.2.1](changelog/2.x/2.2.1.md) | 2026-07-24 | Patch | Globalize two shared boundary rules into agent-shared/ (DRY cleanup) |
| [2.2.0](changelog/2.x/2.2.0.md) | 2026-07-24 | Minor | Marlowe #29, the investigative-journalist reviewer, plus a fold-changelog entry-detection fix |
| [2.1.0](changelog/2.x/2.1.0.md) | 2026-07-23 | Minor | Park move + portable post-merge branch cleanup, plus repo-meta and docs housekeeping |
| [2.0.2](changelog/2.x/2.0.2.md) | 2026-07-23 | Patch | Skill invocation hardening, path hygiene, and workflow-lesson docs |
| [2.0.1](changelog/2.x/2.0.1.md) | 2026-07-23 | Patch | Releases-overview grouping and the CI retrigger lesson |
| [2.0.0](changelog/2.x/2.0.0.md) | 2026-07-23 | Major | Chapter 1 consolidated (v1.0 -> v1.18) |

### 1.x

| Version | Date | Type | Title |
|---|---|---|---|
| [1.18.0](changelog/1.x/1.18.0.md) | 2026-07-22 | Minor | Rename-proof lens scaffolds |
| [1.17.0](changelog/1.x/1.17.0.md) | 2026-07-22 | Minor | E-commerce specialist group (Sergio, Craig, Sean) + Sean-to-Sebastian rename |
| [1.16.0](changelog/1.x/1.16.0.md) | 2026-07-22 | Minor | ship-pr one-command flow, category-grouped release output, and the post-review doc consistency pass |
| [1.15.1](changelog/1.x/1.15.1.md) | 2026-07-22 | Patch | Shared Invoke-NativeCapture helper across the release scripts, and a fully-English CHANGELOG and script layer |
| [1.15.0](changelog/1.x/1.15.0.md) | 2026-07-21 | Minor | English script layer, Shopify dev-first, consumer-fit open-pr/fold, and shared release/check helpers |
| [1.14.0](changelog/1.x/1.14.0.md) | 2026-07-21 | Minor | Cross-browser and automation-first shared rules, and a leaner, plugin-independent CLAUDE.md |
| [1.13.0](changelog/1.x/1.13.0.md) | 2026-07-21 | Minor | Consumer release cards, branch-creates-changelog-entry, and English agent-shared block names |
| [1.12.1](changelog/1.x/1.12.1.md) | 2026-07-20 | Patch | Ship the git/gh stderr-under-Stop sweep to consumers (the open-pr + fold shared-script mirrors from #113) |
| [1.12.0](changelog/1.x/1.12.0.md) | 2026-07-20 | Minor | Workshop switched to English (phases A-C) and the roster-sync feature (detect, signal, stage recovery); plus the open-pr push-stderr fix and the shared language-directive block |
| [1.11.0](changelog/1.x/1.11.0.md) | 2026-07-20 | Minor | Quieter session start (only FOUT/DRIFTED signals) and a slimmed-down connectors register without version bookkeeping |
| [1.10.0](changelog/1.x/1.10.0.md) | 2026-07-19 | Minor | RepoName derivation from the git remote, durable body import, and a not-registered signal for unregistered consumers |
| [1.9.2](changelog/1.x/1.9.2.md) | 2026-07-19 | Patch | Documentation: specialists-init SKILL.md aligned with the plugin-path/lens-only model (#88) |
| [1.9.1](changelog/1.x/1.9.1.md) | 2026-07-19 | Patch | Clean-consumer fix: specialists-init scaffolds the script config and open-pr/fold pre-flight (#86) |
| [1.9.0](changelog/1.x/1.9.0.md) | 2026-07-19 | Minor | Shared workflow scripts (SSOT): repo-config, branch-type source, and plugin mirrors for fold + open-pr |
| [1.8.0](changelog/1.x/1.8.0.md) | 2026-07-18 | Minor | Adoption layer: bootstrap seeds the plugin path + lens-only |
| [1.7.0](changelog/1.x/1.7.0.md) | 2026-07-18 | Minor | Ravi + lens migration: repo lenses on the plugin path, personas lens-only |
| [1.6.0](changelog/1.x/1.6.0.md) | 2026-07-18 | Minor | Shared agent-def blocks from a single source (build-and-lint) |
| [1.5.2](changelog/1.x/1.5.2.md) | 2026-07-18 | Patch | Persona index line location-independent (source fix inbound #64) |
| [1.5.1](changelog/1.x/1.5.1.md) | 2026-07-18 | Patch | Lens-only model in the drift check and persona templates; inbound rule in all agent-defs |
| [1.5.0](changelog/1.x/1.5.0.md) | 2026-07-17 | Minor | Consumer-ready: shareable quickstart, drift noise killed, and the first per-plugin CHANGELOGs |
| [1.4.1](changelog/1.x/1.4.1.md) | 2026-07-16 | Patch | Version-sorting fix and scaffold follow-up corrections |
| [1.4.0](changelog/1.x/1.4.0.md) | 2026-07-16 | Minor | Lens scaffolds on adoption and port follow-up corrections |
| [1.3.0](changelog/1.x/1.3.0.md) | 2026-07-16 | Minor | Inbound route and register sync |
| [1.2.0](changelog/1.x/1.2.0.md) | 2026-07-16 | Minor | Connectors register and session check |
| [1.1.1](changelog/1.x/1.1.1.md) | 2026-07-15 | Patch | Security baseline processed: injection guardrail, cleaned-up example paths, and the CI gate |
| [1.1.0](changelog/1.x/1.1.0.md) | 2026-07-15 | Minor | Sean the Security Engineer + the reload-plugins lesson |
| [1.0.0](changelog/1.x/1.0.0.md) | 2026-07-14 | Major | First official release |
