---
name: cut-release
description: >-
  Checklist for the closing steps of cutting a release: the git tag + push, the internal summary and
  the consumer-document edit, then a GitHub Release (body = the highest tier the repo has, every other tier
  as an attachment -- gh's release-notes body has a hard 125,000-character limit), plus branch cleanup.
  Where the repo has a separate "go live" stage (Get-LiveStage in scripts/repo-config.ps1), also the
  push to that live target and moving the "<- LIVE" marker. Where the repo is a marketplace source
  with a business publication target (Get-BusinessMarketplaceRepo), also the separate, deliberate
  publish step (publish-to-business.ps1). Prints ready-to-paste command blocks in
  a fixed order -- a checklist that imposes itself, not automation: no script is run or mirrored.
  Use this once a release has been cut (version bumped, committed) and its closing git/gh steps need
  to be walked through without skipping one. Inbound issue #177.
disable-model-invocation: true
---

# cut-release — the closing-steps checklist for a release

Inbound [issue #177](https://github.com/DaveKJohn/claude-code-specialists/issues/177) (source:
`DaveKJohn/djcylow-react`) asked for `cut-release.ps1` as a shared skill, on the assumption that a
shareable version of it existed. **At the time it did not** — the paragraph below is the finding as it
stood then, and the section under it says what has changed since. The source repo's own
`scripts/release/cut-release.ps1` was 284 lines of marketplace-specific machinery (it reads
`.claude-plugin/marketplace.json` as the source of truth for what a plugin is, bumps every
`plugin.json` in lockstep; it also wrote per-plugin `CHANGELOG.md` sections and `RELEASE.md` cards
until those were retired on August 8, 2026) and dot-sourced `scripts/lib/release-lib.ps1`, which was
not mirrored into the plugin either. Mirroring it as-it-was would have handed a fresh consumer a
script that stops on its very first line (`.claude-plugin/marketplace.json is missing`).

**Both are mirrored now, and the tense above was wrong until August 21, 2026** — reported from a
consumer as the footnote to inbound
[#802](https://github.com/DaveKJohn/claude-code-specialists/issues/802), which read `Get-BumpType` at
`scripts/lib/release-lib.ps1:136` **in its own install cache** while this page said the file was
deliberately absent from it. A page that talks a reader out of looking where the answer is costs more
than one that says nothing.

**This skill is not that mirror.** It is the recommendation that came out of that finding: codify the
*procedure* — the closing steps every release shares, regardless of what cut the version bump itself
— as a checklist, rather than generalizing the workshop's own release script. Matches the issue's own
words: *"not automation, but a checklist that imposes itself."*

## What the skill does

**Two scripts ARE mirrored now** (this line said the opposite until August 3, 2026): `cut-release.ps1`
does the cut itself, and `new-internal-note.ps1` lays down the internal summary's skeleton. What this
page adds is the part no script performs — the GitHub Release, the live push, the branch cleanup, and
the order. Once a release has been cut, walk through the blocks below **in order** and print/paste
each command as you go — do not skip a step or reorder them from memory. The one thing a repo answers
for itself is whether Block 2 runs before or after Block 1; the checklist does not decide that.

### Block 1 — cutting (always)

**0a. Note the time before you start, and note it again when the last asset has landed.** One line, no
tooling — but it has to be *before*, because a baseline cannot be captured afterwards. Put the end-to-end
duration in the release document's organisational section, beside whatever else that release cost.

**THE END POINT IS THE LAST ASSET, NOT THE PUBLISH** (inbound #988, August 27, 2026). This step used to
say *"note it again when the Release is published"*, and step 5 publishes the Release and *then* uploads
the attachments — deliberately, for the reason given below. So the clock this step defined stopped one
action before the release finished, and said nothing about the gap, which meant two people following it
on the same release wrote down two different totals. That is the failure this step exists to prevent: its
whole premise is that the figure was measured rather than estimated, and a figure whose end point is
ambiguous is not measured. Measured on the patch that reported it: the Release published 59s after the
release commit and the last asset landed **5s after the publish**. Small — and that is the point. It is
small there, on one attachment, and nothing said whether it counted.

**AND ON A RELEASE TYPE THAT WRITES NO DOCUMENT, THE REQUIREMENT IS CONDITIONAL — say so rather than
leaving the figure nowhere to go** (same report). Step 4 states that **a patch writes no document at
all**, and `Get-ReleaseConsumerBumps` is what decides which bumps get one. Its shipped fallback is
`@()` — *the tier switched off* — so **in a repo that has never answered that seam, no release type has
an organisational section for this number to land in**, and in a repo that answered it the way this
source does (`('minor','major')`) the patch is the type left without one. Either way the instruction
does not fail loudly; it simply has no object, and the figure evaporates into the closing chat report,
which the paragraph below names as insufficient.

**THIS PARAGRAPH NAMED `('minor','major')` AS THE SHIPPED DEFAULT UNTIL inbound
[#1070](https://github.com/DaveKJohn/claude-code-specialists/issues/1070)**, which is the source repo's
own answer in `repo-config.ps1` rather than the fallback in `cut-release.ps1`. The conclusion survived
the correction and got wider: the sentence was drawing a conditional that, in an unanswered repo, is
not conditional at all. It is worth the correction because this is the page a reader has open **while**
they cut — it told a repo in exactly that shape that its minors and majors already produce a draft. The
repo that reported it had every other half of the arrangement stated (`Get-ReleaseAudienceTier`,
`Get-ReleaseNoteRoot`, the directory, its contributing page) and only this knob absent, so three places
said the document existed while one unanswered seam switched it off. `check-script-contract` printed the
*correct* fallback the whole time — the gate accurate and silent, this page confidently wrong, and
nothing comparing the two.

Two honest answers, and NOT a third:

- **your repo has somewhere durable that a release's cost belongs** — then name that place in your own
  release-answers page and write it there, exactly as you would the document's organisational section.
  This page does not name the file for you: where it goes is a fact about your tree, and a location
  invented here would be wrong in most repos;
- **your repo has nowhere** — then this step is genuinely conditional for a patch and you are not
  holding an instruction with no target. Measure it anyway if it is interesting; nothing requires you to
  file it.

**The generated tier-0 note is NOT that place**, which is the third answer and the tempting one. It is
generated every cut, so hand-written prose inside it is prose the next cut has no reason to preserve.

**THE DOCUMENT CANNOT TIME ITS OWN PUBLICATION, so the instruction is split in two** (measured August 11,
2026, on the first release that followed this step). The release note is frozen for its own commit at
step 4, and the Release is published at step 5 — so at the moment you write the timing section, legs are
still running *on the file you are writing*: its push, whatever CI that push starts, the publish, and
the attachments that land after it.
Asking for the total there asks for a number that does not exist yet, and the failure mode is obvious the
moment it is named: whoever writes it fills the gap with an estimate, in a section whose whole purpose is
that the figure was measured.

So write it in two passes, and expect the second one:

- **at step 4, in the document**: the clock start, the legs you have already measured from timestamps, the
  subtotal to freeze, and which of them blocked a person. This is the half that cannot be recovered later;
- **after step 5, in the document again** — the total, added once the number exists, plus the legs the
  first pass could not see. It is a two-line edit on the same file, and step 4's exception carries it:
  the second pass is part of writing the release notes, not a change of its own.

**AND THE SECOND PASS RE-UPLOADS THE ATTACHMENT IT JUST EDITED**
([#1897](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1897), September 12, 2026). Step 5
uploads the hand-written documents and *then* this pass edits one of them, so the published asset is one
revision behind the tree **by construction** — it permanently lacks the very figure this step exists to
capture. Measured at this repo's `v5.1.0`: the asset was 11,487 bytes against a committed document of
12,275, caught only because somebody happened to be watching the byte count. Nothing reports it — the
release is right on the tree, right on the tag, and wrong on the one page a reader downloads from, which
is precisely where the argument above says a release's cost belongs.

So re-copy the edited document to its unique filename and upload it over the old asset, with the same
script step 5 uses:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/upload-release-asset.ps1" -Tag vX.Y.Z -Path <vX.Y.Z-notes-for-users.md>
```

**Not `gh release upload --clobber`, which this page prescribed until
[#2347](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2347).** At this repo's `v5.7.0`, on
gh 2.101.0, it returned `HTTP 422 ... ReleaseAsset.name already exists` and left the stale asset in place
(15,071 B against a 15,864 B document), and the fallback a reader reaches for next, `gh release
delete-asset`, reported the asset *not found* while the REST API listed it by that exact name. Both look
the asset up by name first. The script reads the asset list from the API, deletes the stale copy **by
id**, uploads without `--clobber`, and exits 1 unless the published asset has the file's exact byte count.
That check is what #1897 lacked: the byte count had been watched by hand.

**Which document that is depends on the flow, and it is not always the consumer one.** The figure goes in
the *organisational* section, so in the merged one-document flow it is the note under
`Get-ReleaseNoteRoot`; in the two-document flow those sections are the ones `new-internal-note.ps1`
writes, so there it is `releases/internal/<dir>/<X.Y.Z>.md` that goes stale and the consumer document
that does not. Upload whichever one this pass actually edited. **The development notes are not exposed**:
the cut generates them at step 1 and nothing between there and step 7 edits them — it is the *editing*
that creates the exposure, not the attaching, so any document a later step edits inherits this paragraph.

**Do not "solve" this by publishing the Release earlier**, which is the first thing that suggests itself. It
would put the publish before the attachments exist, which is what step 5's ordering is for; the tail of a
release is cheap to measure twice and expensive to publish twice. And where a document IS written, do
not settle for the total living only in the closing report you give the requester: a chat message is not
where the next person looks for what a release costs. That clause is deliberate — on a release type that
writes no document, per step 0a's conditional above, the chat report may be the only place there is, and
saying so beats an absolute a reader cannot obey.

**The measured instance:** at `v4.4.0` the frozen subtotal was 9m 42s of a run that came to **28m 03s**, so
the three unmeasurable legs were **two thirds of the release**. A document carrying only the first pass is
not slightly incomplete; it is missing most of the answer. **That figure was measured while the note still
went via a PR**, so a review leg and a merge leg sat in it that step 4 no longer has — expect the tail to
be shorter now, and re-measure rather than reasoning about how much shorter.

**Why this is step zero and not a nice-to-have.** A release is the most-repeated expensive procedure a repo
has, so it is the one whose duration is worth knowing — and it is measured in **minutes**, which nothing
else here records. Measured instance (August 11, 2026): a whole improvement cycle was run against the
question *"why does a release take about thirty minutes"*, it demonstrably improved things, and the result
was reported as **43% fewer words** — because words were what somebody had counted. The release itself was
never timed, before or after, so the question that started the work has no answer in its own unit. That is
the [performance engineer's own rule](https://github.com/DKJ-Solutions/dkj-claude-plugins/blob/main/plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-06-25-manual.md) broken by the
person who wrote it: *report in the unit the question was asked in; a proxy is not the measurement.*

Two things worth splitting while you have the clock running, because they behave differently and a single
total hides both:

- **what blocked you** (the gates you waited on, the writing) versus **what ran behind you** (a CI run on a
  push nobody is waiting for). Shortening the second is worth close to nothing;
- **the fixed cost per release** versus **how often you release**. Where the cost is fixed per event,
  releasing half as often removes exactly as much of it as making it twice as fast — and needs no code.

Deliberately a **convention and not a gate**: it is a number somebody writes down, and a check that refused
a release for a missing timestamp would be ceremony rather than a guard.

0. **A MAJOR ONLY — open its section first, and repoint the pin with it.** Skip this for a minor or a
   patch. Cutting `X.0.0` stops before anything is written, because the new row would otherwise be filed
   neatly under the previous major's table and *nothing would error* — the failure this guardrail
   prevents is silent, not loud. Clearing it takes one edit by hand — and a second if your repo pins
   the major:

   - **the section**: add `#### <X>.x` and its empty table header above the current top section of the
     release overview. The refusal prints the heading to add **at the level your document actually
     uses** — copy what it prints, because that level is repo-owned;
   - **the pin, if your repo has one**: a test that asserts which major the live overview targets goes
     red the moment the section is opened. That is the tripwire working, not a broken test — repoint it
     and write down why, next to the assertion.

   **Nothing here is done for you, deliberately.** Opening a major is a milestone moment, and a pin is
   the same fact written a second time so a half-done edit cannot land quietly. Each commit goes **directly
   on the trunk, ahead of the release commit**, covered by the same request that authorised the cut and
   bounded by it: a major only, the files named above only, and only once the cut has been asked for. Outside
   a cut they are ordinary changes and take the ordinary branch + PR route.

1. **Cut the release.** On a clean main branch:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/cut-release.ps1" -Bump <major|minor|patch> -Title "<one sentence>"
   ```

   **As a consumer, run it from the plugin and not from a repo path.** This page used to print
   `./scripts/release/cut-release.ps1`, which is a real file in the repo the script is *maintained* in
   and nothing at all in the repo you are cutting a release for — a consumer runs the mirrored copy and
   keeps none of its own. So the first command of the checklist failed for exactly the reader this page
   is written for. The `${CLAUDE_PLUGIN_ROOT}` form is what the other shared skills already use, and it
   resolves **only inside a plugin-owned component**: typing this by hand in a terminal means spelling
   out the absolute path to the plugin cache instead. **In the source repo itself, run
   `./scripts/release/cut-release.ps1` — and not the line above.** This page said only that the repo path
   "works as before", which reads as a permission where it is a requirement: that cache holds the last
   *released* mirror, so between releases it lags its own source by however many merges have landed since.
   Cutting a release through it would run the previous release's cut.

   Give it **either** `-Bump` **or** `-Version <X.Y.Z>` when you want to name the number yourself.
   `-SummaryFile` turns it into a milestone (see below). Five escape valves:

   - **`-NoPush` — inspect before publishing, and use it when anything is unusual.** The script otherwise
     commits, tags **and pushes** in one motion. With `-NoPush` it stops after the commit and tag and
     prints the two push commands for you, which is the moment to read the generated notes. That is not
     optional caution: an entry body's stray `##` is read as a change of its own, and this is the only step
     where a human sees the assembled artifact before it is public. **Its closing line names the baseline
     too** (`1.4.0 -> 1.4.1, Patch`) — it did not until August 21, 2026, so the flag whose whole purpose is
     reading a release before it is public was the one path that hid the number every label hangs on
     (inbound [#802](https://github.com/DaveKJohn/claude-code-specialists/issues/802)).
   - **`-Type <major|minor|patch>` — state the bump type instead of letting it be inferred.** Belongs with
     `-Version`; refused alongside `-Bump`, which says the same thing already. **You need it in exactly one
     situation**: a repo whose git tag line and whose recorded release numbering have deliberately
     diverged — tags used for something other than releases, per-component tags in a monorepo, imported
     history. The cut refuses such a release rather than cutting it, because a baseline that belongs to a
     different release mislabels this one in four places at once and in silence: the notes, the overview
     row, the question the tier gate answers, and whether the hand-written consumer document is drafted at
     all. **It is deliberately not a `-Skip` switch** — a bypass would hand back the very label the check
     caught, while stating the type produces a correct release. Reported from a consumer as
     [#802](https://github.com/DaveKJohn/claude-code-specialists/issues/802), where a single stray `v*` tag
     is enough to trigger the same thing with no policy decision by anyone.
   - **`-SkipLint`** skips the integrity gate that otherwise runs first. It exists for a genuinely broken
     gate, not for a hurry — the gate is what stops a release refusing to cut halfway through.
   - **`-SkipTests`** skips the test suites, which run right after the lint and before anything is
     written. **Added August 7, 2026**, because until then the cut ran the lint *alone* — making the
     release the least-checked commit in the workflow, while every ordinary PR passes the lint *and* the
     suites locally and again in CI. A release could be committed, tagged and pushed with a suite red.
     Separate from `-SkipLint` for the same reason those two are separate in `open-pr`: two tools, and
     skipping one is no reason to skip the other.
   - **`-MaxParallel <n>`** sets how many suites that gate runs at once; `0`, the default, leaves the
     resolution where it always was (`ProcessorCount - 2`, floor 2). **This is the one to reach for when
     the gate will not *finish***, and it matters more here than at a PR: the sentence above is the reason
     `-SkipTests` is not an acceptable answer to a gate that dies, because this script commits and tags on
     the main branch. Measured on an 18-core machine, the default's 16 lanes were killed twice for running
     out of memory where `-MaxParallel 4` passed the same 68 suites in 888s against 716s — 24% slower, and
     it finishes ([#1443](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1443)). The rest
     of the numbers are on the
     [`open-pr` skill page](../open-pr/SKILL.md#when-the-test-gate-will-not-finish--maxparallel-not--skiptests).
   - **`-SkipTierGate`** cuts a bump the pending changelog entries have not earned. **Expect not to need
     it.** Where the pending entries declare their impact, **the bump follows the highest tier pending**:

     | highest tier pending | bump | what is written |
     |---|---|---|
     | `0` | patch | the development notes + the generated Release body |
     | `1` | minor | + the hand-written note; in a **tier-1** repo these fill its *What changed* section |
     | `2` | minor | + an audience section in that same note, written for the consumer |

     A major additionally needs enough minors behind the line. So a refusal usually means the bump is
     wrong, not the gate — the script names the bump the work *does* earn; take that instead.

     **The SECTIONS follow the tier; whether there is a document follows the bump.** In a tier-2 repo a
     tier-1-only minor gets the note without a consumer section: the version moves for everyone, but nobody
     outside is handed a section about work they cannot see. Deliberately a separate flag from `-SkipLint`,
     because it overrules a judgement about **content** rather than skipping a tool.

     **Read that row by YOUR repo's audience tier, which is the whole of inbound #747.** The audience
     section draws on the tier `Get-ReleaseAudienceTier` names, so in a tier-1 repo the tier-1 row above is
     the one that fills it. It used to select a fixed tier 2, which in such a repo is a tier no entry can
     ever declare — so the section was absent from every release rather than from an unlucky one, and the
     document that travels outward never said what shipped.
   - **`-SkipSignificanceGate`** cuts even though a pending entry that reaches tier 1 or higher has not said
     **how much it weighs** there. Every tier an entry reaches is a document with its own reader, so every
     one owes its own named section — a reason it matters at that reach, plus a significance from 1 to 5
     against the rubric. The two look the same whichever audience tier the repo answered, the
     second heading being a question rather than a number:

     ```text
     ### DEPLOY: feat/short-name

     The routine version bump stops needing a developer.

     **Score:** 4

     #### What makes this deploy extra special

     Consumers must re-add the marketplace under its new name.

     **Score:** 5
     ```

     That score is what orders the release documents, so an unscored entry cannot be placed. The gate
     **refuses** rather than quietly sorting it last, because demoting a forgotten line is worst in the one
     document whose subject is which change matters most. The fix is an edit in `CHANGELOG.md`, and the
     refusal names every entry and every missing cell. Separate from both flags above: `-SkipLint` skips a
     tool, `-SkipTierGate` overrules whether the release should exist, and this overrules how its contents
     are **ordered**.

   **A refusal here has cost nothing.** All the guardrails run before the first file is written, so a
   rejected cut leaves the tree exactly as it was — no notes file, no version bump, no half-cut release to
   unpick on main.

   **So there is normally no tag command to type.** If you did use `-NoPush`, finish with what the script
   printed:

   ```powershell
   git push origin main; git push origin vX.Y.Z
   ```

2. **ONE hand-written document, with a named section per reader** (Dave, August 10, 2026). Where the repo
   names this bump in `Get-ReleaseConsumerBumps`, `cut-release.ps1` has already drafted the note under
   `Get-ReleaseNoteRoot` — `<note root>/<dir>/<X.Y.Z>.md`, which is `releases/notes/` unless the repo
   repointed it (the source repo uses `releases/audience/`). There is nothing to invoke — the follow-up is
   an **edit**, and it is committed straight onto `main` under the release-notes exception (step 4).

   | section | who it is for | how it arrives |
   |---|---|---|
   | the audience section — *What changed*, at either tier | whoever this repo publishes to | **pre-filled** — the entries at this repo's own audience tier, still in the words their authors wrote for a diff reviewer. Rewrite them against the seven tests below. Absent where no entry reached that tier. |
   | *What it is worth* | the organisation | **empty** — it cannot be generated. Think in time, risk and reduced dependence on a developer. |
   | *What was still open at this release* | the organisation | **empty**. Past tense on purpose: a published document does not move with reality, so a present-tense line goes stale in hours rather than months. |

   **A patch writes no document at all**, and the release is announced by the generated body alone. **A
   minor or major always writes one**, even where nothing reached the audience tier — then it carries the
   organisation's two sections and no audience section, because a named question with nothing under it is
   worse than no question.

   **The first row follows `Get-ReleaseAudienceTier`, not a fixed 2** (inbound #747). A repo asks its entries
   about tier 0 and its own audience tier only, so in a tier-1 repo the tier-2 group is always empty — which
   is why selecting on the literal 2 removed that repo's audience section from every release, not from an
   occasional one.

   **The heading no longer follows it, and that finished the same repair rather than undoing it** (Dave,
   August 21, 2026). The tier-2 default was *For consumers*, which #747 correctly found names the wrong
   reader in a tier-1 repo — and then reading a built page showed it names nothing useful in a tier-2 one
   either: the consumer holding the document does not need to be told it is for them. Both tiers now write
   *What changed*, so the only heading that names a reader is the one below it, which exists precisely to
   mark the half the audience section may not contain. **Notes already published keep the heading they were
   written with**: they are records, and the page renders them as they are.

   **What this replaced, and the measurement that chose it.** There were two hand-written documents — an
   internal note for the organisation and a consumer document — and at every one of the twelve releases
   since the internal tier existed, **both were written, about the same changes**. Before merging them, the
   internal note of one release (962 words) was held against test 2 of the writing norm below (*does this
   describe our effort or their outcome*):

   | | words | |
   |---|---|---|
   | could appear in a consumer-facing section | ~365 (38%) | and **did**, rewritten in a second register in the other document — that is the duplication |
   | could not | ~597 (62%) | including *what it is worth* (316 words), which is not an outlier but the entire reason the organisational tier exists |

   So a **blended** document was refused: it would have to drop the 62% or break the norm. A named section
   per reader keeps each register intact and writes the shared 38% once. The heading *"what is different
   now"* is gone rather than moved — it **was** the duplicated half, and the consumer section is it.

   **`new-internal-note.ps1` is still shipped and still works**, for a repo running the two-document flow —
   an organisational note in `releases/internal/<dir>/<X.Y.Z>.md` beside a separate consumer document.
   Nothing in this checklist calls it any more, and it is documented here rather than dropped because a
   consumer receives a plugin update rather than choosing one: deleting a working entry point is a breaking
   change, and an undocumented one is worse than a retired one.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/new-internal-note.ps1" -Version X.Y.Z
   ```

   `-Force` overwrites an existing note — needed rarely and deliberately, since a note rewritten back to a
   skeleton is a loss you do not want to make by accident. `-RepoRoot <path>` points it at another checkout,
   the same override the fold script carries, for a run from a temporary or detached worktree.

3. **Rewrite the consumer section.** It is markdown only, and it is the release's **tier-2 entries**: the
   ones whose author declared that a consumer notices them.

   **Nothing to delete, and that is the change.** This content used to carry a developer-only block under
   a "remove before publishing" marker, because the generator had to guess from branch types which entries
   a consumer cares about — a guess that fails in both directions (in a storefront repo a `Style` branch
   *is* customer-visible; in a tooling repo a `chore/` branch can carry the most consequential change
   there is). The tier asks the entry's author instead, so the selection arrives already made. Retired
   August 5, 2026, along with the two seam knobs that configured it. The branch administration — the
   title, id, prefix and PR link sections — is stripped as of August 10, 2026, which was a third of the
   draft's lines.

   **It is still a draft, for the reason that never depended on the marker:** the prose is the entry
   bodies, written for whoever reviews the diff.

   **Before rewriting, run the cut's own last-chance check: does any pending entry retire something
   an earlier note announced?** The selection above trusts the author's tier score, and that score is
   wrong exactly once in a predictable way — an entry that removes a convention a consumer was told to
   adopt, scored `N/A` because nothing about the removal itself is visible to an end user, when the
   reader who adopted the convention very much notices its absence (inbound
   [#1061](https://github.com/DaveKJohn/claude-code-specialists/issues/1061)). If a pending entry
   retires something and was scored `N/A`, that score is wrong and the item belongs on this page, not
   off it — fix the entry's tier before drafting rather than working around a page that is missing it.

   **This check stays here rather than joining the seven tests below, and that is deliberate.** The
   seven tests are about *how* an item already on the page is written; this is a *selection* question
   about which items reach the page at all, and selection happens upstream, at the tier question in
   `DEVELOPMENT-portable.md`, not in this rewrite step. The seven were measured against five dev-tool
   changelogs and two declined neighbour rules (below); folding an unrelated check into that list would
   give it a provenance it does not share, and would falsify the count wherever it is cited.

   **Budget for a rewrite rather than a trim.** This document renders the release a *second time*, it does
   not translate it. Turning entries written for someone reviewing a diff into a document for someone
   deciding whether to update is an authoring job. Measured at this repo's v3.2.0, while the draft still
   held every category: 1,098 draft lines became 153, and the heaviest item for a consumer sat at line
   1,034, below the marker, because it arrived on a `chore/` branch. The tier selection removes the second
   half of that problem; the rewrite is still yours.

   **Seven tests, taken from the field rather than from taste** (August 10, 2026). Five dev-tool changelogs
   were read before this list was written — Linear, Stripe, Vercel, Raycast and GitHub — because the failure
   this is written against is not sloppiness but *audience drift*: a maintainer editing the draft keeps
   writing for the reader they have been writing for all week. Hold the finished page against each of these.

   | | the test | what the field does |
   |---|---|---|
   | 1 | **Every item opens with what the reader can now do**, in the second person. | Linear: *"You can now edit text with Linear Agent."* · Vercel: *"Deploy a `Bun.serve()` server to Vercel Functions."* |
   | 2 | **No internal metric or process decision.** The test is not "is it measured" but *does it describe our effort or their outcome*. | Raycast's changelog contains *zero* references to internal decision-making or development metrics. Linear's one internal figure is one the reader can use: *"resolves roughly 30% of incoming bug reports."* |
   | 3 | **Ordered by urgency, action at the top.** If the most useful part is at the bottom, the page is upside down — and telling the reader to scroll is the symptom, not the fix. | React's 19 upgrade guide orders its whole contents by urgency: install → codemods → breaking → deprecations → notable. |
   | 4 | **Say "no action needed" explicitly, or say exactly what the action is.** | Stripe carries a `Breaking change? Yes/No` field on *every* entry rather than leaving it to be inferred. |
   | 5 | **A silent failure gets its visible symptom.** "It fails quietly" is a category; what the reader can check is a fact. | React 19 quotes the actual console message and names who is affected. |
   | 6 | **Short, and link out.** Detail belongs in the document written for the reader who wants it. | Vercel runs 2–4 sentences per entry; Stripe runs a title plus a link. |
   | 7 | **Never link the reader into a tier written for somebody else.** | The industry equivalent is GitHub, which keeps a terse engineering changelog *separate* from its readable announcements rather than pointing one at the other. |

   **Only the seventh is a gate, and that was measured too.** In this family's own repo,
   `check-plugin-integrity.ps1` refuses a consumer document that links into `development/` or `internal/` —
   a rule born with **2 findings, both real**, both of which had been inviting a paying reader into the
   per-PR record. Two neighbouring rules were measured on the same tree and **declined**: "no significance
   score in this document" produced 4 findings, all false, and "no branch name or PR number" produced 3, all
   false — every one of them a release whose subject *was* the entry format, quoting the shape it was
   announcing. The other six tests therefore stay prose that a person applies, because no regex separates an
   illustration from a leak. **If you adopt this list, adopt the measurement with it**: run the seven over
   your own last few consumer documents before deciding which one your repo can afford to automate.

4. **Commit the edited document directly on `main`** (Dave, August 23, 2026). No branch, no PR: this is the
   **third** direct-on-`main` exception, and it exists so that a cut runs in one place from end to end —
   fold the changelog, bump the version, write the release notes.

   ```powershell
   git add <note root>/<dir>/<X.Y.Z>.md
   git commit -m "release: vX.Y.Z release notes"
   git push origin main
   ```

   **Bounded, because an exception is only safe while it stays the size it was granted at.** It covers the
   hand-written release documents **of a cut that was actually asked for**, and nothing else: the note under
   `Get-ReleaseNoteRoot`, plus `releases/internal/<dir>/<X.Y.Z>.md` where a repo still runs the
   two-document flow. Name those paths in the commit so nothing else in the tree rides along. Outside a cut
   there is nothing for the exception to be part of, and a later edit to an already-published note is an
   ordinary change on the ordinary route.

   **This reverses the August 4, 2026 answer, and the argument that answer rested on is the reason the
   bounds above are written out.** The route used to be `new-branch` → `ship-pr`, chosen over the wider
   version — "the release *and* its written notes" — on the grounds that widening an exception is what had
   to be repaired in `ship-pr.ps1` two days earlier. That reasoning still holds; what changed is the
   judgement about which size is right. A release is **one** procedure, and running it across two routes
   left the trunk carrying a tagged release whose own notes were still in review.

   **Two things the change does not touch.** The tag still holds the *draft* — the cut commits and tags in
   one motion, so the written version lands in the commit after the tag either way, and dropping the PR
   moves where the editing happens rather than what `vX.Y.Z` points at. And the gates are not skipped by
   being off a branch — there is a named way to run them from the trunk:

   ```powershell
   # from the repo root, standing on main -- the lint gate, then every suite. Nothing is pushed.
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/open-pr.ps1" -GatesOnly -NoteTreeOnly
   ```

   **In the source repo, run its own copy instead** — `scripts/release/open-pr.ps1 -GatesOnly -NoteTreeOnly` —
   for the reason given at the top of this page.

   **`-NoteTreeOnly` is what stops this step paying for the suites twice**
   ([#2102](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2102), September 18, 2026). It asks
   whether every path that differs from `HEAD` sits inside the note tree this exception already bounds the
   commit to — the two paths the **Bounded** paragraph above names — and only where that is **proven** does
   it skip the test gate. The lint gate runs either way. On the `v5.5.0` cut this step cost **325s**, over
   one hand-written markdown file; it is one of the two gate runs that together are 652s of that 1,166s
   release, **56%** of it spent on the same 114 suites twice. The lint half it leaves standing measured
   **27s** in the source repo — that cut never split its own 325s, so the figure comes from there rather
   than from the cut.

   **What makes the skip a deduction rather than a favour** is that the suites have no coverage of that tree
   to lose. The whole release tree was moved aside and all 114 suites run: four went red, one on an
   *existence* assert over a path list (which a cut, adding notes, only satisfies more firmly) and three
   because they run the lint script over the live repo as a smoke assert. So the suites' entire coverage of a
   release note **is** the lint gate — which this step is running anyway, in the same invocation.

   **Add nothing else to the commit and this holds by construction.** The switch refuses on one stray path,
   on a clean tree, on an unreadable `git`, and on a rename that drags a note out of the tree — it prints
   which, and runs every suite. So a step that widens past its own bound gets the full gate back
   automatically rather than quietly keeping the saving. Drop `-NoteTreeOnly` and this step is exactly what
   it was before; the fallback and the un-flagged run are the same run.

   **This line replaced *"exactly as `open-pr` would have run them for you"* on August 30, 2026
   ([#1156](https://github.com/DaveKJohn/claude-code-specialists/issues/1156)), and the old sentence was
   right about the rule and wrong about the route.** `open-pr` refuses on `main` several hundred lines
   before it reaches a gate, so at this exact point in the cut it could not be run at all — and what a
   reader does with an unreachable instruction is rebuild it. The invented invocation is the actual
   hazard, because it goes green while missing things: `Get-TestCommands` is not in scope, so a repo
   whose suites are not all PowerShell has the rest of them skipped **without a word**, and the lint half
   gets a hardcoded script instead of the repo's own `Get-LintScript`. `-GatesOnly` runs the same
   function the PR path runs, through the same seams, so the answer here is the answer the PR would have
   given. It is not an escape valve: it adds a place the gates can run and removes none.

5. **Publish the GitHub Release — still after step 4, and the reason has changed.** The body no longer
   comes from step 4, so publishing early would no longer publish a body that does not exist. What it
   *would* do is publish a page whose attachments are missing the hand-written documents, and whose pointer
   line names notes nobody can download yet. One publish with everything attached beats a page corrected
   minutes later. Which bumps get a Release is **repo policy** — see the release manager's repo lens; some
   repos publish at every release, others at Minor/Major only.

   **Do not stop to ask permission here.** Cutting the release is what was asked for, and this is the last
   step of that same procedure — a second approval at the end of a checklist the requester started is a
   rubber stamp (Dave, August 5, 2026). Steps 1 to 5 therefore run in one motion. The approvals that
   remain are **Block 2 below**, where a repo has a live stage, and **Block 3**, where the repo is a
   marketplace source: publishing a document that describes a version, pushing to a target customers
   see, and overwriting the marketplace colleagues receive are three different acts.

   ```powershell
   # the --notes-file is the generated body; cut-release.ps1 printed this exact line for you
   gh release create vX.Y.Z --title "Release Version vX.Y.Z" --notes-file releases/github/<dir>/vX.Y.Z.md
   # copy each attachment to a UNIQUE filename first -- see the collision note below -- then attach
   # each one; the script verifies the published byte count against the file (#2347)
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/upload-release-asset.ps1" -Tag vX.Y.Z -Path <vX.Y.Z-development-notes.md>
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/release/upload-release-asset.ps1" -Tag vX.Y.Z -Path <vX.Y.Z-notes-for-users.md>
   ```

   `-Repo owner/name` pins the tracker where `scripts/repo-config.ps1` has no `Get-RepoName`; without
   either, `gh` resolves it from the checkout.

   **The name is `Release Version vX.Y.Z` and nothing else** (Dave, September 21, 2026). This printed a
   `<short title>` placeholder, so the release was named after whatever sentence the person cutting it
   composed at that moment — an authoring decision taken at the most expensive step of the procedure, by
   whoever happened to be there, with nothing able to check the result. Deriving the name from the tag
   removes the decision rather than standardising it.

   **The short description is NOT removed, and this is the distinction to hold on to.** It keeps its own
   row: the first line of the generated body, and the last column of the release overview — which is
   where `-Title` goes and always went (its own help has read *"short description of the release as a
   whole"* throughout). So none of the release documents change; the sentence simply stopped being
   printed into `--title` as well. A release with a genuinely useful sentence still carries it, one line
   below its name.

   **Two attachments cannot share a filename, and all three tiers name their file `<X.Y.Z>.md`** — so
   uploading two of them straight from `releases/` fails. Measured at this repo's `v3.3.0`: the first
   upload succeeded and the second returned `HTTP 404` on
   `assets?label=…&name=3.3.0.md`. The asset name is the **basename**, and `gh`'s `file#label` syntax does
   not help — it sets the *label* and leaves `name` as the basename, which is why the request above still
   carried the colliding name. **Copy each attachment to a distinct filename and upload the copies**
   (`vX.Y.Z-development-notes.md`, `vX.Y.Z-notes-for-users.md`). That is worth doing on its own merits: a
   reader downloading `3.3.0.md` cannot tell which of the three tiers they got.

   **The generated body carries that basename too, and stays out of the collision anyway** — it is handed to
   `--notes-file` by path and never uploaded, so it cannot be the second asset that 404s. What it does add is
   one more `<X.Y.Z>.md` in the tree: reach for these files by their full path, never by basename.

   **The body is GENERATED and every hand-written document is an attachment** (Dave, August 10, 2026).
   `cut-release.ps1` has written `releases/github/<dir>/<X.Y.Z>.md`: the release title, a
   pointer at the attached notes where one is expected, and one linked line per change that landed —
   **every tier**, because "what landed" is not a tier question. Nothing to edit; point `gh` at it.

   **Why generated, because the previous answer was a coupling rather than a choice.** The body used to be
   the highest hand-written tier the repo had, which made the Release page depend on which tier happened to
   exist — and that is the reasoning that made an internal note *mandatory at every release, patch
   included*: it was the only tier written every time, so it was the only one that could be the body under
   a no-exceptions rule. A generated body cuts that dependency. A release with no hand-written document at
   all still gets a page, and the documents become attachments instead of being the page.

   **It must be generated by the cut, not at this step.** The cut empties `CHANGELOG.md`, so the entries the
   list is built from are gone by the time you get here.

   **Never inline the development notes.** `gh release create`'s notes body has a hard limit of **125,000
   characters**; at life-hub's v2.1.0 the development notes were **134,419 characters** and the "paste
   everything into the body" approach returned an HTTP 422 from `gh`. The generated body cannot hit that
   limit — it is a title and a list — which is a second reason it is the safer body.

   Attach whatever hand-written documents this release produced, plus the development notes.

6. **Name the cache refresh in the closing report — pushing the tag is not the end of a release.** A
   `github` marketplace source is a **cached clone**, and `plugin install` compares against *that*, not
   against the repo you just tagged. So the safe closing line for a consumer is one idempotent command
   before they update:

   ```powershell
   claude plugin marketplace update <marketplace>
   ```

   **State it as two measurements rather than one rule, because the obvious generalisation was tested and
   broke.** They are not the same for `install` and `update`:

   | command | refreshes the cached clone? | how it was measured |
   |---|---|---|
   | `plugin install` | **no** | a controlled pair, same machine, same minute, two fresh folders: without the refresh the install produced the **previous** release and left the clone where it was; with it, the new one. Confirmed on two separate releases. |
   | `plugin update` | **yes** | with the clone verifiably still on the pre-release commit and not even containing the new version, a bare update moved to the new version **and advanced the clone during the run**. |

   So the earlier, tidier claim — "skip the refresh and you get the previous version" — holds for
   `install` and is **false** for `update`. Report the refresh as the *safe first step*, not as a
   mechanism claim about what breaks without it.

   **Why it has to be said out loud at all: a stale cache is invisible by construction.** It reports
   success with a plausible version number, and an install's success line names the scope and **no
   version at all** — so a consumer cannot detect staleness from the output even in principle, only from
   the install record. This is the one thing a release cannot do for its consumers, which is exactly why
   the closing report must name it.

   **A practical note for whoever cuts the next release:** the stale window a release opens lasts only
   until something refreshes it. If a question about cache behaviour is open, the minutes after the tag is
   pushed are when it can be answered; an hour later the cache has moved on and the answer waits for the
   next release.

7. **Branch cleanup** — the same fixed closing move as the `fold-changelog` skill's:

   ```powershell
   git fetch --prune
   git branch -d <merged-branch-name>
   ```

### Block 2 — going live (only where this repo has a live stage)

This block is driven by `Get-LiveStage` in the consumer's `scripts\repo-config.ps1` — **optional**,
**empty by default**. Most repos (this workshop, life-hub) cut a release without a separate live
stage, so `Get-LiveStage` returns `''` and Block 2 does not apply — stop after Block 1.

A repo that *does* have one (e.g. a repo that pushes a live deploy target as a step distinct from
tagging) fills in `Get-LiveStage` with a short description of that target. Where it is filled in:

1. **Push to the live target** described by `Get-LiveStage`.
2. **Mark which recorded version is the one actually live**, wherever this repo records that, so its
   releases overview shows it at a glance. `cut-release.ps1` briefly did this itself, via a
   `Get-ReleaseLiveMarker` seam that moved a marker from the previous release heading onto the new one; that
   seam **retired on August 5, 2026** together with the `CHANGELOG.md` release block it wrote into — a cut
   now empties the changelog and writes no release heading for a marker to sit on. So this is a hand step
   again, which is where it started: the marker is the one release artefact whose correctness a script cannot
   confirm, because only the person who did the push knows it succeeded.

#### Which comes first, the cut or the push — the repo answers this, not the checklist

**Block 1 before Block 2 is the DEFAULT, not a rule** (inbound
[#1378](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1378), September 4, 2026, from
`BWJ-ecommerce/smartwatchbanden`). This page stated it as one for as long as it had a live stage to
describe, and a repo that ran the reverse read as drift. It was not drift, and the question turns on a
single property of the target:

- **A push that cannot meaningfully fail** — it either runs or errors loudly, and nobody else writes to
  the target → **cut, then push.** The audience document exists before anything reaches a customer, so it
  can be reviewed first, and the checklist reads top to bottom.
- **A push that can fail or be partial** — a target with no locking, third parties editing it while you
  work, a drift check that legitimately refuses, a per-file rather than wholesale push → **push, then
  cut**, and the cut becomes the documented closing act of the push.

**What the second order buys is an invariant, and it is worth naming because the first order gives it
up silently.** Cut first and a failed push leaves a **stranded release**: the tag, the GitHub Release
and the audience document all exist, permanently, describing a state no customer ever saw. Nothing
detects that — every artefact is well-formed, and the only witness is the person who watched the push
refuse. Cut afterwards and it cannot arise, because the release records what shipped rather than what
was intended to.

**The `← LIVE` marker in step 2 is the sharpest way to see the difference**, and its own reasoning is
the argument: *only the person who did the push knows it succeeded.* Under push-then-cut that person is
the one cutting, so the marker is correct at the moment it is written. Under cut-then-push the marker is
**wrong by construction** from the moment the cut lands until a human moves it — which is a hand step
this page can ask for but not enforce. Measured in the repo that filed #1378: its marker sat two
releases behind, on a version cut four weeks earlier.

**No seam, deliberately.** `Get-LiveStageCutOrder` was the obvious shape and would have cost a script
contract record, a blueprint entry and asserts to carry a value **no script reads** — the order is a
sentence a person walks past in a checklist, where `Get-LiveStage` gates whether the block prints at
all. The condition above is answerable from the description already in `Get-LiveStage`, and a repo
running the non-default order states it in its own `CLAUDE.md`, where the standing rule that a
live push authorises its own closing cut has to live anyway. Revisit if a second live-stage consumer
ever wants the checklist to render in its order rather than say which orders exist.

**This instruction is the measured instance of `CONTRIBUTING-portable.md`'s fourth move, not an
exception to its corollary against restating shared law.** That page's ranking section polices copies
of a law the plugin states somewhere; this block deliberately states none, and asks the consumer's own
`CLAUDE.md` to carry the only answer that will ever exist. See that page's "A fourth move exists"
paragraph (inbound #1388) if the two ever read as disagreeing again.

**This is not new to the tree, which is what settled it.** `dkj-subagents-shopify`'s webshop-manager manual
already documented push-then-cut for exactly this case — *"only when the user decides to push; the
release is then cut by the release manager"* — so the two pages shipped from one repo contradicting each
other, and #1378 found it from the outside.

### Block 3 — publishing the marketplace to the business organisation (only where this repo is a marketplace source)

This block is driven by two facts rather than a preference: the repo carries
`scripts/release/publish-to-business.ps1`, and `Get-BusinessMarketplaceRepo` in its
`scripts\repo-config.ps1` names a target — the same optional-function-with-a-fallback shape as
`Get-LiveStage`, with `-TargetRepo` on the script as the override for a second organisation. Most repos
have neither — a consumer of the plugins is not a marketplace source — and for them this block does not
exist: stop after Block 1, or after Block 2 where there is a live stage.

Where both facts hold (the source repo publishes its marketplace subset to a private business repo that
Claude Enterprise syncs, so colleagues without GitHub access receive the plugins):

1. **Publishing is a separate, deliberate decision — releasing without publishing is a normal outcome,
   not a half-finished one** (Dave, August 14, 2026). The cut records a version; the publication changes
   what colleagues receive. So this block never runs as part of Block 1's one motion: it runs only when
   the owner asks for it — the same boundary Block 2 draws for a live stage.
2. **Publish after the cut, from a clean `main`.** The script warns on a dirty tree and publishes the
   working copy as-is, so the normal moment is right after a release: the version bumps are on `main`,
   and the target's history then reads as a release log — the commit message records the source commit
   and every plugin version it carried.
3. Run with `-DryRun` first after any change to the published set, then for real:

   ```powershell
   ./scripts/release/publish-to-business.ps1 -DryRun
   ./scripts/release/publish-to-business.ps1
   ```

4. **The target is a publication target, not a second workshop.** Every run empties it (except `.git`)
   and rebuilds it from the published set, so a plugin removed in the source disappears there too — and
   anything committed there by hand is lost on the next run, by design. The `version` in each
   `plugin.json` is the update signal: Claude only hands colleagues a new plugin version when that
   number goes up, which is why the bump belongs to the release and the script never touches versions.
5. **Not every plugin has to travel, and the question to ask is whether the target's users have a
   repository at all** (August 15, 2026, issue #683). `Get-BusinessMarketplacePlugins` names the subset
   that publishes; `-Plugins a,b` overrides it, and an absent or empty answer publishes everything —
   which is what this script did before the seam existed, so a repo that has never heard of it is
   unaffected. The source repo's own answer is instructive: its target serves **Claude App** users, who
   have no checkout, and a *workflow* plugin is a method for moving work through a repository — every
   one of its skills ends in a script run against one. Offering it there offers something that can only
   fail at its last step, so both workflows are excluded and the four teams travel.

   Three things about that, in case the same question comes round in another repo:

   - **Exclusion, not a hide flag.** The manifest format has no per-entry way to gate an entry, and
     inventing one would need Claude to honour it. A plugin that did not travel cannot be offered.
   - **The unit is the plugin, deliberately.** Individual items inside a travelling plugin may still be
     unusable at the target — the published plugin has to stay byte-identical to the released one, or
     its version number stops meaning one thing. Handle those where they live: a skill that needs a
     shell should be non-model-invocable and should name that dependency in its own description.
   - **The keep-list is checked three ways**, because each failure is silent on its own: a name the
     manifest does not have is refused (it would otherwise exclude the plugin it meant to keep), a list
     that keeps nothing is refused, and a plugin folder that travels while the rebuilt manifest never
     names it is refused — that last one produces no error anywhere, it just means Claude never offers
     the plugin while the manifest reads as complete.

## A milestone release — `-SummaryFile`

An ordinary release's notes are the diff since the last one: `-Title` gives it one descriptive sentence
and the entries carry the detail — and where a release rolls up too many unrelated changes for one
sentence to fit, **omit `-Title` altogether** rather than writing filler. The description row then reads
`<Type> release`, the entries and the attached notes carry everything regardless, and the release's
**name** is unaffected either way, being `Release Version vX.Y.Z` in every case since September 21, 2026.
A **milestone** is a different claim — the
arc across many releases, which fits in neither. `-SummaryFile <path>` puts an authored markdown block
between the title line and the generated entries, closed off with a horizontal rule so a reader can see
where the authored part stops and the per-PR record begins. Three things to know:

- **The file may live outside the repo, and normally should.** Its canonical home becomes the generated
  notes file; a second copy kept under `releases/` purely to feed the parameter is duplication.
- **A missing or empty file is a hard stop.** An empty one would otherwise produce an ordinary release
  while you believe you cut a milestone.
- **Links in the summary are left exactly as authored.** Unlike an entry — written in the root changelog
  and then moved several folders deeper, so its relative links are rewritten — a summary is written *for*
  the notes file. Rewriting its links would break the ones that were already right.

**And say plainly whether anything breaks.** A `major` bump reads as "breaking" to anyone applying semver
mechanically, and a milestone may well break nothing — a large change can be backward compatible by
construction. If nothing breaks, the summary's opening lines have to say so, or a consumer sits on an old
version waiting for a migration that does not exist.

## When something a consumer builds on disappears, the release has to say so

**The paragraph above is about a milestone; this is about any cut, and it is a convention rather than a
gate.** Three things a consumer can build on directly are not covered by "the entries carry the detail",
because a consumer reads the notes to learn what changed *for them* and an entry describes what changed *in
here*:

- a **shared script** that is removed or renamed (they resolve it by path through the seam);
- a **script-contract function** that leaves the contract (they may still define it, with a test around it,
  and nothing will tell them it is dead);
- a **written convention** the scripts read — a file name, a directory, a document shape.

For each one the release document names it, says what to call or write instead, and states what the
difference is. One line each is enough; the cost of leaving it out is not.

**Measured, three times in one day** (2026-08-09, inbound
[#556](https://github.com/DaveKJohn/claude-code-specialists/issues/556),
[#557](https://github.com/DaveKJohn/claude-code-specialists/issues/557) and
[#561](https://github.com/DaveKJohn/claude-code-specialists/issues/561)). `v4.0.0` removed
`new-changelog-entry.ps1`, moved the changelog entry from the repo root into `branch/`, and dropped
`Get-ChangelogHeading` from the contract. All three were improvements; none was named as breaking. What the
consumer got instead: a script lookup that threw while they were picking up a Dependabot PR, a CI gate that
failed *after* the work was done, and a seam function still sitting in their repo with a test around it and
nothing reading it. **Two of those three fail loudly, which was not the problem** — the problem was that the
moment of discovery was chosen by the release rather than by them.

**Why this is a convention and not a refusal.** A gate would have to recognise "names a migration" in prose,
which is exactly the kind of matcher this project has been bitten by — one satisfied by a mention rather than
a use. What the model *does* already give you is the place to put it: significance band 5 is *the reader must
act — a breaking change or a required migration*, so an entry that scores a 5 for tier 2 is the entry that
owes this text. Write it there, and the cut carries it outward for you.

## Requirements in the consumer

- `scripts\repo-config.ps1` with, optionally, `Get-LiveStage` — same shape as the existing `Get-LintScript`
  getter. Absent or empty: only Block 1 applies. Declared in
  `script-contract-lib.ps1` as an **Optional** record (the mechanism introduced for
  `Get-ChangelogHeading`, issue #178): a consumer without the function gets `[INFO]` naming the
  fallback (`''`, i.e. no live stage), never `[ERROR]`.
- The script's own getters are separate from this skill's and all optional in the same way:
  `Get-ReservedRootMd`, `Get-ReleaseNotesGrouping`, `Get-ReleaseHistoryPath`, `Get-ReleasePluginTier`,
  `Get-ReleaseConsumerBumps`, `Get-ReleaseNoteRoot`, `Get-ReleaseAudienceTier` and
  `Get-ReleaseMajorMinMinors`. Define none of them and
  the cut behaves exactly as it does in the source repo. Run `check-script-contract.ps1` to see which ones
  this repo answers and which fall back.
- **`Get-ReleaseAudienceTier` says WHICH audience this repo publishes to, and it is a decision taken once,
  before any entry is written** (August 12, 2026). Tier 1 and tier 2 are two **kinds** of reader rather than
  two rungs of a ladder: `1` is management and the employer/commissioner — the audience of a repo that
  *delivers* work, or that sells a **product** whose buyers never read a release note — and `2` is the
  subscriber of a **service**, who decides whether to upgrade. A repo answers one of them. `new-branch` then
  scaffolds tier 0 plus that tier alone, and the gates ask for that tier rather than every rung from 1 up.
  **Define nothing and every tier is asked about**, exactly as before the knob existed — an unstated seam
  means unchanged, never "the audience tier switched off". The tier your repo does not ask about is still
  **read** wherever an older entry carries one, so nothing already folded stops parsing, and an extra
  answered tier is accepted rather than refused.
- **`Get-ReleaseNoteRoot` is the one to check before you answer `Get-ReleaseConsumerBumps`**, and it was
  added because without it that second knob was unanswerable (inbound #616). The bumps knob says *whether*
  the hand-written note is written; this one says *where*. If your notes already live somewhere other than
  `releases/notes/`, naming the bumps without repointing the root sends the cut at a directory you do not
  have and leaves the one you do have out of the release — so the only safe answer was `@()`, the tier
  switched off, which is not an answer to the question the knob asks. Repoint the root, then name the bumps.
  **The default is still `releases/notes/` even though the source repo now answers `releases/audience/`**,
  and that is deliberate: an unstated seam has to keep meaning what it meant yesterday, so a repo that never
  answered this knob is not silently pointed at a directory it does not have. Consider matching the source's
  rename if it suits you — every one of its note roots now names its **reader** or its content
  (`changelog/`, `audience/`, `github/`) rather than the form of the document — but nothing requires it.
  The per-release folder *inside* it stays `Get-ReleaseNotesGrouping`'s answer, so this is the root alone,
  with no trailing slash. The tier-0 tree had no equivalent knob until #885 measured one into existence
  (`Get-ReleaseChangelogNotesRoot`, named `Get-ReleaseDevelopmentNotesRoot` until #947), and #914 then moved
  and renamed the directory it points at — while THIS seam's fallback deliberately stayed put, being the one
  consumers already answer or rely on.
- **Six seams retired on August 5, 2026, and a consumer that still defines one is unaffected** — nothing
  calls them, so they are simply dead code in that repo's config. `Get-ChangelogTierHeadings` and the legacy
  `Get-ChangelogHeading` (#178) configured changelog section headings, and the document has none;
  `Get-ReleaseCategoryTitles` labelled the release-notes categories, and the grouping is gone;
  `Get-ReleaseLiveMarker`, `Get-ReleaseHistoryMode` and `Get-ChangelogReleaseWording` (#462) all described
  the release **block** a cut used to append to `CHANGELOG.md`, and a cut writes none. The capability behind
  that last one is not being taken away from the non-English repo that asked for it: what replaced the
  generated block is the changelog intro's own one-line pointer to the release history — hand-written prose
  in a file the repo owns outright, so it needs no seam to be in their language.
- **`Get-LintScript` is the one that is NOT optional, and the cut now reads it.** The release route does not
  travel via a PR, so this is the only gate it meets; before August 5, 2026 the cut looked for the *source*
  repo's lint script by a fixed path and skipped the gate with a warning wherever it did not find one
  (inbound #464). A named gate that is not on disk is now a hard stop — use `-SkipLint` to cut without one,
  so the choice is in the command.
- **What switches the bump gate on is the entries, not a setting.** `cut-release.ps1` starts requiring the
  bump to be earned (see `-SkipTierGate` in step 1) as soon as **any** pending entry has declared its impact
  — an impact table, or the older `Tier: N` line. A repo whose entries declare nothing has no tier
  information to judge, so the gate reports itself inactive and the cut behaves exactly as it always did.
  That test used to be "does this repo declare more than one changelog section", which stopped working the
  day the sections went: a flat document gives an adopting repo and an unadopted one one group each, so the
  old test would have read every repo as unadopted and switched the gate off in silence. Counting
  declarations keeps *"declared tier 0"* distinct from *"declared nothing"*, which is the whole difference
  between a release that announces nothing on purpose — a patch — and a repo that never chose the model.
- `git` and a logged-in `gh` CLI for the GitHub Release step. **Which bumps get a Release is repo
  policy, not part of this checklist** — it is stated in the release manager's repo lens, because a repo
  that publishes at every release and one that publishes at Minor/Major only are both coherent, and the
  choice follows from who reads the page rather than from the mechanics.
- **`Get-BusinessMarketplaceRepo` and `Get-BusinessMarketplacePlugins` (Block 3) are deliberately NOT in
  the script contract.**
  `publish-to-business.ps1` is not mirrored into the plugin — it is the marketplace source's own tool,
  like the blueprint generator — so `check-script-contract.ps1` never asks a consumer about it, and a
  consumer defining the function would be answering a question no script of theirs reads. It lives in
  the source repo's `scripts\repo-config.ps1` because that is where repo data goes, not because the
  contract requires it.

## Important

- **The script IS mirrored now** (issue #417, August 3, 2026). This page used to say the opposite —
  "no script mirrored, deliberately", because the lockstep `plugin.json` bump is meaningless in a
  consumer. That turned out not to require a fork, only a seam function: a repo with no marketplace
  manifest skips that half. So `cut-release.ps1` travels with the plugin like the rest of the workflow,
  and what differs per repo is read from optional getters in the consumer's `scripts\repo-config.ps1`.
  This page remains the *procedure* around the script — the parts no script performs: the GitHub
  Release, the live push, the branch cleanup.
- **Order matters INSIDE a block, and between blocks it is nearly fixed.** Block 1's steps are walked
  top to bottom. Block 3 comes after Block 1, only where the repo is a marketplace source — and only
  when its publication is itself asked for. **Block 2 is the one exception**: it normally follows
  Block 1, but a live stage whose push can fail or be partial runs it *first* and makes the cut the
  closing act of the push — see
  [Which comes first, the cut or the push](#which-comes-first-the-cut-or-the-push--the-repo-answers-this-not-the-checklist)
  for the condition and the stranded-release failure mode the default gives up.
- **And inside Block 1 the GitHub Release is last, which was a correction and has now outlived its
  original reason** (August 4, 2026; revisited August 10, 2026). It used to be step 2, directly after the
  tag, because its body was a file `cut-release.ps1` had already generated. When the body became the
  internal note — a document step 2 only *starts* and step 4 lands — publishing from step 2 would have
  published a body that did not exist yet, and a checklist meant to impose itself has to be walkable in
  order. The body is generated again now, so that particular impossibility is gone; the step stays last
  because the **attachments** are what step 4 produces. Worth keeping in this form rather than rewritten:
  a step whose reason has been replaced is a step somebody will try to move back.
- **A release itself is cut only at explicit request** (a version bump is never automatic) — that
  governance rule is unchanged and sits upstream of this skill, not inside it.
