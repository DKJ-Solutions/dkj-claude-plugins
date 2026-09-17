## feat/2051-mirror-closeout-instrument

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

Mirror `scripts/maintenance/measure-closeouts.ps1` into `dkj-policy` so a consumer can run it:
registry entry, byte-identical mirror, its own skill page, and the two things the mirror turned out to
need.

#### What the verification found before any work started

**The subject did not exist on the trunk.** #2051 was filed from the #2048 investigation and names a
script that lived only on `fix/2048-closeout-repair-strategy` -- finished and green, but parked with no
PR. Every route to this issue ran through that branch landing, so it was shipped first as PR #2057
(Dave's call, asked because the alternative was stacking 29 commits of someone else's work under this
PR number). Nothing here duplicates it.

**The issue's own open question was answered rather than defaulted.** It flags that the nearest
precedent -- `measure-always-on`, registered under `measure-skill`'s page -- is the wrong home, since
that page's subject is what a *skill* costs in tokens. Decision: its own `measure-closeouts` page, at
the price of one more always-on description in every consumer (Dave, September 17, 2026).

#### And two things the mirror needed that the issue did not name

Both were found by reading the mirroring machinery rather than the report, and both are defects only
once the script travels:

- **No source-repo guard.** `measure-always-on.ps1` beside it carries `Assert-OwnCopy`; this did not.
  It matters more on an instrument than on a gate: a stale gate fails loudly, a stale measurement hands
  back a plausible number nobody can tell from a fresh one.
- **The baseline would have landed in the plugin cache.** `$PSScriptRoot\baselines\` is the committed
  baseline in this repo and the version-scoped cache in the mirror -- which the next
  `claude plugin update` replaces, losing a consumer's baseline silently.

### CREATE

- [x] Ship the prerequisite: PR #2057, `fix/2048-closeout-repair-strategy`, merged and folded
- [x] Register `measure-closeouts` in `Get-SharedScriptPairs`, with the reasoning for its own skill
- [x] Carry the source-repo guard, `$PSScriptRoot`-relative and `Test-Path`-guarded like every caller
- [x] Resolve the repo root dual-context, and land the baseline per copy -- beside the script in this
      repo, in the consumer's `dkj-policy/baselines/` from the mirror; `-BaselinePath` overrides both
- [x] Write `plugins/dkj-policy/skills/measure-closeouts/SKILL.md`, naming all six parameters
- [x] Generate the byte-identical mirror via `build-shared-scripts.ps1`
- [x] Add the four enumerating rows the gate demanded: two `skills:all` spans, `skills:plugin`,
      `shared-scripts:mirror`
- [~] A contract row in `check-script-contract` -- deliberately not added: nothing in the script is
      repo-owned, so there is no seam a consumer has to answer

### TEST

- [x] `closeout-measure.tests.ps1` -- 22 asserts, 6 new: the `-BaselinePath` override honoured, this
      repo's committed baseline provably untouched by it, the per-copy baseline rule, the dual-context
      resolution, and the guard
- [x] `shared-scripts.tests.ps1` 866 asserts (the mirror + the dual-context invariant, which caught the
      first attempt), `source-repo-guard.tests.ps1` 49
- [x] Full lint gate: 0 errors -- `skill-param` holds all six parameters against the page
- [x] Ran the instrument itself: finds the committed baseline, prints the delta, exits 0

### DEPLOY: feat/2051-mirror-closeout-instrument

The close-out instrument now ships to the consumers it measures worst. `measure-closeouts.ps1` landed
in #2048 as a source-repo maintenance script, which was the wrong way round for what it measures: per
repo, close-outs over the three-line ceiling ran `smartwatchbanden` 97%, `xoxowildhearts` 88%,
`claude-code-specialists` 86%, `thumbnail-generator` 67% -- and the repo that owns the instrument is
its best performer at 50%. The two worst were consumers who could not run it, and every close-out
complaint on the record came from a consumer.

It is registered, mirrored byte-identically into `dkj-policy`, and documented by its own
`measure-closeouts` skill page rather than filed under `measure-skill`'s, whose subject is what a skill
costs in tokens. Two things the mirror needed came with it: the source-repo guard, so a stale cached
copy is refused instead of reporting a plausible number, and a baseline that lands in the consumer's
own repo rather than in the plugin cache the next update replaces.

**Score:** 3

#### What makes this deploy extra special

A consumer of this workflow gains an instrument they could not run before, and it needs nothing
configured: it reads `~/.claude/projects` rather than the repo, is read-only, always exits 0, and only
counts leave it -- no transcript content -- so it is safe in a repo whose measurements are published
while its sessions stay private. It costs one more always-on skill description in every session that
enables `dkj-policy`, which was weighed and accepted rather than discovered.

**Score:** 3

#### Pull Request

The close-out instrument ships to the consumers whose rates are worst
