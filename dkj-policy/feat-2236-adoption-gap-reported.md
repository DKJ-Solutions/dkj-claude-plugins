## feat/2236-adoption-gap-reported

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

Declared adoption inventory in script-contract-lib, reported by check-script-contract as a non-counting
[UNADOPTED] token the session hook surfaces; Get-DeclinedAdoptions is the consumer's opt-out seam.

#### What the inbound verification changed about the repair

Inbound #2236 stands on all six checks -- the symptom reproduces (`update-plugins.ps1` and
`plugin-versions.ps1` contain no `adopt` reference at all, no session hook reports a missing floor file,
no audit entry point exists), the reason holds (`git log --follow` confirms the #1903 rename and the
#1843 / #1904 / #1972 scope growth), and every subject it names is in the tree. Two things it did not
have, both of which shaped what got built:

- **Its table of plausible reporters omits `check-connectors.ps1`'s check 6c** (#1850), which was built
  for almost exactly this question. It misses this case for a nameable reason: `Test-ConsumerRunnerAdoption`
  returns `adopted` the moment ONE workflow checks this tree out, so a consumer holding Part 1's
  `branch-entry.yml` and none of Part 3's runners reads green. It is also source-side, over the register,
  which answers the maintainer's question rather than the consumer's.
- **Its first proposal -- one entry point that runs each adopter's detect half -- does not survive.** The
  detection genuinely is there (every adopter is dry-run by default), but `adopt-ci-floor` and
  `adopt-triage-labels` reach `gh`, and all three file-placing adopters refuse outright in the repo that
  publishes this workflow, so such an entry point is network-bound and cannot be exercised here at all. A
  DECLARED inventory was built instead, held to the adopters' own target lists by a test.

### CREATE

- [x] `scripts/lib/script-contract-lib.ps1`: the adoption inventory (`Get-AdoptionInventory`) and the
      four-status verdict (`Get-AdoptionFindings`), beside the contract records that answer the neighbouring
      question about functions.
- [x] One new contract record: `Get-DeclinedAdoptions`, optional and `decide` -- the consumer's own opt-out,
      never an exemption list kept in the check.
- [x] `scripts/sync/check-script-contract.ps1`: the section that reports it, as the non-counting
      `[UNADOPTED]` token, with the two guards that keep it from being a nag.
- [x] `plugins/dkj-policy/hooks/script-contract-sessioncheck.ps1`: forwards that token on its own branch,
      independent of the drift chain.
- [x] Regenerated the config blueprint the new record belongs in, and the plugin mirror of both shared files.
- [~] A line in `update-plugins.ps1`, which the issue offered as its cheapest option. Dropped: the session
      check already runs in every consumer at every start, so the update-time line would be a second place
      to say the same thing, one of them firing less often.

### TEST

- [x] `scripts/tests/script-contract.tests.ps1`: seven new scenarios (12a-12g) pinning the four statuses
      apart, both guards, the hook forwarding, and the drift guard that holds `Places` to each adopter's own
      `Rel` literals in both directions.
- [x] Three existing count asserts bumped for the new record, each with the narration this suite asks for:
      the record total (43 -> 44), scenario 6e's `[INFO]` count (15 -> 16) and the `-SkipReachability`
      summary (9 -> 10).
- [x] Full suite green: 369 pass, 0 fail.
- [x] `check-plugin-integrity.ps1` green, including `[marker-column]`, which derives its subject set from the
      hooks and therefore judged the new `[UNADOPTED]` emissions without being told about them.

### DEPLOY: feat/2236-adoption-gap-reported

Every `adopt-*` command is safe to re-run and correctly finds nothing to do, and that is exactly why
nothing told an already-adopted repo when one of them GAINED a file. The script-contract session check now
reads which files each adoption part places and forwards what is missing as a non-counting `[UNADOPTED]`
line, wording a part that has *some* of its files ("has been run here and has since GAINED a file", naming
when that file joined) apart from one that has none. Two guards keep it from being a nag -- silent in a repo
with no workflow folder, and in the repo that publishes this workflow -- and a repo that decided against a
part names it in `Get-DeclinedAdoptions` to answer the line for good.

**Score:** 3

#### What makes this deploy extra special

A consumer learns at their next session start that part of their CI floor is missing, which until now they
could learn only by running the command they did not know existed. Measured in one: `xoxowildhearts` had
Part 1's entry gate and none of Part 3's three runners, so neither its fold nor its resolves verification
could survive a merge its shipping session never observed -- green on every check, for weeks. The register's
own detector could not see it, being any-or-none rather than per-command.

**Score:** 4

#### Pull Request

A consumer's session reports which adopt-* steps its tree is missing
