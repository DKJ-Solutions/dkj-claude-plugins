# Releases

Releases in this repo are cut by the shared release workflow: the tier model, what a release must earn,
the release documents, and how one is cut. **That process is not this repo's own** — it is what the
`dkj-policy` plugin does, in every repo that enables it, and it is described once, with the plugin:

📄 **[Releases — the portable half](../../plugins/dkj-policy/RELEASES-portable.md)**

Read that first. **This page is this repo's set of answers to it**: the seam values in force here, the
local decisions, and the measured instances behind the portable rules.

**What this repo's releases *are* is not on this page — it is on its sibling**, at
📄 **[`releases/history.md`](history.md)**: the dated list of every version ever cut, beside the
complete per-version notes in `changelog/` and the GitHub Release bodies in `github/`. The release
block in [`CHANGELOG.md`](../CHANGELOG.md) points there for everything but the current version.

**That list sat at the repo root until August 27, 2026, and this page is where its move is recorded**
(Dave). It came here under a new name, `history.md`, because this page is already `releases/README.md` —
the list and the answers are two different documents that shared a filename only while they sat at
different directory levels. The paragraph below is the reasoning that kept it at the root, left standing
rather than deleted, because the half of it that still holds is what makes the move safe.

**Why the list was there and the `audience/` notes were here** (Dave, August 19, 2026) — the test is
whether the thing survives this folder being deleted. A repo that has cut releases has a **history**
whichever tooling cut it, so the list is the repo's and an index of files in `releases/` had no business
sitting in a folder a teardown removes. **The first half of that still holds and the second no longer
does**: the list is indeed the repo's own, and issue #885 settled that this folder is **permanent** — no
command in the workflow plugin removes it, and no future teardown may, precisely because it holds a repo's
changelog and release history. There is no teardown for the list to not survive, so the durability worry is
answered rather than overruled. A per-reader **note** is the opposite: it exists only because the
tier model does, so it is the workflow's and stays. Both moved here together on August 14; only the list
moved back.

The split is the same one [`CONTRIBUTING.md`](../../plugins/dkj-policy/CONTRIBUTING-portable.md) already uses: the portable half travels
with the plugin, the local half stays in the repo. Until August 13, 2026 both halves lived on this page
behind a horizontal rule, and two consumers hand-maintained a 4,154-word verbatim mirror of the top half
because that was the only way to keep it from drifting — inbound
[#646](https://github.com/DaveKJohn/claude-code-specialists/issues/646), which is also where the
measurement lives.

---

## claude-code-specialists (REPLACE WHEN MIRRORING)

### How to build your own version of this page

> **To an agent setting this workflow up in another repo:** do not copy this page's process half — there
> is none any more. The process ships with the plugin as
> [`RELEASES-portable.md`](../../plugins/dkj-policy/RELEASES-portable.md) and stays current
> through plugin updates, which is exactly what a hand-maintained mirror cannot do (two consumers measured
> that cost before this split — inbound #646). Your own `dkj-policy/releases/README.md` (the
> `adopt-workflow-folder` skill scaffolds it) holds only what this section holds: a pointer to the
> portable page, your seam values and your local decisions.
>
> **Your release list does not go on this page — it goes beside it**, in
> `dkj-policy/releases/history.md`, which is where `Get-ReleaseHistoryPath` already points if you
> leave it alone (issue #885). The two are separate documents at the same address, which is exactly why the
> list is not called `README.md`. If you have been cutting releases into a `releases/README.md` at your repo
> root, that is a **layout rather than a mistake** — repoint the seam at it and keep one list, or leave the
> default and accept that your history splits at the point the default starts applying. It
> needs a `<n>.x` section and a table header before your first cut, or the row inserter has nowhere to
> file a row; start it **empty** rather than carrying these versions, dates and PR references across.
> If your page today still carries a hand-copied mirror of the process above a horizontal rule, delete
> that half and keep your own — the plugin's page is the same text with a maintainer. And if it carries
> a release list from before this split, move that list to your root page rather than deleting it.

### Seam values in force here

**`Get-ReleasePluginTier` is true** — this repo is the marketplace source, so every cut bumps all
`plugin.json` versions in lockstep and the current version is read from a `plugin.json`. **A repo that
publishes no plugins answers false**, skips step 1 of the cut entirely, and reads its current version from the
newest `vX.Y.Z` tag; the release is then the tag and the documents, nothing else.

**`Get-ReleaseAudienceTier` is `2`** — this repo is a service its consumers subscribe to, so the
hand-written note's *For consumers* section is written for them. A repo that delivers to management or a
commissioner answers `1` and never writes that section.

Every release document groups **per major** (`3.x`) — the consumer this model came from folders per minor.
`Get-ReleaseHistoryPath` answers [`releases/history.md`](history.md) in this folder — since
August 27, 2026, which is also the answer its computed default has been giving every **consumer** since
issue #885, so the source stopped being the one repo answering it differently. It pointed at this page's
folder once before, between August 14 and August 19, 2026, when the hand-kept release pages moved here and
the list came along; then the list moved back to the root and the audience notes did not. This is that
first move made again on a premise that now holds — see the reversal recorded near the top of this page.
Since the hand-written note merged into one document (August 10, 2026), `cut-release.ps1` drafts that
note itself before it writes this page's **Version cell**, so the cell points straight at it — the hand-written
note where the bump wrote one, the development notes on a patch — with nothing repointing it afterwards.

**Six changelog seams retired on August 5, 2026 and are therefore not stated here either.**
`Get-ChangelogTierHeadings` and the legacy `Get-ChangelogHeading` (#178) named changelog section headings, and
the document has none; `Get-ReleaseCategoryTitles` labelled the release-notes categories, and the grouping is
gone with the branch-prefix guess behind it; `Get-ReleaseLiveMarker`, `Get-ReleaseHistoryMode` and
`Get-ChangelogReleaseWording` (#462) all described the release **block** a cut used to append, and a cut
writes none. A consumer that still defines one is unaffected — nothing calls them.

**`Get-ReleaseMajorMinMinors` is `10`.** Held against this repo's own history that is roughly right rather
than arbitrary: the `1.x` line ran to `1.18` and the `2.x` line to `2.16` before each was recapped into a
major.

**`Get-LintScript` is [`scripts/lint/check-plugin-integrity.ps1`](../../scripts/lint/check-plugin-integrity.ps1),
which is what the release route runs here.** It used to carry a check written *for* this route — check 9,
guarding that every plugin's `RELEASE.md` card existed and that its version matched `plugin.json`. Both the
card and the check were retired on August 8, 2026: with no second statement of a plugin's version, there is
nothing left to compare `plugin.json` against. The gate is still named here because it is what the cut runs;
the rest of its checks are unaffected.

**What a non-English consumer loses with `Get-ChangelogReleaseWording`, stated rather than glossed over.**
That seam existed because those four strings were the most visible generated output in `CHANGELOG.md`, and
inbound #462 asked for them to be repo-owned. The capability is not being taken away — the **output** is
gone. What replaced it is the intro's own pointer to this page: hand-written prose in a file the repo owns
outright, so it needs no seam to be in their language. It simply is.

### Local decisions

**A GitHub Release is published at every release, patch included** (Dave, August 4, 2026). Two consequences
of that "every release" half: patches now get one — so `v2.6.1` and `v2.7.1`, cited here for years as
examples of releases deliberately without one, describe the **old** rule and are left standing as history
rather than as guidance. And a patch gets no hand-written note at all by construction, so on a patch the
attachment list is the development notes alone.

> **Markdown only.** For one release (v3.2.0) the tier also generated a print-ready `.html` beside the
> `.md`. That is gone and is not coming back — Dave's decision, August 3, 2026. A PDF, if ever needed, comes
> from rendering the markdown with a tool built for it rather than from a partial HTML renderer maintained
> here. `v3.2.0`'s `.html` was removed from `main`; the `v3.2.0` **tag** still contains it, because a tag is
> a record of a moment and is not rewritten.

**Every release is titled `Release version X.Y.Z`, and nothing more** (Dave, September 10, 2026, at the
`v4.33.0` cut). A `cut-release.ps1` release rolls up every entry merged since the last one, and a large one
rolls up dozens with nothing in common — so a forced one-sentence `-Title` describes none of them and reads
as filler in `history.md`'s title column. This repo therefore passes `-Title "Release version X.Y.Z"` on
every cut, and `history.md` and the generated GitHub Release body carry that same string. The `-Title`
mechanism is unchanged and a descriptive sentence is still valid — a repo whose releases each carry a
single theme should use one — and `-SummaryFile` still turns a genuine milestone into its own authored
block regardless of the title.

**The notes are also readable as one hosted page** (Dave, August 15, 2026). `build-release-notes-page.ps1`
builds every document under `audience/` into one page with a picker per release; the portable half — what
the page is, why it is generated rather than edited, and what hosting it decides — is in
[`RELEASES-portable.md`](../../plugins/dkj-policy/RELEASES-portable.md#giving-that-note-a-reader-shaped-home--the-release-notes-page).
This repo's answers:

| | |
|---|---|
| `Get-ReleasePageTitle` | `Claude Specialists` — the **product's** name, not the repository's and not what the page is. It is the masthead eyebrow and half the window title; the heading is the template's own *Release notes*. Without it the fallback would head the page `claude-code-specialists`, which is a true answer and not one to send anybody. It carried `-- release notes` until 2026-08-21, which printed those words twice |
| `Get-ReleasePageWorkerName` | `ccs-release-notes` |
| where the output lands | `dkj-policy/releases/page/`, derived from `Get-ReleaseNoteRoot` rather than configured — the note root already says where this repo keeps its release documents |
| what is committed | **nothing from that directory.** The page and the worker are derivatives of the tracked documents, and a 400 KB file changing every release would dirty the tree `cut-release.ps1` refuses to run on |

**The path token is deliberately not in this repository, and that costs something worth stating.** The
worker serves the page at `/notes/<32 hex>` with no login, so the path is the only lock — and this repo is
**public**, which would put the key beside the door. It lives in
`dkj-policy/releases/page/worker-path-token.txt`, which `.gitignore` keeps out, so **nothing in git
remembers the URL**: the file on the machine that made it is the only copy, and whoever creates it records
the finished URL outside the repo. A consumer whose repository is private has the opposite answer available
and should take it — a tracked token is what survives a lost machine.

**What the lock is actually for here, since the notes are public anyway.** It guards the *route*, not the
content: every document on that page is already readable in this repository. What it buys is that the page
is not a second, crawlable, permanent surface for the same text — which is why the `noindex` in the header
and the meta tag matters more than the token does.

**Rebuilding is not part of the cut, and no gate watches it.** The page is a snapshot: after a release it is
stale until somebody runs the script and deploys again. Same category-A silence as any external link — if
the worker is ever removed, whoever removes it takes this section with it.

### Measured instances behind the portable rules

- **The branch prefix does not predict impact here**, and this is the measurement the whole tier model rests
  on. Held against v3.2.0's 19 entries, the most consequential change for a consumer — renaming the
  marketplace, which breaks every existing install — arrived on a `chore/` branch. While the consumer
  document was assembled from `Feat`/`Fix` that change landed *below* the remove-before-publishing marker, so
  the guidance here used to be "expect to promote `Docs`/`Chore` items". Since August 5, 2026 there is nothing
  to promote: the entry's author declares the tier, and the branch prefix decides nothing but the category
  heading an entry is grouped under. Kept as history because it is the evidence for that change, not a rule
  still in force.
- **Both of this repo's majors were already recaps**, which is what the 10-minor rule now requires up front:
  `v2.0.0` consolidated v1.0–v1.18 and `v3.0.0` consolidated v2.2.0–v2.16.0, both written that way after the
  fact. The rule states the practice rather than inventing one.
- **The per-plugin `CHANGELOG.md` and `RELEASE.md` cards were retired against a measurement** (August 8,
  2026), which is the source half of the retired step 3 in the portable page: a consumer receives this
  marketplace source as a git clone of the whole repository, so `CHANGELOG.md` and this entire `releases/`
  tree already sit at `~/.claude/plugins/marketplaces/<marketplace>/` — the cards were ten files and
  11,684 lines, a second copy free to disagree with the original, which is exactly what lint checks 9
  and 17 existed to police.
- **The attachment-filename collision was measured at `v3.3.0`**, where the second upload returned
  `HTTP 404` on `…&name=3.3.0.md`.
- **The written-notes route has a worked instance**:
  [PR #432](https://github.com/DaveKJohn/claude-code-specialists/pull/432) shipped `v3.2.0`'s internal note
  post-tag, gates green and entry folded, with nothing about being post-tag causing friction.
- **The closing step used to sit directly after the tag** and was moved to last on August 4, 2026. It had
  worked only because the body was then the consumer document file the script itself had already generated.
