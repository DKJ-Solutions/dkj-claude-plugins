## fix/2003-json-case-collision-verdict

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

`Test-JsonFile` (`scripts/lint/check-plugin-integrity.ps1`) parsed with a bare `ConvertFrom-Json`
and reported every throw as `[JSON] <path> is not valid JSON: <message>`. Windows PowerShell 5.1
folds object keys case-insensitively and then refuses the collision it made itself, so a **valid**
document carrying two keys differing only in case reached that line and was accused of being
malformed -- the kind of accusation a reader acts on, by editing a file with nothing wrong with it.

Reproduced against the real case, the official marketplace's `lspServers.clangd.extensionToLanguage`
map, which legitimately lists `".c"` beside `".C"`.

#### Two things in the issue that did not stand, checked before the repair was built

- It says the repair must not reuse `ConvertFrom-MarketplaceJson`, which **#1993 added** to
  `scripts/lib/plugin-tree-lib.ps1`. That function does not exist: #1993 is still open and its
  branch `fix/1993-case-collision-json-reader` holds only its park commit. The *conclusion* is
  unaffected -- a generic validator must not hand its callers a three-field projection -- but there
  was nothing to decline to reuse.
- It offers changing only the **message** as the cheap option. That reads as matching the
  exception's text, and the text is localized: measured on this host, the same malformed document
  that reports `Invalid JSON primitive` in English reports `Ongeldige JSON-primitieve`. A verdict
  matched on it would be right in CI and silently wrong on a Dutch workstation.

#### So the repair is the issue's second shape, confined as it worded it

A case-sensitive reader answers the **validity question only**; `ConvertFrom-Json`'s object stays
the return value wherever it succeeds, so no caller sees a new type. `System.Web.Script.Serialization.JavaScriptSerializer`
is the case-sensitive reader available on 5.1; it refuses genuinely malformed JSON (verified against
four malformed documents) and reads a colliding one as written. It is .NET Framework only, so it
finds nothing under PowerShell 7 -- where `ConvertFrom-Json` is already case-sensitive and this path
is never reached.

The verdict **stays an error**. The gate could not parse the manifest, so every check that reads it
did not run, and a gate that passes a manifest it never read is worse than a wrong message. What
changed is the wording and where it sends the reader.

### CREATE

- [x] `Get-JsonCaseCollision` in `check-plugin-integrity.ps1` -- case-sensitive re-read, then an
      iterative walk reporting which keys collided and **where** (`lspServers.clangd.extensionToLanguage`,
      `plugins[1]`, or `at the top level`). Placed in that file rather than a lib, because the block
      directly above it states what a new dot-source costs the two fixtures that copy this script
- [x] `Test-JsonFile` tells the two failures apart; a genuinely malformed file keeps the message it
      always had, unchanged
- [x] scenario 55b in `check-plugin-integrity-docs.tests.ps1`, the mirror of scenario 55, over the
      real colliding document -- plus one assert added to 55 itself, so the pair proves the
      discrimination rather than only the new half

### TEST

- [x] `check-plugin-integrity-docs.tests.ps1`: 165 asserts, all pass (was 158 + the 7 new)
- [x] the gate run by hand against a corrupt marketplace and a colliding one: the first reports
      `is not valid JSON`, the second names the collision and its path, both reach `Summary:`
- [x] full local gate + lint via `open-pr.ps1`

#### The one bug this branch wrote and caught

`$collisions = if (...) { @(...) } else { @() }` yields `$null` under `Set-StrictMode`, because the
empty branch produces nothing to assign -- so `.Count` threw and killed the gate on the one path the
function exists to reach. Scenario 55 went red on a corrupt marketplace it had always tolerated,
which is precisely the value of asserting the mirror case beside the new one.

### DEPLOY: fix/2003-json-case-collision-verdict

`check-plugin-integrity`'s `Test-JsonFile` reported every parse failure as `is not valid JSON`,
which for one whole class of them is the opposite of the truth: Windows PowerShell 5.1's
`ConvertFrom-Json` folds object keys case-insensitively and then refuses the collision it made
itself, so a valid document carrying `.c` beside `.C` was accused of being malformed. It now
establishes validity with a case-sensitive reader before it judges, and where the file is sound it
says so and names which keys collided and where -- `'.C' and '.c' in lspServers.clangd.extensionToLanguage`,
which is the real map the official marketplace ships. Still an error, because the checks that read
the manifest did not run; what changed is that the reader is no longer sent to edit a correct file.
The diagnosis reads the document rather than the exception's message, which is localized.

**Score:** 2

Nothing in this repo is red today -- its own `marketplace.json` and `plugin.json` files carry no
collision and have no reason to. What was wrong was the gate's verdict for a document class that
provably exists, so this is noticed only by whoever meets it, and then it saves them from editing a
file that was already correct.

#### What makes this deploy extra special

`Test-JsonFile` is this repo's own lint, not plugin payload, so no consumer runs it -- the reach
label on the issue is one layer over from where the symptom is. #1993, still open, is the half that
reads the manifest a consumer installs from.

**Score:** N/A

#### Pull Request

Stop calling a case-colliding JSON file malformed
