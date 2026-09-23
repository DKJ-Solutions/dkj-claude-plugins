# Releases — the portable half

**How a release works.** A release is not a deploy but a **recorded moment**: a git tag that marks the
state of the repo at that version. This page carries the **process** — the tier model, what a release must
earn, the release documents, and how one is cut — for every repo that runs this release workflow, naming
the *seam* wherever a repo owns the answer. **Where a repo's own answers to it go is that repo's business,
and there is one place this page does not want them**: a prose page of its own, beside this one. The source
repo kept such a page until September 20, 2026 and retired it — a per-repo RELEASES beside the portable one
makes *"there is only one RELEASES"* false in the repo that ships the sentence, which is the same case that
retired the workflow folder's `README.md` and `CONTRIBUTING.md` that day. Its answers went into the lens of
the specialist who owns each one, where the rest of its repo-specific answers already lived. **The full
list of releases is separate from all of that** — the one such list there is, on the page
`Get-ReleaseHistoryPath` names, which is a file a script appends to rather than a page anybody writes.

[`scripts/release/cut-release.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/release/cut-release.ps1)
itself publishes nothing to GitHub Releases — that is a separate, manual closing step. Releases are cut
**only on the repo owner's explicit request**; see [Cutting a release](#cutting-a-release) below for the
full mechanics. Where the repo publishes plugins — `Get-ReleasePluginTier` answers that, and it gates the
whole plugin half — each release bumps every plugin's `version` in lockstep, and that number in
`.claude-plugin/plugin.json` is what tells a consumer which release they are on. Where it does not, the
current version is read from the newest `vX.Y.Z` tag instead, exactly as the script already does.

**How to read this page.** It travels with the plugin, so two conventions keep it true in every tree it
lands in. *This repo* always names the **source repo** the page was written in
([claude-code-specialists](https://github.com/DKJ-Solutions/claude-code-specialists)) — its measurements travel
as the evidence behind the rules, never as your repo's own record. And links into the source's script tree
are **absolute** on purpose, so they resolve from wherever this page is read; files every adopting repo has
of its own (`scripts/repo-config.ps1`, `CHANGELOG.md`, `releases/history.md`) are named in code rather than
linked, because the copy that matters is yours.

## The tier model

**One scale, used twice.** A change declares how far it reaches, and that number decides two things: which
document — and, where the document has more than one reader, which section of it — the change appears in,
and, together with its significance score, where within that section it sits.

| tier | who notices | where it is written | when |
|---|---|---|---|
| **2** | subscribers of the service | the *For consumers* section of `audience/<dir>/<X.Y.Z>.md` | minor/major |
| **1** | management and the employer/commissioner | the *What changed* section of that same file | minor/major |
| **0** | only this repo's own developers | `changelog/<dir>/<X.Y.Z>.md` | every release |

**Tiers 1 and 2 are two KINDS of audience, and this repo has exactly one of them** (Dave, August 12, 2026;
inbound [#620](https://github.com/DaveKJohn/claude-code-specialists/issues/620)). They are not two rungs of a
ladder. Tier 1 is management and whoever commissions or pays for the work — the audience of a repo that
*delivers* something, or that sells a **product** whose buyers never read a release note. Tier 2 is the
subscriber of a **service**, who decides whether to upgrade. A repo answers one of them, once, in
`Get-ReleaseAudienceTier`, before any entry is written; **this repo answers 2**, being a service rather than
a product. `new-branch.ps1` then scaffolds tier 0 plus that tier alone, and `open-pr.ps1` and
`cut-release.ps1` ask for that tier rather than every rung from 1 up.

**And the service is YOUR OWN: the tier-2 reader is whoever takes what this repo ships, never whoever
they sell to in turn** ([#1896](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1896),
September 12, 2026). *Subscriber of a service* names a **role**, not a party, so in a repo whose
subscribers are themselves businesses the phrase reads two ways — and the wrong reading is the more
vivid one, because that party is a real customer somebody in the room can picture. A plugin two webshops
run reaches **their developers**, and it is those developers who decide whether to upgrade. The shops'
own customers are one hop further out: they subscribe to the shop, not to this repo, and nothing this
repo releases is ever addressed to them. So the test is **one hop and no further** — name the party that
runs the upgrade, and score against them. The rule is written for a plugin because that is where it was
measured, and it holds for any repo whose output is consumed by another repo.

**Measured on the release that produced the question, and the error is a reader swapped mid-sentence.**
Two `v5.1.0` entries about issue labels in the same two store repos scored the same tier-2 question `N/A`
and `4`. The `N/A` one named the right reader in its own first clause — *"this workflow's consumers are
the BWJ store repos"* — and then justified the score with *"no customer of either store ever sees one"*,
which is a different reader entirely. That cost a **required migration**, two `gh label edit` commands per
store, its place on the audience note; a person carried it onto the page by hand at the rewrite step, which
is the model failing and being covered for rather than working. **The reading is older than that release**:
`docs/1537` and `fix/1536` in `v4.32.0` score `N/A` in the same shape, each naming in the very sentence the
consumers who *do* receive the change. Those three are left as written — the release record is historical —
so this paragraph is the only repair.

**A repo that has stated nothing is asked about all three**, exactly as before the knob existed — an
unstated seam means unchanged, never "switch the audience tier off". The loud channel is the script
contract, where this is a `decide` record that `adopt-dkj-policy` (Part 2) puts to the repo rather than answering for it.

**The tier a repo no longer asks about is still read.** `Get-EntryTierMax` stays 2 and every validator keeps
using it: the maximum says which tier numbers are valid to *parse* — 97 entries in this repo's record were
written under the cumulative ladder — while the audience says which are *asked*. An extra answered tier is
accepted, never refused, so no finished dossier became unopenable on the day the knob landed.

**`CHANGELOG.md` has no sections to file into** (Dave, August 5, 2026). It is an intro followed by one `###`
per change, ranked furthest-reach-first and, within a tier, highest-significance-first — so what the three
`## Tier N - Pull Requests` sections used to say visually is now the ordering, and each entry states its own
reach in its opening section — directly under the DEPLOY heading for tier 0, and under
`#### What makes this deploy extra special` for the one audience tier the repo has stated. The
**fold** is the only moment that order can be decided, because the cut empties the list: whatever order it
leaves is what the release documents inherit, with nothing re-estimated days later.

**The cumulative ladder is gone, and the measurement is why.** Until August 12, 2026 a tier-2 entry *owed* a
tier-1 section, on the reasoning that something a consumer notices is something a colleague should hear
about too. That reasoning holds for a repo with two genuine audiences and produces nothing but duplication
for the far more common repo with one. Measured over the 97 scored entries in this repo's record: **81 top
out at tier 2 and only 8 at tier 1**, so 81 of the 89 tier-1 sections existed only because a scored tier-2
section sat above them — the same reach argued twice, in a second register, for a reader who here is the
same person. The reporting consumer measured the mirror image on its own side: 37 open entries, 15 at tier
1, zero ever at tier 2. The development note still carries everything, tier 0 included, because it is the
record rather than a summary of one.

**Counting per entry, not in aggregate, is what produced that answer.** In aggregate tier 1 looks like a
working axis here — 89 of 95 scored entries carry one — and that number argues *against* this change. It is
an artefact of the ladder that required them.

**Where the number comes from: the author of the entry, on the branch.** `new-branch.ps1` writes the
blocks this repo asks about with their scores left empty; whoever finishes the branch answers each one, with a
score or with `N/A` and the reason it reaches nobody there. **The reach is the highest tier carrying a
number**, so an `N/A` costs a sentence and keeps the reasoning behind a negative claim in the record.
`open-pr.ps1` refuses an entry whose description, body or any tier's reason is still blank, and
`fold-changelog-entry.ps1` folds the entry **verbatim** — so the declaration lives in exactly one place, the
entry itself, and no second definition of the format sits inside the fold.

**The older `Tier: N` line is still read and is deliberately not stripped.** Every entry written before
August 6, 2026 — here and in every consumer's tree — carries it instead of the sub-sections, and a parser
that only knew the new shape would read all of them as tier 0: silent, correct-looking, and wrong in the
direction that empties a release. Recognise both, write one.

**Deliberately not derived from the branch prefix**, which this repo has measured does not predict impact:
held against the 19 entries pending at v3.2.0, the single most consequential change for a consumer —
renaming the marketplace, which breaks every existing install — arrived on a `chore/` branch.

### The same scale on an issue — the reach label

**Reach is a property of the change, not of the document it is written in**, so the scale reads on an
issue too — before the entry it will eventually be written into exists. An issue whose landing will be
written at tier 1 or 2 carries the **reach label**; one that will be written at tier 0 does not.

| the issue will land as | label | what that says |
|---|---|---|
| tier 1 or 2 | `minor` | it reaches past this repo's own developers, so the release carrying it is a **minor** |
| tier 0 | *(none)* | only this repo's own developers notice, so the release carrying it is a **patch** |

**The label is named for what the landing does to the release, not for a tier number**, and that is what
makes one name serve every repo. [What a release must earn](#what-a-release-must-earn) below already
reads the scale this way — tier 0 alone is a patch, and a tier-1 or tier-2 entry is what earns a minor —
so `minor` is true in a tier-1 repo and a tier-2 repo alike. A label named `tier-1` is not: it names the
audience the repo answering `Get-ReleaseAudienceTier = 2` does not have, and the reverse for a tier-1
repo. The tiers stay the vocabulary of the *entry*, where both numbers are asked for; the label carries
the one distinction an issue can already answer.

**The name is a row in your tracker's settings, and `Get-ReachLabel` states it** — defaulting to `minor`,
so a repo that never answers the seam is already right. A repo whose colleagues know the axis by another
word answers that instead, and every command that types a label reads the seam rather than a literal.
Reading it is not politeness: `gh issue create` **fails outright** on a label the repo does not have, so
a literal typed into a repo that renamed its label gets you an error instead of an issue. The seam exists
because the name *was* a literal, in four places, two of which pointed at a label its own repo no longer
had ([#1841](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1841), September 11, 2026).

**This is the one label this workflow prescribes**, and [`CONTRIBUTING-portable.md`](CONTRIBUTING-portable.md)
names it as the exception it is: your other labels are your tracker's business. This one is not a
free-standing convention but the scale above, projected — which is why it is here, in the document that
defines that scale, rather than in a repo's own lens.

**The model transfers; the mechanism does not.** A changelog entry is a form with a field per reader, and
every tier is scored on it — tier 0 included, because an unanswered field reads as an omission rather
than a decision. A label is not a field, it is a filter, and *a filter that matches everything filters
nothing*. So: **score every tier on an entry, label only the exception on an issue** (Dave, September 1,
2026, after two other shapes were tried in a consuming store repo — a `tier-0` label marking the
exception, which labelled 106 of 135 issues and left the actionable set unmarked, and a `tier-0` floor
with a second label stacked on it, which is the changelog model exactly and is where the two genuinely
part company). `is:open label:minor` is then a worklist somebody can actually work.

**The test is whether the reader notices the DEFECT, not whether the file renders to them.** This is the
mistake a file path invites, and it was made: `smartwatchbanden#455` is a storefront block on the product
page — inline CSS, an invented hex instead of the token, five unsynchronised copies. It renders correctly
to every shopper. The named failure is that a copy change has to be made in four places with nothing
reporting the one left behind, which only a developer can see. Tier 0, first classified a tier up on the
wrong question (*the product page is customer-facing, so a product-page file reaches the business*).
Re-testing all 31 labelled issues on the sharper question moved a second. **The inverse holds too**: a
build script no customer will ever load, whose breakage stops a release the business is waiting on, is
not tier 0.

**Doubt resolves to tier 0** — no label (Dave, September 1, 2026, on three borderline cases in the
backfill that first applied this label to an existing tracker, in the same consuming store repo). The point of the label is a short list somebody can work, and it is cheap to add later with
`gh issue edit <n> --repo <owner>/<repo> --add-label <reach label>`.

### What a release must earn

`cut-release.ps1` refuses a bump the pending entries have not earned. Three rules, all checked before
anything is written:

| bump | requires |
|---|---|
| **patch** | nothing — a release made entirely of tier-0 work is what a patch is for |
| **minor** | at least one entry of **tier 1 or higher** |
| **major** | at least **10 minors** cut in the current major line, on top of the general minimum |

**Why a tier-0-only release is a patch rather than a refusal** (Dave, August 7, 2026). It used to be refused
outright, on the grounds that such a release "has nobody to announce it to" — and the answer is that
announcing nothing is exactly what a patch is for. The version number still moves, the tag still marks the
moment, and the one document that gets written is the record.

**Why a minor needs tier 1 rather than tier 2.** It demanded a tier-2 entry until August 7, 2026, so work a
colleague on this project got something out of earned only a patch — while the version here speaks to all
stakeholders, not to consumers alone. The rule is written as **tier 1 or higher** rather than as "the
audience tier" on purpose: it then reads correctly in a tier-1 repo and a tier-2 repo alike, without either
having to translate it. What keeps the looser rule honest is that **the sections follow the tier and not the
bump**: in a tier-2 repo, a minor whose highest pending entry is tier 1 writes the note without its
*For consumers* section, so nobody outside is handed a section about work they cannot see. **In a tier-1 repo
that same rule reads differently and used to bite** — see
[The audience tier](#the-audience-tier---the-hand-written-note).

**Why a major counts minors rather than pending work:** a major is a **recap** of the minors before it,
which is what both of this repo's majors actually were (`v2.0.0` consolidated v1.0–v1.18, `v3.0.0`
consolidated v2.2.0–v2.16.0). So a pending tier-2 entry is deliberately *not* required; the accumulation is.
The count is read off the current version's minor component — within major 3 the minors are 3.1 … 3.10, so
the component *is* the count.

`-SkipTierGate` overrules all three. It is deliberately separate from `-SkipLint`, because it overrules a
judgement about **content** rather than skipping a tool — folding them into one flag would let someone
skipping a slow lint run also, silently, cut a minor with nothing in it for a consumer.

**The gate switches itself off where no pending entry declared its impact at all**, and that is what makes it
safe to share: a repo that never adopted the model is untouched rather than refused at every cut.

**The signal is a count of declarations, not a count of sections**, and the difference is not academic. The
test used to be "does this repo declare more than one changelog section", which had a real basis while the
tier headings existed and became a landmine the moment they went: a flat changelog gives an unadopted repo
and an adopting one exactly one group each, so the old line would have read **every** repo as not adopting
and switched the gate off in silence — in the same change that made the tier the model's primary fact.
Nothing would have errored. Counting declarations keeps "declared tier 0" distinct from "declared nothing",
which is the whole difference between a release with nobody to announce itself to and a repo that never
chose the model.

## The release documents

Which directory scheme groups them — `<X>.x` per major or `<X.Y>` per minor — is answered once by
`Get-ReleaseNotesGrouping` in your own `scripts/repo-config.ps1`, so `<dir>` below
stands for whichever this repo uses.

| document | for whom | when | generated by |
|---|---|---|---|
| `changelog/<dir>/<X.Y.Z>.md` | developers — the full per-PR record, auto-complete | every release | `cut-release.ps1` |
| `audience/<dir>/<X.Y.Z>.md` | whoever this repo publishes to — one hand-written note with a named section per reader | minor/major, where a pending entry earns one | drafted by `cut-release.ps1`, written by hand |
| `github/<dir>/<X.Y.Z>.md` | whoever opens the GitHub Releases page | every release | `cut-release.ps1` |

**Every note root names its READER or what the document IS, and both halves of that rule were arrived at
late.** `audience/` was `notes/` until August 12, 2026 (Dave), which names the *form* rather than the reader
— the same mistake `highlights/` made, and one this repo had already fixed in that sibling two days earlier
without noticing it in this one. `development/` survived that pass and named neither: it is a stage of the
work. It became `changelog/` on August 26, 2026 (Dave;
[#914](https://github.com/DaveKJohn/claude-code-specialists/issues/914)) — the changelog for that version,
the entries at the levels the fold left them, which is literally what `CHANGELOG.md` held before the cut
emptied it. So: `changelog/` says what it is, `github/` names the page, `audience/` names whoever the repo
publishes to, whichever of the two audience tiers that is. The audience root is stated in
`Get-ReleaseNoteRoot`; **its shared default is deliberately still `releases/notes`**, so a consumer who never
answered that knob is not silently pointed at a directory they do not have.

**All three of them live inside this workflow's own folder by default** (`dkj-policy/releases/`),
and the two generated ones joined `audience/` there in #914. The reasoning is worth stating because it is the
line between these roots and the two files whose DEFAULT still branches: a repo's `CHANGELOG.md` and its
release list exist whichever tooling cut them, so `Get-ChangelogPath` and `Get-ReleaseHistoryPath` answer the
repo root for a repo that publishes plugins — while a tree nothing writes but a cut exists only *because*
this workflow does. `Get-ReleaseChangelogNotesRoot` and `Get-ReleaseGithubNotesRoot` still answer it per
repo; they simply no longer answer it differently for the workflow's source repo. If your notes already sit
somewhere else, point the seam at the tree you have — that keeps one tree rather than starting a second
beside it.

**That branch is about the default, not about a rule** (August 27, 2026). It exists so a plugin source is not
silently moved; a source that would rather have every one of these documents in one folder simply states the
two seams, which is what the workflow's own source repo does. So read the paragraph above as *"unstated, these
two answer the root for a plugin source"* rather than as *"a plugin source keeps them there"* — nothing in
this workflow requires the second.

**If your config defines `Get-ReleaseDevelopmentNotesRoot`, leave it — it still answers** (#947, August 26,
2026). That was this seam's name until the directory rename caught up with it; both read sites try the new
name first and fall back to the old one, so nothing in your repo has to change. Rename it when you next touch
that file, not because anything is waiting on you.

**`consumer/` and `internal/` are gone, and the twelve pairs in them are now twelve documents in
`audience/`** (Dave, August 12, 2026). They had been written up as *frozen archives* of the two-document
era — a freeze nobody had actually decided, recorded in three places and attributed to no one, while the
`notes/` → `audience/` rename standing beside it in the same entry was Dave's. Asked directly, he chose the
merge: there are three note roots and nothing else.

**The identical filenames are why this was a merge rather than a rename.** `3.x/3.2.0.md` existed in both
trees, so 24 documents became 12 and no `git mv` could do it. Each pair kept both registers intact — the
consumer body under *For consumers*, the organisational prose under *What it is worth* and *What was still
open at this release* — and dropped exactly one thing: the internal note's `## What is different now`, which
the 62/38 measurement below identifies as the duplicated half. The prose of a published record was otherwise
left as written, so a merged document may still name `releases/highlights/` or describe itself as one of
three tiers; that is what it said on the day it went out.

**A patch writes no hand-written note at all**, and is announced by the generated GitHub Release body alone
(see [Cutting a release](#cutting-a-release)). The **sections** inside the note follow the tier; **whether
the note exists at all** follows the bump.

### Tier 0 - development

**Raw and complete, and the only document nobody writes.** Every changelog entry as it was written, nothing
rewritten — literally the whole changelog, generated in full by `cut-release.ps1` at every release. It is
the per-PR record a developer goes back to, which is why it is never edited down: a summary of it is what
the hand-written note is for.

**It renders at `CHANGELOG.md`'s own heading levels** — since August 25, 2026 the structure is the
changelog's, entry for entry. Each tier's entries follow one another as a flat ranked list in the order the
fold left them, highest tier first, with no heading marking where one tier stops and the next begins. It
used to open each group with `## Tier <n> - <audience>`, which put every heading in this document one level
deeper than the changelog the entries were copied out of — and this is the document a hand-written note is
copied *from*, so the copy has to paste at the level it was written at. The tier still decides the order; it
no longer prints a heading to say so, because *where a change reached* is a claim about attribution and this
document is the record of *what changed*. Each entry states its own reach, so nothing is lost with the
heading: a reader who wants the tier reads it off the entry.

Each entry arrives whole, exactly as it was folded — its `###` heading naming the **branch**, and beneath it
the same `####` sections the scaffolder wrote on the day it was folded, at the very levels `CHANGELOG.md`
carries them — today `What makes this deploy extra special` and `Pull Request`, with tier 0's answer sitting
directly under the entry's own heading and carrying none of its own, and for an older entry whichever
wording it was written with.

Nothing is rewritten and nothing is cut, which is what "the record" means. There are no
branch-type categories in between — the grouping came from the branch prefix, which this repo measured does
not predict impact. Tier 0 is in it, unlike in the hand-written note below.

Its size is also why it is never the body of a GitHub Release but always an attachment: `gh`'s
release-notes body has a hard **125,000-character** limit, which a full notes file can exceed.

### The audience tier - the hand-written note

**One document since August 10, 2026, with a named section per reader** (Dave). It replaced two separate
documents — an internal note for the organisation and a consumer document — and at all twelve releases
since the internal tier existed, **both were written, about the same changes**. Measured before merging
them: one release's internal note (962 words) held against test 2 of the writing norm in the
[cut-release skill](https://github.com/DaveKJohn/claude-code-specialists/blob/main/plugins/dkj-policy/skills/cut-release/SKILL.md)
(*does this describe our effort or their outcome*) gave:

| | words | |
|---|---|---|
| could appear in a consumer-facing section | ~365 (38%) | and **did**, rewritten in a second register in the other document — that is the duplication |
| could not | ~597 (62%) | including *what it is worth* (316 words), which is not an outlier but the entire reason the organisational sections exist |

So a **blended** document was refused, since it would have had to drop the 62% or break the writing norm; a
**sectioned** one keeps each register intact and writes the shared 38% once. The heading *"what is different
now"* is gone rather than moved — it **was** the duplicated half, and the *For consumers* section is what
replaced it.

`cut-release.ps1` drafts a note under `Get-ReleaseNoteRoot` — `releases/audience/<dir>/<X.Y.Z>.md` here —
for every bump `Get-ReleaseConsumerBumps` names. Three sections, in this order:

| section | for whom | how it arrives |
|---|---|---|
| the audience section — *For consumers* at tier 2, *What changed* at tier 1 | whoever your repo publishes to | **pre-filled** — your audience tier's entries, still in the words their authors wrote for a diff reviewer. Absent where no entry reached that tier. |
| *What it is worth* | the organisation | **empty** — it cannot be generated. Think in time, risk and reduced dependence on a developer. |
| *What was still open at this release* | the organisation | **empty**, and past tense on purpose: a published document does not move with reality, so a present-tense line goes stale in hours rather than months. |

**The first section is drawn from YOUR audience tier, not from tier 2** — so a tier-1 repo's entries fill it
exactly as a tier-2 repo's do. A repo asks its entries about tier 0 and its own audience tier only, so that
tier's entries are the only non-zero ones it has, and reading a fixed 2 discarded all of them.

**A minor with no entry at that tier gets the note without the section**, which is an occasional minor in
either kind of repo. The organisational two sections belong to every bump the seam names — the version moves
for everyone, so the organisation's question is always answered — while a section about work the audience
cannot see would be worse than none, because it looks written.

**That distinction is younger than it looks, and it shipped as a defect first.** Until inbound
[#747](https://github.com/DaveKJohn/claude-code-specialists/issues/747) the selection was the literal 2, and
this page described the consequence as intended: *"which is every minor in a repo whose audience is tier 1"*.
Every minor, not an occasional one — because no entry in such a repo can ever declare tier 2, so the section
was suppressed always rather than rarely. The one hand-written document that travels outward could be
finished, attached to a Release and published while never saying what shipped, and no gate objected, because
a tier-2 repo's own runs all produced a correct document. Measured from a consuming repo against `4.13.0`.
Worth keeping as a shape rather than as an anecdote: **a rule stated for one seam value, then read as though
it held for every value.**

**Still a draft to be edited, and the reason never depended on the selection.** Entry bodies are written for
whoever reviews the diff, even when the change reaches a consumer — so the *For consumers* section's
*selection* is right and its *prose* still needs rewriting from the reader's end. What is gone is the
deleting, not the writing.

**It is published output, not an internal file.** Where the bump wrote one, the note is uploaded as an
attachment to the GitHub Release (the release body itself is generated separately — see
[Cutting a release](#cutting-a-release)), which has a consequence worth stating: anything the *What was
still open* section phrases as a *live* claim goes stale in place within hours of publishing. Write it as
"open at the time of this release", not as a statement about now.

> **The "remove before publishing" marker was retired on August 5, 2026**, together with its two seam knobs
> (`Get-ReleaseHighlightsStakeholderTypes`, `Get-ReleaseHighlightsWording`). It existed because the generator
> had to guess from branch prefixes which entries a consumer cares about, so it wrote out both halves and
> left the release manager to cut one — explicitly a *proposal*, since the prefix
> measurably does not predict impact here (the marketplace-rename measurement under
> [The tier model](#the-tier-model)). The tier asks the
> entry's author instead, at the moment they know. Do not reintroduce a category-based split beside it: that
> is the guess this replaced.

**`new-internal-note.ps1` is still shipped and still works**, for a repo running the two-document flow — a
separate organisational note alongside a separate consumer document. Nothing in this repo's chain calls it
any more; it is documented here rather than dropped, because a consumer receives a plugin update rather than
choosing one, and deleting a working entry point is a breaking change.

### Where the hand-written note lands

**It is committed straight onto `main`** (Dave, August 23, 2026). `cut-release.ps1` commits and tags in one
motion, so by the time you edit the note draft, the release commit is already tagged — and the written
version lands in the commit after it. This is the **third** named direct-on-`main` exception, and it exists
so that a cut runs in one place from end to end: fold the changelog, bump the version, write the release
notes.

**Bounded, and that bound is the whole of it:** the hand-written documents of a cut that was actually asked
for — the note under `Get-ReleaseNoteRoot`, plus `internal/<dir>/<X.Y.Z>.md` where a repo still runs the
two-document flow — named in the commit so nothing else in the tree rides along. Outside a cut there is
nothing for the exception to be part of, and a later edit to an already-published note takes the ordinary
route. Being off a branch skips `open-pr`, not the gates: run the lint and the suites before this commit.

**This reverses the earlier answer, in which the note travelled the normal reviewed route.** The wider
version was offered and declined then, on the reasoning that an exception is only safe while it stays the
size it was granted at — **which is why the paragraph above spells the paths out**. That argument holds; the
judgement that changed is which size is right. A release is one procedure, and splitting it across two
routes left the trunk carrying a tagged release whose own notes were still in review.

### Once it has landed it is a published record — and that protects only what was true

A note that has gone out is not edited into agreement with the present. Links may be repointed when a
target moves; prose is left as written, so a page may still describe a directory that has since been
renamed or a model that has since been retired. That is what it said on the day it went out, and going
stale afterwards is the record working rather than breaking.

**A line that was false when it was written is a different thing, and the rule does not cover it.**
Correcting one *restores* the record; freezing it preserves a mistake, which is the opposite of what a
record is for. The two are easy to confuse because they look identical afterwards — the test is not
whether the line is wrong now, but whether it was wrong when it was typed.

Where you correct one, say so on the page: the date, what it first said, and — if your release process
attaches a copy of the note to the release itself — that the attached copy still carries the error, since
an attachment is what was published at the moment of publication and is not replaced. Without that line a
reader who downloads the asset is misled with no way to know.

**The failure worth naming, because it manufactures the second kind out of the first.** Each note's *what
was still open* block is easiest to write by carrying the previous one's items forward and updating the
counts. An item that was true at the last release and has been overtaken since then arrives in the new
note as a **false** statement — the stale line, copied forward, becomes an error. So verify each carried
item against whatever it is a claim about, not against the note you are copying from.

### Giving that note a reader-shaped home — the release-notes page

The hand-written note is the one release document written for somebody **outside** the development work,
and it lives as markdown inside a repository. That is the right home for it and the wrong place to read
it: the reader you wrote it for has to find a directory, pick a version out of a filename, and read raw
markdown in a code host.

**`build-release-notes-page.ps1` builds those same documents into one page** — a picker per release, the
document rendered — and with `-Worker` into a Cloudflare Worker that serves it. The
[`release-notes-page` skill](skills/release-notes-page/SKILL.md) is the procedure; four things belong here,
because they are decisions rather than steps.

**It is generated, never edited.** Your note is already written for that reader, so a hand-edited summary
of it would be a second thing to keep true. A repo whose notes are per-PR records — where the summarising
is the work — wants a *different*, hand-written page, not a mode of this script.

**It reads the release list, not the directory.** Only your history page knows the order, the date, the
type, the title and which release is live. A directory listing knows none of those and sorts `4.10.0`
before `4.9.0`.

**It is a snapshot, not a mirror.** After a release: rebuild, then redeploy. Nothing reminds you, and
nothing can — so the page carries its build date in the footer, which is the honest version of a guarantee
nobody can make.

**Hosting it is a decision about who may read, and the answer is written into the URL.** The worker serves
the page at `/notes/<32 hex>` with no login, so *the path is the only lock*: anyone with the link reads it.
That is defensible where the notes are already public, or where the link only ever goes to the people the
note was written for — and it is why the page carries `noindex` in both the response header and the meta
tag, since an unguessable link is worth nothing once a crawler has published it. Two consequences follow:

- **The token is an input, never invented.** A token generated on the fly does not mean *"a new path"* — it
  means every link you have already sent now 404s, while the build and the deploy both report success. The
  script refuses instead, and `-InitToken` is the separate, explicit way to make the first one.
- **Whether the token belongs in git depends on your repository.** Private: commit it, because a tracked
  token is what survives a lost machine. Public: keep it out, and accept the consequence — nothing in git
  then remembers your URL, so whoever creates it records it elsewhere.
- **A lost token is not a lost URL, while the worker is still up.** The bundle carries its route as a
  literal, so a live deployment is itself a copy of the token — readable from the worker's code view in
  the Cloudflare dashboard or from the Workers script API. That is the route to exhaust before minting a
  fresh path, and it is why the refusal names three in order: the URL you have, then the deployment, then
  `-InitToken`. Written down after a repo with no local copy concluded its links were unrecoverable, with
  its worker still serving them.

**Publishing is `npx wrangler deploy`, run by hand.** The script writes the bundle and stops there, because
publishing is outward-facing. **Verify a redeploy against the bytes the URL serves**, never against the
deploy command's own output: once wrangler has created a deployment on a worker, an API-side upload only
creates *inactive* versions — with no error, while the live page stays the old one.

## Cutting a release

A release is a **captured moment**: the state is tagged as `vX.Y.Z`, and where the repo publishes plugins
they all get the same version number (**lockstep, repo-wide**). `cut-release.ps1` produces only a git tag,
the full notes here in
`changelog/`, and a reference to them in the repo's own `CHANGELOG.md`. A release is cut **only on the
owner's explicit request** and deliberately does **not** go through a branch + PR: like the fold commit, the
release commit is a permitted direct-on-`main` action (the second of three exceptions to "everything via branch + PR"
— see [the contribution cycle](CONTRIBUTING-portable.md#releases--a-different-cycle)).

In one motion, on a clean `main`:
[`scripts/release/cut-release.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/release/cut-release.ps1)`(-Version <X.Y.Z> | -Bump <major|minor|patch>) [-Title "…"]`

1. where `Get-ReleasePluginTier` is true, bumps all `plugin.json` versions in lockstep to `X.Y.Z` —
   otherwise there is nothing to bump and the version lives in the tag alone;
2. generates the full release notes in `changelog/<dir>/<X.Y.Z>.md` (from the folded entries, grouped by
   tier and, within a tier, a flat list in the ranked order the fold left), adds a row to the release list
   on the page `Get-ReleaseHistoryPath` names — `dkj-policy/releases/history.md` unless you repointed it
   — and **empties `CHANGELOG.md` down to its intro** — that intro passes through
   verbatim, so whatever the repo says about itself up there survives every cut. A cut writes no release
   block: the section that used to hold one had grown in the source repo to 434 of the changelog's 1,062
   lines across 72 blocks
   each saying no more than "see the notes", while its release list already carried all 72 with a date, a
   type and a title. What replaced it is the intro's own one-line pointer to the release list;
3. **(retired, August 8, 2026)** step 3 used to append, per plugin, the entries that touched it to a
   **per-plugin `CHANGELOG.md`** and regenerate that plugin's **`RELEASE.md`** card — a second copy of a
   history the consumer already receives, since a marketplace source arrives as a git clone of the whole
   repository. One repository, one product, one changelog; the measurement that retired it is with the
   source repo's other measured instances, in its release manager's repo lens. The `Plugins:` line survives:
   the release notes still read it;
4. commits that directly on `main` (`release: vX.Y.Z`) and sets an annotated tag `vX.Y.Z`;
5. pushes `main` + the tag (unless `-NoPush` for inspection first).

**Closing step, after the script and after the hand-written note has merged, where the bump wrote one:
publish a GitHub Release.** Not run by `cut-release.ps1` and not automated; the release manager walks
through the
[`cut-release` skill](https://github.com/DaveKJohn/claude-code-specialists/blob/main/plugins/dkj-policy/skills/cut-release/SKILL.md)'s
checklist: `gh release create`
with the **generated body** (`--notes-file` pointing at the `releases/github/<dir>/<X.Y.Z>.md` the cut already
wrote — nothing to edit), then `upload-release-asset.ps1` with the full development notes **and the hand-written note,
where the bump generated one** — one call per document, each verifying the published byte count (#2347). Never inline the development notes — see
[Tier 0 - development](#tier-0---development) for the character limit that makes that fail.

**Upload the attachments under unique filenames.** Every document a release produces shares the basename
`<X.Y.Z>.md`, so uploading two of them straight from `releases/` collides — the second upload returns
`HTTP 404`. `gh`'s `file#label` syntax does not solve it (it sets the label, not the name). Copy them to
`vX.Y.Z-development-notes.md` and `vX.Y.Z-notes-for-users.md` and upload the copies.

**It comes last on the checklist, and the reason has outlived one rewrite already.** The body used to be a
hand-written document merged via its own branch + PR, so publishing straight after the tag would have had no
body to publish. The body is generated by the cut itself now, so that particular impossibility is gone — but
publishing early would still publish a page whose attachments are missing the hand-written note and whose
pointer line names a document nobody can download yet.

**And it needs no separate approval** (Dave, August 5, 2026). Cutting the release is the act that is asked
for; publishing its Release is the last step of that same procedure, so stopping to ask there is a rubber
stamp. Once a cut has been requested, the whole run goes through in one motion — generate, commit the
hand-written note on `main`, publish. **The boundaries that remain are the live stage (Block 2 of the checklist)
and, in a marketplace source, the business publication (Block 3)** — different acts with different
audiences, and this approval covers Block 1. A repo wanting a different boundary states that in its own
lens rather than softening this paragraph.

**Where the repo is itself a marketplace source with a business publication target, one more step exists
after the cut — and it is a boundary, not a tail.**
[`scripts/release/publish-to-business.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/release/publish-to-business.ps1)
overwrites the business repo with the marketplace subset of the source, so an organisation's Claude
Enterprise can sync it as a plugin marketplace for colleagues without GitHub access. It runs **after** a
release and **only on the owner's explicit request** — releasing without publishing is a normal outcome,
not a half-finished one (Dave, August 14, 2026). The target is repo data (`Get-BusinessMarketplaceRepo`
in `scripts/repo-config.ps1`, with `-TargetRepo` as the override for a second organisation); a repo
without one simply has no such step. **Which plugins travel is repo data too**
(`Get-BusinessMarketplacePlugins`, `-Plugins a,b` to override; empty or absent means all of them, as it
did before the seam existed) — the source repo excludes both workflow plugins from its own target,
because that target serves Claude App users who have no repository, and a workflow is a method for
moving work through one. The mechanics are Block 3 of the
[`cut-release` skill](https://github.com/DaveKJohn/claude-code-specialists/blob/main/plugins/dkj-policy/skills/cut-release/SKILL.md)'s
checklist.

Guardrails: a clean `main`, no unfolded entry files, **[the bump earned by the pending
tiers](#what-a-release-must-earn)** (`-SkipTierGate` overrules), lint gate green, **all test suites green**
(`-SkipTests` overrules), tag doesn't exist yet. All
of them run **before the first file is written**, deliberately: failing after the notes file exists would
leave a release half-cut on `main` — and for the test gate this is the last moment a red suite can still
stop anything, because CI fires only after the tagged commit is already pushed.

**The lint gate is *your* repo's, read from `Get-LintScript` — the same seam `open-pr` uses.** This route
needs its own gate precisely because it does not travel via a PR, so nothing else on it ever meets that
copy. Until August 5, 2026 the cut resolved the gate by a fixed path to the script the *source* repo
happens to carry, which meant every consumer release ran with no gate at all and said so in a warning
(inbound [#464](https://github.com/DaveKJohn/claude-code-specialists/issues/464)). **A gate the seam names
but the tree does not have is a hard stop**, not a warning: skipping it is `-SkipLint`, and that choice
belongs in the command rather than in output that scrolls past.

**And so is the test gate: the `*.tests.ps1` suites in `scripts/tests`, plus whatever the optional
`Get-TestCommands` names** — extra command lines (an `npm test`, a `pytest`) for a repo whose tests are not
all PowerShell, each failing the gate exactly like a failing suite. The seam is read inside the one shared
gate function, so the PR gate and the release gate cannot drift into checking different things; a repo that
states nothing keeps exactly the gate it had.

The pure logic (version bump, CHANGELOG transformation, notes construction, and the bump rules in
`Test-ReleaseBumpEarned`) lives in
[`scripts/lib/release-lib.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/lib/release-lib.ps1)
and is covered by
[`scripts/tests/release-lib.tests.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/tests/release-lib.tests.ps1).
The tier line's own format
— writing it, validating it, and the section map it selects — lives in
[`scripts/lib/entry-scaffold-lib.ps1`](https://github.com/DaveKJohn/claude-code-specialists/blob/main/scripts/lib/entry-scaffold-lib.ps1),
shared with the three scripts
that must not disagree about it.

