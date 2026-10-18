## feat/issues-page

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

The owner asked for a Repo hub page that maps this repo's GitHub issues. Measured first: the repo had
**0 open issues** on October 18, 2026, and about 17 a day come in and go out, so a page of open issues
alone would be empty. It shows the open board **and** the flow: opened against closed per week, and what
was closed, by kind, priority and reason. A GitHub search returns at most 1,000 issues, which over
eight weeks is already reached, so the window is 28 days (about 475 issues).

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: `ConvertTo-IssueRow`, `ConvertFrom-IssueList` (pure model: dedupe by number, the board state -- parked over claimed over free --, the priority matrix, four weekly buckets, the median time to close, the closed-by groups) and `Format-IssuesPageHtml` in the shell every hub page shares; the hub's Pages card links `/issues`
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: `Get-IssuesModel` (three `gh issue list` calls: open, created in the window, closed in the window), the `/issues` route, its own cache (`-IssuesCacheSeconds`, 300: the read takes about 12 s) and `/refresh?page=issues`
- [x] The owner asked for a clear split between the general pages and this repo's own (October 18, 2026): `Get-RepoHubPages` gives each page a `Group`, and the hub lists the repo's own (Connectors, Test gate) in block 7 **Pages** and the general ones (Artifacts, Issues, Release notes, SessionStart) in a second card of the same form, **General pages**, directly under it -- house classes only (a split one level down, two h3s in one Pages card, was tried and the owner chose the two cards back); "general" means every DKJ-Solutions repo (owner, same day), the form itself is asked for upstream in DKJ-Solutions/dkj-brandbook#206 and shipping the pages from `dkj-solutions` is #3119

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: the model (ordering, board states, kinds, dedupe, window edges, weeks, median, reasons) and the page (escaped titles, integer-only links, the empty and the failed read); 127 pass
- [x] Served live on this machine: 0 open, 455 opened and 458 closed in 28 days, median 1.3 h to close, in 12.3 s
- [x] Victor's and Sebastian's reviews: the gh read goes through `Invoke-NativeCapture -Utf8` (5.1 would decode a non-ASCII title through the console code page), a failed read is cached 30 s instead of 300 s, `/refresh?page=issues` re-reads at most once a minute (a read holds the single-threaded server about 12 s), and the tiles and weekly rows both end at the read's own moment
- [x] `native-capture.tests.ps1`: the new bounded capture asks `Test-NativeExitMeasured` and the audited site count moves 95 -> 96 with its reason; the lib is loaded inside `Get-IssuesModel` on every read, with no `Get-Command` probe (`command-probe-lib.tests.ps1` refuses one), so the server keeps its start-up set (`connector-dashboard.tests.ps1` 127 pass)
- [x] `dev-pages.tests.ps1`: the groups, each card holding only its own rows, and a group with no page leaving its card out; 131 pass
- [x] The page is a visible result: it waits for the owner's look before it merges

### DEPLOY: feat/issues-page

The dev server's Repo hub has an **Issues** page: the open GitHub issues by priority and by where they
stand (free, parked on an `awaiting-*` label, or claimed), and the last 28 days of flow -- opened against
closed per week, and what was closed by kind, priority and how it was closed.

**Score:** 3

#### What makes this deploy extra special

N/A -- the page lives on this repo's own dev server; nothing a consumer installs changes.

**Score:** N/A

#### Pull Request

Adds `/issues` to the Repo hub of this repo's dev server: a map of the GitHub issues (the open board and
four weeks of flow), read with `gh` and cached for five minutes. A visible result, so it waits for the
owner's look before merging.