## feat/2967-dev-preview-hook

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

Inbound #2967 (the owner, October 13, 2026): three DKJ-Solutions repos each carry their own dev-preview
SessionStart hook (dkj-brandbook, dkj-etf-tracker, life-hub, all three read on that date). Ship one in
the `dkj-solutions` extension, with what differs per repo behind a seam.

#### The design points the issue named, settled

- **Seam:** `Get-DevPreview` in `scripts/repo-config.ps1`, read in a child scope like the
  bwj-development hooks read theirs; absent means a silent no-op.
- **Ownership:** brandbook's command-line rule, generalised to the listener's four nearest ancestors,
  because the hook starts every server under a `cmd.exe` that changes into the root first. That also
  recognises a server whose own command line names no path (etf-tracker's `http.server`). Path-boundary
  matching keeps `repo-lanes`, `repo2` and `.claude/worktrees/` out.
- **Matcher:** `startup|resume|clear`. `compact` stays out, for etf-tracker's reason. `resume` is in,
  because a resumed session may well find its server gone.
- **VS Code:** `OpenInVsCode` keeps etf-tracker's `code --open-url` route, off by default. life-hub's note
  is about a `vscode://` handler, a different route, so the two do not contradict each other. Whether the
  Simple Browser opens is that repo's own `externalUriOpeners` setting, and this session had no VS Code to
  try it in.

### CREATE

- [x] `scripts/lib/dev-preview-rules.ps1` in the plugin: the seam's validation, the ownership rule, and
  the port choice, with no I/O.
- [x] `hooks/dev-preview-sessionstart.ps1` + `hooks/hooks.json`: read the seam, snapshot the sockets
  and processes, reuse or start, wait until it listens, and emit `systemMessage` + `additionalContext`.
- [x] README section, plus the plugin and marketplace descriptions. `CLAUDE.md` is untouched, because a
  hook needs no always-on rule.

### TEST

- [x] Review (Victor, Sebastian, Edith) worked in. The lines that reach the session are held to plain
  text (Name capped at 40 characters, Path a plain URL path, every printed line stripped of control
  characters and cut at 300). The process table is read only when a port has a listener (each read is
  about 0.4s). A server that dies at start ends the wait. A `Write-Host` in the config no longer breaks
  the JSON. A root holding `%` or `^` is refused. The README states the trust model.
- [x] `scripts/tests/dev-preview-sessionstart.tests.ps1`: 63 asserts, 11s. The rules are tested from
  hand-built tables, and the hook end to end: silent without the seam, one line on a bad seam, on a
  config that throws and on a missing prerequisite. A real loopback listener is started, then REUSED by
  a second run with exactly one listener left, and a second checkout refuses to take it as its own. The
  suite caught a PowerShell 5.1 trap in the reworked poll: a lone listener unrolled to a PSCustomObject
  whose `.Count` is `$null`, so the hook's own server read as not listening.

### DEPLOY: feat/2967-dev-preview-hook

`dkj-solutions` now ships a dev-preview SessionStart hook
([#2967](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2967)). A repo that states
`Get-DevPreview` in its `scripts/repo-config.ps1` (the command with `{port}`, the port or port range,
and optionally the URL path, a prerequisite and a VS Code hand-off) gets its local dev server started,
or reused, at `startup`, `resume` and `clear`. It also gets a clickable localhost link, which reaches
the session too. A server counts as this checkout's only when its command line, or its nearest
ancestors', names this checkout's root, so a foreign app, another clone or a worktree is never taken
for it. A repo that states nothing pays nothing. This replaces the per-repo copies in `dkj-brandbook`,
`dkj-etf-tracker` and `life-hub`, each of which can drop its own script and define the seam instead
([README](../plugins/dkj-policy/dkj-solutions/README.md#the-dev-preview-hook)).

**Score:** 3

#### What makes this deploy extra special

A DKJ-Solutions repo with a dev server gets its preview link at every session start by stating one
function, instead of copying and maintaining a hook of its own.

**Score:** 3

#### Pull Request

dkj-solutions ships the dev-preview SessionStart hook: a repo states Get-DevPreview and gets its localhost link at session start

