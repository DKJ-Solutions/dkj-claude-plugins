## fix/3419-stale-install-by-content

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

#3419, a false positive from #3404 (PR #3416), reproduced on this repo's `brandbook/`: the lock was rewritten
18 minutes after the install and `npm ls` was clean, yet the line said `run npm install`.

### CREATE

- [x] The mtime stays as the cheap filter; a lock newer than the install record is then compared by content --
  every `node_modules/*` version it pins against npm's `node_modules/.package-lock.json`. Optional, devOptional
  and peer packages may be absent; an unreadable file claims nothing.
- [x] Parsed with `JavaScriptSerializer`, because 5.1's `ConvertFrom-Json` refuses the lock's `""` root key
  (measured).
- [x] The hub README row says so.

### TEST

- [x] `dev-preview-sessionstart.tests.ps1`: another version is named, a rewritten lock with the same versions is
  not, an optional package for another platform may be missing, a missing package is named, an unreadable
  record claims nothing (359 passed standalone). The measured `brandbook/` case now reads as matching, in 55 ms.

### DEPLOY: fix/3419-stale-install-by-content

dev-preview's `run npm install` note now fires only where the install really differs from the lock
([#3419](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3419)). The note added in #3404 compared
file times, and git rewrites `package-lock.json` on any commit or checkout that touches it. In this repo it fired
on an install that `npm ls` called clean. A lock newer than npm's own install record is now compared by content:
every package version it pins against `node_modules/.package-lock.json`. The note appears only where a package is
installed at another version, or not at all. Optional packages for other platforms never count.

**Score:** 2

#### What makes this deploy extra special

A consumer no longer gets a `run npm install` note on every session after a pull or checkout that rewrote the
lock without changing what it pins.

**Score:** 2

#### Pull Request

dev-preview's stale-install note compares the lock's content with the install, not its time

