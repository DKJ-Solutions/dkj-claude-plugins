## fix/1993-case-collision-json-reader

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Issue #1993, verified against the tree before anything was written: the symptom reproduces on this
host (5.1.26100.9444), the collision in the official marketplace is real and legitimate, and the
reason the issue gives is the reason. What the issue did NOT know is the constraint that decided the
shape -- a `PSObject` refuses a second property differing only in case exactly as the hashtable does,
so there is no 5.1 container that can hold the document as written and a faithful reparse was never
on the table.

### CREATE

- [x] `ConvertFrom-MarketplaceJson` in `../scripts/lib/plugin-tree-lib.ps1`, and `Get-PluginRoots`
      reads through it.
- [x] The skip rule for a url source, `IsLocal` on every returned object, and `-IncludeRemote` for
      the one caller that has to tell the two absences apart.
- [x] The third verdict branch in `../scripts/task/plugin-versions.ps1`, so a url-sourced plugin is
      no longer sent to a refresh that cannot help it.
- [x] Both plugin mirrors regenerated (`../scripts/sync/build-shared-scripts.ps1`).

### TEST

- [x] New asserts in `../scripts/tests/release-lib.tests.ps1`, including one pinning the PREMISE --
      that `ConvertFrom-Json` still refuses a case collision on this host -- so the day the platform
      fixes this, the suite says so instead of the fallback quietly becoming dead code.
- [x] Measured live against the real colliding manifest: 296 declared, 52 with a path source, all 52
      resolving; `plugin-versions` reports `shopify-ai-toolkit` correctly.
- [x] Lint gate green, all 105 suites green.
- [x] Victor (code review) and Sebastian (security review) on the diff.

### DEPLOY: fix/1993-case-collision-json-reader

A marketplace manifest that Windows PowerShell 5.1's own JSON reader refuses can be read again.

5.1's `ConvertFrom-Json` folds object keys case-insensitively and then refuses the collision it made
itself, so a *valid* manifest carrying two keys differing only in case could not be parsed at all --
and the official marketplace carries exactly such a pair, an `lspServers.clangd` extension map
listing `.c` beside `.C`. Every plugin from that marketplace was therefore permanently
`cannot determine` in `plugin-versions`, `update-plugins`' step-3 receipt could never verify what its
step 2 had done for them, and nothing a consumer ran changed it: the state was stable, not transient.
`#1987` had already stopped the tool prescribing a refresh that provably cannot help; this is the
reading itself.

`ConvertFrom-MarketplaceJson` keeps `ConvertFrom-Json` as the only path an ordinary document takes,
and falls back to a case-sensitive reader for the documents it refuses. The fallback is **lazy**, so
the header's no-dependencies rule survives where it was written to hold: nothing extra is loaded on
the path `check-connectors.ps1` takes at every SessionStart. It triggers on **any** parse failure
rather than on the error message -- an exception message is not a contract, and matching one is not
merely risky but unnecessary: a failure that is not a case collision fails in the second reader too,
and then the original exception is what the caller sees. The discriminating is done by trying.

Two things the issue could not have known, both found by measuring rather than by reading it:

- **A faithful reparse is impossible on 5.1**, because a `PSObject` rejects the colliding property
  for the same reason the hashtable does. So the fallback does not pretend to return the document: it
  projects the three fields this repo consumes, and everything else is dropped by design rather than
  lost by accident -- checkable, because exactly two functions parse a marketplace document anywhere
  in the repo, and both now read through it. Routing only the first would have moved the symptom four
  lines down `cut-release.ps1` rather than removed it.
- **Making the document readable made a second branch reachable that had never had to be decided.**
  244 of that manifest's 296 entries declare a *url* source rather than a path -- the majority shape
  in a real catalogue -- and resolving one produces a root that is a stringified type name. Those are
  now skipped: a plugin fetched from a url does not live in this tree, and one of them must not cost
  the whole catalogue, which would have been #1993's own symptom in a new costume.

That skip made `plugin-versions` say `'x' is not listed in the clone's marketplace.json` about a
plugin that plainly is, and send the reader to a marketplace refresh -- the third loop of the shape
#1987 had just finished splitting apart. So `-IncludeRemote` lets that one caller tell *declared
elsewhere* from *not declared*, and the row now says the version cannot be read because the payload
is fetched from a url, with nothing to run, because nothing is broken.

**Score:** 3

#### What makes this deploy extra special

N/A. This repo's own consumers read `plugin-versions` and `update-plugins`, and both get a truthful
answer where they previously got a permanent `cannot determine` and an instruction that could not
work -- but it reaches no subscriber of a service, because there is none.

**Score:** N/A

#### Pull Request

A marketplace manifest with case-colliding JSON keys is readable again
