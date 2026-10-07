---
name: golive-block
description: >-
  Write the paste-ready block for a GitHub issue, including its go-live half: where the result can be
  seen, when it is planned to go live (the next release day), and the live storefront URL per market.
  Use it as the closing act of the chain that shipped the work, while the issue is still OPEN, then close the issue as completed:
  the asana-closed-message workflow then carries the block into the Asana task as its closed message, so nobody pastes it.
  It prints by default and posts only with -Post; it never touches Asana itself, and it never
  writes a placeholder link.
---

# golive-block -- the block a colleague reads, with the release day in it

`WORKFLOW-portable.md`'s paste-ready block answered *where can I see it* and stopped there. The
requester's next question is always *and when do I actually see it*, and the ticket is the only place
they are looking -- so the block carries more facts: the release day, the live URLs, and a version only where one is given
([#2100](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2100), Dave,
September 18, 2026).

## What the skill does

Run the shared script from the **root of the repo the issue is on**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/build-golive-block.ps1" -Issue 412 -Link "https://..." -Path "/collections/straps" -Post
```

1. Resolves the issue (a bare number, `#412`, or its URL) and the repo.
2. **The date** -- the next release day, strictly after today. BWJ cuts on a Monday, which is the
   default; `-ReleaseDay` is there for a repo on another cadence.
3. **The version** -- **only when you pass `-Version`.** The newest `vX.Y.Z` tag stepped by the bump
   the changelog's pending tally names today is printed on the console as a projection for you, and
   left out of the block: every entry still to land before release day can raise it, and the requester
   quotes the block back as a fact. The owner rejected a block that named one six days out
   ([#2620](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2620)).
4. **The live URLs** -- `Get-MarketUrls` over the pages `-Path` names, out of the same market table a
   preview pair is built from, **bare**. The result link is normally a preview, and a bare URL renders
   that preview in any browser that opened it first
   ([#2477](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2477)), so beside a result link
   the label tells the requester to open them in a private window until the release. They are **not**
   pinned to the live theme id: `?preview_theme_id=<live id>` is a true comparison, but to a colleague
   it reads as a preview link under a label saying *live*, and the owner rejected a block for exactly
   that ([#2619](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2619)).
5. **The ask** -- where a `-Link` was given, a closing section asking the requester to look at the
   result themselves: an approval ticks off the task, a rejection names what is not right AND what
   should change and reopens the issue, and the release happens either way
   ([#2352](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2352)). The five rules behind it
   are in `WORKFLOW-portable.md`, under *What the block asks of the requester*.
6. **The shape and the language** -- the block as it was written for Asana: its header (*— GitHub automation 🤖*)
   and the closed line (`GitHub issue [<owner>/<repo>#<n>](<issue url>) is now **closed**.`, then
   *"It can be reopened anytime when something is still not working as expected."*), both fixed and
   English on every board, then five fixed
   headings (`TE BEKIJKEN OP` / `WAT ER NU ANDERS IS` / `WANNEER HET LIVE KOMT` / `WAT ER BEWUST NIET IN ZIT`
   / `WAT WE VAN JE VRAGEN`, where-to-look first, [#2700](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2700)), in the language
   of the Asana task -- Dutch by default, `-Language en` for a task written in English
   ([#2507](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2507)). The prose sections are
   **yours to write**, and they come in through `-ProseFile` (below). The script fills in the facts.
7. Prints the block. With `-OutFile`, also writes it as UTF-8; with `-Post`, comments it on the issue.
8. **The store-admin prerequisites** -- with `-OutFile` or `-Post` it reads the issue for the checklist
   under `<!-- store-admin-prerequisites -->`: work the change needs on the store rather than in the
   theme, such as a metafield definition, a menu or a setting. `-OutFile` **warns** about each open box,
   so the handover page can name it, or that the issue could not be read. `-Post` **refuses** while one is open or the issue cannot be read,
   and `-Force` gets past it
   ([#2885](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2885)). The checklist's form is in
   `WORKFLOW-portable.md`, under *Store-admin prerequisites*. A print-only run reads nothing.

## The prose file

What changed, where exactly to look, and what was deliberately left out are judgements about the work,
so the session writes them. They go in a UTF-8 text file, one section line per part:

```text
[changed]
Je kunt vanaf nu per collectiepagina zelf een SEO-introductietekst plaatsen, direct onder de titel.

Opmaak mag daarin: vet, cursief, links.

[where]
Kijk direct onder de paginatitel, en bekijk het ook op je telefoon.

[not-included]
Er is geen A/B-test opgezet; de afspraak was om de impact via de rankings te volgen.
```

A blank line separates paragraphs. Every part is optional, and a missing part's heading is left out
too; a missing `[changed]` is warned about, because it is the first thing the reader looks for. An
unknown section line, or text above the first one, is **refused**: a misspelled heading that silently
dropped its paragraph would ship a block without the part you wrote. It is a file and not a parameter
because `powershell -File` delivers a `string[]` as one string, and a paragraph's newlines do not
survive the command line.

### When the change hands the requester a task

Most blocks say *look at this result*. Some say *do this from now on*, because the change gives a
colleague something to maintain themselves, such as a metafield to fill or a setting to steer. That
kind of block teaches a procedure, and the `[changed]` and `[where]` prose then follows this order:

1. **The goal, and what happens when the reader does nothing.** The default comes first. A default
   stated after the syntax, or not at all, makes a workaround read as the normal procedure.
2. **The click route, walked once with a non-admin account before you post it.** Name each click,
   such as *Edit metafields*, rather than the system behind it ("Metafields", a field key, an app name).
   An admin sees fields and buttons that a colleague's account does not, so an unwalked route is a
   guess.
3. **One worked example, on a page of the reader's own.** It shows a filled-in field and the result
   on the storefront.
4. **Then the exceptions.**

**When the model changes, rewrite the whole instruction rather than the delta.** A block that opens
with what changed asks the reader to rebuild the procedure from a version they may never have got
working. Measured in `BWJ-Development/smartwatchbanden` (Asana task 1215990009309345, #393): over
three rounds, from September 23 to October 7, 2026, the anchor-button model changed three times, and
the SEO colleague got stuck five times on blocks that broke these four rules
([#2878](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2878)). The headings and their
order stay as the script writes them. Only the prose inside them follows this order.

**Use `-OutFile` for any copy that is not read by eye.** The block now carries accents and dashes. The
console printout may lose them to its code page, and a pipe from Windows PowerShell 5.1 into a native
command encodes as ASCII, which is why `-Post` sends the body through a UTF-8 file.

## The parameters

| parameter | what it is for |
|---|---|
| `-Issue <n>` | required; a bare number, `#412`, or the issue's URL |
| `-Link <url>` | where the result can be seen, **openable by the requester without an account** -- a storefront preview URL (`Get-MarketPreviewUrls`) or a live page. Not the preview handover page: a `claude.ai` Artifact is private to its owner, so it is refused ([#2341](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2341)). **Omitted, that sentence is not written at all** -- see below |
| `-Path <p[]>` | the storefront pages the change touched; each becomes one live URL per market. Pages separate on `,`; where a page's handle differs per market, write it `/default\|NL=/nl-handle\|DE=/de-handle` (the backslash before each `\|` only escapes it for this Markdown table -- type a plain `\|` on the command line, and quote the argument). Unknown or repeated labels, two defaults, and a page that leaves a market unnamed with no default are refused ([#2627](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2627)) |
| `-Repo <owner/repo>` | when `GITHUB_REPOSITORY` and `gh repo view` cannot answer |
| `-Version <X.Y.Z>` | the version to name in the block. Omitted, the block names the release day alone; pass it once the number can no longer change (the cut is prepared, or a major is decided) |
| `-ReleaseDay <day>` | the weekday releases are cut on. `Monday` |
| `-From <date>` | the day the next release day is counted from. Today |
| `-Language nl\|en` | the language of the Asana task, and so of the block between the rules. Omitted, the repo's own `Get-GoLiveBlockLanguage` in `scripts/repo-config.ps1` (returning `nl` or `en`) answers it, so a store that writes GitHub in English states that once ([#2830](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2830)); without that seam, `nl` |
| `-ProseFile <path>` | your prose for the `[changed]`, `[where]` and `[not-included]` sections -- see below |
| `-OutFile <path>` | also write the whole comment as UTF-8, without a BOM: the faithful copy for a page that embeds it |
| `-Post` | actually comment it on the issue. Without it, nothing is written anywhere |
| `-Force` | post although a block already appears to be there, a store-admin prerequisite is still open, or the issue could not be read |
| `-AllowPrivateLink` | accept a `claude.ai` Artifact as `-Link` once it has actually been shared with the requester. Kept apart from `-Force` so that posting a second block never also lets a private link through |

## What it deliberately does not do

- **It never writes `[ADD LINK]`.** That placeholder belonged to the retired `asana-mirror` backstop,
  which genuinely could not know the link. A session running this script does know it, so a link it was
  not given is a **sentence it does not write** -- a missing line, never a placeholder.
- **It never hands the requester a link they cannot open.** The handover page is the *reviewer's*
  surface, and it stays private until somebody shares it, so a `claude.ai/artifact/` or
  `claude.ai/code/artifact/` `-Link` is refused. That covers printing too, because the printout is
  what reaches the task. Measured in `BWJ-Development/smartwatchbanden#750`.
- **It never touches Asana itself.** The close does: when the issue closes as completed, the
  `asana-closed-message` workflow posts the block on the task as its closed message (#2818), the job the
  retired `asana-mirror` did from #2700. So the framing sentence above the rules reads *"The closed
  message carries the block below into the Asana task when this issue closes as completed -- no paste
  needed:"*. A close as not planned sends nothing.
- **It never promises.** *"Het staat gepland voor de release van maandag 22 september 2026"* is a
  cadence, and a release can slip. This block is the one surface a colleague quotes back, so it must
  not read as a commitment nobody made.
- **It guesses nothing.** A predicted version is a guess while entries can still land, so it stays on
  the console unless you pass `-Version`. A repo that has declared no storefront markets gets no
  live-URL list.

## The order is the rule, and this script is the second-to-last step

```text
work shipped -> build-golive-block -Post -> close the GitHub issue (the block stays on the issue)
```

**While the issue is still OPEN.** Nobody returns to a closed one, which is the whole finding behind
[#2049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2049): a comment posted at the close
appears underneath an item that has just left every open-issue view. The script warns where the issue
is already closed and posts anyway -- a late block beats none.

**And it refuses a second block by default.** `Test-AsanaPasteBlockPosted` (in
`scripts/lib/asana-task-lib.ps1`) answers *true* where it cannot read the comments, which is the safe
default for a duplicate check, so an unreadable issue is reported as exactly that and `-Force` is the way
past it.

## Where the rule lives

[`WORKFLOW-portable.md`](../../WORKFLOW-portable.md), chapter one, under *The go-live block*. The
other cycle step this plugin adds -- the storefront-visibility step, last under `### CREATE` -- is in
[`PREVIEW-portable.md`](../../PREVIEW-portable.md), and both are indexed in
[the README](../../README.md#what-the-cycle-gains-here). **The same output is that page's fourth
block** -- a preview handover embeds it read-only, as what the requester will read, rather than composing its own
([#2474](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2474)), so run it with `-OutFile`
for the page and with `-Post` for the issue.

## Requirements in the consumer

`gh`, authenticated, for resolving the repo and for `-Post`. `git`, for the tag. The live-URL half
needs `Get-StorefrontMarkets` in `scripts/repo-config.ps1`, and is skipped entirely where no `-Path`
is given -- so a repo with no storefront never has to answer it. The changelog is found through
`Get-ChangelogPath`, defaulting to `CHANGELOG.md`.

## Important

This script is maintained in the source repo; do not modify it locally in a consumer. A change lands
first in the source and then travels via a release to the plugin mirror.
