## fix/2052-handover-control-pinned-to-live

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

Two inbound reports against the same file pair in `dkj-policy-bwj`, taken on one branch because both
touch `PREVIEW-portable.md` and splitting them would only conflict there.

#### What the verification found -- and why the two issues end differently

**#2052 stands in full.** `Get-MarketHandoverPairs` returned `LiveUrl = $row.Url`, the bare storefront
URL, which is precisely the control form the chapter it claims to implement spends a measured table
ruling out. Confirmed verbatim in the source.

**#2054's symptom is real and its reason is disproven.** It reports that a `301` path drops
`preview_theme_id` and therefore lands the reviewer on live. The first half is true; the second is not.
Measured here September 17, 2026 against `smartwatch-straps.co.uk` on a fresh cookie jar: a `301` path
carrying the preview parameters rendered the **preview** theme (`200170373503`), not live
(`170064871700`). Shopify's own handshake `302` sets the preview cookie *before* the storefront's handle
redirect fires, so the preview survives it. The report's own table is also confounded -- it reads `200`
for `/collections/all`, which redirects too once the preview parameters are on it.

Building the repair #2054 proposes -- a per-path `200` gate -- would refuse correct cards, and run
against the preview URLs the function actually holds it would refuse *every* card. So it is closed on
the measurement, and the measurement is written into the chapter instead, because the inference is the
natural one and the next reader will make it too.

### CREATE

- [x] `Get-ControlThemeId`: resolve the live theme id from `-LiveThemeId`, else the consumer's
      `Get-ShopifyLiveThemeId` seam, using the inline `GetCommands` probe idiom `Get-MarketTable` argues for
- [x] `Get-MarketHandoverPairs`: pin `LiveUrl` to that id, resolved once before the loop
- [x] Throw rather than fall back -- a bare-URL fallback would silently rebuild the reported defect
- [x] `PREVIEW-portable.md`: record that the builder now does all three bullets, and that it did not before
- [x] `PREVIEW-portable.md`: the measured non-trap, so a redirect is not "repaired" by a later reader
- [~] A per-path `200`/HEAD check in the pair builder -- dropped: the measurement above shows it would
      refuse correct cards and, against preview URLs, all of them

### TEST

- [x] Two existing asserts pinned the defect (`the control half ... carries none`, and the bare-URL
      equality) -- inverted, with a comment saying a suite can hold a bug in place as firmly as code
- [x] New cases: explicit `-LiveThemeId` wins; the no-seam throw names the function and the file and
      hands back no URL; an empty seam answer is refused; the seam path pins the control
- [x] `Get-ControlThemeId` added to the superset export assertion
- [x] `bwj-market-urls.tests.ps1`: 95 pass, 0 fail
- [x] Full lint + test gate via `open-pr.ps1`
- [~] A test for the redirect measurement -- dropped: it asserts about a live storefront over the
      network, which is not this suite's job and would go red on any store change

### DEPLOY: fix/2052-handover-control-pinned-to-live

`Get-MarketHandoverPairs` returned the bare storefront URL as its control half -- the exact form
`PREVIEW-portable.md` rules out, because `preview_theme_id` sets a per-domain cookie and the bare URL
keeps rendering the *preview* once the preview link has been opened. Both tabs of a handover then
agreed and the reviewer concluded the change was not visible. The control is now pinned to the live
theme id, read from the consumer's own `Get-ShopifyLiveThemeId` seam or passed as `-LiveThemeId`, and
the builder **throws rather than falling back** -- a fallback would rebuild the same silent defect. Two
tests that had pinned the old behaviour were inverted.

The chapter also gains a measured section on what is *not* a trap: a `301` path drops
`preview_theme_id` from the address bar but does **not** lose the preview, because Shopify's handshake
sets the cookie before the handle redirect fires. That closes a second report which proposed gating
handovers on a per-path `200` -- a check that would have refused correct cards, and every card built
from a preview URL.

**Score:** 4

#### What makes this deploy extra special

Both BWJ stores build preview handovers through this function, so both have been publishing controls
in the wrong form. A reviewer who opened the preview link first saw the preview theme in *both* tabs
and reported the change as not visible -- a false negative on work that had shipped correctly. The fix
is invisible to a colleague but the handovers they receive stop lying to them.

**Score:** 3

#### Pull Request

The handover control URL is pinned to the live theme id

